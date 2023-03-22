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
 * @dev The "result" of execution.
 *      - FULFILLMENT: Order should be fulfilled.
 *      - UNAVAILABLE: Order should be skipped.
 *      - VALIDATE: Order should be validated.
 *      - CANCEL: Order should be cancelled.
 */
enum Result {
    FULFILLMENT,
    UNAVAILABLE,
    VALIDATE,
    CANCEL
}

/**
 * @notice Stateless helpers for Fuzz tests.
 */
library FuzzHelpers {
    using OrderLib for Order;
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;
    using AdvancedOrderLib for AdvancedOrder;
    using ZoneParametersLib for AdvancedOrder;
    using ZoneParametersLib for AdvancedOrder[];

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
            revert("FuzzEngine: Type not found");
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
     * @dev The idea here is to be able to feed in an AdvancedOrder and get back
     *      a descriptive revert reason.  This is just to get me up to speed. I
     *      understand we'll need something different for prod MOAT work.  I'll
     *      modify or delete this function.
     */
    function getBasicOrderTypeIneligibilityReason(
        AdvancedOrder memory order
    ) internal pure {
        uint256 i;
        OrderParameters memory parameters = order.parameters;

        // TODO: Think about concatenating these into a string or something.

        // Order cannot contain any ADVANCED information (no criteria-based
        // items, no extraData, cannot specify a partial fraction to fill
        // (though it can fully fill an order that supports partial fills and
        // has not yet been partially fulfilled).
        if (order.extraData.length != 0) {
            revert("Basic orders cannot have extraData");
        }

        // Order must contain exactly one offer item and one or more
        // consideration items.
        if (parameters.offer.length != 1) {
            revert("Basic orders must have exactly one offer item");
        }
        if (parameters.consideration.length == 0) {
            revert("Basic orders must have at least one consideration item");
        }

        // Order must contain exactly one NFT item.
        uint256 totalNFTs;
        if (
            parameters.offer[0].itemType == ItemType.ERC721 ||
            parameters.offer[0].itemType == ItemType.ERC1155
        ) {
            totalNFTs += 1;
        }
        for (i = 0; i < parameters.consideration.length; ++i) {
            if (
                parameters.offer[i].itemType == ItemType.ERC721 ||
                parameters.offer[i].itemType == ItemType.ERC1155
            ) {
                totalNFTs += 1;
            }
        }

        if (totalNFTs != 1) {
            revert("There must be exactly one NFT in the order");
        }

        // The one NFT must appear either as the offer item or as the first
        // consideration item.
        if (
            parameters.offer[0].itemType != ItemType.ERC721 &&
            parameters.offer[0].itemType != ItemType.ERC1155 &&
            parameters.consideration[0].itemType != ItemType.ERC721 &&
            parameters.consideration[0].itemType != ItemType.ERC1155
        ) {
            revert(
                "The NFT must be offer item or the first consideration item"
            );
        }

        // All items that are not the NFT must share the same item type and
        // token (and the identifier must be zero).
        if (
            parameters.offer[0].itemType == ItemType.ERC721 ||
            parameters.offer[0].itemType == ItemType.ERC1155
        ) {
            ItemType expectedItemType = parameters.consideration[0].itemType;
            address expectedToken = parameters.consideration[0].token;

            for (i = 0; i < parameters.consideration.length; ++i) {
                if (parameters.consideration[i].itemType != expectedItemType) {
                    revert("All non-NFT items must have the same item type");
                }

                if (parameters.consideration[i].token != expectedToken) {
                    revert("All non-NFT items must have the same token");
                }

                if (parameters.consideration[i].identifierOrCriteria != 0) {
                    revert("The identifier of non-NFT items must be zero");
                }
            }
        }

        if (
            parameters.consideration[0].itemType == ItemType.ERC721 ||
            parameters.consideration[0].itemType == ItemType.ERC1155
        ) {
            ItemType expectedItemType = parameters.consideration[1].itemType;
            address expectedToken = parameters.consideration[1].token;

            for (i = 2; i < parameters.consideration.length; ++i) {
                if (parameters.consideration[i].itemType != expectedItemType) {
                    revert("All non-NFT items must have the same item type");
                }

                if (parameters.consideration[i].token != expectedToken) {
                    revert("All non-NFT items must have the same token");
                }

                if (parameters.consideration[i].identifierOrCriteria != 0) {
                    revert("The identifier of non-NFT items must be zero");
                }
            }
        }

        // If the NFT is the first consideration item, the sum of the amounts of
        // all the other consideration items cannot exceed the amount of the
        // offer item.
        if (
            parameters.consideration[0].itemType == ItemType.ERC721 ||
            parameters.consideration[0].itemType == ItemType.ERC1155
        ) {
            uint256 totalConsiderationAmount;
            for (i = 1; i < parameters.consideration.length; ++i) {
                totalConsiderationAmount += parameters
                    .consideration[i]
                    .startAmount;
            }

            if (totalConsiderationAmount > parameters.offer[0].startAmount) {
                revert("Sum of other consideration items amount too high.");
            }

            // Note: these cases represent a “bid” for an NFT, and the non-NFT
            // consideration items (i.e. the “payment tokens”) are sent directly
            // from the offerer to each recipient; this means that the fulfiller
            // accepting the bid does not need to have approval set for the
            // payment tokens.
        }

        if (parameters.orderType == OrderType.CONTRACT) {
            revert("Basic orders cannot be contract orders");

            // Note: the order type is combined with the “route” into a single
            // BasicOrderType with a value between 0 and 23; there are 4
            // supported order types (full open, partial open, full restricted,
            // partial restricted) and 6 routes (ETH ⇒ ERC721, ETH ⇒ ERC1155,
            // ERC20 ⇒ ERC721, ERC20 ⇒ ERC1155, ERC721 ⇒ ERC20, ERC1155 ⇒ ERC20)
        }

        // All items must have startAmount == endAmount
        if (parameters.offer[0].startAmount != parameters.offer[0].endAmount) {
            revert("Basic orders must have fixed prices");
        }
        for (i = 0; i < parameters.consideration.length; ++i) {
            if (
                parameters.consideration[i].startAmount !=
                parameters.consideration[i].endAmount
            ) {
                revert("Basic orders must have fixed prices");
            }
        }

        // The offer item cannot have a native token type.
        if (parameters.offer[0].itemType == ItemType.NATIVE) {
            revert("The offer item cannot have a native token type");
        }
    }

    /**
     * @dev Get the BasicORderType for a given advanced order.
     */
    function getBasicOrderType(
        AdvancedOrder memory order
    ) internal pure  returns (BasicOrderType basicOrderType) {
        getBasicOrderTypeIneligibilityReason(order);

        // Get the route (ETH ⇒ ERC721, etc.) for the order.
        BasicOrderRouteType route;
        ItemType providingItemType = order.parameters.consideration[0].itemType;
        ItemType offeredItemType = order.parameters.offer[0].itemType;

        if (providingItemType == ItemType.NATIVE) {
            if (offeredItemType == ItemType.ERC721) {
                route = BasicOrderRouteType.ETH_TO_ERC721;
            } else if (offeredItemType == ItemType.ERC1155) {
                route = BasicOrderRouteType.ETH_TO_ERC1155;
            }
        } else if (providingItemType == ItemType.ERC20) {
            if (offeredItemType == ItemType.ERC721) {
                route = BasicOrderRouteType.ERC20_TO_ERC721;
            } else if (offeredItemType == ItemType.ERC1155) {
                route = BasicOrderRouteType.ERC20_TO_ERC1155;
            }
        } else if (providingItemType == ItemType.ERC721) {
            if (offeredItemType == ItemType.ERC20) {
                route = BasicOrderRouteType.ERC721_TO_ERC20;
            }
        } else if (providingItemType == ItemType.ERC1155) {
            if (offeredItemType == ItemType.ERC20) {
                route = BasicOrderRouteType.ERC1155_TO_ERC20;
            }
        }

        // Get the order type (restricted, etc.) for the order.
        OrderType orderType = order.parameters.orderType;

        // Multiply the route by 4 and add the order type to get the
        // BasicOrderType.
        assembly {
            basicOrderType := add(orderType, mul(route, 4))
        }
    }

    /**
     * @dev Derive ZoneParameters from a given restricted order and return
     *      the expected calldata hash for the call to validateOrder.
     */
    function getExpectedZoneCalldataHash(
        AdvancedOrder[] memory orders,
        address seaport,
        address fulfiller
    ) internal view returns (bytes32[] memory calldataHashes) {
        SeaportInterface seaportInterface = SeaportInterface(seaport);

        calldataHashes = new bytes32[](orders.length);

        ZoneParameters[] memory zoneParameters = new ZoneParameters[](
            orders.length
        );
        for (uint256 i; i < orders.length; ++i) {
            AdvancedOrder memory order = orders[i];
            // Get counter
            uint256 counter = seaportInterface.getCounter(
                order.parameters.offerer
            );

            // Derive the ZoneParameters from the AdvancedOrder
            zoneParameters[i] = orders.getZoneParameters(
                fulfiller,
                counter,
                orders.length,
                seaport
            )[i];

            // Derive the expected calldata hash for the call to validateOrder
            calldataHashes[i] = keccak256(
                abi.encodeCall(ZoneInterface.validateOrder, (zoneParameters[i]))
            );
        }
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
