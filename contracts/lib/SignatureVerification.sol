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
        bytes32 r;
        bytes32 s;
        uint8 v;

        // If signature contains 64 bytes, parse as EIP-2098 signature (r+s&v).
        if (signature.length == 64) {
            // Declare temporary vs that will be decomposed into s and v.
            bytes32 vs;

            // Read each parameter directly from the signature's memory region.
            assembly {
                // Put the first word from the signature onto the stack as r.
                r := mload(add(signature, OneWord))

                // Put the second word from the signature onto the stack as vs.
                vs := mload(add(signature, TwoWords))

                // Extract canonical s from vs (all but the highest bit).
                s := and(vs, EIP2098_allButHighestBitMask)

                // Extract yParity from highest bit of vs and add 27 to get v.
                v := add(shr(255, vs), 27)
            }
        } else if (signature.length == 65) {
            // Whether v value is not properly formatted.
            bool vIsInvalid;

            // If signature is 65 bytes, parse as a standard signature (r+s+v).
            // Read each parameter directly from the signature's memory region.
            assembly {
                // Place first word on the stack at r.
                r := mload(add(signature, OneWord))

                // Place second word on the stack at s.
                s := mload(add(signature, TwoWords))

                // Place final byte on the stack at v.
                v := byte(0, mload(add(signature, ThreeWords)))

                // Whether v is not 27 or 28.
                // The magic constant has the 27th and 28th bytes
                // counting from the most significant byte set to 1.
                vIsInvalid := iszero(
                    byte(v, ECDSA_twentySeventhAndTwentyEighthBytesSet)
                )
            }

            // Ensure v value is properly formatted.
            if (vIsInvalid) {
                // Revert with BadSignatureV(v) and passed the error to EIP-1271 signature verification.
                assembly {
                    mstore(0, BadSignatureV_error_signature)
                    mstore(BadSignatureV_error_offset, v)
                }
                
                _assertValidEIP1271Signature(signer, digest, BadSignatureV_error_length, signature);
            }
        } else {
            // For all other signature lengths, try verification via EIP-1271.
            // Attempt EIP-1271 static call to signer in case it's a contract.
            _assertValidEIP1271Signature(signer, digest, 0, signature);

            // Return early if the ERC-1271 signature check succeeded.
            return;
        }

        // Attempt to recover signer using the digest and signature parameters.
        address recoveredSigner = ecrecover(digest, v, r, s);

        // Disallow invalid signers.
        if (recoveredSigner == address(0)) {
            // Revert with InvalidSignature and passed the error to EIP-1271 signature verification.
            assembly {
                mstore(0, InvalidSignature_error_signature)
            }

            _assertValidEIP1271Signature(signer, digest, InvalidSignature_error_length, signature);
            // Should a signer be recovered, but it doesn't match the signer...
        } else if (recoveredSigner != signer) {
            // Attempt EIP-1271 static call to signer in case it's a contract.
            _assertValidEIP1271Signature(signer, digest, 0, signature);
        }
    }

    /**
     * @dev Internal view function to verify the signature of an order using
     *      ERC-1271 (i.e. contract signatures via `isValidSignature`). Note
     *      that, in contrast to standard ECDSA signatures, 1271 signatures may
     *      be valid in certain contexts and invalid in others, or vice versa;
     *      orders that validate signatures ahead of time must explicitly cancel
     *      those orders to invalidate them.
     *
     * @param signer    The signer for the order.
     * @param digest    The signature digest, derived from the domain separator
     *                  and the order hash.
     * @param signature A signature (or other data) used to validate the digest.
     */
    function _assertValidEIP1271Signature(
        address signer,
        bytes32 digest,
        uint256 errorLength,
        bytes memory signature
    ) internal view {
        // Attempt an EIP-1271 staticcall to the signer.
        bool success = _staticcall(
            signer,
            abi.encodeWithSelector(
                EIP1271Interface.isValidSignature.selector,
                digest,
                signature
            )
        );

        // If the call fails...
        if (!success) {
            // Revert and pass reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            assembly {
                // If error is not passed from _assertValidSignature, revert with BadContractSignature().
                if iszero(errorLength) {
                    mstore(0, BadContractSignature_error_signature)
                    revert(0, BadContractSignature_error_length)
                }

                // If error is passed from _assertValidSignature, revert with passed error.
                revert(0, errorLength)
            }
        }

        // Ensure result was extracted and matches EIP-1271 magic value.
        if (_doesNotMatchMagic(EIP1271Interface.isValidSignature.selector)) {
            assembly {
                // If error is not passed from _assertValidSignature, revert with InvalidSigner().
                if iszero(errorLength) {
                    mstore(0, InvalidSigner_error_signature)
                    revert(0, InvalidSigner_error_length)
                }

                // If error is passed from _assertValidSignature, revert with passed error.
                revert(0, errorLength)
            }
        }
    }
}
