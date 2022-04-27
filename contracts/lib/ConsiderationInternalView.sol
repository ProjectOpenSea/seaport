// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { EIP1271Interface } from "../interfaces/EIP1271Interface.sol";

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import { OrderType, ItemType, Side } from "./ConsiderationEnums.sol";

// prettier-ignore
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
    FulfillmentComponent
} from "./ConsiderationStructs.sol";

import { ConsiderationPure } from "./ConsiderationPure.sol";

import "./ConsiderationConstants.sol";

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
     * @param conduitController           A contract that deploys conduits, or
     *                                    proxies that may optionally be used to
     *                                    transfer approved ERC20+721+1155
     *                                    tokens.
     * @param legacyProxyRegistry         A proxy registry that stores per-user
     *                                    proxies that may optionally be used to
     *                                    transfer approved ERC721+1155 tokens.
     * @param legacyTokenTransferProxy    A shared proxy contract that may
     *                                    optionally be used to transfer
     *                                    approved ERC20 tokens.
     * @param requiredProxyImplementation The implementation that must be set on
     *                                    each proxy in order to utilize it.
     */
    constructor(
        address conduitController,
        address legacyProxyRegistry,
        address legacyTokenTransferProxy,
        address requiredProxyImplementation
    )
        ConsiderationPure(
            conduitController,
            legacyProxyRegistry,
            legacyTokenTransferProxy,
            requiredProxyImplementation
        )
    {}

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
                s := and(vs, EIP2098_allButHighestBitMask)

                // Extract yParity from highest bit of vs and add 27 to get v.
                v := add(shr(255, vs), 27)
            }
            // If signature is 65 bytes, parse as a standard signature. (r+s+v)
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
            // For all other signature lengths, try verification via EIP-1271.
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
            offerer,
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
    function _staticcall(address target, bytes memory callData)
        internal
        view
        returns (bool success)
    {
        (success, ) = target.staticcall(callData);
    }

    /**
     * @dev Internal view function to get the EIP-712 domain separator. If the
     *      chainId matches the chainId set on deployment, the cached domain
     *      separator will be returned; otherwise, it will be derived from
     *      scratch.
     */
    function _domainSeparator() internal view returns (bytes32) {
        // prettier-ignore
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

        // Declare a variable for the derived hash of the offer array.
        bytes32 offerHash;

        // Read offer item EIP-712 typehash from runtime code & place on stack.
        bytes32 typeHash = _OFFER_ITEM_TYPEHASH;

        // Utilize assembly so that memory regions can be reused across hashes.
        assembly {
            // Retrieve the free memory pointer and place on the stack.
            let hashArrPtr := mload(FreeMemoryPointerSlot)

            // Get the pointer to the offers array.
            let offerArrPtr := mload(add(orderParameters, 0x40))

            // Load the length.
            let offerLength := mload(offerArrPtr)

            // Set the pointer to the first offer's head.
            offerArrPtr := add(offerArrPtr, 0x20)

            // Iterate over the offer items.
            // prettier-ignore
            for { let i := 0 } lt(i, offerLength) {
                i := add(i, 1)
            } {
                // Read the pointer to the offer data and subtract 32
                // to get typeHash pointer.
                let ptr := sub(mload(offerArrPtr), 0x20)

                // Read the current value before the offer data.
                let value := mload(ptr)

                // Write the type hash to the previous word.
                mstore(ptr, typeHash)

                // Take the EIP712 hash and store it in the hash array.
                mstore(hashArrPtr, keccak256(ptr, 0xc0))

                // Restore the previous word.
                mstore(ptr, value)

                // Increment the array pointers.
                offerArrPtr := add(offerArrPtr, 0x20)
                hashArrPtr := add(hashArrPtr, 0x20)
            }

            // Derive the offer hash.
            offerHash := keccak256(
                mload(FreeMemoryPointerSlot),
                mul(offerLength, 0x20)
            )
        }

        // Declare a variable for the derived hash of the consideration array.
        bytes32 considerationHash;

        // Read consideration item typehash from runtime code & place on stack.
        typeHash = _CONSIDERATION_ITEM_TYPEHASH;

        // Utilize assembly so that memory regions can be reused across hashes.
        assembly {
            // Retrieve the free memory pointer and place on the stack.
            let hashArrPtr := mload(FreeMemoryPointerSlot)

            // Get the pointer to the consideration array.
            let considerationArrPtr := add(
                mload(add(orderParameters, 0x60)),
                0x20
            )

            // Iterate over the offer items.
            // prettier-ignore
            for { let i := 0 } lt(i, originalConsiderationLength) {
                i := add(i, 1)
            } {
                // Read the pointer to the consideration data and subtract 32
                // to get typeHash pointer.
                let ptr := sub(mload(considerationArrPtr), 0x20)

                // Read the current value before the consideration data.
                let value := mload(ptr)

                // Write the type hash to the previous word.
                mstore(ptr, typeHash)

                // Take the EIP712 hash and store it in the hash array.
                mstore(hashArrPtr, keccak256(ptr, 0xe0))

                // Restore the previous word.
                mstore(ptr, value)

                // Increment the array pointers.
                considerationArrPtr := add(considerationArrPtr, 0x20)
                hashArrPtr := add(hashArrPtr, 0x20)
            }

            // Derive the offer hash.
            considerationHash := keccak256(
                mload(FreeMemoryPointerSlot),
                mul(originalConsiderationLength, 0x20)
            )
        }

        // Read order item EIP-712 typehash from runtime code & place on stack.
        typeHash = _ORDER_TYPEHASH;

        // Utilize assembly to access derived hashes & other arguments directly.
        assembly {
            let typeHashPtr := sub(orderParameters, 0x20)
            let previousValue := mload(typeHashPtr)
            mstore(typeHashPtr, typeHash)

            let offerHeadPtr := add(orderParameters, 0x40)
            let offerDataPtr := mload(offerHeadPtr)
            mstore(offerHeadPtr, offerHash)

            let considerationHeadPtr := add(orderParameters, 0x60)
            let considerationDataPtr := mload(considerationHeadPtr)
            mstore(considerationHeadPtr, considerationHash)

            let noncePtr := add(orderParameters, 0x140)
            mstore(noncePtr, nonce)

            orderHash := keccak256(typeHashPtr, 0x180)
            mstore(typeHashPtr, previousValue)
            mstore(offerHeadPtr, offerDataPtr)
            mstore(considerationHeadPtr, considerationDataPtr)
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
     * @dev Internal view function to determine if an order has a restricted
     *      order type and, if so, to ensure that either the offerer or the zone
     *      are the fulfiller or that a staticcall to `isValidOrder` on the zone
     *      returns a magic value indicating that the order is currently valid.
     *
     * @param orderHash The hash of the order.
     * @param zoneHash  The hash to provide upon calling the zone.
     * @param orderType The type of the order.
     * @param offerer   The offerer in question.
     * @param zone      The zone in question.
     */
    function _assertRestrictedBasicOrderValidity(
        bytes32 orderHash,
        bytes32 zoneHash,
        OrderType orderType,
        address offerer,
        address zone
    ) internal view {
        // Order type 2-3 require zone or offerer be caller or zone to approve.
        if (
            uint256(orderType) > 1 &&
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
     * @param advancedOrder    The order in question.
     * @param priorOrderHashes The order hashes of each order supplied prior to
     *                         the current order as part of a "match" variety of
     *                         order fulfillment (e.g. this array will be empty
     *                         for single or "fulfill available").
     * @param orderHash        The hash of the order.
     * @param zoneHash         The hash to provide upon calling the zone.
     * @param orderType        The type of the order.
     * @param offerer          The offerer in question.
     * @param zone             The zone in question.

     */
    function _assertRestrictedAdvancedOrderValidity(
        AdvancedOrder memory advancedOrder,
        bytes32[] memory priorOrderHashes,
        bytes32 orderHash,
        bytes32 zoneHash,
        OrderType orderType,
        address offerer,
        address zone
    ) internal view {
        // Order type 2-3 require zone or offerer be caller or zone to approve.
        if (
            uint256(orderType) > 1 &&
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
            } else {
                // Otherwise, extraData was supplied; in that event, perform a
                // more verbose staticcall to the zone.
                success = _staticcall(
                    zone,
                    abi.encodeWithSelector(
                        ZoneInterface.isValidOrderIncludingExtraData.selector,
                        orderHash,
                        msg.sender,
                        advancedOrder,
                        priorOrderHashes
                    )
                );
            }

            // Ensure call was successful and returned the correct magic value.
            _assertIsValidOrderStaticcallSuccess(success, orderHash);
        }
    }

    /**
     * @dev Internal view function to match offer items to consideration items
     *      on a group of orders via a supplied fulfillment.
     *
     * @param advancedOrders          The orders to match.
     * @param offerComponents         An array designating offer components to
     *                                match to consideration components.
     * @param considerationComponents An array designating consideration
     *                                components to match to offer components.
     *                                Note that each consideration amount must
     *                                be zero in order for the match operation
     *                                to be valid.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _applyFulfillment(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] memory offerComponents,
        FulfillmentComponent[] memory considerationComponents
    ) internal view returns (Execution memory execution) {
        // Ensure 1+ of both offer and consideration components are supplied.
        if (
            offerComponents.length == 0 || considerationComponents.length == 0
        ) {
            revert OfferAndConsiderationRequiredOnFulfillment();
        }

        // Validate and aggregate consideration items and store the result as a
        // ReceivedItem.
        ReceivedItem memory considerationItem = (
            _aggregateValidFulfillmentConsiderationItems(
                advancedOrders,
                considerationComponents,
                0
            )
        );

        // Validate & aggregate offer items and store result as an Execution.
        (
            execution
            /**
             * ItemType itemType,
             * address token,
             * uint256 identifier,
             * address offerer,
             * bytes32 conduitKey,
             * uint256 offerAmount
             */
        ) = _aggregateValidFulfillmentOfferItems(
            advancedOrders,
            offerComponents,
            0
        );

        // Ensure offer and consideration share types, tokens and identifiers.
        if (
            execution.item.itemType != considerationItem.itemType ||
            execution.item.token != considerationItem.token ||
            execution.item.identifier != considerationItem.identifier
        ) {
            revert MismatchedFulfillmentOfferAndConsiderationComponents();
        }

        // If total consideration amount exceeds the offer amount...
        if (considerationItem.amount > execution.item.amount) {
            // Retrieve the first consideration component from the fulfillment.
            FulfillmentComponent memory targetComponent = (
                considerationComponents[0]
            );

            // Add excess consideration item amount to original array of orders.
            advancedOrders[targetComponent.orderIndex]
                .parameters
                .consideration[targetComponent.itemIndex]
                .startAmount = considerationItem.amount - execution.item.amount;

            // Reduce total consideration amount to equal the offer amount.
            considerationItem.amount = execution.item.amount;
        } else {
            // Retrieve the first offer component from the fulfillment.
            FulfillmentComponent memory targetComponent = (offerComponents[0]);

            // Add excess offer item amount to the original array of orders.
            advancedOrders[targetComponent.orderIndex]
                .parameters
                .offer[targetComponent.itemIndex]
                .startAmount = execution.item.amount - considerationItem.amount;
        }

        // Reuse execution struct with consideration amount and recipient.
        execution.item.amount = considerationItem.amount;
        execution.item.recipient = considerationItem.recipient;

        // Return the final execution that will be triggered for relevant items.
        return execution; // Execution(considerationItem, offerer, conduitKey);
    }

    /**
     * 2. Here's the summary of this section
     * blah blah blah
     */

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
     * @param fulfillerConduitKey   A bytes32 value indicating what conduit, if
     *                              any, to source the fulfiller's token
     *                              approvals from. The zero hash signifies that
     *                              no conduit should be used (and direct
     *                              approvals set on Consideration) and
     *                              `bytes32(1)` signifies to utilize the legacy
     *                               user proxy for the fulfiller.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateAvailable(
        AdvancedOrder[] memory advancedOrders,
        Side side,
        FulfillmentComponent[] memory fulfillmentComponents,
        bytes32 fulfillerConduitKey
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
                if (advancedOrders[orderIndex].numerator != 0) {
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
            // prettier-ignore
            return Execution(
                ReceivedItem(
                    ItemType.NATIVE,
                    address(0),
                    0,
                    0,
                    payable(address(0))
                ),
                address(0),
                bytes32(0)
            );
        }

        // If the fulfillment components are offer components...
        if (side == Side.OFFER) {
            // Return execution for aggregated items provided by the offerer.
            // prettier-ignore
            return _aggregateValidFulfillmentOfferItems(
                advancedOrders,
                fulfillmentComponents,
                nextComponentIndex - 1
            );
        } else {
            // Otherwise, fulfillment components are consideration components.
            // Return execution for aggregated items provided by the fulfiller.
            // prettier-ignore
            return _aggregateConsiderationItems(
                advancedOrders,
                fulfillmentComponents,
                nextComponentIndex - 1,
                fulfillerConduitKey
            );
        }
    }

    /**
     * @dev Internal pure function to aggregate a group of offer items using
     *      supplied directives on which component items are candidates for
     *      aggregation, skipping items on orders that are not available.
     *
     * @param advancedOrders  The orders to aggregate offer items from.
     * @param offerComponents An array of FulfillmentComponent structs
     *                        indicating the order index and item index of each
     *                        candidate offer item for aggregation.
     * @param startIndex      The initial order index to begin iteration on when
     *                        searching for offer items to aggregate.
     *
     * @return execution The aggregated offer items.
     */
    function _aggregateValidFulfillmentOfferItems(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] memory offerComponents,
        uint256 startIndex
    ) internal view returns (Execution memory execution) {
        // Declare a variable for the final aggregated item amount.
        uint256 amount;

        // Declare a variable indicating whether the aggregation is invalid.
        bool invalidFulfillment;

        // Utilize assembly in order to efficiently aggregate the items.
        assembly {
            // Retrieve fulfillment pointer from offer component & start index.
            let fulfillmentPtr := mload(
                add(add(offerComponents, 0x20), mul(startIndex, 0x20))
            )

            // Retrieve the order index using the fulfillment pointer.
            let orderIndex := mload(fulfillmentPtr)

            // Retrieve item index using an offset of the fulfillment pointer.
            let itemIndex := mload(
                add(fulfillmentPtr, Fulfillment_itemIndex_offset)
            )

            // Ensure that the order index is not out of range.
            invalidFulfillment := iszero(lt(orderIndex, mload(advancedOrders)))

            // Retrieve the initial order pointer from the order index.
            let orderPtr := mload(
                mload(
                    add(
                        // Calculate pointer to start of advancedOrders head.
                        add(advancedOrders, 0x20),
                        // Calculate offset to pointer for desired order.
                        mul(orderIndex, 0x20)
                    )
                )
            )
            // Retrieve offer array pointer using offset of the order pointer.
            let offerArrPtr := mload(
                add(orderPtr, OrderParameters_offer_head_offset)
            )

            // Ensure that the item index is not out of range.
            invalidFulfillment := or(
                iszero(lt(itemIndex, mload(offerArrPtr))),
                invalidFulfillment
            )

            // Retrieve the offer item pointer using offset of the item index.
            let offerItemPtr := mload(
                add(
                    // Get pointer to beginning of OfferItem.
                    add(offerArrPtr, 0x20),
                    // Calculate offset to pointer for desired order.
                    mul(itemIndex, 0x20)
                )
            )

            // Retrieve the received item pointer.
            let receivedItemPtr := mload(execution)

            // Set itemType located at the offerItem pointer on receivedItem.
            mstore(receivedItemPtr, mload(offerItemPtr))

            // Set token located at offset of offerItem pointer on receivedItem.
            mstore(
                add(receivedItemPtr, Common_token_offset),
                mload(add(offerItemPtr, Common_token_offset))
            )

            // Set identifier located at offset of offerItem pointer as well.
            mstore(
                add(receivedItemPtr, 0x40),
                mload(add(offerItemPtr, Common_identifier_offset))
            )

            // Set amount on received item and additionaly place on the stack.
            let amountPtr := add(offerItemPtr, Common_amount_offset)
            amount := mload(amountPtr)

            // Set the caller as the recipient on the received item.
            mstore(
                add(receivedItemPtr, ReceivedItem_recipient_offset),
                caller()
            )

            // Zero out amount on original offerItem to indicate it is spent.
            mstore(amountPtr, 0)

            // Set the offerer on returned execution using order pointer.
            mstore(add(execution, Execution_offerer_offset), mload(orderPtr))

            // Set conduitKey on returned execution via offset of order pointer.
            mstore(
                add(execution, Execution_conduit_offset),
                mload(add(orderPtr, OrderParameters_conduit_offset))
            )
        }

        // Declare new assembly scope to avoid stack too deep errors.
        assembly {
            // Retrieve the received item pointer using the execution.
            let receivedItemPtr := mload(execution)

            // Iterate over offer components as long as fulfillment is valid.
            // prettier-ignore
            for {
                let i := add(startIndex, 1)
            } and(iszero(invalidFulfillment), lt(i, mload(offerComponents))) {
                i := add(i, 1)
            } {
                // Retrieve fulfillment pointer for the current offer component.
                let fulfillmentPtr := mload(
                    add(add(offerComponents, 0x20), mul(i, 0x20))
                )

                // Retrieve the order index using the fulfillment pointer.
                let orderIndex := mload(fulfillmentPtr)

                // Retrieve the item index using offset of fulfillment pointer.
                let itemIndex := mload(
                    add(fulfillmentPtr, Fulfillment_itemIndex_offset)
                )

                // Ensure that the order index is in range.
                invalidFulfillment := iszero(
                    lt(orderIndex, mload(advancedOrders))
                )

                // Exit iteration if it is out of range.
                if invalidFulfillment {
                    break
                }

                // Retrieve the order pointer using the order index. Note that
                // advancedOrders[orderIndex].OrderParameters pointer is first
                // word of AdvancedOrder struct, so mload again in a moment.
                let orderPtr := mload(
                    add(add(advancedOrders, 0x20), mul(orderIndex, 0x20))
                )

                // If the order is available (i.e. has a numerator != 0)...
                if mload(add(orderPtr, AdvancedOrder_numerator_offset)) {
                    // Retrieve the order pointer (i.e. the second mload).
                    orderPtr := mload(orderPtr)

                    // Load offer item array pointer.
                    let offerArrPtr := mload(
                        add(orderPtr, OrderParameters_offer_head_offset)
                    )

                    // Ensure that the offer item index is in range.
                    invalidFulfillment := iszero(
                        lt(itemIndex, mload(offerArrPtr))
                    )

                    // Exit iteration if it is out of range.
                    if invalidFulfillment {
                        break
                    }

                    // Retrieve the offer item pointer using the item index.
                    let offerItemPtr := mload(
                        add(
                            // Get pointer to beginning of OfferItem
                            add(offerArrPtr, 0x20),
                            // Calculate offset to pointer for desired order
                            mul(itemIndex, 0x20)
                        )
                    )

                    // Retrieve the amount using the offer item pointer.
                    let amountPtr := add(offerItemPtr, Common_amount_offset)

                    // Increment the amount.
                    amount := add(amount, mload(amountPtr))

                    // Zero out amount on original item to indicate it is spent.
                    mstore(amountPtr, 0)

                    // Ensure the indicated offer item matches original item.
                    invalidFulfillment := iszero(
                        and(
                            // The identifier must match on both items.
                            eq(
                                mload(
                                    add(offerItemPtr, Common_identifier_offset)
                                ),
                                mload(
                                    add(
                                        receivedItemPtr,
                                        Common_identifier_offset
                                    )
                                )
                            ),
                            and(
                                and(
                                    // The offerer must match on both items.
                                    eq(
                                        mload(orderPtr),
                                        mload(
                                            add(execution, Common_token_offset)
                                        )
                                    ),
                                    // The conduit key must match on both items.
                                    eq(
                                        mload(
                                            add(
                                                orderPtr,
                                                OrderParameters_conduit_offset
                                            )
                                        ),
                                        mload(
                                            add(
                                                execution,
                                                Execution_conduit_offset
                                            )
                                        )
                                    )
                                ),
                                and(
                                    // The item type must match on both items.
                                    eq(
                                        mload(offerItemPtr),
                                        mload(receivedItemPtr)
                                    ),
                                    // The token must match on both items.
                                    eq(
                                        mload(
                                            add(
                                                offerItemPtr,
                                                Common_token_offset
                                            )
                                        ),
                                        mload(
                                            add(
                                                receivedItemPtr,
                                                Common_token_offset
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                }
            }

            // Update the final amount on the returned received item.
            mstore(add(receivedItemPtr, Common_amount_offset), amount)
        }

        // Revert if an order/item was out of range or was not aggregatable.
        if (invalidFulfillment) {
            revert InvalidFulfillmentComponentData();
        }
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
     * @param nextComponentIndex      The index of the next potential
     *                                consideration component.
     * @param fulfillerConduitKey     A bytes32 value indicating what conduit,
     *                                if any, to source the fulfiller's token
     *                                approvals from. The zero hash signifies
     *                                that no conduit should be used (and direct
     *                                approvals set on Consideration) and
     *                                `bytes32(1)` signifies to utilize the
     *                                legacy user proxy for the fulfiller.
     *
     * @return execution The transfer performed as a result of the fulfillment.
     */
    function _aggregateConsiderationItems(
        AdvancedOrder[] memory advancedOrders,
        FulfillmentComponent[] memory considerationComponents,
        uint256 nextComponentIndex,
        bytes32 fulfillerConduitKey
    ) internal view returns (Execution memory execution) {
        // Validate and aggregate consideration items on available orders and
        // store result as a ReceivedItem.
        ReceivedItem memory receiveConsiderationItem = (
            _aggregateValidFulfillmentConsiderationItems(
                advancedOrders,
                considerationComponents,
                nextComponentIndex
            )
        );

        // Return execution for aggregated items provided by the fulfiller.
        execution = Execution(
            receiveConsiderationItem,
            msg.sender,
            fulfillerConduitKey
        );
    }

    /**
     * @dev Internal view function to derive the address of a given conduit
     *      using a corresponding conduit key.
     *
     * @param conduitKey A bytes32 value indicating what corresponding conduit,
     *                   if any, to source token approvals from. This value is
     *                   the "salt" parameter supplied by the deployer (i.e. the
     *                   conduit controller) when deploying the given conduit.
     *
     * @return conduit The address of the conduit associated with the given
     *                 conduit key.
     */
    function _deriveConduit(bytes32 conduitKey)
        internal
        view
        returns (address conduit)
    {
        // Derive conduit address using deployer, key, and creation code hash.
        conduit = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(_CONDUIT_CONTROLLER),
                            conduitKey,
                            _CONDUIT_CREATION_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
