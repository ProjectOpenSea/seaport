// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";

import { ItemType, OrderType } from "./ConsiderationEnums.sol";

import {
    AdvancedOrder,
    OrderParameters,
    BasicOrderParameters,
    AdditionalRecipient,
    ZoneParameters,
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem
} from "./ConsiderationStructs.sol";

import { ZoneInteractionErrors } from "../interfaces/ZoneInteractionErrors.sol";

import { LowLevelHelpers } from "./LowLevelHelpers.sol";

import "./ConsiderationConstants.sol";

import "./ConsiderationErrors.sol";

/**
 * @title ZoneInteraction
 * @author 0age
 * @notice ZoneInteraction contains logic related to interacting with zones.
 */
contract ZoneInteraction is ZoneInteractionErrors, LowLevelHelpers {
    /**
     * @dev Internal view function to determine if an order has a restricted
     *      order type and, if so, to ensure that either the offerer or the zone
     *      are the fulfiller or that a staticcall to `isValidOrder` on the zone
     *      returns a magic value indicating that the order is currently valid.
     *
     * @param orderHash   The hash of the order.
     * @param orderType   The order type.
     * @param parameters  The parameters of the basic order.
     */
    function _assertRestrictedBasicOrderValidity(
        bytes32 orderHash,
        OrderType orderType,
        BasicOrderParameters calldata parameters
    ) internal {
        if (uint256(orderType) < 2) {
            return;
        }

        bytes memory callData;
        address target;
        bytes4 magicValue;
        function(bytes32) internal view errorHandler;

        // TODO: optimize (copy relevant arguments directly for calldata)
        bytes32[] memory orderHashes = new bytes32[](1);
        orderHashes[0] = orderHash;

        SpentItem[] memory offer = new SpentItem[](1);

        ReceivedItem[] memory consideration = new ReceivedItem[](
            parameters.additionalRecipients.length + 1
        );

        bytes memory extraData;

        // Copy offer & consideration from event data into target callData.
        // 2 words (lengths) + 4 (offer data) + 5 (consideration 1) + 5 * ar
        uint256 size;
        unchecked {
            size =
                OrderFulfilled_baseDataSize +
                (parameters.additionalRecipients.length * ReceivedItem_size);
        }

        uint256 offerDataOffset;
        assembly {
            offerDataOffset := add(
                OrderFulfilled_offer_length_baseOffset,
                mul(
                    calldataload(BasicOrder_additionalRecipients_length_cdPtr),
                    OneWord
                )
            )
        }

        // Send to the identity precompile. Note that some random data will be
        // written to the first word of scratch space in the process.
        _call(IdentityPrecompile, offerDataOffset, size);

        // Order type 2-3 require zone be caller or zone to approve.
        if (_isRestrictedAndCallerNotZone(orderType, parameters.zone)) {
            // TODO: optimize (conversion is temporary to get it to compile)
            callData = _generateValidateCallData(
                orderHash,
                parameters.offerer,
                offer,
                consideration,
                extraData,
                orderHashes,
                parameters.startTime,
                parameters.endTime,
                parameters.zoneHash
            );

            // Copy into the correct region of calldata.
            assembly {
                returndatacopy(
                    add(callData, ValidateOrder_offerDataOffset),
                    0,
                    size
                )
            }

            target = parameters.zone;
            magicValue = ZoneInterface.validateOrder.selector;
            errorHandler = _revertInvalidRestrictedOrder;
        } else if (orderType == OrderType.CONTRACT) {
            callData = _generateRatifyCallData(
                orderHash,
                offer,
                consideration,
                extraData,
                orderHashes
            );

            // Copy into the correct region of calldata.
            assembly {
                returndatacopy(
                    add(callData, RatifyOrder_offerDataOffset),
                    0,
                    size
                )
            }

            target = parameters.offerer;
            magicValue = ContractOffererInterface.ratifyOrder.selector;
            errorHandler = _revertInvalidContractOrder;
        } else {
            return;
        }

        _callAndCheckStatus(
            target,
            orderHash,
            callData,
            magicValue,
            errorHandler
        );
    }

    /**
     * @dev Internal view function to determine whether an order is a restricted
     *      order and, if so, to ensure that it was either submitted by the
     *      offerer or the zone for the order, or that the zone returns the
     *      expected magic value upon performing a staticcall to `isValidOrder`
     *      or `isValidOrderIncludingExtraData` depending on whether the order
     *      fulfillment specifies extra data or criteria resolvers.
     *
     * @param advancedOrder     The advanced order in question.
     * @param orderHashes       The order hashes of each order supplied prior to
     *                          the current order as part of a "match" variety
     *                          of order fulfillment (e.g. this array will be
     *                          empty for single or "fulfill available").
     * @param orderHash         The hash of the order.
     */
    function _assertRestrictedAdvancedOrderValidity(
        AdvancedOrder memory advancedOrder,
        bytes32[] memory orderHashes,
        bytes32 orderHash
    ) internal {
        bytes memory callData;
        address target;
        bytes4 magicValue;
        function(bytes32) internal view errorHandler;

        OrderParameters memory parameters = advancedOrder.parameters;

        // OrderType 2-3 require zone to be caller or approve via validateOrder.
        if (
            _isRestrictedAndCallerNotZone(parameters.orderType, parameters.zone)
        ) {
            // TODO: optimize (conversion is temporary to get it to compile)
            callData = _generateValidateCallData(
                orderHash,
                parameters.offerer,
                _convertOffer(parameters.offer),
                _convertConsideration(parameters.consideration),
                advancedOrder.extraData,
                orderHashes,
                parameters.startTime,
                parameters.endTime,
                parameters.zoneHash
            );

            target = parameters.zone;
            magicValue = ZoneInterface.validateOrder.selector;
            errorHandler = _revertInvalidRestrictedOrder;
        } else if (parameters.orderType == OrderType.CONTRACT) {
            callData = _generateRatifyCallData(
                orderHash,
                _convertOffer(parameters.offer),
                _convertConsideration(parameters.consideration),
                advancedOrder.extraData,
                orderHashes
            );

            target = parameters.offerer;
            magicValue = ContractOffererInterface.ratifyOrder.selector;
            errorHandler = _revertInvalidContractOrder;
        } else {
            return;
        }

        _callAndCheckStatus(
            target,
            orderHash,
            callData,
            magicValue,
            errorHandler
        );
    }

    function _isRestrictedAndCallerNotZone(OrderType orderType, address zone)
        internal
        view
        returns (bool mustValidate)
    {
        assembly {
            mustValidate := and(
                or(eq(orderType, 2), eq(orderType, 3)),
                iszero(eq(caller(), zone))
            )
        }
    }

    function _callAndCheckStatus(
        address target,
        bytes32 orderHash,
        bytes memory callData,
        bytes4 magicValue,
        function(bytes32) internal view errorHandler
    ) internal {
        uint256 callDataMemoryPointer;
        assembly {
            callDataMemoryPointer := add(callData, OneWord)
        }

        // If the call failed...
        if (!_call(target, callDataMemoryPointer, callData.length)) {
            // Revert and pass reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic error message.
            errorHandler(orderHash);
        }

        // Ensure result was extracted and matches magic value.
        if (_doesNotMatchMagic(magicValue)) {
            errorHandler(orderHash);
        }
    }

    function _generateValidateCallData(
        bytes32 orderHash,
        address offerer,
        SpentItem[] memory offer,
        ReceivedItem[] memory consideration,
        bytes memory extraData,
        bytes32[] memory orderHashes,
        uint256 startTime,
        uint256 endTime,
        bytes32 zoneHash
    ) internal view returns (bytes memory) {
        // TODO: optimize (conversion is temporary to get it to compile)
        return
            abi.encodeWithSelector(
                ZoneInterface.validateOrder.selector,
                ZoneParameters(
                    orderHash,
                    msg.sender,
                    offerer,
                    offer,
                    consideration,
                    extraData,
                    orderHashes,
                    startTime,
                    endTime,
                    zoneHash
                )
            );
    }

    function _generateRatifyCallData(
        bytes32 orderHash, // e.g. offerer + contract nonce
        SpentItem[] memory offer,
        ReceivedItem[] memory consideration,
        bytes memory context, // encoded based on the schemaID
        bytes32[] memory orderHashes
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                ContractOffererInterface.ratifyOrder.selector,
                offer,
                consideration,
                context,
                orderHashes,
                uint96(uint256(orderHash))
            );
    }

    function _convertOffer(OfferItem[] memory offer)
        internal
        pure
        returns (SpentItem[] memory spentItems)
    {
        assembly {
            spentItems := offer
        }
    }

    function _convertConsideration(ConsiderationItem[] memory consideration)
        internal
        pure
        returns (ReceivedItem[] memory receivedItems)
    {
        assembly {
            receivedItems := consideration
        }
    }
}
