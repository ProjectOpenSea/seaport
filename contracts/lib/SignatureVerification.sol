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
            let len := mload(signature)
            let lenDiff := sub(ECDSA_MaxLength, len)
            let ptrBeforeSignature := sub(signature, OneWord)
            let oldValue := mload(ptrBeforeSignature)
            if lt(lenDiff, 2) {
                // Place first word on the stack at r.
                // let r := mload(add(signature, OneWord))
                // Place second word on the stack at s.
                let originalS := mload(add(signature, TwoWords))
                v := byte(0, mload(add(signature, ThreeWords)))
                if eq(lenDiff, 1) {
                    // Extract canonical s from vs (all but the highest bit).
                    // s := and(s, EIP2098_allButHighestBitMask)
                    // Extract yParity from highest bit of vs and add 27 to get v.
                    // v := add(shr(255, s), 27)

                    v := add(shr(255, originalS), 27)
                    mstore(
                        add(signature, TwoWords),
                        and(originalS, EIP2098_allButHighestBitMask)
                    )
                }
                mstore(signature, v)
                mstore(ptrBeforeSignature, digest)
                pop(staticcall(5000, 1, ptrBeforeSignature, 0x80, 0, 0x20))
                mstore(ptrBeforeSignature, oldValue)
                mstore(signature, len)
                mstore(add(signature, TwoWords), originalS)
                recoveredSigner := mload(0)
            }
            success := eq(signer, recoveredSigner)
            if iszero(success) {
                mstore(ptrBeforeSignature, 0x40)
                let ptr2WordsBeforeSignature := sub(ptrBeforeSignature, 0x20)
                let ptr2AndAnEighthWordsBeforeSignature := sub(
                    ptr2WordsBeforeSignature,
                    0x4
                )
                let oldValue2 := mload(ptr2WordsBeforeSignature)
                let oldValue3 := mload(ptr2AndAnEighthWordsBeforeSignature)
                mstore(
                    ptr2AndAnEighthWordsBeforeSignature,
                    EIP1271_isValidSignature_selector
                )
                mstore(ptr2WordsBeforeSignature, digest)
                success := staticcall(
                    gas(),
                    signer,
                    ptr2AndAnEighthWordsBeforeSignature,
                    add(len, 0x64),
                    0,
                    0x20
                )
                mstore(ptrBeforeSignature, oldValue)
                mstore(ptr2AndAnEighthWordsBeforeSignature, oldValue3)
                mstore(ptr2WordsBeforeSignature, oldValue2)

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
