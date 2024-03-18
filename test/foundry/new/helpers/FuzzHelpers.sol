// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrderLib,
    ConsiderationItemLib,
    MatchComponent,
    MatchComponentType,
    OfferItemLib,
    OrderComponentsLib,
    OrderLib,
    OrderParametersLib,
    SeaportArrays,
    ZoneParametersLib
} from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    Fulfillment,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    ReceivedItem,
    SpentItem,
    ZoneParameters
} from "seaport-sol/src/SeaportStructs.sol";

import {
    BasicOrderRouteType,
    BasicOrderType,
    ItemType,
    OrderType,
    Side
} from "seaport-sol/src/SeaportEnums.sol";

import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";

import {
    ContractOffererInterface
} from "seaport-sol/src/ContractOffererInterface.sol";

import { SeaportInterface } from "seaport-sol/src/SeaportInterface.sol";

import { ZoneInterface } from "seaport-sol/src/ZoneInterface.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { FuzzInscribers } from "./FuzzInscribers.sol";

import { assume } from "./VmUtils.sol";

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
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem[];
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using ZoneParametersLib for AdvancedOrder;
    using ZoneParametersLib for AdvancedOrder[];
    using FuzzInscribers for AdvancedOrder;

    event ExpectedGenerateOrderDataHash(bytes32 dataHash);

    function _gcd(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            return a;
        } else {
            return _gcd(b, a % b);
        }
    }

    function _lcm(
        uint256 a,
        uint256 b,
        uint256 gcdValue
    ) internal returns (uint256 result) {
        bool success;
        (success, result) = _tryMul(a, b);

        if (success) {
            return result / gcdValue;
        } else {
            uint256 candidate = a / gcdValue;
            if (candidate * gcdValue == a) {
                (success, result) = _tryMul(candidate, b);
                if (success) {
                    return result;
                } else {
                    candidate = b / gcdValue;
                    if (candidate * gcdValue == b) {
                        (success, result) = _tryMul(candidate, a);
                        if (success) {
                            return result;
                        }
                    }
                }
            }

            assume(false, "cannot_derive_lcm_for_partial_fill");
        }

        return result / gcdValue;
    }

    function _tryMul(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) {
                return (true, 0);
            }

            uint256 c = a * b;

            if (c / a != b) {
                return (false, 0);
            }

            return (true, c);
        }
    }

    function findSmallestDenominator(
        uint256[] memory numbers
    ) internal returns (uint256 denominator) {
        require(
            numbers.length > 0,
            "FuzzHelpers: Input array must not be empty"
        );

        bool initialValueSet = false;

        uint256 gcdValue;
        uint256 lcmValue;

        for (uint256 i = 0; i < numbers.length; i++) {
            uint256 number = numbers[i];

            if (number == 0) {
                continue;
            }

            if (!initialValueSet) {
                initialValueSet = true;
                gcdValue = number;
                lcmValue = number;
                continue;
            }

            gcdValue = _gcd(gcdValue, number);
            lcmValue = _lcm(lcmValue, number, gcdValue);
        }

        if (gcdValue == 0) {
            return 0;
        }

        denominator = lcmValue / gcdValue;

        // TODO: this should support up to uint120, work out
        // how to fly closer to the sun on this
        if (denominator > type(uint80).max) {
            return 0;
        }
    }

    function getTotalFractionalizableAmounts(
        OrderParameters memory order
    ) internal pure returns (uint256) {
        if (
            order.orderType == OrderType.PARTIAL_OPEN ||
            order.orderType == OrderType.PARTIAL_RESTRICTED
        ) {
            return 2 * (order.offer.length + order.consideration.length);
        }

        return 0;
    }

    function getSmallestDenominator(
        OrderParameters memory order
    ) internal returns (uint256 smallestDenominator, bool canScaleUp) {
        canScaleUp = true;

        uint256 totalFractionalizableAmounts = (
            getTotalFractionalizableAmounts(order)
        );

        if (totalFractionalizableAmounts != 0) {
            uint256[] memory numbers = new uint256[](
                totalFractionalizableAmounts
            );

            uint256 numberIndex = 0;

            for (uint256 j = 0; j < order.offer.length; ++j) {
                OfferItem memory item = order.offer[j];
                numbers[numberIndex++] = item.startAmount;
                numbers[numberIndex++] = item.endAmount;
                if (
                    item.itemType == ItemType.ERC721 ||
                    item.itemType == ItemType.ERC721_WITH_CRITERIA
                ) {
                    canScaleUp = false;
                }
            }

            for (uint256 j = 0; j < order.consideration.length; ++j) {
                ConsiderationItem memory item = order.consideration[j];
                numbers[numberIndex++] = item.startAmount;
                numbers[numberIndex++] = item.endAmount;
                if (
                    item.itemType == ItemType.ERC721 ||
                    item.itemType == ItemType.ERC721_WITH_CRITERIA
                ) {
                    canScaleUp = false;
                }
            }

            smallestDenominator = findSmallestDenominator(numbers);
        } else {
            smallestDenominator = 0;
        }
    }

    /**
     * @dev Get the "quantity" of orders to process, equal to the number of
     *      orders in the provided array.
     *
     * @param orders array of AdvancedOrders.
     *
     * @custom:return quantity of orders to process.
     */
    function getQuantity(
        AdvancedOrder[] memory orders
    ) internal pure returns (uint256) {
        return orders.length;
    }

    /**
     * @dev Get the "family" of method that can fulfill these orders.
     *
     * @param orders array of AdvancedOrders.
     *
     * @custom:return family of method that can fulfill these orders.
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
     *
     * @param order   an AdvancedOrder.
     * @param seaport a SeaportInterface, either reference or optimized.
     *
     * @custom:return state of the given order.
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

        if (totalFilled != 0 && totalSize != 0 && totalFilled == totalSize) {
            return State.FULLY_FILLED;
        }
        if (totalFilled != 0 && totalSize != 0) return State.PARTIALLY_FILLED;
        if (isCancelled) return State.CANCELLED;
        if (isValidated) return State.VALIDATED;
        return State.UNUSED;
    }

    /**
     * @dev Get the "type" of the given order.
     *
     * @param order an AdvancedOrder.
     *
     * @custom:return type of the given order (in the sense of the enum defined
     *                above in this file, not ConsiderationStructs' OrderType).
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
     * @param order   an AdvancedOrder.
     * @param seaport a SeaportInterface, either reference or optimized.
     *
     * @custom:return structure of the given order.
     */
    function getStructure(
        AdvancedOrder memory order,
        address seaport
    ) internal view returns (Structure) {
        // If the order has extraData, it's advanced
        if (order.extraData.length > 0) return Structure.ADVANCED;

        // If the order has numerator or denominator, it's advanced
        if (order.numerator != 0 || order.denominator != 0) {
            if (order.numerator < order.denominator) {
                return Structure.ADVANCED;
            }
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

        if (getBasicOrderTypeEligibility(order, seaport)) {
            return Structure.BASIC;
        }

        return Structure.STANDARD;
    }

    function getStructure(
        AdvancedOrder[] memory orders,
        address seaport
    ) internal view returns (Structure) {
        if (orders.length == 1) {
            return getStructure(orders[0], seaport);
        }

        for (uint256 i; i < orders.length; i++) {
            Structure structure = getStructure(orders[i], seaport);
            if (structure == Structure.ADVANCED) {
                return Structure.ADVANCED;
            }
        }

        return Structure.STANDARD;
    }

    /**
     * @dev Inspect an AdvancedOrder and check that it is eligible for the
     *      fulfillBasic functions.
     *
     * @param order   an AdvancedOrder.
     * @param seaport a SeaportInterface, either reference or optimized.
     *
     * @custom:return true if the order is eligible for the fulfillBasic
     *                functions, false otherwise.
     */
    function getBasicOrderTypeEligibility(
        AdvancedOrder memory order,
        address seaport
    ) internal view returns (bool) {
        uint256 i;
        ConsiderationItem[] memory consideration = order
            .parameters
            .consideration;
        OfferItem[] memory offer = order.parameters.offer;

        // Order must contain exactly one offer item and one or more
        // consideration items.
        if (offer.length != 1) {
            return false;
        }
        if (
            consideration.length == 0 ||
            order.parameters.totalOriginalConsiderationItems == 0
        ) {
            return false;
        }

        // The order cannot have a contract order type.
        if (order.parameters.orderType == OrderType.CONTRACT) {
            return false;

            // Note: the order type is combined with the “route” into a single
            // BasicOrderType with a value between 0 and 23; there are 4
            // supported order types (full open, partial open, full restricted,
            // partial restricted) and 6 routes (ETH ⇒ ERC721, ETH ⇒ ERC1155,
            // ERC20 ⇒ ERC721, ERC20 ⇒ ERC1155, ERC721 ⇒ ERC20, ERC1155 ⇒ ERC20)
        }

        // Order cannot specify a partial fraction to fill.
        if (order.denominator > 1 && (order.numerator < order.denominator)) {
            return false;
        }

        // Order cannot be partially filled.
        SeaportInterface seaportInterface = SeaportInterface(seaport);
        uint256 counter = seaportInterface.getCounter(order.parameters.offerer);
        OrderComponents memory orderComponents = order
            .parameters
            .toOrderComponents(counter);
        bytes32 orderHash = seaportInterface.getOrderHash(orderComponents);
        (, , uint256 totalFilled, uint256 totalSize) = seaportInterface
            .getOrderStatus(orderHash);

        if (totalFilled != totalSize) {
            return false;
        }

        // Order cannot contain any criteria-based items.
        for (i = 0; i < consideration.length; ++i) {
            if (
                consideration[i].itemType == ItemType.ERC721_WITH_CRITERIA ||
                consideration[i].itemType == ItemType.ERC1155_WITH_CRITERIA
            ) {
                return false;
            }
        }

        if (
            offer[0].itemType == ItemType.ERC721_WITH_CRITERIA ||
            offer[0].itemType == ItemType.ERC1155_WITH_CRITERIA
        ) {
            return false;
        }

        // Order cannot contain any extraData.
        if (order.extraData.length != 0) {
            return false;
        }

        // Order must contain exactly one NFT item.
        uint256 totalNFTs;
        if (
            offer[0].itemType == ItemType.ERC721 ||
            offer[0].itemType == ItemType.ERC1155
        ) {
            totalNFTs += 1;
        }
        for (i = 0; i < consideration.length; ++i) {
            if (
                consideration[i].itemType == ItemType.ERC721 ||
                consideration[i].itemType == ItemType.ERC1155
            ) {
                totalNFTs += 1;
            }
        }

        if (totalNFTs != 1) {
            return false;
        }

        // The one NFT must appear either as the offer item or as the first
        // consideration item.
        if (
            offer[0].itemType != ItemType.ERC721 &&
            offer[0].itemType != ItemType.ERC1155 &&
            consideration[0].itemType != ItemType.ERC721 &&
            consideration[0].itemType != ItemType.ERC1155
        ) {
            return false;
        }

        // All items that are not the NFT must share the same item type and
        // token (and the identifier must be zero).
        if (
            offer[0].itemType == ItemType.ERC721 ||
            offer[0].itemType == ItemType.ERC1155
        ) {
            ItemType expectedItemType = consideration[0].itemType;
            address expectedToken = consideration[0].token;

            for (i = 0; i < consideration.length; ++i) {
                if (consideration[i].itemType != expectedItemType) {
                    return false;
                }

                if (consideration[i].token != expectedToken) {
                    return false;
                }

                if (consideration[i].identifierOrCriteria != 0) {
                    return false;
                }
            }
        }

        if (
            consideration[0].itemType == ItemType.ERC721 ||
            consideration[0].itemType == ItemType.ERC1155
        ) {
            if (consideration.length >= 2) {
                ItemType expectedItemType = offer[0].itemType;
                address expectedToken = offer[0].token;
                for (i = 1; i < consideration.length; ++i) {
                    if (consideration[i].itemType != expectedItemType) {
                        return false;
                    }

                    if (consideration[i].token != expectedToken) {
                        return false;
                    }

                    if (consideration[i].identifierOrCriteria != 0) {
                        return false;
                    }
                }
            }
        }

        // The offerer must be the recipient of the first consideration item.
        if (consideration[0].recipient != order.parameters.offerer) {
            return false;
        }

        // If the NFT is the first consideration item, the sum of the amounts of
        // all the other consideration items cannot exceed the amount of the
        // offer item.
        if (
            consideration[0].itemType == ItemType.ERC721 ||
            consideration[0].itemType == ItemType.ERC1155
        ) {
            uint256 totalConsiderationAmount;
            for (i = 1; i < consideration.length; ++i) {
                totalConsiderationAmount += consideration[i].startAmount;
            }

            if (totalConsiderationAmount > offer[0].startAmount) {
                return false;
            }

            // Note: these cases represent a “bid” for an NFT, and the non-NFT
            // consideration items (i.e. the “payment tokens”) are sent directly
            // from the offerer to each recipient; this means that the fulfiller
            // accepting the bid does not need to have approval set for the
            // payment tokens.
        }

        // All items must have startAmount == endAmount
        if (offer[0].startAmount != offer[0].endAmount) {
            return false;
        }
        for (i = 0; i < consideration.length; ++i) {
            if (consideration[i].startAmount != consideration[i].endAmount) {
                return false;
            }
        }

        // The offer item cannot have a native token type.
        if (offer[0].itemType == ItemType.NATIVE) {
            return false;
        }

        return true;
    }

    /**
     * @dev Get the BasicOrderType for a given advanced order.
     *
     * @param order The advanced order.
     *
     * @return basicOrderType The BasicOrderType.
     */
    function getBasicOrderType(
        AdvancedOrder memory order
    ) internal pure returns (BasicOrderType basicOrderType) {
        // Get the route (ETH ⇒ ERC721, etc.) for the order.
        BasicOrderRouteType route = getBasicOrderRouteType(order);

        // Get the order type (restricted, etc.) for the order.
        OrderType orderType = order.parameters.orderType;

        // Multiply the route by 4 and add the order type to get the
        // BasicOrderType.
        assembly {
            basicOrderType := add(orderType, mul(route, 4))
        }
    }

    /**
     * @dev Get the BasicOrderRouteType for a given advanced order.
     *
     * @param order The advanced order.
     *
     * @return route The BasicOrderRouteType.
     */
    function getBasicOrderRouteType(
        AdvancedOrder memory order
    ) internal pure returns (BasicOrderRouteType route) {
        // Get the route (ETH ⇒ ERC721, etc.) for the order.
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
    }

    /**
     * @dev Derive ZoneParameters from a given restricted order and return
     *      the expected calldata hash for the call to authorizeOrder.
     *
     * @param orders             The restricted orders.
     * @param seaport            The Seaport address.
     * @param fulfiller          The fulfiller.
     * @param maximumFulfilled   The maximum number of orders to fulfill.
     * @param criteriaResolvers  The criteria resolvers.
     * @param maximumFulfilled   The maximum number of orders to fulfill.
     * @param unavailableReasons The availability status.
     *
     * @return calldataHashes The derived calldata hashes.
     */
    function getExpectedZoneAuthorizeCalldataHash(
        AdvancedOrder[] memory orders,
        address seaport,
        address fulfiller,
        CriteriaResolver[] memory criteriaResolvers,
        uint256 maximumFulfilled,
        UnavailableReason[] memory unavailableReasons
    ) internal view returns (bytes32[] memory calldataHashes) {
        calldataHashes = new bytes32[](orders.length);

        ZoneParameters[] memory zoneParameters = orders
            .getZoneAuthorizeParameters(
                fulfiller,
                maximumFulfilled,
                seaport,
                criteriaResolvers,
                unavailableReasons
            );

        for (uint256 i; i < zoneParameters.length; ++i) {
            // Derive the expected calldata hash for the call to authorizeOrder
            calldataHashes[i] = keccak256(
                abi.encodeCall(
                    ZoneInterface.authorizeOrder,
                    (zoneParameters[i])
                )
            );
        }
    }

    /**
     * @dev Derive ZoneParameters from a given restricted order and return
     *      the expected calldata hash for the call to validateOrder.
     *
     * @param orders             The restricted orders.
     * @param seaport            The Seaport address.
     * @param fulfiller          The fulfiller.
     * @param maximumFulfilled   The maximum number of orders to fulfill.
     * @param criteriaResolvers  The criteria resolvers.
     * @param maximumFulfilled   The maximum number of orders to fulfill.
     * @param unavailableReasons The availability status.
     *
     * @return calldataHashes The derived calldata hashes.
     */
    function getExpectedZoneValidateCalldataHash(
        AdvancedOrder[] memory orders,
        address seaport,
        address fulfiller,
        CriteriaResolver[] memory criteriaResolvers,
        uint256 maximumFulfilled,
        UnavailableReason[] memory unavailableReasons
    ) internal view returns (bytes32[] memory calldataHashes) {
        calldataHashes = new bytes32[](orders.length);

        ZoneParameters[] memory zoneParameters = orders
            .getZoneValidateParameters(
                fulfiller,
                maximumFulfilled,
                seaport,
                criteriaResolvers,
                unavailableReasons
            );

        for (uint256 i; i < zoneParameters.length; ++i) {
            // Derive the expected calldata hash for the call to validateOrder
            calldataHashes[i] = keccak256(
                abi.encodeCall(ZoneInterface.validateOrder, (zoneParameters[i]))
            );
        }
    }

    /**
     * @dev Get the orderHashes of an array of AdvancedOrders and return
     *      the expected calldata hashes for calls to validateOrder.
     */
    function getExpectedContractOffererCalldataHashes(
        FuzzTestContext memory context
    ) internal pure returns (bytes32[2][] memory) {
        AdvancedOrder[] memory orders = context.executionState.orders;
        address fulfiller = context.executionState.caller;

        bytes32[] memory orderHashes = new bytes32[](orders.length);
        for (uint256 i = 0; i < orderHashes.length; ++i) {
            if (
                context.executionState.orderDetails[i].unavailableReason !=
                UnavailableReason.AVAILABLE
            ) {
                orderHashes[i] = bytes32(0);
            } else {
                orderHashes[i] = context
                    .executionState
                    .orderDetails[i]
                    .orderHash;
            }
        }

        bytes32[2][] memory calldataHashes = new bytes32[2][](orders.length);

        // Iterate over contract orders to derive calldataHashes
        for (uint256 i; i < orders.length; ++i) {
            AdvancedOrder memory order = orders[i];

            // calldataHashes for non-contract orders should be null
            if (getType(order) != Type.CONTRACT) {
                continue;
            }

            SpentItem[] memory minimumReceived = order
                .parameters
                .offer
                .toSpentItemArray();

            SpentItem[] memory maximumSpent = order
                .parameters
                .consideration
                .toSpentItemArray();

            // apply criteria resolvers before hashing
            for (
                uint256 j = 0;
                j < context.executionState.criteriaResolvers.length;
                ++j
            ) {
                CriteriaResolver memory resolver = context
                    .executionState
                    .criteriaResolvers[j];

                if (resolver.orderIndex != i) {
                    continue;
                }

                // NOTE: assumes that all provided resolvers are valid
                if (resolver.side == Side.OFFER) {
                    minimumReceived[resolver.index].itemType = ItemType(
                        uint256(minimumReceived[resolver.index].itemType) - 2
                    );
                    minimumReceived[resolver.index].identifier = resolver
                        .identifier;
                } else {
                    maximumSpent[resolver.index].itemType = ItemType(
                        uint256(maximumSpent[resolver.index].itemType) - 2
                    );
                    maximumSpent[resolver.index].identifier = resolver
                        .identifier;
                }
            }

            // Derive the expected calldata hash for the call to generateOrder
            calldataHashes[i][0] = keccak256(
                abi.encodeCall(
                    ContractOffererInterface.generateOrder,
                    (fulfiller, minimumReceived, maximumSpent, order.extraData)
                )
            );

            uint256 shiftedOfferer = uint256(
                uint160(order.parameters.offerer)
            ) << 96;

            // Get counter of the order offerer
            uint256 counter = shiftedOfferer ^ uint256(orderHashes[i]);

            // Derive the expected calldata hash for the call to ratifyOrder
            calldataHashes[i][1] = keccak256(
                abi.encodeCall(
                    ContractOffererInterface.ratifyOrder,
                    (
                        context.executionState.orderDetails[i].offer,
                        context.executionState.orderDetails[i].consideration,
                        order.extraData,
                        orderHashes,
                        counter
                    )
                )
            );
        }

        return calldataHashes;
    }

    /**
     * @dev Call `validate` on an AdvancedOrders and return the success bool.
     *      This function can be treated as a wrapper around Seaport's
     *      `validate` function. It is used to validate an AdvancedOrder that
     *      thas a tip added onto it.  Calling it on an AdvancedOrder that does
     *      not have a tip is identical to calling Seaport's `validate` function
     *      directly. Seaport handles tips gracefully inside of the top level
     *      fulfill and match functions, but since we're adding tips early in
     *      the fuzz test lifecycle, it's necessary to flip them back and forth
     *      when we need to validate orders. Note: they're two different orders,
     *      so e.g. cancelling or validating order with a tip on it is not the
     *      same as cancelling the order without a tip on it.
     */
    function validateTipNeutralizedOrder(
        AdvancedOrder memory order,
        FuzzTestContext memory context
    ) internal returns (bool validated) {
        order.inscribeOrderStatusValidated(true, context.seaport);
        return true;
    }

    function cancelTipNeutralizedOrder(
        AdvancedOrder memory order,
        SeaportInterface seaport
    ) internal view returns (bytes32 orderHash) {
        // Get the orderHash using the tweaked OrderComponents.
        orderHash = order.getTipNeutralizedOrderHash(seaport);
    }

    /**
     * @dev Check all offer and consideration items for criteria.
     *
     * @param order The advanced order.
     *
     * @return hasCriteria        Whether any offer or consideration item has
     *                            criteria.
     * @return hasNonzeroCriteria Whether any offer or consideration item has
     *                            nonzero criteria.
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
            if (hasCriteria) {
                return (hasCriteria, offerItem.identifierOrCriteria != 0);
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
            if (hasCriteria) {
                return (
                    hasCriteria,
                    considerationItem.identifierOrCriteria != 0
                );
            }
        }

        return (false, false);
    }
}

function _locateCurrentAmount(
    uint256 startAmount,
    uint256 endAmount,
    uint256 startTime,
    uint256 endTime,
    bool roundUp
) view returns (uint256 amount) {
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
                add(div(sub(totalBeforeDivision, roundUp), duration), roundUp)
            )
        }

        // Return the current amount.
        return amount;
    }

    // Return the original amount as startAmount == endAmount.
    return endAmount;
}
