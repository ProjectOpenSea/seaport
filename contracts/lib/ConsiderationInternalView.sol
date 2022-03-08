// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { EIP1271Interface } from "../interfaces/EIP1271Interface.sol";

import { OrderType } from "./ConsiderationEnums.sol";

import {
    OfferedItem,
    ReceivedItem,
    OrderParameters,
    Order,
    AdvancedOrder,
    OrderStatus
} from "./ConsiderationStructs.sol";

import { ConsiderationPure } from "./ConsiderationPure.sol";

/**
 * @title ConsiderationInternalView
 * @author 0age
 * @notice ConsiderationInternal contains all internal view functions.
 */
contract ConsiderationInternalView is ConsiderationPure {
    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param legacyProxyRegistry         A proxy registry that stores per-user
     *                                    proxies that may optionally be used to
     *                                    transfer approved tokens.
     * @param requiredProxyImplementation The implementation that must be set on
     *                                    each proxy in order to utilize it.
     */
    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) ConsiderationPure(legacyProxyRegistry, requiredProxyImplementation) {}

    /**
     * @dev Internal view function to ensure that the sentinel value for the
            reentrancy guard is not currently set.
     */
    function _assertNonReentrant() internal view {
        // Ensure that the reentrancy guard is not currently set.
        if (_reentrancyGuard == _ENTERED) {
            revert NoReentrantCalls();
        }
    }

    /**
     * @dev Internal view function to ensure that the current time falls within
     *      an order's valid timespan.
     *
     * @param startTime The time at which the order becomes active.
     * @param endTime   The time at which the order becomes inactive.
     */
    function _assertValidTime(
        uint256 startTime,
        uint256 endTime
    ) internal view {
        // Revert if order's timespan hasn't started yet or has already ended.
        if (startTime > block.timestamp || endTime < block.timestamp) {
            revert InvalidTime();
        }
    }

    /**
     * @dev Internal view function to validate whether a token transfer was
     *      successful based on the returned status and data. Note that
     *      malicious or non-compliant tokens (like fee-on-transfer tokens) may
     *      still return improper data — consider checking token balances before
     *      and after for more comprehensive transfer validation. Also note that
     *      this function must be called after the account in question has been
     *      called and before any other contracts have been called.
     *
     * @param ok      The status of the call to transfer. Note that contract
     *                size must be checked on status of true and no returned
     *                data to rule out undeployed contracts.
     * @param token   The token to transfer.
     * @param from    The originator of the transfer.
     * @param to      The recipient of the transfer.
     * @param tokenId The tokenId to transfer (if applicable).
     * @param amount  The amount to transfer (if applicable).
     */
    function _assertValidTokenTransfer(
        bool ok,
        address token,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal view {
        // If the call failed...
        if (!ok) {
            // Revert and pass reason along if one was returned from the token.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic error.
            revert TokenTransferGenericFailure(
                token,
                from,
                to,
                tokenId,
                amount
            );
        }

        // Ensure that the token contract has code.
        _assertContractIsDeployed(token);
    }

    /**
     * @dev Internal view function to item that a contract is deployed to a
     *      given account. Note that this function must be called after the
     *      account in question has been called and before any other contracts
     *      have been called.
     *
     * @param account The account to check.
     */
    function _assertContractIsDeployed(address account) internal view {
        // Find out whether data was returned by inspecting returndata buffer.
        uint256 returnDataSize;
        assembly {
            returnDataSize := returndatasize()
        }

        // If no data was returned...
        if (returnDataSize == 0) {
            // get the codesize of the account.
            uint256 size;
            assembly {
                size := extcodesize(account)
            }

            // Ensure that the account has code.
            if (size == 0) {
                revert NoContract(account);
            }
        }
    }

    /**
     * @dev Internal view function to retrieve the order status and verify it.
     *
     * @param orderHash       The order hash.
     * @param offerer         The offerer for the order.
     * @param signature       A signature from the offerer indicating that the
     *                        order has been approved.
     * @param onlyAllowUnused A boolean flag indicating whether partial fills
     *                        are supported by the calling function.
     *
     * @return numerator   The amount filled on the order.
     * @return denominator The total fill size of the order.
     */
    function _verifyOrder(
        bytes32 orderHash,
        address offerer,
        bytes memory signature,
        bool onlyAllowUnused
    ) internal view returns (uint256 numerator, uint256 denominator) {
        // Retrieve the order status for the given order hash.
        OrderStatus memory orderStatus = _orderStatus[orderHash];

        // Ensure order is fillable and retrieve the filled amount.
        (numerator, denominator) = _validateOrderStatus(
            orderHash,
            orderStatus,
            onlyAllowUnused
        );

        // If the order is not already validated, verify the supplied signature.
        if (!orderStatus.isValidated) {
            _verifySignature(
                offerer, orderHash, signature
            );
        }

        // Return the filled amount for the order in question.
        return (numerator, denominator);
    }

    /**
     * @dev Internal view function to verify the signature of an order. An
     *      ERC-1271 fallback will be attempted should the recovered signature
     *      not match the supplied offerer. Note that only 32-byte or 33-byte
     *      ECDSA signatures are supported.
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
        if (offerer == msg.sender) {
            return;
        }

        // Derive EIP-712 digest using the domain separator and the order hash.
        bytes32 digest = _hashDigest(_domainSeparator(), orderHash);

        // Declare r, s, and v signature parameters.
        bytes32 r;
        bytes32 s;
        uint8 v;

        // If signature contains 65 bytes, parse as standard signature. (r+s+v)
        if (signature.length == 65) {
            // Read each parameter directly from the signature's memory region.
            assembly {
                r := mload(add(signature, 0x20)) // Put first word on stack at r
                s := mload(add(signature, 0x40)) // Put next word on stack at s
                v := byte(0, mload(add(signature, 0x60))) // Put last byte at v
            }

            // Ensure v value is properly formatted.
            if (v != 27 && v != 28) {
                revert BadSignatureV(v);
            }
        // If signature contains 64 bytes, parse as EIP-2098 signature. (r+s&v)
        } else if (signature.length == 64) {
            // Declare temporary vs that will be decomposed into s and v.
            bytes32 vs;

            // Read each parameter directly from the signature's memory region.
            assembly {
                // Put the first word from the signature onto the stack as r.
                r := mload(add(signature, 0x20))

                // Put the second word from the signature onto the stack as vs.
                vs := mload(add(signature, 0x40))

                // Extract canonical s from vs (all but the highest bit).
                s := and(
                    vs,
                    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )

                // Extract yParity from highest bit of vs and add 27 to get v.
                v := add(shr(255, vs), 27)
            }
        } else {
            // Disallow signatures that are not 64 or 65 bytes long.
            revert BadSignatureLength(signature.length);
        }

        // Attempt to recover signer using the digest and signature parameters.
        address signer = ecrecover(digest, v, r, s);

        // Disallow invalid signers.
        if (signer == address(0)) {
            revert InvalidSignature();
        // Should a signer be recovered, but it doesn't match the offerer...
        } else if (signer != offerer) {
            // Attempt EIP-1271 static call to offerer in case it's a contract.
            (bool ok, ) = offerer.staticcall(
                abi.encodeWithSelector(
                    EIP1271Interface.isValidSignature.selector,
                    digest,
                    signature
                )
            );

            // If the call fails...
            if (!ok) {
                // Revert and pass reason along if one was returned.
                _revertWithReasonIfOneIsReturned();

                // Otherwise, revert with a generic error message.
                revert BadContractSignature();

            }

            // Extract result from returndata buffer in case of memory overflow.
            bytes4 result;
            assembly {
                // Only put result on stack if return data is exactly 32 bytes.
                if eq(returndatasize(), 0x20) {
                    // Copy directly from return data into scratch space.
                    returndatacopy(0, 0, 0x20)

                    // Take value from scratch space and place it on the stack.
                    result := mload(0)
                }
            }

            // Ensure result was extracted and matches EIP-1271 magic value.
            if (result != EIP1271Interface.isValidSignature.selector) {
                revert InvalidSigner();
            }
        }
    }

    /**
     * @dev Internal view function to get the EIP-712 domain separator. If the
     *      chainId matches the chainId set on deployment, the cached domain
     *      separator will be returned; otherwise, it will be derived from
     *      scratch.
     */
    function _domainSeparator() internal view returns (bytes32) {
        return block.chainid == _CHAIN_ID
            ? _DOMAIN_SEPARATOR
            : _deriveDomainSeparator();
    }

    /**
     * @dev Internal view function to derive the order hash for a given order.
     *
     * @param orderParameters The parameters of the order to hash.
     * @param nonce           The nonce of the order to hash.
     *
     * @return The hash.
     */
    function _getOrderHash(
        OrderParameters memory orderParameters,
        uint256 nonce
    ) internal view returns (bytes32) {
        // Put offer and consideration item array lengths onto the stack.
        uint256 offerLength = orderParameters.offer.length;
        uint256 considerationLength = orderParameters.consideration.length;

        // Designate new memory regions for offer and consideration item hashes.
        bytes32[] memory offerHashes = new bytes32[](offerLength);
        bytes32[] memory considerationHashes = new bytes32[](
            considerationLength
        );

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Iterate over each offer on the order.
            for (uint256 i = 0; i < offerLength; ++i) {
                // Hash the offer and place the result into memory.
                offerHashes[i] = _hashOfferedItem(orderParameters.offer[i]);
            }

            // Iterate over each consideration on the order.
            for (uint256 i = 0; i < considerationLength; ++i) {
                // Hash the consideration and place the result into memory.
                considerationHashes[i] = _hashReceivedItem(
                    orderParameters.consideration[i]
                );
            }
        }

        // Derive and return the order hash as specified by EIP-712.
        return keccak256(
            abi.encode(
                _ORDER_HASH,
                orderParameters.offerer,
                orderParameters.zone,
                keccak256(abi.encodePacked(offerHashes)),
                keccak256(abi.encodePacked(considerationHashes)),
                orderParameters.orderType,
                orderParameters.startTime,
                orderParameters.endTime,
                orderParameters.salt,
                nonce
            )
        );
    }

    /**
     * @dev Internal view function to retrieve the current nonce for a given
     *      order's offerer and zone and use that to derive the order hash.
     *
     * @param orderParameters The parameters of the order to hash.
     *
     * @return The hash.
     */
    function _getNoncedOrderHash(
        OrderParameters memory orderParameters
    ) internal view returns (bytes32) {
        // Derive and return order hash using current nonce for offerer in zone.
        return _getOrderHash(
            orderParameters,
            _nonces[orderParameters.offerer][orderParameters.zone]
        );
    }

    /**
     * @dev Internal view function to derive the EIP-712 hash for an offererd
     *      item.
     *
     * @param offeredItem The offered item to hash.
     *
     * @return The hash.
     */
    function _hashOfferedItem(
        OfferedItem memory offeredItem
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _OFFERED_ITEM_TYPEHASH,
                offeredItem.itemType,
                offeredItem.token,
                offeredItem.identifierOrCriteria,
                offeredItem.startAmount,
                offeredItem.endAmount
            )
        );
    }

    /**
     * @dev Internal view function to derive the EIP-712 hash for a received
     *      item (i.e. a consideration item).
     *
     * @param receivedItem The received item to hash.
     *
     * @return The hash.
     */
    function _hashReceivedItem(
        ReceivedItem memory receivedItem
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _RECEIVED_ITEM_TYPEHASH,
                receivedItem.itemType,
                receivedItem.token,
                receivedItem.identifierOrCriteria,
                receivedItem.startAmount,
                receivedItem.endAmount,
                receivedItem.recipient
            )
        );
    }

    /**
     * @dev Internal view function to determine if a proxy should be utilized
     *      for a given order and to ensure that the submitter is allowed by the
     *      order type.
     *
     * @param orderType        The type of the order.
     * @param offerer          The offerer in question.
     * @param zone             The zone in question.
     *
     * @return useOffererProxy A boolean indicating whether a proxy should be
     *                         utilized for the order.
     */
    function _determineProxyUtilizationAndEnsureValidSubmitter(
        OrderType orderType,
        address offerer,
        address zone
    ) internal view returns (bool useOffererProxy) {
        // Convert the order type from enum to uint256.
        uint256 orderTypeAsUint256 = uint256(orderType);

        // Order type 0-3 are executed directly while 4-7 are executed by proxy.
        useOffererProxy = orderTypeAsUint256 > 3;

        // Order type 2-3 and 6-7 require the zone or the offerer be the caller.
        if (
            orderTypeAsUint256 > (useOffererProxy ? 5 : 1) &&
            msg.sender != zone &&
            msg.sender != offerer
        ) {
            revert InvalidSubmitterOnRestrictedOrder();
        }
    }

    /**
     * @dev Internal view function to derive the current amount of a given item
     *      based on the current price, the starting price, and the ending
     *      price. If the start and end prices differ, the current price will be
     *      extrapolated on a linear basis.
     *
     * @param order The original order.
     */
    function _adjustOrderPrice(
        AdvancedOrder memory order
    ) internal view {
        // Retrieve the order parameters for the order.
        OrderParameters memory orderParameters = order.parameters;

        // Place the start time for the order on the stack.
        uint256 startTime = orderParameters.startTime;

        // Retrieve the offer items for the order.
        OfferedItem[] memory offer = orderParameters.offer;

        // Retrieve the consideration items for the order.
        ReceivedItem[] memory consideration = orderParameters.consideration;

        // Skip checks: for loops indexed at zero and durations are validated.
        unchecked {
            // Derive total order duration and total time elapsed and remaining.
            uint256 duration = orderParameters.endTime - startTime;
            uint256 elapsed = block.timestamp - startTime;
            uint256 remaining = duration - elapsed;

            // Iterate over each offer on the order.
            for (uint256 i = 0; i < offer.length; ++i) {
                // Retrieve the offer item.
                OfferedItem memory offeredItem = offer[i];

                // Adjust offer amounts based on current time (round down).
                offeredItem.endAmount = _locateCurrentAmount(
                    offeredItem.startAmount,
                    offeredItem.endAmount,
                    elapsed,
                    remaining,
                    duration,
                    false // round down
                );
            }

            // Iterate over each consideration on the order.
            for (uint256 i = 0; i < consideration.length; ++i) {
                // Retrieve the received consideration item.
                ReceivedItem memory receivedItem = consideration[i];

                // Adjust consideration amount based on current time (round up).
                receivedItem.endAmount = (
                    _locateCurrentAmount(
                        receivedItem.startAmount,
                        receivedItem.endAmount,
                        elapsed,
                        remaining,
                        duration,
                        true // round up
                    )
                );
            }
        }
    }
}