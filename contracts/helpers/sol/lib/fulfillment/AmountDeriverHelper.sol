// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AmountDeriver } from "../../../../lib/AmountDeriver.sol";
import {
    OfferItem,
    Order,
    ConsiderationItem,
    OrderParameters,
    AdvancedOrder,
    SpentItem,
    ReceivedItem
} from "../../../../lib/ConsiderationStructs.sol";

/**
 * @notice Note that this contract relies on current block.timestamp to determine amounts.
 */
contract AmountDeriverHelper is AmountDeriver {
    function getSpentAndReceivedItems(Order memory order)
        internal
        view
        returns (SpentItem[] memory spent, ReceivedItem[] memory received)
    {
        return getSpentAndReceivedItems(order.parameters);
    }

    function getSpentAndReceivedItems(AdvancedOrder memory order)
        internal
        view
        returns (SpentItem[] memory spent, ReceivedItem[] memory received)
    {
        return getSpentAndReceivedItems(
            order.parameters, order.numerator, order.denominator
        );
    }

    function getSpentAndReceivedItems(OrderParameters memory parameters)
        internal
        view
        returns (SpentItem[] memory spent, ReceivedItem[] memory received)
    {
        spent = getSpentItems(parameters);
        received = getReceivedItems(parameters);
    }

    function getSpentAndReceivedItems(
        OrderParameters memory parameters,
        uint256 numerator,
        uint256 denominator
    )
        internal
        view
        returns (SpentItem[] memory spent, ReceivedItem[] memory received)
    {
        spent = getSpentItems(parameters, numerator, denominator);
        received = getReceivedItems(parameters, numerator, denominator);
    }

    function getSpentItems(
        OrderParameters memory parameters,
        uint256 numerator,
        uint256 denominator
    ) internal view returns (SpentItem[] memory) {
        return getSpentItems(
            parameters.offer,
            parameters.startTime,
            parameters.endTime,
            numerator,
            denominator
        );
    }

    function getSpentItems(OrderParameters memory parameters)
        internal
        view
        returns (SpentItem[] memory)
    {
        return getSpentItems(
            parameters.offer, parameters.startTime, parameters.endTime
        );
    }

    function getSpentItems(
        OfferItem[] memory offerItems,
        uint256 startTime,
        uint256 endTime
    ) internal view returns (SpentItem[] memory) {
        SpentItem[] memory spentItems = new SpentItem[](offerItems.length);
        for (uint256 i = 0; i < offerItems.length; i++) {
            spentItems[i] = getSpentItem(offerItems[i], startTime, endTime);
        }
        return spentItems;
    }

    function getSpentItems(
        OfferItem[] memory items,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) internal view returns (SpentItem[] memory) {
        SpentItem[] memory spentItems = new SpentItem[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            spentItems[i] = getSpentItem(
                items[i], startTime, endTime, numerator, denominator
            );
        }
        return spentItems;
    }

    function getSpentItem(
        OfferItem memory offerItem,
        uint256 startTime,
        uint256 endTime
    ) internal view returns (SpentItem memory spent) {
        spent = SpentItem({
            itemType: offerItem.itemType,
            token: offerItem.token,
            identifier: offerItem.identifierOrCriteria,
            amount: _locateCurrentAmount({
                item: offerItem,
                startTime: startTime,
                endTime: endTime
            })
        });
    }

    function getSpentItem(
        OfferItem memory item,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) internal view returns (SpentItem memory spent) {
        spent = SpentItem({
            itemType: item.itemType,
            token: item.token,
            identifier: item.identifierOrCriteria,
            amount: _applyFraction({
                numerator: numerator,
                denominator: denominator,
                item: item,
                startTime: startTime,
                endTime: endTime
            })
        });
    }

    function getReceivedItems(OrderParameters memory parameters)
        internal
        view
        returns (ReceivedItem[] memory)
    {
        return getReceivedItems(
            parameters.consideration, parameters.startTime, parameters.endTime
        );
    }

    function getReceivedItems(
        OrderParameters memory parameters,
        uint256 numerator,
        uint256 denominator
    ) internal view returns (ReceivedItem[] memory) {
        return getReceivedItems(
            parameters.consideration,
            parameters.startTime,
            parameters.endTime,
            numerator,
            denominator
        );
    }

    function getReceivedItems(
        ConsiderationItem[] memory considerationItems,
        uint256 startTime,
        uint256 endTime
    ) internal view returns (ReceivedItem[] memory) {
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            considerationItems.length
        );
        for (uint256 i = 0; i < considerationItems.length; i++) {
            receivedItems[i] =
                getReceivedItem(considerationItems[i], startTime, endTime);
        }
        return receivedItems;
    }

    function getReceivedItems(
        ConsiderationItem[] memory considerationItems,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) internal view returns (ReceivedItem[] memory) {
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            considerationItems.length
        );
        for (uint256 i = 0; i < considerationItems.length; i++) {
            receivedItems[i] = getReceivedItem(
                considerationItems[i],
                startTime,
                endTime,
                numerator,
                denominator
            );
        }
        return receivedItems;
    }

    function getReceivedItem(
        ConsiderationItem memory considerationItem,
        uint256 startTime,
        uint256 endTime
    ) internal view returns (ReceivedItem memory received) {
        received = ReceivedItem({
            itemType: considerationItem.itemType,
            token: considerationItem.token,
            identifier: considerationItem.identifierOrCriteria,
            amount: _locateCurrentAmount({
                item: considerationItem,
                startTime: startTime,
                endTime: endTime
            }),
            recipient: considerationItem.recipient
        });
    }

    function getReceivedItem(
        ConsiderationItem memory considerationItem,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) internal view returns (ReceivedItem memory received) {
        received = ReceivedItem({
            itemType: considerationItem.itemType,
            token: considerationItem.token,
            identifier: considerationItem.identifierOrCriteria,
            amount: _applyFraction({
                numerator: numerator,
                denominator: denominator,
                item: considerationItem,
                startTime: startTime,
                endTime: endTime
            }),
            recipient: considerationItem.recipient
        });
    }

    function _locateCurrentAmount(
        OfferItem memory item,
        uint256 startTime,
        uint256 endTime
    ) internal view returns (uint256) {
        return _locateCurrentAmount({
            startAmount: item.startAmount,
            endAmount: item.endAmount,
            startTime: startTime,
            endTime: endTime,
            roundUp: false
        });
    }

    function _locateCurrentAmount(
        ConsiderationItem memory item,
        uint256 startTime,
        uint256 endTime
    ) internal view returns (uint256) {
        return _locateCurrentAmount({
            startAmount: item.startAmount,
            endAmount: item.endAmount,
            startTime: startTime,
            endTime: endTime,
            roundUp: true
        });
    }

    function _applyFraction(
        uint256 numerator,
        uint256 denominator,
        uint256 startTime,
        uint256 endTime,
        OfferItem memory item
    ) internal view returns (uint256) {
        uint256 startAmount = item.startAmount;
        uint256 endAmount = item.endAmount;
        return _applyFraction({
            numerator: numerator,
            denominator: denominator,
            startAmount: startAmount,
            endAmount: endAmount,
            startTime: startTime,
            endTime: endTime,
            roundUp: false // don't round up offers
         });
    }

    function _applyFraction(
        uint256 numerator,
        uint256 denominator,
        uint256 startTime,
        uint256 endTime,
        ConsiderationItem memory item
    ) internal view returns (uint256) {
        uint256 startAmount = item.startAmount;
        uint256 endAmount = item.endAmount;

        return _applyFraction({
            numerator: numerator,
            denominator: denominator,
            startAmount: startAmount,
            endAmount: endAmount,
            startTime: startTime,
            endTime: endTime,
            roundUp: true // round up considerations
         });
    }
}
