// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { EIP1271Interface } from "../interfaces/EIP1271Interface.sol";

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import {
    OrderType,
    ItemType,
    Side
} from "./ConsiderationEnums.sol";

import {
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem,
    OrderParameters,
    Order,
    AdvancedOrder,
    OrderStatus,
    Execution,
    FulfillmentComponent,
    FulfillmentDetail
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
        if (_reentrancyGuard != _NOT_ENTERED) {
            revert NoReentrantCalls();
        }
    }

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
        // Revert if order's timespan hasn't started yet or has already ended.
        if (startTime > block.timestamp || endTime <= block.timestamp) {
            // Only revert if revertOnInvalid has been supplied as true.
            if (revertOnInvalid) {
                revert InvalidTime();
            }

            // Return false as the order is invalid.
            return false;
        }

        // Return true as the order time is valid.
        valid = true;
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
     * @param success The status of the call to transfer. Note that contract
     *                size must be checked on status of true and no returned
     *                data to rule out undeployed contracts.
     * @param token   The token to transfer.
     * @param from    The originator of the transfer.
     * @param to      The recipient of the transfer.
     * @param tokenId The tokenId to transfer (if applicable).
     * @param amount  The amount to transfer (if applicable).
     */
    function _assertValidTokenTransfer(
        bool success,
        address token,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal view {
        // If the call failed...
        if (!success) {
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
        
        // If no data was returned, ensure that the account has code.
        if (returnDataSize == 0 && account.code.length == 0) {
            revert NoContract(account);
        }
    }

    /**
     * @dev Internal view function to verify the signature of an order. An
     *      ERC-1271 fallback will be attempted if either the signature length
     *      is not 32 or 33 bytes or if the recovered signer does not match the
     *      supplied offerer. Note that in cases where a 32 or 33 byte signature
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
        if (offerer == msg.sender) {
            return;
        }

        // Derive EIP-712 digest using the domain separator and the order hash.
        bytes32 digest = _hashDigest(_domainSeparator(), orderHash);

        // Declare r, s, and v signature parameters.
        bytes32 r;
        bytes32 s;
        uint8 v;

        // If signature contains 64 bytes, parse as EIP-2098 signature. (r+s&v)
        if (signature.length == 64) {
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
                    0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff // solhint-disable-line max-line-length
                )

                // Extract yParity from highest bit of vs and add 27 to get v.
                v := add(shr(255, vs), 27)
            }
        // If signature contains 65 bytes, parse as standard signature. (r+s+v)
        } else if (signature.length == 65) {
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
        // For all other signature lengths, attempt verification using EIP-1271.
        } else {
            // Attempt EIP-1271 static call to offerer in case it's a contract.
            _verifySignatureViaERC1271(offerer, digest, signature);

            // Return early if the ERC-1271 signature check succeeded.
            return;
        }

        // Attempt to recover signer using the digest and signature parameters.
        address signer = ecrecover(digest, v, r, s);

        // Disallow invalid signers.
        if (signer == address(0)) {
            revert InvalidSignature();
        // Should a signer be recovered, but it doesn't match the offerer...
        } else if (signer != offerer) {
            // Attempt EIP-1271 static call to offerer in case it's a contract.
            _verifySignatureViaERC1271(offerer, digest, signature);
        }
    }

    /**
     * @dev Internal view function to verify the signature of an order using
     *      ERC-1271 (i.e. contract signatures via `isValidSignature`).
     *
     * @param offerer   The offerer for the order.
     * @param digest    The signature digest, derived from the domain separator
     *                  and the order hash.
     * @param signature A signature (or other data) used to validate the digest.
     */
    function _verifySignatureViaERC1271(
        address offerer,
        bytes32 digest,
        bytes memory signature
    ) internal view {
        // Attempt an EIP-1271 staticcall to the offerer.
        bool success = _staticcall(
            offerer, abi.encodeWithSelector(
                EIP1271Interface.isValidSignature.selector,
                digest,
                signature
            )
        );

        // If the call fails...
        if (!success) {
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

    /**
     * @dev Internal view function to staticcall an arbitrary target with given
     *      calldata. Note that no data is written to memory and no contract
     *      size check is performed.
     *
     * @param target   The account to staticcall.
     * @param callData The calldata to supply when staticcalling the target.
     *
     * @return success The status of the staticcall to the target.
     */
    function _staticcall(
        address target,
        bytes memory callData
    ) internal view returns (bool success) {
        (success, ) = target.staticcall(callData);
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
     *      Note that only the original consideration items are included in the
     *      order hash, as additional consideration items may be supplied by the
     *      caller.
     *
     * @param orderParameters The parameters of the order to hash.
     * @param nonce           The nonce of the order to hash.
     *
     * @return orderHash The hash.
     */
    function _getOrderHash(
        OrderParameters memory orderParameters,
        uint256 nonce
    ) internal view returns (bytes32 orderHash) {
        // Get length of original consideration array and place it on the stack.
        uint256 originalConsiderationLength = (
          orderParameters.totalOriginalConsiderationItems
        );
        /*
          * Memory layout for an array of structs (dynamic or not) is similar
          * to ABI encoding of dynamic types, with a head segment followed by
          * a data segment. The main difference is that the head of an element
          * is a memory pointer rather than an offset.
          */
        bytes32 offersHash;
        bytes32 typeHash = _OFFER_ITEM_TYPEHASH;
        assembly {
          // Pointer to free memory
          let hashArrPtr := mload(0x40)
          // Get the pointer to the offers array
          let offerArrPtr := mload(add(orderParameters, 0x40))
          // Load the length
          let offerLength := mload(offerArrPtr)
          // Set the pointer to the first offer's head
          offerArrPtr := add(offerArrPtr, 0x20)
          for {let i := 0} lt(i, offerLength) {i:=add(i, 1)} {
            // Read the pointer to the offer data and subtract 32
            // to get typeHash pointer
            let ptr := sub(mload(offerArrPtr), 0x20)
            // Read the current value before the offer data
            let value := mload(ptr)
            // Write the type hash to the previous word
            mstore(ptr, typeHash)
            // Take the EIP712 hash and store it in the hash array
            mstore(hashArrPtr, keccak256(ptr, 0xc0))
            // Restore the previous word
            mstore(ptr, value)
            // Increment the array pointers
            offerArrPtr := add(offerArrPtr, 0x20)
            hashArrPtr := add(hashArrPtr, 0x20)
          }
          offersHash := keccak256(mload(0x40), mul(offerLength, 0x20))
        }
        bytes32 considerationsHash;
        typeHash = _CONSIDERATION_ITEM_TYPEHASH;
        assembly {
          let hashArrPtr := mload(0x40)
          // Get the pointer to the considerations array
          let considerationsArrPtr := add(
            mload(add(orderParameters, 0x60)),
            0x20
          )
          for {let i := 0} lt(i, originalConsiderationLength) {i:=add(i, 1)} {
            // Read the pointer to the consideration data and subtract 32
            // to get typeHash pointer
            let ptr := sub(mload(considerationsArrPtr), 0x20)
            // Read the current value before the consideration data
            let value := mload(ptr)
            // Write the type hash to the previous word
            mstore(ptr, typeHash)
            // Take the EIP712 hash and store it in the hash array
            mstore(hashArrPtr, keccak256(ptr, 0xe0))
            // Restore the previous word
            mstore(ptr, value)
            // Increment the array pointers
            considerationsArrPtr := add(considerationsArrPtr, 0x20)
            hashArrPtr := add(hashArrPtr, 0x20)
          }
          considerationsHash := keccak256(
            mload(0x40),
            mul(originalConsiderationLength, 0x20)
          )
        }
        typeHash = _ORDER_HASH;
        assembly {
          let typeHashPtr := sub(orderParameters, 0x20)
          let previousValue := mload(typeHashPtr)
          mstore(typeHashPtr, typeHash)

          let offerHeadPtr := add(orderParameters, 0x40)
          let offerDataPtr := mload(offerHeadPtr)
          mstore(offerHeadPtr, offersHash)

          let considerationsHeadPtr := add(orderParameters, 0x60)
          let considerationsDataPtr := mload(considerationsHeadPtr)
          mstore(considerationsHeadPtr, considerationsHash)

          let noncePtr := add(orderParameters, 0x120)
          mstore(noncePtr, nonce)

          orderHash := keccak256(typeHashPtr, 0x160)
          mstore(typeHashPtr, previousValue)
          mstore(offerHeadPtr, offerDataPtr)
          mstore(considerationsHeadPtr, considerationsDataPtr)
          mstore(noncePtr, originalConsiderationLength)
        }
    }

    /**
     * @dev Internal view function to to ensure that the supplied consideration
     *      array length on a given set of order parameters is not less than the
     *      original consideration array length for that order and to retrieve
     *      the current nonce for a given order's offerer and zone and use it to
     *      derive the order hash.
     *
     * @param orderParameters The parameters of the order to hash.
     *
     * @return The hash.
     */
    function _assertConsiderationLengthAndGetNoncedOrderHash(
        OrderParameters memory orderParameters
    ) internal view returns (bytes32) {
        // Ensure supplied consideration array length is not less than original.
        _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
            orderParameters.consideration.length,
            orderParameters.totalOriginalConsiderationItems
        );

        // Derive and return order hash using current nonce for the offerer.
        return _getOrderHash(orderParameters, _nonces[orderParameters.offerer]);
    }

    /**
     * @dev Internal view function to determine if a proxy should be utilized
     *      for a given order and to ensure that the submitter is allowed by the
     *      order type.
     *
     * @param orderHash The hash of the order.
     * @param zoneHash  The hash to provide upon calling the zone.
     * @param orderType The type of the order.
     * @param offerer   The offerer in question.
     * @param zone      The zone in question.
     *
     * @return useOffererProxy A boolean indicating whether a proxy should be
     *                         utilized for the order.
     */
    function _determineProxyUtilizationAndEnsureValidBasicOrder(
        bytes32 orderHash,
        bytes32 zoneHash,
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
            // Perform minimal staticcall to the zone.
            bool success = _staticcall(
                zone,
                abi.encodeWithSelector(
                    ZoneInterface.isValidOrder.selector,
                    orderHash,
                    msg.sender,
                    offerer,
                    zoneHash
                )
            );

            // Ensure call was successful and returned the correct magic value.
            _assertIsValidOrderStaticcallSuccess(success, orderHash);
        }
    }

    /**
     * @dev Internal view function to determine if a proxy should be utilized
     *      for a given order and to ensure that the submitter is allowed by the
     *      order type.
     *
     * @param advancedOrder The order in question.
     * @param orderHash     The hash of the order.
     * @param zoneHash      The hash to provide upon calling the zone.
     * @param orderType     The type of the order.
     * @param offerer       The offerer in question.
     * @param zone          The zone in question.
     *
     * @return useOffererProxy A boolean indicating whether a proxy should be
     *                         utilized for the order.
     */
    function _determineProxyUtilizationAndEnsureValidAdvancedOrder(
        AdvancedOrder memory advancedOrder,
        bytes32 orderHash,
        bytes32 zoneHash,
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
            // Declare a variable for the status of the staticcall to the zone.
            bool success;

            // If no extraData is supplied...
            if (advancedOrder.extraData.length == 0) {
                // Perform minimal staticcall to the zone.
                success = _staticcall(
                    zone,
                    abi.encodeWithSelector(
                        ZoneInterface.isValidOrder.selector,
                        orderHash,
                        msg.sender,
                        offerer,
                        zoneHash
                    )
                );
            // Otherwise, extraData has been supplied.
            } else {
                // Perform verbose staticcall to zone.
                success = _staticcall(
                    zone,
                    abi.encodeWithSelector(
                        ZoneInterface.isValidOrderIncludingExtraData.selector,
                        orderHash,
                        msg.sender,
                        advancedOrder
                    )
                );
            }

            // Ensure call was successful and returned the correct magic value.
            _assertIsValidOrderStaticcallSuccess(success, orderHash);
        }
    }

    /**
     * @dev Internal view function to apply a fraction to an offer item and to
     *      return a received item.
     *
     * @param offerItem         The offer item.
     * @param numerator         A value indicating the portion of the order that
     *                          should be filled.
     * @param denominator       A value indicating the total size of the order.
     * @param elapsed           The time elapsed since the order's start time.
     * @param remaining         The time left until the order's end time.
     * @param duration          The total duration of the order.
     *
     * @return item The received item to transfer, including the final amount.
     */
    function _applyFractionToOfferItem(
        OfferItem memory offerItem,
        uint256 numerator,
        uint256 denominator,
        uint256 elapsed,
        uint256 remaining,
        uint256 duration
    ) internal view returns (ReceivedItem memory item) {
        // Declare variable for final amount.
        uint256 amount;

        // If start amount equals end amount, apply fraction to end amount.
        if (offerItem.startAmount == offerItem.endAmount) {
            amount = _getFraction(
                numerator,
                denominator,
                offerItem.endAmount
            );
        } else {
            // Otherwise, apply fraction to both to extrapolate final amount.
            amount = _locateCurrentAmount(
                _getFraction(
                    numerator,
                    denominator,
                    offerItem.startAmount
                ),
                _getFraction(
                    numerator,
                    denominator,
                    offerItem.endAmount
                ),
                elapsed,
                remaining,
                duration,
                false // round down
            );
        }

        // Apply order fill fraction, set caller as the receiver, and return.
        item = ReceivedItem(
            offerItem.itemType,
            offerItem.token,
            offerItem.identifierOrCriteria,
            amount,
            payable(msg.sender)
        );
    }

    /**
     * @dev Internal view function to derive the current amount of each item for
     *      an advanced order based on the current price, the starting price,
     *      and the ending price. If the start and end prices differ, the
     *      current price will be extrapolated on a linear basis.
     *
     * @param advancedOrder The advanced order order.
     */
    function _adjustAdvancedOrderPrice(
        AdvancedOrder memory advancedOrder
    ) internal view {
        // Retrieve the order parameters for the order.
        OrderParameters memory orderParameters = advancedOrder.parameters;

        // Place the start time for the order on the stack.
        uint256 startTime = orderParameters.startTime;

        // Retrieve the offer items for the order.
        OfferItem[] memory offer = orderParameters.offer;

        // Retrieve the consideration items for the order.
        ConsiderationItem[] memory consideration = (
            orderParameters.consideration
        );

        // Skip checks: for loops indexed at zero and durations are validated.
        unchecked {
            // Derive total order duration and total time elapsed and remaining.
            uint256 duration = orderParameters.endTime - startTime;
            uint256 elapsed = block.timestamp - startTime;
            uint256 remaining = duration - elapsed;

            // Iterate over each offer on the order.
            for (uint256 i = 0; i < offer.length; ++i) {
                // Retrieve the offer item.
                OfferItem memory offerItem = offer[i];

                // Adjust offer amounts based on current time (round down).
                offerItem.endAmount = _locateCurrentAmount(
                    offerItem.startAmount,
                    offerItem.endAmount,
                    elapsed,
                    remaining,
                    duration,
                    false // round down
                );
            }

            // Iterate over each consideration on the order.
            for (uint256 i = 0; i < consideration.length; ++i) {
                // Retrieve the received consideration item.
                ConsiderationItem memory considerationItem = consideration[i];

                // Adjust consideration amount based on current time (round up).
                considerationItem.endAmount = (
                    _locateCurrentAmount(
                        considerationItem.startAmount,
                        considerationItem.endAmount,
                        elapsed,
                        remaining,
                        duration,
                        true // round up
                    )
                );
            }
        }
    }

    /**
     * @dev Internal view function to aggregate offer or consideration items
     *      from a group of orders into a single execution via a supplied array
     *      of fulfillment components. Items that are not available to aggregate
     *      will not be included in the aggregated execution.
     *
     * @param advancedOrders        The orders to aggregate.
     * @param side                  The side (i.e. offer or consideration).
     * @param fulfillmentComponents An array designating item components to
     *                              aggregate if part of an available order.
     * @param fulfillmentDetails    An array of FulfillmentDetail structs, each
     *                              indicating whether to fulfill the order and
     *                              whether to use a proxy for it.
     * @param useFulfillerProxy     A flag indicating whether to source
     *                              approvals for fulfilled tokens from the
     *                              fulfiller's respective proxy.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateAvailable(
        AdvancedOrder[] memory advancedOrders,
        Side side,
        FulfillmentComponent[] memory fulfillmentComponents,
        FulfillmentDetail[] memory fulfillmentDetails,
        bool useFulfillerProxy
    ) internal view returns (Execution memory execution) {
        // Ensure at least one fulfillment component has been supplied.
        if (fulfillmentComponents.length == 0) {
            revert MissingFulfillmentComponentOnAggregation(side);
        }

        // Determine component index after first available (zero implies none).
        uint256 nextComponentIndex = 0;

        // Skip overflow checks as all for loops are indexed starting at zero.
        unchecked {
            // Iterate over components until finding one with a fulfilled order.
            for (uint256 i = 0; i < fulfillmentComponents.length; ++i) {
                // Retrieve the fulfillment component index.
                uint256 orderIndex = fulfillmentComponents[i].orderIndex;

                // Ensure that the order index is in range.
                if (orderIndex >= advancedOrders.length) {
                    revert FulfilledOrderIndexOutOfRange();
                }

                // If order is being fulfilled (i.e. it is still available)...
                if (fulfillmentDetails[orderIndex].fulfillOrder) {
                    // Update the next potential component index.
                    nextComponentIndex = i + 1;

                    // Exit the loop.
                    break;
                }
            }
        }

        // If no available order was located...
        if (nextComponentIndex == 0) {
            // Return early with a null execution element that will be filtered.
            return Execution(
                ReceivedItem(
                    ItemType.NATIVE, address(0), 0, 0, payable(address(0))
                ),
                address(0),
                false
            );
        }

        // Otherwise, get first available fulfillment component.
        FulfillmentComponent memory firstAvailableComponent;
        unchecked {
            // Skip check decrementing next potential index as it is not zero.
            firstAvailableComponent = (
                fulfillmentComponents[nextComponentIndex - 1]
            );
        }

        // If the fulfillment components are offer components...
        if (side == Side.OFFER) {
            // Return execution for aggregated items provided by the offerer.
            return _aggregateOfferItems(
                advancedOrders,
                fulfillmentComponents,
                firstAvailableComponent,
                nextComponentIndex,
                fulfillmentDetails
            );
        // Otherwise, fulfillment components are consideration components.
        } else {
            // Return execution for aggregated items provided by the fulfiller.
            return _aggregateConsiderationItems(
                advancedOrders,
                fulfillmentComponents,
                firstAvailableComponent,
                nextComponentIndex,
                fulfillmentDetails,
                useFulfillerProxy
            );
        }
    }

    /**
     * @dev Internal view function to aggregate offer items from a group of
     *      orders into a single execution via a supplied array of components.
     *      Offer items that are not available to aggregate will not be included
     *      in the aggregated execution.
     *
     * @param advancedOrders          The orders to aggregate.
     * @param offerComponents         An array designating offer components to
     *                                aggregate if part of an available order.
     * @param firstAvailableComponent The first available offer component.
     * @param nextComponentIndex      The index of the next potential offer
     *                                component.
     * @param fulfillmentDetails      An array of FulfillmentDetail structs,
     *                                each indicating whether to fulfill the
     *                                order and whether to use a proxy for it.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateOfferItems(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] memory offerComponents,
        FulfillmentComponent memory firstAvailableComponent,
        uint256 nextComponentIndex,
        FulfillmentDetail[] memory fulfillmentDetails
    ) internal view returns (Execution memory execution) {
        // Get offerer and consume offer component, returning a spent item.
        (
            address offerer,
            SpentItem memory offerItem,
            bool useProxy
        ) = _consumeOfferComponent(
            advancedOrders,
            firstAvailableComponent.orderIndex,
            firstAvailableComponent.itemIndex,
            fulfillmentDetails
        );

        // Iterate over each remaining component on the fulfillment.
        for (uint256 i = nextComponentIndex; i < offerComponents.length;) {
            // Retrieve the offer component from the fulfillment array.
            FulfillmentComponent memory offerComponent = offerComponents[i];

            // Read order index from offer component and place on the stack.
            uint256 orderIndex = offerComponent.orderIndex;

            // Ensure that the order index is in range.
            if (orderIndex >= advancedOrders.length) {
                revert FulfilledOrderIndexOutOfRange();
            }

            // If order is not being fulfilled (i.e. it is unavailable)...
            if (!fulfillmentDetails[orderIndex].fulfillOrder) {
                // Skip overflow check as for loop is indexed starting at one.
                unchecked {
                    ++i;
                }

                // Do not consume associated offer item but continue search.
                continue;
            }

            // Get offerer & consume offer component, returning spent item.
            (
                address subsequentOfferer,
                SpentItem memory nextOfferItem,
                bool subsequentUseProxy
            ) = _consumeOfferComponent(
                advancedOrders,
                orderIndex,
                offerComponent.itemIndex,
                fulfillmentDetails
            );

            // Ensure all relevant parameters are consistent with initial offer.
            if (
                offerer != subsequentOfferer ||
                offerItem.itemType != nextOfferItem.itemType ||
                offerItem.token != nextOfferItem.token ||
                offerItem.identifier != nextOfferItem.identifier ||
                useProxy != subsequentUseProxy
            ) {
                revert MismatchedFulfillmentOfferComponents();
            }

            // Increase the total offer amount by the current amount.
            offerItem.amount += nextOfferItem.amount;

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        // Convert offer item into received item with fulfiller as receiver.
        ReceivedItem memory receivedOfferItem = ReceivedItem(
            offerItem.itemType,
            offerItem.token,
            offerItem.identifier,
            offerItem.amount,
            payable(msg.sender)
        );

        // Return execution for aggregated items provided by the offerer.
        execution = Execution(
            receivedOfferItem,
            offerer,
            useProxy
        );
    }

    /**
     * @dev Internal view function to aggregate consideration items from a group
     *      of orders into a single execution via a supplied components array.
     *      Consideration items that are not available to aggregate will not be
     *      included in the aggregated execution.
     *
     * @param advancedOrders          The orders to aggregate.
     * @param considerationComponents An array designating consideration
     *                                components to aggregate if part of an
     *                                available order.
     * @param firstAvailableComponent The first available consideration
     *                                component.
     * @param nextComponentIndex      The index of the next potential
     *                                consideration component.
     * @param fulfillmentDetails      An array of FulfillmentDetail structs,
     *                                each indicating whether to fulfill the
     *                                order and whether to use a proxy for it.
     * @param useFulfillerProxy       A flag indicating whether to source
     *                                approvals for fulfilled tokens from the
     *                                fulfiller's respective proxy.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateConsiderationItems(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] memory considerationComponents,
        FulfillmentComponent memory firstAvailableComponent,
        uint256 nextComponentIndex,
        FulfillmentDetail[] memory fulfillmentDetails,
        bool useFulfillerProxy
    ) internal view returns (Execution memory execution) {
        // Consume consideration component, returning a received item.
        ReceivedItem memory requiredConsideration = (
            _consumeConsiderationComponent(
                advancedOrders,
                firstAvailableComponent.orderIndex,
                firstAvailableComponent.itemIndex
            )
        );

        // Iterate over each remaining component on the fulfillment.
        for (
            uint256 i = nextComponentIndex;
            i < considerationComponents.length;
        ) {
            // Retrieve the consideration component from the fulfillment array.
            FulfillmentComponent memory considerationComponent = (
                considerationComponents[i]
            );

            // Read order index from consideration component and place on stack.
            uint256 orderIndex = considerationComponent.orderIndex;

            // Ensure that the order index is in range.
            if (orderIndex >= advancedOrders.length) {
                revert FulfilledOrderIndexOutOfRange();
            }

            // If order is not being fulfilled (i.e. it is unavailable)...
            if (!fulfillmentDetails[orderIndex].fulfillOrder) {
                // Skip overflow check as for loop is indexed starting at one.
                unchecked {
                    ++i;
                }

                // Do not consume the consideration item & continue search.
                continue;
            }

            // Consume consideration component, returning a received item.
            ReceivedItem memory nextRequiredConsideration = (
                _consumeConsiderationComponent(
                    advancedOrders,
                    orderIndex,
                    considerationComponent.itemIndex
                )
            );

            // Ensure parameters are consistent with initial consideration.
            if (
                requiredConsideration.recipient != (
                    nextRequiredConsideration.recipient
                ) ||
                requiredConsideration.itemType != (
                    nextRequiredConsideration.itemType
                ) ||
                requiredConsideration.token != (
                    nextRequiredConsideration.token
                ) ||
                requiredConsideration.identifier != (
                    nextRequiredConsideration.identifier
                )
            ) {
                revert MismatchedFulfillmentConsiderationComponents();
            }

            // Increase total consideration amount by the current amount.
            requiredConsideration.amount += (
                nextRequiredConsideration.amount
            );

            // Skip overflow check as for loop is indexed starting at one.
            unchecked {
                ++i;
            }
        }

        // Return execution for aggregated items provided by the fulfiller.
        return Execution(
            requiredConsideration,
            msg.sender,
            useFulfillerProxy
        );
    }
}