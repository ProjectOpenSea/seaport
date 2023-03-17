// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "seaport-sol/SeaportSol.sol";

/**
 * @dev The "structure" of the order.
 *      - BASIC: adheres to basic construction rules.
 *      - STANDARD: does not adhere to basic construction rules.
 *      - ADVANCED: requires criteria resolution, partial fulfillment, and/or
 *        extraData.
 */
enum Structure {
    BASIC,
    STANDARD,
    ADVANCED
}

/**
 * @dev The "type" of the order.
 *      - OPEN: FULL_OPEN or PARTIAL_OPEN orders.
 *      - RESTRICTED: FULL_RESTRICTED or PARTIAL_RESTRICTED orders.
 *      - CONTRACT: CONTRACT orders
 */
enum Type {
    OPEN,
    RESTRICTED,
    CONTRACT
}

/**
 * @dev The "family" of method that can fulfill the order.
 *      - SINGLE: methods that accept a single order.
 *        (fulfillOrder, fulfillAdvancedOrder, fulfillBasicOrder,
 *        fulfillBasicOrder_efficient_6GL6yc)
 *      - COMBINED: methods that accept multiple orders.
 *        (fulfillAvailableOrders, fulfillAvailableAdvancedOrders, matchOrders,
 *        matchAdvancedOrders, cancel, validate)
 */
enum Family {
    SINGLE,
    COMBINED
}

/**
 * @dev The "state" of the order.
 *      - UNUSED: New, not validated, cancelled, or partially/fully filled.
 *      - VALIDATED: Order has been validated, but not cancelled or filled.
 *      - CANCELLED: Order has been cancelled.
 *      - PARTIALLY_FILLED: Order is partially filled.
 *      - FULLY_FILLED: Order is fully filled.
 */
enum State {
    UNUSED,
    VALIDATED,
    CANCELLED,
    PARTIALLY_FILLED,
    FULLY_FILLED
}

/**
 * @notice Stateless helpers for MOAT tests.
 */
library MOATHelpers {
    using OrderLib for Order;
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using AdvancedOrderLib for AdvancedOrder;

    /**
     * @dev Get the "quantity" of orders to process, equal to the number of
     *      orders in the provided array.
     * @param orders array of AdvancedOrders.
     */
    function getQuantity(
        AdvancedOrder[] memory orders
    ) internal pure returns (uint256) {
        return orders.length;
    }

    /**
     * @dev Get the "family" of method that can fulfill these orders.
     * @param orders array of AdvancedOrders.
     */
    function getFamily(
        AdvancedOrder[] memory orders
    ) internal pure returns (Family) {
        uint256 quantity = getQuantity(orders);
        if (quantity > 1) {
            return Family.COMBINED;
        }
        return Family.SINGLE;
    }

    /**
     * @dev Get the "state" of the given order.
     * @param order an AdvancedOrder.
     * @param seaport a SeaportInterface, either reference or optimized.
     */
    function getState(
        AdvancedOrder memory order,
        SeaportInterface seaport
    ) internal view returns (State) {
        uint256 counter = seaport.getCounter(order.parameters.offerer);
        bytes32 orderHash = seaport.getOrderHash(
            order.parameters.toOrderComponents(counter)
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

    /**
     * @dev Get the "type" of the given order.
     * @param order an AdvancedOrder.
     */
    function getType(AdvancedOrder memory order) internal pure returns (Type) {
        OrderType orderType = order.parameters.orderType;
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

    /**
     * @dev Get the "structure" of the given order.
     *
     *      Note: Basic orders are not yet implemented here and are detected
     *      as standard orders for now.
     *
     * @param order an AdvancedOrder.
     */
    function getStructure(
        AdvancedOrder memory order
    ) internal pure returns (Structure) {
        // If the order has extraData, it's advanced
        if (order.extraData.length > 0) return Structure.ADVANCED;

        // If the order has numerator or denominator, it's advanced
        if (order.numerator != 0 || order.denominator != 0) {
            return Structure.ADVANCED;
        }

        (bool hasCriteria, bool hasNonzeroCriteria) = _checkCriteria(order);
        bool isContractOrder = order.parameters.orderType == OrderType.CONTRACT;

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

    /**
     * @dev Check all offer and consideration items for criteria.
     */
    function _checkCriteria(
        AdvancedOrder memory order
    ) internal pure returns (bool hasCriteria, bool hasNonzeroCriteria) {
        // Check if any offer item has criteria
        OfferItem[] memory offer = order.parameters.offer;
        for (uint256 i; i < offer.length; ++i) {
            OfferItem memory offerItem = offer[i];
            ItemType itemType = offerItem.itemType;
            hasCriteria = (itemType == ItemType.ERC721_WITH_CRITERIA ||
                itemType == ItemType.ERC1155_WITH_CRITERIA);
            if (offerItem.identifierOrCriteria != 0) {
                hasNonzeroCriteria = true;
                return (hasCriteria, hasNonzeroCriteria);
            }
        }

        // Check if any consideration item has criteria
        ConsiderationItem[] memory consideration = order
            .parameters
            .consideration;
        for (uint256 i; i < consideration.length; ++i) {
            ConsiderationItem memory considerationItem = consideration[i];
            ItemType itemType = considerationItem.itemType;
            hasCriteria = (itemType == ItemType.ERC721_WITH_CRITERIA ||
                itemType == ItemType.ERC1155_WITH_CRITERIA);
            if (considerationItem.identifierOrCriteria != 0) {
                hasNonzeroCriteria = true;
                return (hasCriteria, hasNonzeroCriteria);
            }
        }
    }
}
