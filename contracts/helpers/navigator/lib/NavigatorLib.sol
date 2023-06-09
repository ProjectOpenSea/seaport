// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import { AdvancedOrderLib } from "seaport-sol/src/lib/AdvancedOrderLib.sol";
import { OrderComponentsLib } from "seaport-sol/src/lib/OrderComponentsLib.sol";
import { OrderLib } from "seaport-sol/src/lib/OrderLib.sol";
import { OrderParametersLib } from "seaport-sol/src/lib/OrderParametersLib.sol";
import { UnavailableReason } from "seaport-sol/src/SpaceEnums.sol";

import {
    MatchComponent
} from "seaport-sol/src/lib/types/MatchComponentType.sol";
import {
    FulfillmentDetails,
    OrderDetails
} from "seaport-sol/src/fulfillments/lib/Structs.sol";

import {
    FulfillmentGeneratorLib
} from "seaport-sol/src/fulfillments/lib/FulfillmentLib.sol";

import {
    ExecutionHelper
} from "seaport-sol/src/executions/ExecutionHelper.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    Execution,
    Order,
    OrderComponents,
    OrderParameters,
    ConsiderationItem,
    OfferItem,
    ReceivedItem,
    SpentItem,
    Fulfillment,
    FulfillmentComponent
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ItemType,
    Side,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    Type,
    Family,
    OrderStructureLib,
    Structure
} from "./OrderStructureLib.sol";

import { OrderAvailabilityLib } from "./OrderAvailabilityLib.sol";

import { CriteriaHelperLib } from "./CriteriaHelperLib.sol";

import {
    NavigatorRequest,
    NavigatorResponse,
    NavigatorContext,
    NavigatorOfferItem,
    NavigatorConsiderationItem,
    NavigatorOrderParameters,
    NavigatorAdvancedOrder
} from "./SeaportNavigatorTypes.sol";

import {
    SeaportValidatorInterface,
    ErrorsAndWarnings
} from "../../order-validator/SeaportValidator.sol";

/**
 * @dev Bad request error: provided orders include at least one contract order.
 *      The order helper does not currently support contract orders.
 */
error ContractOrdersNotSupported();
/**
 * @dev Bad request error: provided orders cannot be fulfilled.
 */
error CannotFulfillProvidedCombinedOrder();
/**
 * @dev Bad request error: provided orders include an invalid combination of
 *      native tokens and unavailable orders.
 */
error InvalidNativeTokenUnavailableCombination();
/**
 * @dev Internal error: Could not select a fulfillment method for the provided
 *      orders.
 */
error UnknownAction();
/**
 * @dev Internal error: Could not convert item type.
 */
error UnknownItemType();
/**
 * @dev Internal error: Could not find selector for the suggested action.
 */
error UnknownSelector();

