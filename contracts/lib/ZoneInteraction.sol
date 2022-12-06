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
     *      Note that contract orders are not accessible via basic fulfillments.
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
        // Order type 2-3 require zone be caller or zone to approve.
        if (_isRestrictedAndCallerNotZone(orderType, parameters.zone)) {
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
                    (parameters.additionalRecipients.length *
                        ReceivedItem_size);
            }

            {
                uint256 offerDataOffset;
                assembly {
                    offerDataOffset := add(
                        OrderFulfilled_offer_length_baseOffset,
                        mul(
                            calldataload(
                                BasicOrder_additionalRecipients_length_cdPtr
                            ),
                            OneWord
                        )
                    )
                }

                // Send to the identity precompile. Note: some random data will
                // be written to the first word of scratch space in the process.
                _call(IdentityPrecompile, offerDataOffset, size);
            }

            // TODO: optimize (conversion is temporary to get it to compile)
            bytes memory callData = _generateValidateCallData(
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

            _callAndCheckStatus(
                parameters.zone,
                orderHash,
                callData,
                ZoneInterface.validateOrder.selector,
                _revertInvalidRestrictedOrder
            );
        }
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

    /**
    * @dev Determines whether the specified order type is restricted and the caller is not the specified zone.
    *
    * @param orderType The type of the order to check.
    * @param zone The address of the zone to check against.
    *
    * @return mustValidate True if the order type is restricted and the caller is not the specified zone, false otherwise.
    */
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

    /**
    * @dev Calls the specified target with the given data and checks the status of the call.
    *
    * @param target The address of the contract to call.
    * @param orderHash The hash of the order associated with the call.
    * @param callData The data to pass to the contract call.
    * @param magicValue The expected magic value of the call result.
    * @param errorHandler The error handling function to call if the call fails or the magic value does not match.
    */
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
    /**
    * @dev Generates the call data for a `validateOrder` call to a zone contract.
    *
    * @param orderHash The hash of the order to validate.
    * @param offerer The address of the offerer.
    * @param offer The items being offered.
    * @param consideration The items being received.
    * @param extraData Additional data to include in the call.
    * @param orderHashes The hashes of any orders that must be validated together with this order.
    * @param startTime The start time of the order.
    * @param endTime The end time of the order.
    * @param zoneHash The hash of the zone that the order is being validated in.
    *
    * @return bytes The call data for the `validateOrder` call to the zone contract.
    */
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

    /**
    * @dev Generates the call data for a `ratifyOrder` call to a contract offerer.
    *
    * @param orderHash The hash of the order to ratify.
    * @param offer The items being offered.
    * @param consideration The items being received.
    * @param context The context of the order.
    * @param orderHashes The hashes of any orders that must be ratified together with this order.
    *
    * @return The call data for the `ratifyOrder` call to the contract offerer.
    */

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

    /**
    * @dev Converts an offer from an `OfferItem` array to a `SpentItem` array.
    *
    * @param offer The offer to convert.
    * @return spentItems The converted offer.
    */
    function _convertOffer(OfferItem[] memory offer)
        internal
        pure
        returns (SpentItem[] memory spentItems)
    {
        assembly {
            spentItems := offer
        }
    }

    /**
    * @dev Converts consideration from a `ConsiderationItem` array to a `ReceivedItem` array.
    *
    * @param consideration The consideration to convert.
    * @return receivedItems The converted consideration.
    */
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
