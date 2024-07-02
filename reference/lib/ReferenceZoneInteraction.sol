// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ZoneInterface } from "seaport-types/src/interfaces/ZoneInterface.sol";

import {
    ContractOffererInterface
} from "seaport-types/src/interfaces/ContractOffererInterface.sol";

import {
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    AdditionalRecipient,
    AdvancedOrder,
    BasicOrderParameters,
    ReceivedItem,
    SpentItem,
    ZoneParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { OrderToExecute } from "./ReferenceConsiderationStructs.sol";

import {
    ZoneInteractionErrors
} from "seaport-types/src/interfaces/ZoneInteractionErrors.sol";

/**
 * @title ZoneInteraction
 * @author 0age
 * @notice ZoneInteraction contains logic related to interacting with zones.
 */
contract ReferenceZoneInteraction is ZoneInteractionErrors {
    function _assertRestrictedBasicOrderAuthorization(
        bytes32 orderHash,
        OrderType orderType,
        BasicOrderParameters calldata basicOrderParameters,
        ItemType offeredItemType,
        ItemType receivedItemType
    ) internal {
        // Create a new array for the hash.
        bytes32[] memory orderHashes = new bytes32[](0);

        // Convert the order params and types to spent and received items.
        (
            SpentItem[] memory offer,
            ReceivedItem[] memory consideration
        ) = _convertToSpentAndReceivedItems(
                basicOrderParameters,
                offeredItemType,
                receivedItemType
            );

        // Order types 2-3 require zone or offerer be caller or zone to approve.
        // Note that in cases where fulfiller == zone, the restricted order
        // validation will be skipped.
        if (
            (orderType == OrderType.FULL_RESTRICTED ||
                orderType == OrderType.PARTIAL_RESTRICTED) &&
            msg.sender != basicOrderParameters.zone
        ) {
            // Validate the order with the zone.
            if (
                ZoneInterface(basicOrderParameters.zone).authorizeOrder(
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
                ) != ZoneInterface.authorizeOrder.selector
            ) {
                revert InvalidRestrictedOrder(orderHash);
            }
        }
    }

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

        // Order types 2-3 require zone or offerer be caller or zone to approve.
        // Note that in cases where fulfiller == zone, the restricted order
        // validation will be skipped.
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
     * @dev Internal function to check if a restricted advanced order is
     *      authorized by its zone or offerer, in cases where the caller is not
     *      the zone or offerer.
     *
     * @param advancedOrder        The advanced order in question.
     * @param orderToExecute       The order to execute.
     * @param orderHashes          The order hashes of each order supplied
     *                             alongside the current order as part of a
                                   "match" or "fulfill available" variety of
                                   order fulfillment.
     * @param orderHash            The hash of the order to execute.
     * @param revertOnUnauthorized A boolean indicating whether the function
     *                             should revert if the order is invalid.
     *
     * @return authorized          A boolean indicating whether the order is
     *                             authorized by the zone or offerer.
     * @return checked             A boolean indicating whether the order has
     *                             been checked for authorization.
     */
    function _checkRestrictedAdvancedOrderAuthorization(
        AdvancedOrder memory advancedOrder,
        OrderToExecute memory orderToExecute,
        bytes32[] memory orderHashes,
        bytes32 orderHash,
        bool revertOnUnauthorized
    ) internal returns (bool authorized, bool checked) {
        // Order types 2-3 require zone or offerer be caller or zone to approve.
        if (
            (advancedOrder.parameters.orderType == OrderType.FULL_RESTRICTED ||
                advancedOrder.parameters.orderType ==
                OrderType.PARTIAL_RESTRICTED) &&
            msg.sender != advancedOrder.parameters.zone
        ) {
            // Authorize the order.
            try
                ZoneInterface(advancedOrder.parameters.zone).authorizeOrder(
                    ZoneParameters({
                        orderHash: orderHash,
                        fulfiller: msg.sender,
                        offerer: advancedOrder.parameters.offerer,
                        offer: orderToExecute.spentItems,
                        consideration: orderToExecute.receivedItems,
                        extraData: advancedOrder.extraData,
                        orderHashes: orderHashes,
                        startTime: advancedOrder.parameters.startTime,
                        endTime: advancedOrder.parameters.endTime,
                        zoneHash: advancedOrder.parameters.zoneHash
                    })
                )
            returns (bytes4 selector) {
                if (selector != ZoneInterface.authorizeOrder.selector) {
                    revert InvalidRestrictedOrder(orderHash);
                }

                return (true, true);
            } catch {
                if (revertOnUnauthorized) {
                    revert InvalidRestrictedOrder(orderHash);
                }

                return (false, false);
            }
        } else {
            return (true, false);
        }
    }

    /**
     * @dev Internal function to validate that a restricted advanced order is
     *      authorized by its zone or offerer, in cases where the caller is not
     *      the zone or offerer.
     *
     * @param advancedOrder        The advanced order in question.
     * @param orderToExecute       The order to execute.
     * @param orderHashes          The order hashes of each order supplied
     *                             alongside the current order as part of a
                                   "match" or "fulfill available" variety of
                                   order fulfillment.
     * @param orderHash            The hash of the order to execute.
     * @param zoneHash             The hash to provide upon calling the zone.
     * @param orderType            The type of the order.
     * @param offerer              The offerer in question.
     * @param zone                 The zone in question.
     */
    function _assertRestrictedAdvancedOrderAuthorization(
        AdvancedOrder memory advancedOrder,
        OrderToExecute memory orderToExecute,
        bytes32[] memory orderHashes,
        bytes32 orderHash,
        bytes32 zoneHash,
        OrderType orderType,
        address offerer,
        address zone
    ) internal {
        // Order types 2-3 require zone or offerer be caller or zone to approve.
        if (
            (orderType == OrderType.FULL_RESTRICTED ||
                orderType == OrderType.PARTIAL_RESTRICTED) && msg.sender != zone
        ) {
            // Authorize the order.
            if (
                ZoneInterface(zone).authorizeOrder(
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
                ) != ZoneInterface.authorizeOrder.selector
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
        // Order types 2-3 require zone or offerer be caller or zone to approve.
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
                    uint256(orderHash) ^ (uint256(uint160(offerer)) << 96)
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
     * @return spentItems           The converted offer parameters as an array
     *                              of SpentItem objects.
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
                itemType: offerItemType == ItemType.ERC20
                    ? ItemType.ERC20
                    : considerationItemType,
                token: offerItemType == ItemType.ERC20
                    ? parameters.offerToken
                    : token,
                amount: amount,
                identifier: offerItemType == ItemType.ERC20 ? 0 : identifier,
                recipient: additionalRecipient.recipient
            });
        }

        // Return the spent and received items.
        return (spentItems, receivedItems);
    }
}