library HelperItemLib {
    error InvalidIdentifier(uint256 identifier, uint256[] candidateIdentifiers);
    error InvalidItemTypeForCandidateIdentifiers();

    function normalizeType(
        NavigatorOfferItem memory item
    ) internal pure returns (ItemType) {
        ItemType itemType = item.itemType;
        if (hasCriteria(item)) {
            if (
                itemType == ItemType.ERC721 ||
                itemType == ItemType.ERC721_WITH_CRITERIA
            ) {
                return ItemType.ERC721_WITH_CRITERIA;
            } else if (
                itemType == ItemType.ERC1155 ||
                itemType == ItemType.ERC1155_WITH_CRITERIA
            ) {
                return ItemType.ERC1155_WITH_CRITERIA;
            } else {
                revert UnknownItemType();
            }
        } else {
            return itemType;
        }
    }

    function normalizeType(
        NavigatorConsiderationItem memory item
    ) internal pure returns (ItemType) {
        ItemType itemType = item.itemType;
        if (hasCriteria(item)) {
            if (
                itemType == ItemType.ERC721 ||
                itemType == ItemType.ERC721_WITH_CRITERIA
            ) {
                return ItemType.ERC721_WITH_CRITERIA;
            } else if (
                itemType == ItemType.ERC1155 ||
                itemType == ItemType.ERC1155_WITH_CRITERIA
            ) {
                return ItemType.ERC1155_WITH_CRITERIA;
            } else {
                revert UnknownItemType();
            }
        } else {
            return itemType;
        }
    }

    function hasCriteria(
        NavigatorOfferItem memory item
    ) internal pure returns (bool) {
        return item.candidateIdentifiers.length > 0;
    }

    function hasCriteria(
        NavigatorConsiderationItem memory item
    ) internal pure returns (bool) {
        return item.candidateIdentifiers.length > 0;
    }

    function validate(NavigatorOfferItem memory item) internal pure {
        ItemType itemType = item.itemType;
        if (itemType == ItemType.ERC20 || itemType == ItemType.NATIVE) {
            if (item.candidateIdentifiers.length > 0) {
                revert InvalidItemTypeForCandidateIdentifiers();
            } else {
                return;
            }
        }
        // If the item has candidate identifiers, the item identifier must be
        // zero for wildcard or one of the candidates.
        if (item.candidateIdentifiers.length == 0 && item.identifier == 0) {
            revert InvalidIdentifier(
                item.identifier,
                item.candidateIdentifiers
            );
        }
        if (item.candidateIdentifiers.length > 0) {
            bool identifierFound;
            for (uint256 i; i < item.candidateIdentifiers.length; i++) {
                if (item.candidateIdentifiers[i] == item.identifier) {
                    identifierFound = true;
                    break;
                }
            }
            if (!identifierFound && item.identifier != 0) {
                revert InvalidIdentifier(
                    item.identifier,
                    item.candidateIdentifiers
                );
            }
        }
    }

    function validate(NavigatorConsiderationItem memory item) internal pure {
        ItemType itemType = item.itemType;
        if (itemType == ItemType.ERC20 || itemType == ItemType.NATIVE) {
            if (item.candidateIdentifiers.length > 0) {
                revert InvalidItemTypeForCandidateIdentifiers();
            } else {
                return;
            }
        }
        // If the item has candidate identifiers, the item identifier must be
        // zero for wildcard or one of the candidates.
        if (item.candidateIdentifiers.length == 0 && item.identifier == 0) {
            revert InvalidIdentifier(
                item.identifier,
                item.candidateIdentifiers
            );
        }
        if (item.candidateIdentifiers.length > 0) {
            bool identifierFound;
            for (uint256 i; i < item.candidateIdentifiers.length; i++) {
                if (item.candidateIdentifiers[i] == item.identifier) {
                    identifierFound = true;
                    break;
                }
            }
            if (!identifierFound && item.identifier != 0) {
                revert InvalidIdentifier(
                    item.identifier,
                    item.candidateIdentifiers
                );
            }
        }
    }
}

