// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";
import "forge-std/console.sol";

struct MOATOrderContext {
    uint256 nothingHereYet;
}

struct MOATOrder {
    AdvancedOrder order;
    MOATOrderContext context;
}

enum Structure {
    BASIC,
    STANDARD,
    ADVANCED
}

enum Type {
    OPEN,
    RESTRICTED,
    CONTRACT
}

enum Family {
    SINGLE,
    COMBINED
}

enum State {
    UNUSED,
    VALIDATED,
    CANCELLED,
    PARTIALLY_FILLED,
    FULLY_FILLED
}

library MOATHelpers {
    using OrderLib for Order;
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using AdvancedOrderLib for AdvancedOrder;

    function getQuantity(
        MOATOrder[] memory orders
    ) internal pure returns (uint256) {
        return orders.length;
    }

    function getFamily(
        MOATOrder[] memory orders
    ) internal pure returns (Family) {
        uint256 quantity = getQuantity(orders);
        if (quantity > 1) {
            return Family.COMBINED;
        }
        return Family.SINGLE;
    }

    function getState(
        MOATOrder memory order,
        SeaportInterface seaport
    ) internal view returns (State) {
        uint256 counter = seaport.getCounter(order.order.parameters.offerer);
        bytes32 orderHash = seaport.getOrderHash(
            order.order.parameters.toOrderComponents(counter)
        );
        (
            bool isValidated,
            bool isCancelled,
            uint256 totalFilled,
            uint256 totalSize
        ) = seaport.getOrderStatus(orderHash);

        if (totalFilled != 0 && totalSize != 0 && totalFilled == totalSize)
            return State.FULLY_FILLED;
        if (totalFilled != 0 && totalSize != 0) return State.PARTIALLY_FILLED;
        if (isCancelled) return State.CANCELLED;
        if (isValidated) return State.VALIDATED;
        return State.UNUSED;
    }

    function getType(MOATOrder memory order) internal pure returns (Type) {
        OrderType orderType = order.order.parameters.orderType;
        if (
            orderType == OrderType.FULL_OPEN ||
            orderType == OrderType.PARTIAL_OPEN
        ) {
            return Type.OPEN;
        } else if (
            orderType == OrderType.FULL_RESTRICTED ||
            orderType == OrderType.PARTIAL_RESTRICTED
        ) {
            return Type.RESTRICTED;
        } else if (orderType == OrderType.CONTRACT) {
            return Type.CONTRACT;
        } else {
            revert("MOATEngine: Type not found");
        }
    }

    function getStructure(
        MOATOrder memory order
    ) internal pure returns (Structure) {
        // If the order has extraData, it's advanced
        if (order.order.extraData.length > 0) return Structure.ADVANCED;

        // If the order has numerator or denominator, it's advanced
        if (order.order.numerator != 0 || order.order.denominator != 0) {
            return Structure.ADVANCED;
        }

        (bool hasCriteria, bool hasNonzeroCriteria) = _checkCriteria(order);
        bool isContractOrder = order.order.parameters.orderType ==
            OrderType.CONTRACT;

        // If any non-contract item has criteria, it's advanced,
        if (hasCriteria) {
            // Unless it's a contract order
            if (isContractOrder) {
                // And the contract order's critera are all zero
                if (hasNonzeroCriteria) {
                    return Structure.ADVANCED;
                }
            } else {
                return Structure.ADVANCED;
            }
        }

        return Structure.STANDARD;
    }

    function _checkCriteria(
        MOATOrder memory order
    ) internal pure returns (bool hasCriteria, bool hasNonzeroCriteria) {
        // Check if any offer item has criteria
        OfferItem[] memory offer = order.order.parameters.offer;
        for (uint256 i; i < offer.length; ++i) {
            OfferItem memory offerItem = offer[i];
            ItemType itemType = offerItem.itemType;
            hasCriteria = (itemType == ItemType.ERC721_WITH_CRITERIA ||
                itemType == ItemType.ERC1155_WITH_CRITERIA);
            if (offerItem.identifierOrCriteria != 0) hasNonzeroCriteria = true;
        }

        // Check if any consideration item has criteria
        ConsiderationItem[] memory consideration = order
            .order
            .parameters
            .consideration;
        for (uint256 i; i < consideration.length; ++i) {
            ConsiderationItem memory considerationItem = consideration[i];
            ItemType itemType = considerationItem.itemType;
            hasCriteria = (itemType == ItemType.ERC721_WITH_CRITERIA ||
                itemType == ItemType.ERC1155_WITH_CRITERIA);
            if (considerationItem.identifierOrCriteria != 0)
                hasNonzeroCriteria = true;
        }
    }

    function toMOATOrder(
        AdvancedOrder memory order
    ) internal pure returns (MOATOrder memory) {
        return
            MOATOrder({
                order: order,
                context: MOATOrderContext({ nothingHereYet: 0 })
            });
    }

    function toMOATOrder(
        AdvancedOrder memory order,
        MOATOrderContext memory context
    ) internal pure returns (MOATOrder memory) {
        return MOATOrder({ order: order, context: context });
    }
}
