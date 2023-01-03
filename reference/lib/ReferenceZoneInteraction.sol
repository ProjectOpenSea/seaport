// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ZoneInterface } from "../../contracts/interfaces/ZoneInterface.sol";

import {
    ContractOffererInterface
} from "../../contracts/interfaces/ContractOffererInterface.sol";

import {
    OrderType,
    ItemType
} from "../../contracts/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    OrderParameters,
    CriteriaResolver,
    BasicOrderParameters,
    OrderParameters,
    ZoneParameters,
    SpentItem,
    ReceivedItem,
    AdditionalRecipient
} from "../../contracts/lib/ConsiderationStructs.sol";

import { OrderToExecute } from "./ReferenceConsiderationStructs.sol";

import "../../contracts/lib/ConsiderationConstants.sol";

import {
    ZoneInteractionErrors
} from "../../contracts/interfaces/ZoneInteractionErrors.sol";

/**
 * @title ZoneInteraction
 * @author 0age
 * @notice ZoneInteraction contains logic related to interacting with zones.
 */
contract ReferenceZoneInteraction is ZoneInteractionErrors {
    /**
     * @dev Internal view function to determine if an order has a restricted
     *      order type and, if so, to ensure that either the offerer or the zone
     *      are the fulfiller or that a staticcall to `isValidOrder` on the zone
     *      returns a magic value indicating that the order is currently valid.
     *
     * @param orderHash             The hash of the order.
     * @param basicOrderParameters  The original basic order parameters.
     * @param offeredItemType       The type of the order.
     * @param receivedItemType      The offerer in question.
     */
    function _assertRestrictedBasicOrderValidity(
        bytes32 orderHash,
        OrderType orderType,
        BasicOrderParameters calldata basicOrderParameters,
        ItemType offeredItemType,
        ItemType receivedItemType
    ) internal {
        // Create a new array for the hash.
        bytes32[] memory orderHashes = new bytes32[](1);
        orderHashes[0] = orderHash;

        // Convert the order params and types to spent and received items.
        (
            SpentItem[] memory offer,
            ReceivedItem[] memory consideration
        ) = _convertToSpentAndReceivedItems(
                basicOrderParameters,
                offeredItemType,
                receivedItemType
            );

        // Order type 2-3 require zone or offerer be caller or zone to approve.
        if (
            (orderType == OrderType.FULL_RESTRICTED ||
                orderType == OrderType.PARTIAL_RESTRICTED) &&
            msg.sender != basicOrderParameters.zone
        ) {
            // Validate the order with the zone.
            if (
                ZoneInterface(basicOrderParameters.zone).validateOrder(
                    ZoneParameters({
                        orderHash: orderHash,
                        fulfiller: msg.sender,
                        offerer: basicOrderParameters.offerer,
                        offer: offer,
                        consideration: consideration,
                        extraData: "",
                        orderHashes: orderHashes,
                        startTime: basicOrderParameters.startTime,
                        endTime: basicOrderParameters.endTime,
                        zoneHash: basicOrderParameters.zoneHash
                    })
                ) != ZoneInterface.validateOrder.selector
            ) {
                revert InvalidRestrictedOrder(orderHash);
            }
        }
    }

    /**
     * @dev Internal view function to determine if a proxy should be utilized
     *      for a given order and to ensure that the submitter is allowed by the
     *      order type.
     *
     * @param advancedOrder  The order in question.
     * @param orderHashes    The order hashes of each order supplied alongside
     *                       the current order as part of a "match" or "fulfill
     *                       available" variety of order fulfillment.
     * @param orderHash      The hash of the order.
     * @param zoneHash       The hash to provide upon calling the zone.
     * @param orderType      The type of the order.
     * @param offerer        The offerer in question.
     * @param zone           The zone in question.
     */
    function _assertRestrictedAdvancedOrderValidity(
        AdvancedOrder memory advancedOrder,
        OrderToExecute memory orderToExecute,
        bytes32[] memory orderHashes,
        bytes32 orderHash,
        bytes32 zoneHash,
        OrderType orderType,
        address offerer,
        address zone
    ) internal {
        // Order type 2-3 require zone or offerer be caller or zone to approve.
        if (
            (orderType == OrderType.FULL_RESTRICTED ||
                orderType == OrderType.PARTIAL_RESTRICTED) && msg.sender != zone
        ) {
            // Validate the order.
            if (
                ZoneInterface(zone).validateOrder(
                    ZoneParameters({
                        orderHash: orderHash,
                        fulfiller: msg.sender,
                        offerer: offerer,
                        offer: orderToExecute.spentItems,
                        consideration: orderToExecute.receivedItems,
                        extraData: advancedOrder.extraData,
                        orderHashes: orderHashes,
                        startTime: advancedOrder.parameters.startTime,
                        endTime: advancedOrder.parameters.endTime,
                        zoneHash: zoneHash
                    })
                ) != ZoneInterface.validateOrder.selector
            ) {
                revert InvalidRestrictedOrder(orderHash);
            }
        } else if (orderType == OrderType.CONTRACT) {
            // Ratify the contract order.
            if (
                ContractOffererInterface(offerer).ratifyOrder(
                    orderToExecute.spentItems,
                    orderToExecute.receivedItems,
                    advancedOrder.extraData,
                    orderHashes,
                    uint96(uint256(orderHash))
                ) != ContractOffererInterface.ratifyOrder.selector
            ) {
                revert InvalidContractOrder(orderHash);
            }
        }
    }

    /**
     * @dev Converts the offer and consideration parameters from a
     *      BasicOrderParameters object into an array of SpentItem and
     *      ReceivedItem objects.
     *
     * @param parameters            The BasicOrderParameters object containing
     *                              the offer and consideration parameters to be
     *                              converted.
     * @param offerItemType         The item type of the offer.
     * @param considerationItemType The item type of the consideration.
     *
     * @return spentItems           The converted offer parameters as an array of
     *                              SpentItem objects.
     * @return receivedItems        The converted consideration parameters as an
     *                              array of ReceivedItem objects.
     */
    function _convertToSpentAndReceivedItems(
        BasicOrderParameters calldata parameters,
        ItemType offerItemType,
        ItemType considerationItemType
    ) internal pure returns (SpentItem[] memory, ReceivedItem[] memory) {
        // Create the spent item.
        SpentItem[] memory spentItems = new SpentItem[](1);
        spentItems[0] = SpentItem({
            itemType: offerItemType,
            token: parameters.offerToken,
            amount: parameters.offerAmount,
            identifier: parameters.offerIdentifier
        });

        // Create the received item.
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            1 + parameters.additionalRecipients.length
        );
        address token = parameters.considerationToken;
        uint256 amount = parameters.considerationAmount;
        uint256 identifier = parameters.considerationIdentifier;
        receivedItems[0] = ReceivedItem({
            itemType: considerationItemType,
            token: token,
            amount: amount,
            identifier: identifier,
            recipient: parameters.offerer
        });

        // Iterate through the additional recipients and create the received
        // items.
        for (uint256 i = 0; i < parameters.additionalRecipients.length; i++) {
            AdditionalRecipient calldata additionalRecipient = parameters
                .additionalRecipients[i];
            amount = additionalRecipient.amount;
            receivedItems[i + 1] = ReceivedItem({
                itemType: considerationItemType,
                token: token,
                amount: amount,
                identifier: identifier,
                recipient: additionalRecipient.recipient
            });
        }

        // Return the spent and received items.
        return (spentItems, receivedItems);
    }
}