library NavigatorAdvancedOrderLib {
    using CriteriaHelperLib for uint256[];
    using HelperItemLib for NavigatorOfferItem;
    using HelperItemLib for NavigatorConsiderationItem;

    function fromAdvancedOrders(
        AdvancedOrder[] memory orders
    ) internal pure returns (NavigatorAdvancedOrder[] memory) {
        NavigatorAdvancedOrder[]
            memory helperOrders = new NavigatorAdvancedOrder[](orders.length);
        for (uint256 i; i < orders.length; i++) {
            helperOrders[i] = fromAdvancedOrder(orders[i]);
        }
        return helperOrders;
    }

    function fromAdvancedOrder(
        AdvancedOrder memory order
    ) internal pure returns (NavigatorAdvancedOrder memory) {
        NavigatorOfferItem[] memory offerItems = new NavigatorOfferItem[](
            order.parameters.offer.length
        );
        for (uint256 i; i < order.parameters.offer.length; i++) {
            OfferItem memory item = order.parameters.offer[i];
            offerItems[i] = NavigatorOfferItem({
                itemType: item.itemType,
                token: item.token,
                identifier: item.identifierOrCriteria,
                startAmount: item.startAmount,
                endAmount: item.endAmount,
                candidateIdentifiers: new uint256[](0)
            });
        }
        NavigatorConsiderationItem[]
            memory considerationItems = new NavigatorConsiderationItem[](
                order.parameters.consideration.length
            );
        for (uint256 i; i < order.parameters.consideration.length; i++) {
            ConsiderationItem memory item = order.parameters.consideration[i];
            considerationItems[i] = NavigatorConsiderationItem({
                itemType: item.itemType,
                token: item.token,
                identifier: item.identifierOrCriteria,
                startAmount: item.startAmount,
                endAmount: item.endAmount,
                recipient: item.recipient,
                candidateIdentifiers: new uint256[](0)
            });
        }
        return
            NavigatorAdvancedOrder({
                parameters: NavigatorOrderParameters({
                    offerer: order.parameters.offerer,
                    zone: order.parameters.zone,
                    offer: offerItems,
                    consideration: considerationItems,
                    orderType: order.parameters.orderType,
                    startTime: order.parameters.startTime,
                    endTime: order.parameters.endTime,
                    zoneHash: order.parameters.zoneHash,
                    salt: order.parameters.salt,
                    conduitKey: order.parameters.conduitKey,
                    totalOriginalConsiderationItems: order
                        .parameters
                        .totalOriginalConsiderationItems
                }),
                numerator: order.numerator,
                denominator: order.denominator,
                signature: order.signature,
                extraData: order.extraData
            });
    }

    function toAdvancedOrder(
        NavigatorAdvancedOrder memory order,
        uint256 orderIndex
    ) internal pure returns (AdvancedOrder memory, CriteriaResolver[] memory) {
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](
            order.parameters.offer.length +
                order.parameters.consideration.length
        );
        uint256 criteriaResolverLen;
        OfferItem[] memory offer = new OfferItem[](
            order.parameters.offer.length
        );
        for (uint256 i; i < order.parameters.offer.length; i++) {
            NavigatorOfferItem memory item = order.parameters.offer[i];
            if (item.hasCriteria()) {
                item.validate();
                offer[i] = OfferItem({
                    itemType: item.normalizeType(),
                    token: item.token,
                    identifierOrCriteria: uint256(
                        item.candidateIdentifiers.criteriaRoot()
                    ),
                    startAmount: item.startAmount,
                    endAmount: item.endAmount
                });
                criteriaResolvers[criteriaResolverLen] = CriteriaResolver({
                    orderIndex: orderIndex,
                    side: Side.OFFER,
                    index: i,
                    identifier: item.identifier,
                    criteriaProof: item.candidateIdentifiers.criteriaProof(
                        item.identifier
                    )
                });
                criteriaResolverLen++;
            } else {
                offer[i] = OfferItem({
                    itemType: item.itemType,
                    token: item.token,
                    identifierOrCriteria: item.identifier,
                    startAmount: item.startAmount,
                    endAmount: item.endAmount
                });
            }
        }
        ConsiderationItem[] memory consideration = new ConsiderationItem[](
            order.parameters.consideration.length
        );
        for (uint256 i; i < order.parameters.consideration.length; i++) {
            NavigatorConsiderationItem memory item = order
                .parameters
                .consideration[i];
            if (item.hasCriteria()) {
                item.validate();
                consideration[i] = ConsiderationItem({
                    itemType: item.normalizeType(),
                    token: item.token,
                    identifierOrCriteria: uint256(
                        item.candidateIdentifiers.criteriaRoot()
                    ),
                    startAmount: item.startAmount,
                    endAmount: item.endAmount,
                    recipient: item.recipient
                });
                criteriaResolvers[criteriaResolverLen] = CriteriaResolver({
                    orderIndex: orderIndex,
                    side: Side.CONSIDERATION,
                    index: i,
                    identifier: item.identifier,
                    criteriaProof: item.candidateIdentifiers.criteriaProof(
                        item.identifier
                    )
                });
                criteriaResolverLen++;
            } else {
                consideration[i] = ConsiderationItem({
                    itemType: item.itemType,
                    token: item.token,
                    identifierOrCriteria: item.identifier,
                    startAmount: item.startAmount,
                    endAmount: item.endAmount,
                    recipient: item.recipient
                });
            }
        }
        assembly {
            mstore(criteriaResolvers, criteriaResolverLen)
        }
        return (
            AdvancedOrder({
                parameters: OrderParameters({
                    offerer: order.parameters.offerer,
                    zone: order.parameters.zone,
                    offer: offer,
                    consideration: consideration,
                    orderType: order.parameters.orderType,
                    startTime: order.parameters.startTime,
                    endTime: order.parameters.endTime,
                    zoneHash: order.parameters.zoneHash,
                    salt: order.parameters.salt,
                    conduitKey: order.parameters.conduitKey,
                    totalOriginalConsiderationItems: order
                        .parameters
                        .totalOriginalConsiderationItems
                }),
                numerator: order.numerator,
                denominator: order.denominator,
                signature: order.signature,
                extraData: order.extraData
            }),
            criteriaResolvers
        );
    }

    function toAdvancedOrders(
        NavigatorAdvancedOrder[] memory orders
    )
        internal
        pure
        returns (AdvancedOrder[] memory, CriteriaResolver[] memory)
    {
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](
            orders.length
        );
        uint256 maxCriteriaResolvers;
        for (uint256 i; i < orders.length; i++) {
            NavigatorOrderParameters memory parameters = orders[i].parameters;
            maxCriteriaResolvers += (parameters.offer.length +
                parameters.consideration.length);
        }
        uint256 criteriaResolverIndex;
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](
            maxCriteriaResolvers
        );
        for (uint256 i = 0; i < orders.length; i++) {
            (
                AdvancedOrder memory order,
                CriteriaResolver[] memory orderResolvers
            ) = toAdvancedOrder(orders[i], i);
            advancedOrders[i] = order;
            for (uint256 j; j < orderResolvers.length; j++) {
                criteriaResolvers[criteriaResolverIndex] = orderResolvers[j];
                criteriaResolverIndex++;
            }
        }
        assembly {
            mstore(criteriaResolvers, criteriaResolverIndex)
        }
        return (advancedOrders, criteriaResolvers);
    }
}

