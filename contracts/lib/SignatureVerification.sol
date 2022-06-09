// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { EIP1271Interface } from "../interfaces/EIP1271Interface.sol";

// prettier-ignore
import {
    SignatureVerificationErrors
} from "../interfaces/SignatureVerificationErrors.sol";

import { LowLevelHelpers } from "./LowLevelHelpers.sol";

import "./ConsiderationConstants.sol";

/**
 * @title SignatureVerification
 * @author 0age
 * @notice SignatureVerification contains logic for verifying signatures.
 */
contract SignatureVerification is SignatureVerificationErrors, LowLevelHelpers {
    /**
     * @dev Internal view function to verify the signature of an order. An
     *      ERC-1271 fallback will be attempted if either the signature length
     *      is not 32 or 33 bytes or if the recovered signer does not match the
     *      supplied signer.
     *
     * @param signer    The signer for the order.
     * @param digest    The digest to verify the signature against.
     * @param signature A signature from the signer indicating that the order
     *                  has been approved.
     */
    function _assertValidSignature(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) internal view {
        // Declare r, s, and v signature parameters.
        uint8 v;
        address recoveredSigner;
        bool success;

        assembly {
            // Get the length of the signature
            let signatureLength := mload(signature)
            // Take the difference between the max ECDSA signature length
            // and the actual signature length. Overflow desired for values > 65.
            // If the diff is not 0 or 1, it is not a valid ECDSA signature - move
            // on to EIP1271 check.
            let lenDiff := sub(ECDSA_MaxLength, signatureLength)

            // Get the pointer to the value preceding the signature length.
            // This will be used for temporary memory overrides - either the
            // signature head for isValidSignature or the digest for ecrecover.
            let wordBeforeSignaturePtr := sub(signature, OneWord)

            // Cache the current value behind the signature to restore it later.
            let cachedWordBeforeSignature := mload(wordBeforeSignaturePtr)

            // If diff is 0 or 1, it may be an ECDSA signature. Try to recover signer.
            if lt(lenDiff, 2) {
                // Read the signature `s` value.
                let originalSignatureS := mload(
                    add(signature, ECDSA_signature_s_offset)
                )

                // Read the first byte of the word after `s`. If the signature is 65
                // bytes, this will be the real `v` value. If not, we will have to
                // modify it - doing it this way saves an extra condition.
                v := byte(0, mload(add(signature, ECDSA_signature_v_offset)))

                if eq(lenDiff, 1) {
                    // Extract yParity from highest bit of vs and add 27 to get v.
                    v := add(shr(255, originalSignatureS), 27)

                    // Extract canonical s from vs (all but the highest bit).
                    // Temporarily overwrite the original `s` value in the signature.
                    mstore(
                        add(signature, ECDSA_signature_s_offset),
                        and(originalSignatureS, EIP2098_allButHighestBitMask)
                    )
                }
                // Temporarily overwrite the signature length with `v` to conform to
                // the expected input for ecrecover.
                mstore(signature, v)

                // Temporarily overwrite the word before the length with `digest` to
                // conform to the expected input for ecrecover.
                mstore(wordBeforeSignaturePtr, digest)

                // Attempt to recover the signer for the given signature. We do not need
                // the call status as ecrecover will return a null address if the signature
                // is invalid.
                pop(staticcall(5000, 1, wordBeforeSignaturePtr, 0x80, 0, 0x20))

                // Restore cached word before signature
                mstore(wordBeforeSignaturePtr, cachedWordBeforeSignature)

                // Restore cached signature length
                mstore(signature, signatureLength)

                // Restore cached signature `s` value
                mstore(
                    add(signature, ECDSA_signature_s_offset),
                    originalSignatureS
                )

                // Read the recovered signer from the buffer given as return space for ecrecover.
                recoveredSigner := mload(0)
            }
            // Set success to true if the signature provided was a valid ECDSA signature.
            success := eq(signer, recoveredSigner)

            // If the signature was not verified with ecrecover, try EIP1271.
            if iszero(success) {
                // Temporarily overwrite the word before the signature length and use it as the
                // head of the signature input to `isValidSignature`, which has a value of 64.
                mstore(wordBeforeSignaturePtr, 0x40)
                // Get the pointer to use for the selector of `isValidSignature`.
                let selectorPtr := sub(
                    signature,
                    EIP1271_isValidSignature_selector_negativeOffset
                )
                // Cache the value currently stored at the selector pointer
                let cachedWordOverwrittenBySelector := mload(selectorPtr)

                // Get the pointer to use for the `digest` input to `isValidSignature`.
                let digestPtr := sub(
                    signature,
                    EIP1271_isValidSignature_digest_negativeOffset
                )
                // Cache the value currently stored at the digest pointer
                let cachedWordOverwrittenByDigest := mload(digestPtr)

                // Write the selector first, since it overlaps the digest.
                mstore(
                    selectorPtr,
                    EIP1271_isValidSignature_selector
                )
                // Write digest next
                mstore(digestPtr, digest)
                // Call the signer with `isValidSignature` to validate the signature.
                success := staticcall(
                    gas(),
                    signer,
                    selectorPtr,
                    add(signatureLength, EIP1271_isValidSignature_calldata_baseLength),
                    0,
                    0x20
                )
                // Restore the cached values overwritten by selector, digest and signature head.
                mstore(wordBeforeSignaturePtr, cachedWordBeforeSignature)
                mstore(selectorPtr, cachedWordOverwrittenBySelector)
                mstore(digestPtr, cachedWordOverwrittenByDigest)

                if success {
                    // If returndata is not 32 bytes with the 1271 valid signature
                    // selector, revert
                    if iszero(
                        and(
                            eq(mload(0), EIP1271_isValidSignature_selector),
                            eq(returndatasize(), 0x20)
                        )
                    ) {
                        // If signer is a contract, revert with bad 1271 signature
                        if extcodesize(signer) {
                            // bad contract signature
                            mstore(0, BadContractSignature_error_signature)
                            revert(0, BadContractSignature_error_length)
                        }
                        // Check if v was invalid
                        if iszero(
                            byte(v, ECDSA_twentySeventhAndTwentyEighthBytesSet)
                        ) {
                            // v is invalid, revert with invalid v value
                            mstore(0, BadSignatureV_error_signature)
                            mstore(BadSignatureV_error_offset, v)
                            revert(0, 0x24)
                        }
                        // Revert with generic invalid signer error message
                        mstore(0, InvalidSigner_error_signature)
                        revert(0, InvalidSigner_error_length)
                    }
                }
            }
        }
        // If the call fails...
        if (!success) {
            // Revert and pass reason along if one was returned.
            _revertWithReasonIfOneIsReturned();
            assembly {
                mstore(0, BadContractSignature_error_signature)
                revert(0, BadContractSignature_error_length)
            }
        }
    }
}
