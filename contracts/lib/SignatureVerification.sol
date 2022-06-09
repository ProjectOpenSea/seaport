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
        address recoveredSigner;

        assembly {
            let len := mload(signature)
            let lenDiff := sub(65, len)
            if lt(lenDiff, 2) {
                // Place first word on the stack at r.
                r := mload(add(signature, OneWord))
                // Place second word on the stack at s.
                s := mload(add(signature, TwoWords))
                v := byte(0, mload(add(signature, ThreeWords)))
                if iszero(lenDiff) {
                    // Extract canonical s from vs (all but the highest bit).
                    s := and(s, EIP2098_allButHighestBitMask)
                    // Extract yParity from highest bit of vs and add 27 to get v.
                    v := add(shr(255, s), 27)
                }
            }
        }
        recoveredSigner = ecrecover(digest, v, r, s);

        // Don't need an explicit address(0) check
        if (recoveredSigner != signer) {
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
                    mstore(0, BadContractSignature_error_signature)
                    revert(0, BadContractSignature_error_length)
                }
            }

            assembly {
              returndatacopy(0, 0, 0x20)
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
}