library NavigatorRequestValidatorLib {
    using OrderStructureLib for AdvancedOrder;

    /**
     * @dev Validate the provided orders. Checks that none of the provided orders
     *      are contract orders and applies basic criteria constraint validations.
     */
    function validate(
        NavigatorContext memory context
    ) internal pure returns (NavigatorContext memory) {
        validateNoContractOrders(context);
        return context;
    }

    /**
     * @dev Checks that none of the provided orders are contract orders.
     */
    function validateNoContractOrders(
        NavigatorContext memory context
    ) internal pure returns (NavigatorContext memory) {
        for (uint256 i; i < context.response.orders.length; i++) {
            AdvancedOrder memory order = context.response.orders[i];
            if (order.getType() == Type.CONTRACT) {
                revert ContractOrdersNotSupported();
            }
        }
        return context;
    }
}

library NavigatorCriteriaResolverLib {
    using NavigatorAdvancedOrderLib for NavigatorAdvancedOrder[];

    /**
     * @dev Calculate criteria resolvers, merkle proofs, and criteria merkle
     *      roots for the provided orders and criteria constraints. Modifies
     *      orders in place to add criteria merkle roots to the appropriate
     *      offer/consdieration items. Adds calculated criteria resolvers to
     *      the NavigatorResponse.
     */
    function withCriteria(
        NavigatorContext memory context
    ) internal pure returns (NavigatorContext memory) {
        (
            AdvancedOrder[] memory orders,
            CriteriaResolver[] memory resolvers
        ) = context.request.orders.toAdvancedOrders();
        context.response.orders = orders;
        if (context.request.criteriaResolvers.length > 0) {
            context.response.criteriaResolvers = context
                .request
                .criteriaResolvers;
            return context;
        } else {
            context.response.criteriaResolvers = resolvers;
            return context;
        }
    }
}

interface ValidatorHelper {
    function validateAndRevert(
        SeaportValidatorInterface validator,
        Order memory order,
        address seaport
    ) external view;
}

