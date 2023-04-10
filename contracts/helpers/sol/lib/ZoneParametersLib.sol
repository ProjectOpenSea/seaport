// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ItemType, Side } from "../../../lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    SpentItem,
    ReceivedItem,
    ZoneParameters,
    CriteriaResolver
} from "../../../lib/ConsiderationStructs.sol";

import { SeaportInterface } from "../SeaportInterface.sol";

import { GettersAndDerivers } from "../../../lib/GettersAndDerivers.sol";

import { AdvancedOrderLib } from "./AdvancedOrderLib.sol";

import { ConsiderationItemLib } from "./ConsiderationItemLib.sol";

import { OfferItemLib } from "./OfferItemLib.sol";

import { ReceivedItemLib } from "./ReceivedItemLib.sol";

import { OrderParametersLib } from "./OrderParametersLib.sol";

import { StructCopier } from "./StructCopier.sol";

import { AmountDeriverHelper } from "./fulfillment/AmountDeriverHelper.sol";
import { OrderDetails } from "../fulfillments/lib/Structs.sol";

library ZoneParametersLib {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using OrderParametersLib for OrderParameters;

    struct ZoneParametersStruct {
        AdvancedOrder[] advancedOrders;
        address fulfiller;
        uint256 maximumFulfilled;
        address seaport;
        CriteriaResolver[] criteriaResolvers;
    }

    struct ZoneDetails {
        AdvancedOrder[] advancedOrders;
        address fulfiller;
        uint256 maximumFulfilled;
        OrderDetails[] orderDetails;
        bytes32[] orderHashes;
    }

    function getZoneParameters(
        AdvancedOrder memory advancedOrder,
        address fulfiller,
        uint256 counter,
        address seaport,
        CriteriaResolver[] memory criteriaResolvers
    ) internal view returns (ZoneParameters memory zoneParameters) {
        SeaportInterface seaportInterface = SeaportInterface(seaport);
        // Get orderParameters from advancedOrder
        OrderParameters memory orderParameters = advancedOrder.parameters;

        // Get orderHash
        bytes32 orderHash = advancedOrder.getTipNeutralizedOrderHash(
            seaportInterface,
            counter
        );

        (
            SpentItem[] memory spentItems,
            ReceivedItem[] memory receivedItems
        ) = getSpentAndReceivedItems(
                orderParameters,
                advancedOrder.numerator,
                advancedOrder.denominator,
                0,
                criteriaResolvers
            );

        // Store orderHash in orderHashes array to pass into zoneParameters
        bytes32[] memory orderHashes = new bytes32[](1);
        orderHashes[0] = orderHash;

        // Create ZoneParameters and add to zoneParameters array
        zoneParameters = ZoneParameters({
            orderHash: orderHash,
            fulfiller: fulfiller,
            offerer: orderParameters.offerer,
            offer: spentItems,
            consideration: receivedItems,
            extraData: advancedOrder.extraData,
            orderHashes: orderHashes,
            startTime: orderParameters.startTime,
            endTime: orderParameters.endTime,
            zoneHash: orderParameters.zoneHash
        });
    }

    function getZoneParameters(
        AdvancedOrder[] memory advancedOrders,
        address fulfiller,
        uint256 maximumFulfilled,
        address seaport,
        CriteriaResolver[] memory criteriaResolvers
    ) internal view returns (ZoneParameters[] memory) {
        return
            _getZoneParametersFromStruct(
                _getZoneParametersStruct(
                    advancedOrders,
                    fulfiller,
                    maximumFulfilled,
                    seaport,
                    criteriaResolvers
                )
            );
    }

    function _getZoneParametersStruct(
        AdvancedOrder[] memory advancedOrders,
        address fulfiller,
        uint256 maximumFulfilled,
        address seaport,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure returns (ZoneParametersStruct memory) {
        return
            ZoneParametersStruct(
                advancedOrders,
                fulfiller,
                maximumFulfilled,
                seaport,
                criteriaResolvers
            );
    }

    function _getZoneParametersFromStruct(
        ZoneParametersStruct memory zoneParametersStruct
    ) internal view returns (ZoneParameters[] memory) {
        // TODO: use testHelpers pattern to use single amount deriver helper
        ZoneDetails memory details = _getZoneDetails(zoneParametersStruct);

        // Convert offer + consideration to spent + received
        _applyOrderDetails(details, zoneParametersStruct);

        // Iterate over advanced orders to calculate orderHashes
        _applyOrderHashes(details, zoneParametersStruct.seaport);

        return _finalizeZoneParameters(details);
    }

    function _getZoneDetails(
        ZoneParametersStruct memory zoneParametersStruct
    ) internal pure returns (ZoneDetails memory) {
        return
            ZoneDetails({
                advancedOrders: zoneParametersStruct.advancedOrders,
                fulfiller: zoneParametersStruct.fulfiller,
                maximumFulfilled: zoneParametersStruct.maximumFulfilled,
                orderDetails: new OrderDetails[](
                    zoneParametersStruct.advancedOrders.length
                ),
                orderHashes: new bytes32[](
                    zoneParametersStruct.advancedOrders.length
                )
            });
    }

    function _applyOrderDetails(
        ZoneDetails memory details,
        ZoneParametersStruct memory zoneParametersStruct
    ) internal view {
        details.orderDetails = _getOrderDetails(
            zoneParametersStruct.advancedOrders,
            zoneParametersStruct.criteriaResolvers
        );
    }

    function _applyOrderHashes(
        ZoneDetails memory details,
        address seaport
    ) internal view {
        bytes32[] memory orderHashes = details.advancedOrders.getOrderHashes(
            seaport
        );

        uint256 totalFulfilled = 0;
        // Iterate over advanced orders to calculate orderHashes
        for (uint256 i = 0; i < details.advancedOrders.length; i++) {
            bytes32 orderHash = orderHashes[i];

            if (
                totalFulfilled >= details.maximumFulfilled ||
                _isUnavailable(
                    details.advancedOrders[i].parameters,
                    orderHash,
                    SeaportInterface(seaport)
                )
            ) {
                // Set orderHash to 0 if order index exceeds maximumFulfilled
                details.orderHashes[i] = bytes32(0);
            } else {
                // Add orderHash to orderHashes and increment totalFulfilled/
                details.orderHashes[i] = orderHash;
                ++totalFulfilled;
            }
        }
    }

    function _isUnavailable(
        OrderParameters memory order,
        bytes32 orderHash,
        SeaportInterface seaport
    ) internal view returns (bool) {
        (, bool isCancelled, uint256 totalFilled, uint256 totalSize) = seaport
            .getOrderStatus(orderHash);

        return (block.timestamp >= order.endTime ||
            block.timestamp < order.startTime ||
            isCancelled ||
            (totalFilled >= totalSize && totalSize > 0));
    }

    function _getOrderDetails(
        AdvancedOrder[] memory advancedOrders,
        CriteriaResolver[] memory criteriaResolvers
    ) internal view returns (OrderDetails[] memory) {
        OrderDetails[] memory orderDetails = new OrderDetails[](
            advancedOrders.length
        );
        for (uint256 i = 0; i < advancedOrders.length; i++) {
            orderDetails[i] = toOrderDetails(
                advancedOrders[i],
                i,
                criteriaResolvers
            );
        }
        return orderDetails;
    }

    function toOrderDetails(
        AdvancedOrder memory order,
        uint256 orderIndex,
        CriteriaResolver[] memory resolvers
    ) internal view returns (OrderDetails memory) {
        (
            SpentItem[] memory offer,
            ReceivedItem[] memory consideration
        ) = getSpentAndReceivedItems(
                order.parameters,
                order.numerator,
                order.denominator,
                orderIndex,
                resolvers
            );
        return
            OrderDetails({
                offerer: order.parameters.offerer,
                conduitKey: order.parameters.conduitKey,
                offer: offer,
                consideration: consideration
            });
    }

    function getSpentAndReceivedItems(
        OrderParameters memory parameters,
        uint256 numerator,
        uint256 denominator,
        uint256 orderIndex,
        CriteriaResolver[] memory criteriaResolvers
    )
        private
        view
        returns (SpentItem[] memory spent, ReceivedItem[] memory received)
    {
        if (parameters.isAvailable()) {
            spent = getSpentItems(parameters, numerator, denominator);
            received = getReceivedItems(parameters, numerator, denominator);

            applyCriteriaResolvers(
                spent,
                received,
                orderIndex,
                criteriaResolvers
            );
        }
    }

    function applyCriteriaResolvers(
        SpentItem[] memory spentItems,
        ReceivedItem[] memory receivedItems,
        uint256 orderIndex,
        CriteriaResolver[] memory criteriaResolvers
    ) private pure {
        for (uint256 i = 0; i < criteriaResolvers.length; i++) {
            CriteriaResolver memory resolver = criteriaResolvers[i];
            if (resolver.orderIndex != orderIndex) {
                continue;
            }
            if (resolver.side == Side.OFFER) {
                SpentItem memory item = spentItems[resolver.index];
                item.itemType = convertCriteriaItemType(item.itemType);
                item.identifier = resolver.identifier;
            } else {
                ReceivedItem memory item = receivedItems[resolver.index];
                item.itemType = convertCriteriaItemType(item.itemType);
                item.identifier = resolver.identifier;
            }
        }
    }

    function convertCriteriaItemType(
        ItemType itemType
    ) internal pure returns (ItemType) {
        if (itemType == ItemType.ERC721_WITH_CRITERIA) {
            return ItemType.ERC721;
        } else if (itemType == ItemType.ERC1155_WITH_CRITERIA) {
            return ItemType.ERC1155;
        } else {
            revert(
                "ZoneParametersLib: amount deriver helper resolving non criteria item type"
            );
        }
    }

    function getSpentItems(
        OrderParameters memory parameters,
        uint256 numerator,
        uint256 denominator
    ) private view returns (SpentItem[] memory) {
        return
            getSpentItems(
                parameters.offer,
                parameters.startTime,
                parameters.endTime,
                numerator,
                denominator
            );
    }

    function getReceivedItems(
        OrderParameters memory parameters,
        uint256 numerator,
        uint256 denominator
    ) private view returns (ReceivedItem[] memory) {
        return
            getReceivedItems(
                parameters.consideration,
                parameters.startTime,
                parameters.endTime,
                numerator,
                denominator
            );
    }

    function getSpentItems(
        OfferItem[] memory items,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) private view returns (SpentItem[] memory) {
        SpentItem[] memory spentItems = new SpentItem[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            spentItems[i] = getSpentItem(
                items[i],
                startTime,
                endTime,
                numerator,
                denominator
            );
        }
        return spentItems;
    }

    function getReceivedItems(
        ConsiderationItem[] memory considerationItems,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) private view returns (ReceivedItem[] memory) {
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

    function getSpentItem(
        OfferItem memory item,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) private view returns (SpentItem memory spent) {
        spent = SpentItem({
            itemType: item.itemType,
            token: item.token,
            identifier: item.identifierOrCriteria,
            amount: (block.timestamp < startTime || block.timestamp >= endTime)
                ? 0
                : _applyFraction({
                    numerator: numerator,
                    denominator: denominator,
                    startAmount: item.startAmount,
                    endAmount: item.endAmount,
                    startTime: startTime,
                    endTime: endTime,
                    roundUp: false
                })
        });
    }

    function getReceivedItem(
        ConsiderationItem memory considerationItem,
        uint256 startTime,
        uint256 endTime,
        uint256 numerator,
        uint256 denominator
    ) private view returns (ReceivedItem memory received) {
        received = ReceivedItem({
            itemType: considerationItem.itemType,
            token: considerationItem.token,
            identifier: considerationItem.identifierOrCriteria,
            amount: (block.timestamp < startTime || block.timestamp >= endTime)
                ? 0
                : _applyFraction({
                    numerator: numerator,
                    denominator: denominator,
                    startAmount: considerationItem.startAmount,
                    endAmount: considerationItem.endAmount,
                    startTime: startTime,
                    endTime: endTime,
                    roundUp: true
                }),
            recipient: considerationItem.recipient
        });
    }

    function _applyFraction(
        uint256 startAmount,
        uint256 endAmount,
        uint256 numerator,
        uint256 denominator,
        uint256 startTime,
        uint256 endTime,
        bool roundUp
    ) internal view returns (uint256 amount) {
        // If start amount equals end amount, apply fraction to end amount.
        if (startAmount == endAmount) {
            // Apply fraction to end amount.
            amount = _getFraction(numerator, denominator, endAmount);
        } else {
            // Otherwise, apply fraction to both and interpolated final amount.
            amount = _locateCurrentAmount(
                _getFraction(numerator, denominator, startAmount),
                _getFraction(numerator, denominator, endAmount),
                startTime,
                endTime,
                roundUp
            );
        }
    }

    function _getFraction(
        uint256 numerator,
        uint256 denominator,
        uint256 value
    ) internal pure returns (uint256 newValue) {
        // Return value early in cases where the fraction resolves to 1.
        if (numerator == denominator) {
            return value;
        }

        bool failure = false;

        // Ensure fraction can be applied to the value with no remainder. Note
        // that the denominator cannot be zero.
        assembly {
            // Ensure new value contains no remainder via mulmod operator.
            // Credit to @hrkrshnn + @axic for proposing this optimal solution.
            if mulmod(value, numerator, denominator) {
                failure := true
            }
        }

        if (failure) {
            revert("ZoneParametersLib: bad fraction");
        }

        // Multiply the numerator by the value and ensure no overflow occurs.
        uint256 valueTimesNumerator = value * numerator;

        // Divide and check for remainder. Note that denominator cannot be zero.
        assembly {
            // Perform division without zero check.
            newValue := div(valueTimesNumerator, denominator)
        }
    }

    function _locateCurrentAmount(
        uint256 startAmount,
        uint256 endAmount,
        uint256 startTime,
        uint256 endTime,
        bool roundUp
    ) internal view returns (uint256 amount) {
        // Only modify end amount if it doesn't already equal start amount.
        if (startAmount != endAmount) {
            // Declare variables to derive in the subsequent unchecked scope.
            uint256 duration;
            uint256 elapsed;
            uint256 remaining;

            // Skip underflow checks as startTime <= block.timestamp < endTime.
            unchecked {
                // Derive the duration for the order and place it on the stack.
                duration = endTime - startTime;

                // Derive time elapsed since the order started & place on stack.
                elapsed = block.timestamp - startTime;

                // Derive time remaining until order expires and place on stack.
                remaining = duration - elapsed;
            }

            // Aggregate new amounts weighted by time with rounding factor.
            uint256 totalBeforeDivision = ((startAmount * remaining) +
                (endAmount * elapsed));

            // Use assembly to combine operations and skip divide-by-zero check.
            assembly {
                // Multiply by iszero(iszero(totalBeforeDivision)) to ensure
                // amount is set to zero if totalBeforeDivision is zero,
                // as intermediate overflow can occur if it is zero.
                amount := mul(
                    iszero(iszero(totalBeforeDivision)),
                    // Subtract 1 from the numerator and add 1 to the result if
                    // roundUp is true to get the proper rounding direction.
                    // Division is performed with no zero check as duration
                    // cannot be zero as long as startTime < endTime.
                    add(
                        div(sub(totalBeforeDivision, roundUp), duration),
                        roundUp
                    )
                )
            }

            // Return the current amount.
            return amount;
        }

        // Return the original amount as startAmount == endAmount.
        return endAmount;
    }

    function _finalizeZoneParameters(
        ZoneDetails memory zoneDetails
    ) internal pure returns (ZoneParameters[] memory zoneParameters) {
        zoneParameters = new ZoneParameters[](
            zoneDetails.advancedOrders.length
        );

        // Iterate through advanced orders to create zoneParameters
        uint256 totalFulfilled = 0;

        for (uint i = 0; i < zoneDetails.advancedOrders.length; i++) {
            if (totalFulfilled >= zoneDetails.maximumFulfilled) {
                break;
            }

            if (zoneDetails.orderHashes[i] != bytes32(0)) {
                // Create ZoneParameters and add to zoneParameters array
                zoneParameters[i] = _createZoneParameters(
                    zoneDetails.orderHashes[i],
                    zoneDetails.orderDetails[i],
                    zoneDetails.advancedOrders[i],
                    zoneDetails.fulfiller,
                    zoneDetails.orderHashes
                );
                ++totalFulfilled;
            }
        }

        return zoneParameters;
    }

    function _createZoneParameters(
        bytes32 orderHash,
        OrderDetails memory orderDetails,
        AdvancedOrder memory advancedOrder,
        address fulfiller,
        bytes32[] memory orderHashes
    ) internal pure returns (ZoneParameters memory) {
        return
            ZoneParameters({
                orderHash: orderHash,
                fulfiller: fulfiller,
                offerer: advancedOrder.parameters.offerer,
                offer: orderDetails.offer,
                consideration: orderDetails.consideration,
                extraData: advancedOrder.extraData,
                orderHashes: orderHashes,
                startTime: advancedOrder.parameters.startTime,
                endTime: advancedOrder.parameters.endTime,
                zoneHash: advancedOrder.parameters.zoneHash
            });
    }
}
