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
    OrderHelperResponse,
    CriteriaConstraint,
    OrderHelperContext
} from "./SeaportOrderHelperTypes.sol";

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
 * @dev Bad request error: a constraint includes a nonexistent order index
 */
error InvalidCriteriaConstraintOrderIndex(uint256 orderIndex);
/**
 * @dev Bad request error: a constraint includes a nonexistent offer item index.
 */
error InvalidCriteriaConstraintOfferIndex(
    uint256 orderIndex,
    uint256 itemIndex
);
/**
 * @dev Bad request error: a constraint includes a nonexistent consideration
 *      item index.
 */
error InvalidCriteriaConstraintConsiderationIndex(
    uint256 orderIndex,
    uint256 itemIndex
);
/**
 * @dev Bad request error: a constraint specifies an identifier that's not
 *      included in the provided token IDs.
 */
error InvalidCriteriaConstraintIdentifier(uint256 identifier);
/**
 * @dev Internal error: Could not select a fulfillment method for the provided
 *      orders.
 */
error UnknownAction();
/**
 * @dev Internal error: Could not find selector for the suggested action.
 */
error UnknownSelector();

library OrderHelperContextLib {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;
    using FulfillmentGeneratorLib for OrderDetails[];
    using ExecutionHelper for FulfillmentDetails;

    using OrderStructureLib for AdvancedOrder;
    using OrderStructureLib for AdvancedOrder[];
    using OrderAvailabilityLib for AdvancedOrder[];

    using CriteriaHelperLib for uint256[];

    function from(
        AdvancedOrder[] memory orders,
        ConsiderationInterface seaport,
        SeaportValidatorInterface validator
    ) internal pure returns (OrderHelperContext memory) {
        return
            OrderHelperContext({
                seaport: seaport,
                validator: validator,
                caller: address(0),
                recipient: address(0),
                nativeTokensSupplied: 0,
                maximumFulfilled: 0,
                fulfillerConduitKey: bytes32(0),
                OrderHelperResponse: OrderHelperResponse({
                    orders: orders,
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
                    remainders: new MatchComponent[](0),
                    explicitExecutions: new Execution[](0),
                    implicitExecutions: new Execution[](0),
                    implicitExecutionsPre: new Execution[](0),
                    implicitExecutionsPost: new Execution[](0),
                    nativeTokensReturned: 0
                })
            });
    }

    /**
     * @dev Add provided call parameters to the context.
     */
    function withCallContext(
        OrderHelperContext memory context,
        address caller,
        uint256 nativeTokensSupplied,
        bytes32 fulfillerConduitKey,
        address recipient,
        uint256 maximumFulfilled
    ) internal pure returns (OrderHelperContext memory) {
        context.caller = caller;
        context.nativeTokensSupplied = nativeTokensSupplied;
        context.fulfillerConduitKey = fulfillerConduitKey;
        context.recipient = recipient;
        context.maximumFulfilled = maximumFulfilled;
        return context;
    }

    /**
     * @dev Add criteria resolvers to the OrderHelperResponse.
     */
    function withCriteriaResolvers(
        OrderHelperContext memory context,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure returns (OrderHelperContext memory) {
        context.OrderHelperResponse.criteriaResolvers = criteriaResolvers;
        return context;
    }

    /**
     * @dev Validate the provided orders. Checks that none of the provided orders
     *      are contract orders.
     */
    function validate(
        OrderHelperContext memory context
    ) internal pure returns (OrderHelperContext memory) {
        validateNoContractOrders(context);
        return context;
    }

    /**
     * @dev Validate the provided orders. Checks that none of the provided orders
     *      are contract orders and applies basic criteria constraint validations.
     */
    function validate(
        OrderHelperContext memory context,
        CriteriaConstraint[] memory criteriaConstraints
    ) internal pure returns (OrderHelperContext memory) {
        validateNoContractOrders(context);
        validateCriteriaConstraints(context, criteriaConstraints);
        return context;
    }

    /**
     * @dev Checks that none of the provided orders are contract orders.
     */
    function validateNoContractOrders(
        OrderHelperContext memory context
    ) internal pure returns (OrderHelperContext memory) {
        for (uint256 i; i < context.OrderHelperResponse.orders.length; i++) {
            AdvancedOrder memory order = context.OrderHelperResponse.orders[i];
            if (order.getType() == Type.CONTRACT) {
                revert ContractOrdersNotSupported();
            }
        }
        return context;
    }

    /**
     * @dev Basic validations for criteria constraints. Checks for valid order
     *     and item indexes and that the provided identifier is included in the
     *     constraint's token IDs. Caller beware: we omit more advanced
     *     validations like checking for duplicate and conflicting constraints.
     */
    function validateCriteriaConstraints(
        OrderHelperContext memory context,
        CriteriaConstraint[] memory criteriaConstraints
    ) internal pure returns (OrderHelperContext memory) {
        for (uint256 i; i < criteriaConstraints.length; i++) {
            CriteriaConstraint memory constraint = criteriaConstraints[i];

            // Validate order index
            if (
                constraint.orderIndex >=
                context.OrderHelperResponse.orders.length
            ) {
                revert InvalidCriteriaConstraintOrderIndex(
                    constraint.orderIndex
                );
            }

            // Validate item index
            if (constraint.side == Side.OFFER) {
                if (
                    constraint.index >=
                    context
                        .OrderHelperResponse
                        .orders[constraint.orderIndex]
                        .parameters
                        .offer
                        .length
                ) {
                    revert InvalidCriteriaConstraintOfferIndex(
                        constraint.orderIndex,
                        constraint.index
                    );
                }
            } else {
                if (
                    constraint.index >=
                    context
                        .OrderHelperResponse
                        .orders[constraint.orderIndex]
                        .parameters
                        .consideration
                        .length
                ) {
                    revert InvalidCriteriaConstraintConsiderationIndex(
                        constraint.orderIndex,
                        constraint.index
                    );
                }
            }

            // Validate identifier in tokenIds
            uint256 id = constraint.identifier;
            bool found;
            for (uint256 j; j < constraint.tokenIds.length; j++) {
                if (constraint.tokenIds[j] == id) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                revert InvalidCriteriaConstraintIdentifier(
                    constraint.identifier
                );
            }
        }
        return context;
    }

    /**
     * @dev Calculate criteria resolvers, merkle proofs, and criteria merkle
     *      roots for the provided orders and criteria constraints. Modifies
     *      orders in place to add criteria merkle roots to the appropriate
     *      offer/consdieration items. Adds calculated criteria resolvers to
     *      the OrderHelperResponse.
     */
    function withInferredCriteria(
        OrderHelperContext memory context,
        CriteriaConstraint[] memory criteria
    ) internal pure returns (OrderHelperContext memory) {
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](
            criteria.length
        );
        for (uint256 i; i < criteria.length; i++) {
            CriteriaConstraint memory constraint = criteria[i];
            OrderParameters memory parameters = context
                .OrderHelperResponse
                .orders[constraint.orderIndex]
                .parameters;
            if (constraint.side == Side.OFFER) {
                OfferItem memory offerItem = parameters.offer[constraint.index];
                ItemType itemType = offerItem.itemType;
                if (
                    itemType == ItemType.ERC721_WITH_CRITERIA ||
                    itemType == ItemType.ERC1155_WITH_CRITERIA
                ) {
                    offerItem.identifierOrCriteria = uint256(
                        constraint.tokenIds.criteriaRoot()
                    );
                }
            } else {
                ConsiderationItem memory considerationItem = parameters
                    .consideration[constraint.index];
                ItemType itemType = considerationItem.itemType;
                if (
                    itemType == ItemType.ERC721_WITH_CRITERIA ||
                    itemType == ItemType.ERC1155_WITH_CRITERIA
                ) {
                    considerationItem.identifierOrCriteria = uint256(
                        constraint.tokenIds.criteriaRoot()
                    );
                }
            }
            criteriaResolvers[i] = CriteriaResolver({
                orderIndex: constraint.orderIndex,
                side: constraint.side,
                index: constraint.index,
                identifier: constraint.identifier,
                criteriaProof: constraint.tokenIds.criteriaProof(
                    constraint.identifier
                )
            });
        }
        context.OrderHelperResponse.criteriaResolvers = criteriaResolvers;
        return context;
    }

    /**
     * @dev Calculate OrderDetails for each order and add them to the OrderHelperResponse.
     */
    function withDetails(
        OrderHelperContext memory context
    ) internal view returns (OrderHelperContext memory) {
        UnavailableReason[] memory unavailableReasons = context
            .OrderHelperResponse
            .orders
            .unavailableReasons(context.maximumFulfilled, context.seaport);
        bytes32[] memory orderHashes = context
            .OrderHelperResponse
            .orders
            .getOrderHashes(address(context.seaport));
        context.OrderHelperResponse.orderDetails = context
            .OrderHelperResponse
            .orders
            .getOrderDetails(
                context.OrderHelperResponse.criteriaResolvers,
                orderHashes,
                unavailableReasons
            );
        return context;
    }

    /**
     * @dev Validate each order using SeaportValidator and add the results to
     *      the OrderHelperResponse.
     */
    function withErrors(
        OrderHelperContext memory context
    ) internal view returns (OrderHelperContext memory) {
        AdvancedOrder[] memory orders = context.OrderHelperResponse.orders;

        ErrorsAndWarnings[] memory errors = new ErrorsAndWarnings[](
            orders.length
        );
        for (uint256 i; i < orders.length; i++) {
            errors[i] = context.validator.isValidOrderReadOnly(
                orders[i].toOrder(),
                address(context.seaport)
            );
        }
        context.OrderHelperResponse.validationErrors = errors;
        return context;
    }

    /**
     * @dev Calculate fulfillments and match components for the provided orders
     *      and add them to the OrderHelperResponse.
     */
    function withFulfillments(
        OrderHelperContext memory context
    ) internal pure returns (OrderHelperContext memory) {
        (
            ,
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments,
            Fulfillment[] memory fulfillments,
            MatchComponent[] memory unspentOfferComponents,
            MatchComponent[] memory unmetConsiderationComponents
        ) = context.OrderHelperResponse.orderDetails.getFulfillments(
                context.recipient,
                context.caller
            );

        (, , MatchComponent[] memory remainders) = context
            .OrderHelperResponse
            .orderDetails
            .getMatchedFulfillments();

        context.OrderHelperResponse.offerFulfillments = offerFulfillments;
        context
            .OrderHelperResponse
            .considerationFulfillments = considerationFulfillments;
        context.OrderHelperResponse.fulfillments = fulfillments;
        context
            .OrderHelperResponse
            .unspentOfferComponents = unspentOfferComponents;
        context
            .OrderHelperResponse
            .unmetConsiderationComponents = unmetConsiderationComponents;
        context.OrderHelperResponse.remainders = remainders;
        return context;
    }

    /**
     * @dev Calculate executions for the provided orders and add them to the
     *      OrderHelperResponse.
     */
    function withExecutions(
        OrderHelperContext memory context
    ) internal view returns (OrderHelperContext memory) {
        bytes4 _suggestedAction = context.OrderHelperResponse.suggestedAction;
        FulfillmentDetails memory fulfillmentDetails = FulfillmentDetails({
            orders: context.OrderHelperResponse.orderDetails,
            recipient: payable(context.recipient),
            fulfiller: payable(context.caller),
            nativeTokensSupplied: context.nativeTokensSupplied,
            fulfillerConduitKey: context.fulfillerConduitKey,
            seaport: address(context.seaport)
        });

        Execution[] memory explicitExecutions;
        Execution[] memory implicitExecutions;
        Execution[] memory implicitExecutionsPre;
        Execution[] memory implicitExecutionsPost;
        uint256 nativeTokensReturned;

        if (
            _suggestedAction ==
            context.seaport.fulfillAvailableOrders.selector ||
            _suggestedAction ==
            context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            (
                explicitExecutions,
                implicitExecutionsPre,
                implicitExecutionsPost,
                nativeTokensReturned
            ) = fulfillmentDetails.getFulfillAvailableExecutions(
                context.OrderHelperResponse.offerFulfillments,
                context.OrderHelperResponse.considerationFulfillments,
                context.OrderHelperResponse.orderDetails
            );
        } else if (
            _suggestedAction == context.seaport.matchOrders.selector ||
            _suggestedAction == context.seaport.matchAdvancedOrders.selector
        ) {
            (
                explicitExecutions,
                implicitExecutionsPre,
                implicitExecutionsPost,
                nativeTokensReturned
            ) = fulfillmentDetails.getMatchExecutions(
                context.OrderHelperResponse.fulfillments
            );
        } else if (
            _suggestedAction == context.seaport.fulfillOrder.selector ||
            _suggestedAction == context.seaport.fulfillAdvancedOrder.selector
        ) {
            (implicitExecutions, nativeTokensReturned) = fulfillmentDetails
                .getStandardExecutions();
        } else if (
            _suggestedAction == context.seaport.fulfillBasicOrder.selector ||
            _suggestedAction ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            (implicitExecutions, nativeTokensReturned) = fulfillmentDetails
                .getBasicExecutions();
        } else {
            revert UnknownAction();
        }
        context.OrderHelperResponse.explicitExecutions = explicitExecutions;
        context.OrderHelperResponse.implicitExecutions = implicitExecutions;
        context
            .OrderHelperResponse
            .implicitExecutionsPre = implicitExecutionsPre;
        context
            .OrderHelperResponse
            .implicitExecutionsPost = implicitExecutionsPost;
        context.OrderHelperResponse.nativeTokensReturned = nativeTokensReturned;
        return context;
    }

    /**
     * @dev Choose a suggested fulfillment method based on the structure of the
     *      orders and add it to the OrderHelperResponse.
     */
    function withSuggestedAction(
        OrderHelperContext memory context
    ) internal view returns (OrderHelperContext memory) {
        context.OrderHelperResponse.suggestedAction = action(context);
        context.OrderHelperResponse.suggestedActionName = actionName(context);
        return context;
    }

    /**
     * @dev Add the human-readable name of the selected fulfillment method to
     *      the OrderHelperResponse.
     */
    function actionName(
        OrderHelperContext memory context
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
        OrderHelperContext memory context
    ) internal view returns (bytes4) {
        Family family = context.OrderHelperResponse.orders.getFamily();

        bool invalidOfferItemsLocated = mustUseMatch(context);

        Structure structure = context.OrderHelperResponse.orders.getStructure(
            address(context.seaport)
        );

        bool hasUnavailable = context.maximumFulfilled <
            context.OrderHelperResponse.orders.length;
        for (
            uint256 i = 0;
            i < context.OrderHelperResponse.orderDetails.length;
            ++i
        ) {
            if (
                context.OrderHelperResponse.orderDetails[i].unavailableReason !=
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
                return context.seaport.fulfillAvailableAdvancedOrders.selector;
            } else {
                return context.seaport.fulfillAvailableOrders.selector;
            }
        }

        if (family == Family.SINGLE && !invalidOfferItemsLocated) {
            if (structure == Structure.BASIC) {
                return
                    context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector;
            }

            if (structure == Structure.STANDARD) {
                return context.seaport.fulfillOrder.selector;
            }

            if (structure == Structure.ADVANCED) {
                return context.seaport.fulfillAdvancedOrder.selector;
            }
        }

        bool cannotMatch = (context.OrderHelperResponse.remainders.length !=
            0 ||
            hasUnavailable);

        if (cannotMatch && invalidOfferItemsLocated) {
            revert CannotFulfillProvidedCombinedOrder();
        }

        if (cannotMatch) {
            if (structure == Structure.ADVANCED) {
                return context.seaport.fulfillAvailableAdvancedOrders.selector;
            } else {
                return context.seaport.fulfillAvailableOrders.selector;
            }
        } else if (invalidOfferItemsLocated) {
            if (structure == Structure.ADVANCED) {
                return context.seaport.matchAdvancedOrders.selector;
            } else {
                return context.seaport.matchOrders.selector;
            }
        } else {
            if (structure == Structure.ADVANCED) {
                return context.seaport.fulfillAvailableAdvancedOrders.selector;
            } else {
                return context.seaport.fulfillAvailableOrders.selector;
            }
        }
    }

    /**
     * @dev Return whether the provided orders must be matched using matchOrders
     *      or matchAdvancedOrders.
     */
    function mustUseMatch(
        OrderHelperContext memory context
    ) internal pure returns (bool) {
        OrderDetails[] memory orders = context.OrderHelperResponse.orderDetails;

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

        if (context.caller == context.recipient) {
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