library NavigatorSeaportValidatorLib {
    using AdvancedOrderLib for AdvancedOrder;

    error ValidatorReverted();

    /**
     * @dev Validate each order using SeaportValidator and add the results to
     *      the NavigatorResponse.
     */
    function withErrors(
        NavigatorContext memory context
    ) internal view returns (NavigatorContext memory) {
        AdvancedOrder[] memory orders = context.response.orders;

        ErrorsAndWarnings[] memory errors = new ErrorsAndWarnings[](
            orders.length
        );
        for (uint256 i; i < orders.length; i++) {
            errors[i] = context.request.validator.isValidOrder(
                orders[i].toOrder(),
                address(context.request.seaport)
            );
        }
        context.response.validationErrors = errors;
        return context;
    }
}

library NavigatorDetailsLib {
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderAvailabilityLib for AdvancedOrder[];

    /**
     * @dev Calculate OrderDetails for each order and add them to the NavigatorResponse.
     */
    function withDetails(
        NavigatorContext memory context
    ) internal view returns (NavigatorContext memory) {
        UnavailableReason[] memory unavailableReasons = context
            .response
            .orders
            .unavailableReasons(
                context.request.maximumFulfilled,
                context.request.seaport
            );
        bytes32[] memory orderHashes = context.response.orders.getOrderHashes(
            address(context.request.seaport)
        );
        context.response.orderDetails = context.response.orders.getOrderDetails(
            context.response.criteriaResolvers,
            orderHashes,
            unavailableReasons
        );
        return context;
    }
}

library NavigatorFulfillmentsLib {
    using FulfillmentGeneratorLib for OrderDetails[];

    /**
     * @dev Calculate fulfillments and match components for the provided orders
     *      and add them to the NavigatorResponse.
     */
    function withFulfillments(
        NavigatorContext memory context
    ) internal pure returns (NavigatorContext memory) {
        (
            ,
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        ) = context.response.orderDetails.getFulfillments(
                context.request.fulfillmentStrategy,
                context.request.recipient,
                context.request.caller,
                context.request.seed
            );

        context.response.offerFulfillments = offerFulfillments;
        context.response.considerationFulfillments = considerationFulfillments;
        context.response.fulfillments = fulfillments;
        context.response.unspentOfferComponents = unspentOfferComponents;
        context
            .response
            .unmetConsiderationComponents = unmetConsiderationComponents;
        return context;
    }
}

