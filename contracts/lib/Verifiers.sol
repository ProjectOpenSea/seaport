// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OrderStatus } from "./ConsiderationStructs.sol";

import { Assertions } from "./Assertions.sol";

import { SignatureVerification } from "./SignatureVerification.sol";

import "./ConsiderationErrors.sol";

/**
 * @title Verifiers
 * @author 0age
 * @notice Verifiers contains functions for performing verifications.
 */
contract Verifiers is Assertions, SignatureVerification {
    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param conduitController A contract that deploys conduits, or proxies
     *                          that may optionally be used to transfer approved
     *                          ERC20/721/1155 tokens.
     */
    constructor(address conduitController) Assertions(conduitController) {}

    /**
     * @dev Internal view function to ensure that the current time falls within
     *      an order's valid timespan.
     *
     * @param startTime       The time at which the order becomes active.
     * @param endTime         The time at which the order becomes inactive.
     * @param revertOnInvalid A boolean indicating whether to revert if the
     *                        order is not active.
     *
     * @return valid A boolean indicating whether the order is active.
     */
    function _verifyTime(
        uint256 startTime,
        uint256 endTime,
        bool revertOnInvalid
    ) internal view returns (bool valid) {
        // Mark as valid if order has started and has not already ended.
        assembly {
            valid := and(
                iszero(gt(startTime, timestamp())),
                gt(endTime, timestamp())
            )
        }

        // Only revert on invalid if revertOnInvalid has been supplied as true.
        if (revertOnInvalid && !valid) {
            _revertInvalidTime(startTime, endTime);
        }
    }

    /**
     * @dev Internal view function to verify the signature of an order. An
     *      ERC-1271 fallback will be attempted if either the signature length
     *      is not 64 or 65 bytes or if the recovered signer does not match the
     *      supplied offerer. Note that in cases where a 64 or 65 byte signature
     *      is supplied, only standard ECDSA signatures that recover to a
     *      non-zero address are supported.
     *
     * @param offerer   The offerer for the order.
     * @param orderHash The order hash.
     * @param signature A signature from the offerer indicating that the order
     *                  has been approved.
     */
    function _verifySignature(
        address offerer,
        bytes32 orderHash,
        bytes memory signature
    ) internal view {
        // Skip signature verification if the offerer is the caller.
        if (_unmaskedAddressComparison(offerer, msg.sender)) {
            return;
        }

        bytes32 domainSeparator = _domainSeparator();

        // Derive original EIP-712 digest using domain separator and order hash.
        bytes32 originalDigest = _deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        uint256 originalSignatureLength = signature.length;

        bytes32 digest;
        if (_isValidBulkOrderSize(signature)) {
            // Rederive order hash and digest using bulk order proof.
            (orderHash) = _computeBulkOrderProof(signature, orderHash);
            digest = _deriveEIP712Digest(domainSeparator, orderHash);
        } else {
            digest = originalDigest;
        }

        // Ensure that the signature for the digest is valid for the offerer.
        _assertValidSignature(
            offerer,
            digest,
            originalDigest,
            originalSignatureLength,
            signature
        );
    }

    /**
     * @dev Determines whether the specified bulk order size is valid.
     *
     * @param signature    The signature of the bulk order to check.
     *
     * @return validLength True if the bulk order size is valid, false otherwise.
     */
    function _isValidBulkOrderSize(
        bytes memory signature
    ) internal pure returns (bool validLength) {
        assembly {
            validLength := lt(
                sub(mload(signature), EIP712_BulkOrder_minSize),
                2
            )
        }
    }

    /**
     * @dev Computes the bulk order hash for the specified proof and leaf.
     *
     * @param proofAndSignature  The proof and signature of the bulk order.
     * @param leaf               The leaf of the bulk order tree.
     *
     * @return bulkOrderHash     The bulk order hash.
     */
    function _computeBulkOrderProof(
        bytes memory proofAndSignature,
        bytes32 leaf
    ) internal view returns (bytes32 bulkOrderHash) {
        bytes32 root;

        assembly {
            // Set length to just the size of the signature
            let length := sub(
                mload(proofAndSignature),
                BulkOrderProof_proofAndKeySize
            )
            mstore(proofAndSignature, length)

            let keyPtr := add(proofAndSignature, add(0x20, length))
            let key := shr(248, mload(keyPtr))
            let proof := add(keyPtr, 1)

            // Compute level 1
            let scratch := shl(5, and(key, 1))
            mstore(scratch, leaf)
            mstore(xor(scratch, OneWord), mload(proof))

            // Compute level 2
            scratch := shl(5, and(shr(1, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), mload(add(proof, 0x20)))

            // Compute level 3
            scratch := shl(5, and(shr(2, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), mload(add(proof, 0x40)))

            // Compute level 4
            scratch := shl(5, and(shr(3, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), mload(add(proof, 0x60)))

            // Compute level 5
            scratch := shl(5, and(shr(4, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), mload(add(proof, 0x80)))

            // Compute level 6
            scratch := shl(5, and(shr(5, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), mload(add(proof, 0xa0)))

            // Compute root hash
            scratch := shl(5, and(shr(6, key), 1))
            mstore(scratch, keccak256(0, TwoWords))
            mstore(xor(scratch, OneWord), mload(add(proof, 0xc0)))
            root := keccak256(0, TwoWords)
        }

        bytes32 rootTypeHash = _BULK_ORDER_TYPEHASH;
        assembly {
            mstore(0, rootTypeHash)
            mstore(0x20, root)
            bulkOrderHash := keccak256(0, 0x40)
        }
    }

    /**
     * @dev Internal view function to validate that a given order is fillable
     *      and not cancelled based on the order status.
     *
     * @param orderHash       The order hash.
     * @param orderStatus     The status of the order, including whether it has
     *                        been cancelled and the fraction filled.
     * @param onlyAllowUnused A boolean flag indicating whether partial fills
     *                        are supported by the calling function.
     * @param revertOnInvalid A boolean indicating whether to revert if the
     *                        order has been cancelled or filled beyond the
     *                        allowable amount.
     *
     * @return valid          A boolean indicating whether the order is valid.
     */
    function _verifyOrderStatus(
        bytes32 orderHash,
        OrderStatus storage orderStatus,
        bool onlyAllowUnused,
        bool revertOnInvalid
    ) internal view returns (bool valid) {
        // Ensure that the order has not been cancelled.
        if (orderStatus.isCancelled) {
            // Only revert if revertOnInvalid has been supplied as true.
            if (revertOnInvalid) {
                _revertOrderIsCancelled(orderHash);
            }

            // Return false as the order status is invalid.
            return false;
        }

        // Read order status numerator from storage and place on stack.
        uint256 orderStatusNumerator = orderStatus.numerator;

        // If the order is not entirely unused...
        if (orderStatusNumerator != 0) {
            // ensure the order has not been partially filled when not allowed.
            if (onlyAllowUnused) {
                // Always revert on partial fills when onlyAllowUnused is true.
                _revertOrderPartiallyFilled(orderHash);
            }
            // Otherwise, ensure that order has not been entirely filled.
            else if (orderStatusNumerator >= orderStatus.denominator) {
                // Only revert if revertOnInvalid has been supplied as true.
                if (revertOnInvalid) {
                    _revertOrderAlreadyFilled(orderHash);
                }

                // Return false as the order status is invalid.
                return false;
            }
        }

        // Return true as the order status is valid.
        valid = true;
    }
}