library NavigatorExecutionsLib {
    using ExecutionHelper for FulfillmentDetails;
    using OrderStructureLib for AdvancedOrder[];

    /**
     * @dev Calculate executions for the provided orders and add them to the
     *      NavigatorResponse.
     */
    function withExecutions(
        NavigatorContext memory context
    ) internal pure returns (NavigatorContext memory) {
        bytes4 _suggestedAction = context.response.suggestedAction;
        FulfillmentDetails memory fulfillmentDetails = FulfillmentDetails({
            orders: context.response.orderDetails,
            recipient: payable(context.request.recipient),
            fulfiller: payable(context.request.caller),
            nativeTokensSupplied: context.request.nativeTokensSupplied,
            fulfillerConduitKey: context.request.fulfillerConduitKey,
            seaport: address(context.request.seaport)
        });

        Execution[] memory explicitExecutions;
        Execution[] memory implicitExecutions;
        Execution[] memory implicitExecutionsPre;
        Execution[] memory implicitExecutionsPost;
        uint256 nativeTokensReturned;

        if (
            _suggestedAction ==
            ConsiderationInterface.fulfillAvailableOrders.selector ||
            _suggestedAction ==
            ConsiderationInterface.fulfillAvailableAdvancedOrders.selector
        ) {
            (
                explicitExecutions,
                implicitExecutionsPre,
                implicitExecutionsPost,
                nativeTokensReturned
            ) = fulfillmentDetails.getFulfillAvailableExecutions(
                context.response.offerFulfillments,
                context.response.considerationFulfillments,
                context.response.orderDetails
            );
        } else if (
            _suggestedAction == ConsiderationInterface.matchOrders.selector ||
            _suggestedAction ==
            ConsiderationInterface.matchAdvancedOrders.selector
        ) {
            (
                explicitExecutions,
                implicitExecutionsPre,
                implicitExecutionsPost,
                nativeTokensReturned
            ) = fulfillmentDetails.getMatchExecutions(
                context.response.fulfillments
            );
        } else if (
            _suggestedAction == ConsiderationInterface.fulfillOrder.selector ||
            _suggestedAction ==
            ConsiderationInterface.fulfillAdvancedOrder.selector
        ) {
            (implicitExecutions, nativeTokensReturned) = fulfillmentDetails
                .getStandardExecutions();
        } else if (
            _suggestedAction ==
            ConsiderationInterface.fulfillBasicOrder.selector ||
            _suggestedAction ==
            ConsiderationInterface.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            (implicitExecutions, nativeTokensReturned) = fulfillmentDetails
                .getBasicExecutions();
        } else {
            revert UnknownAction();
        }
        context.response.explicitExecutions = explicitExecutions;
        context.response.implicitExecutions = implicitExecutions;
        context.response.implicitExecutionsPre = implicitExecutionsPre;
        context.response.implicitExecutionsPost = implicitExecutionsPost;
        context.response.nativeTokensReturned = nativeTokensReturned;
        return context;
    }

    /**
     * @dev Choose a suggested fulfillment method based on the structure of the
     *      orders and add it to the NavigatorResponse.
     */
    function withSuggestedAction(
        NavigatorContext memory context
    ) internal view returns (NavigatorContext memory) {
        context.response.suggestedAction = action(context);
        context.response.suggestedActionName = actionName(context);
        return context;
    }

    /**
     * @dev Add the human-readable name of the selected fulfillment method to
     *      the NavigatorResponse.
     */
    function actionName(
        NavigatorContext memory context
    ) internal view returns (string memory) {
        bytes4 selector = action(context);
        if (selector == 0xe7acab24) return "fulfillAdvancedOrder";
        if (selector == 0x87201b41) return "fulfillAvailableAdvancedOrders";
        if (selector == 0xed98a574) return "fulfillAvailableOrders";
        if (selector == 0xfb0f3ee1) return "fulfillBasicOrder";
        if (selector == 0x00000000) return "fulfillBasicOrder_efficient_6GL6yc";
        if (selector == 0xb3a34c4c) return "fulfillOrder";
        if (selector == 0xf2d12b12) return "matchAdvancedOrders";
        if (selector == 0xa8174404) return "matchOrders";

        revert UnknownSelector();
    }

    /**
     * @dev Choose a suggested fulfillment method based on the structure of the
     *      orders.
     */
    function action(
        NavigatorContext memory context
    ) internal view returns (bytes4) {
        Family family = context.response.orders.getFamily();

        bool invalidOfferItemsLocated = mustUseMatch(context);

        Structure structure = context.response.orders.getStructure(
            address(context.request.seaport)
        );

        bool hasUnavailable = context.request.maximumFulfilled <
            context.response.orders.length;
        for (uint256 i = 0; i < context.response.orderDetails.length; ++i) {
            if (
                context.response.orderDetails[i].unavailableReason !=
                UnavailableReason.AVAILABLE
            ) {
                hasUnavailable = true;
                break;
            }
        }

        if (hasUnavailable) {
            if (invalidOfferItemsLocated) {
                revert InvalidNativeTokenUnavailableCombination();
            }

            if (structure == Structure.ADVANCED) {
                return
                    ConsiderationInterface
                        .fulfillAvailableAdvancedOrders
                        .selector;
            } else {
                return ConsiderationInterface.fulfillAvailableOrders.selector;
            }
        }

        if (family == Family.SINGLE && !invalidOfferItemsLocated) {
            if (structure == Structure.BASIC) {
                return
                    ConsiderationInterface
                        .fulfillBasicOrder_efficient_6GL6yc
                        .selector;
            }

            if (structure == Structure.STANDARD) {
                return ConsiderationInterface.fulfillOrder.selector;
            }

            if (structure == Structure.ADVANCED) {
                return ConsiderationInterface.fulfillAdvancedOrder.selector;
            }
        }

        bool cannotMatch = (context
            .response
            .unmetConsiderationComponents
            .length !=
            0 ||
            hasUnavailable);

        if (cannotMatch && invalidOfferItemsLocated) {
            revert CannotFulfillProvidedCombinedOrder();
        }

        if (cannotMatch) {
            if (structure == Structure.ADVANCED) {
                return
                    ConsiderationInterface
                        .fulfillAvailableAdvancedOrders
                        .selector;
            } else {
                return ConsiderationInterface.fulfillAvailableOrders.selector;
            }
        } else if (invalidOfferItemsLocated) {
            if (structure == Structure.ADVANCED) {
                return ConsiderationInterface.matchAdvancedOrders.selector;
            } else {
                return ConsiderationInterface.matchOrders.selector;
            }
        } else {
            if (structure == Structure.ADVANCED) {
                return
                    context.request.preferMatch
                        ? ConsiderationInterface.matchAdvancedOrders.selector
                        : ConsiderationInterface
                            .fulfillAvailableAdvancedOrders
                            .selector;
            } else {
                return
                    context.request.preferMatch
                        ? ConsiderationInterface.matchOrders.selector
                        : ConsiderationInterface
                            .fulfillAvailableOrders
                            .selector;
            }
        }
    }

    /**
     * @dev Return whether the provided orders must be matched using matchOrders
     *      or matchAdvancedOrders.
     */
    function mustUseMatch(
        NavigatorContext memory context
    ) internal pure returns (bool) {
        OrderDetails[] memory orders = context.response.orderDetails;

        for (uint256 i = 0; i < orders.length; ++i) {
            OrderDetails memory order = orders[i];

            if (order.isContract) {
                continue;
            }

            for (uint256 j = 0; j < order.offer.length; ++j) {
                if (order.offer[j].itemType == ItemType.NATIVE) {
                    return true;
                }
            }
        }

        if (context.request.caller == context.request.recipient) {
            return false;
        }

        for (uint256 i = 0; i < orders.length; ++i) {
            OrderDetails memory order = orders[i];

            for (uint256 j = 0; j < order.offer.length; ++j) {
                SpentItem memory item = order.offer[j];

                if (item.itemType != ItemType.ERC721) {
                    continue;
                }

                for (uint256 k = 0; k < orders.length; ++k) {
                    OrderDetails memory comparisonOrder = orders[k];
                    for (
                        uint256 l = 0;
                        l < comparisonOrder.consideration.length;
                        ++l
                    ) {
                        ReceivedItem memory considerationItem = comparisonOrder
                            .consideration[l];

                        if (
                            considerationItem.itemType == ItemType.ERC721 &&
                            considerationItem.identifier == item.identifier &&
                            considerationItem.token == item.token
                        ) {
                            return true;
                        }
                    }
                }
            }
        }

        return false;
    }
}

library NavigatorContextLib {
    function from(
        NavigatorRequest memory request
    ) internal pure returns (NavigatorContext memory context) {
        context.request = request;
    }

    function withEmptyResponse(
        NavigatorContext memory context
    ) internal pure returns (NavigatorContext memory) {
        context.response = NavigatorResponse({
            orders: new AdvancedOrder[](0),
            criteriaResolvers: new CriteriaResolver[](0),
            suggestedAction: bytes4(0),
            suggestedActionName: "",
            validationErrors: new ErrorsAndWarnings[](0),
            orderDetails: new OrderDetails[](0),
            offerFulfillments: new FulfillmentComponent[][](0),
            considerationFulfillments: new FulfillmentComponent[][](0),
            fulfillments: new Fulfillment[](0),
            unspentOfferComponents: new MatchComponent[](0),
            unmetConsiderationComponents: new MatchComponent[](0),
            explicitExecutions: new Execution[](0),
            implicitExecutions: new Execution[](0),
            implicitExecutionsPre: new Execution[](0),
            implicitExecutionsPost: new Execution[](0),
            nativeTokensReturned: 0
        });
        return context;
    }
}
