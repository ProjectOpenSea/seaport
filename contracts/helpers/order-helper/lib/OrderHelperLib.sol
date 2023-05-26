// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import { AdvancedOrderLib } from "seaport-sol/lib/AdvancedOrderLib.sol";
import { OrderComponentsLib } from "seaport-sol/lib/OrderComponentsLib.sol";
import { OrderLib } from "seaport-sol/lib/OrderLib.sol";
import { OrderParametersLib } from "seaport-sol/lib/OrderParametersLib.sol";
import { UnavailableReason } from "seaport-sol/SpaceEnums.sol";

import { MatchComponent } from "seaport-sol/lib/types/MatchComponentType.sol";
import {
    FulfillmentDetails,
    OrderDetails
} from "seaport-sol/fulfillments/lib/Structs.sol";

import {
    FulfillmentGeneratorLib
} from "seaport-sol/fulfillments/lib/FulfillmentLib.sol";

import { ExecutionHelper } from "seaport-sol/executions/ExecutionHelper.sol";

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
    Response,
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
                response: Response({
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
     * @dev Add criteria resolvers to the response.
     */
    function withCriteriaResolvers(
        OrderHelperContext memory context,
        CriteriaResolver[] memory criteriaResolvers
    ) internal pure returns (OrderHelperContext memory) {
        context.response.criteriaResolvers = criteriaResolvers;
        return context;
    }

    /**
     * @dev Validate the provided orders. Checks that none of the provided orders
     *      are contract orders.
     */
    function validate(
        OrderHelperContext memory context
    ) internal pure returns (OrderHelperContext memory) {
        for (uint256 i; i < context.response.orders.length; i++) {
            AdvancedOrder memory order = context.response.orders[i];
            if (order.getType() == Type.CONTRACT) {
                revert ContractOrdersNotSupported();
            }
        }
        return context;
    }

    /**
     * @dev Calculate criteria resolvers, merkle proofs, and criteria merkle
     *      roots for the provided orders and criteria constraints. Modifies
     *      orders in place to add criteria merkle roots to the appropriate
     *      offer/consdieration items. Adds calculated criteria resolvers to
     *      the response.
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
                .response
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
        context.response.criteriaResolvers = criteriaResolvers;
        return context;
    }

    /**
     * @dev Calculate OrderDetails for each order and add them to the response.
     */
    function withDetails(
        OrderHelperContext memory context
    ) internal view returns (OrderHelperContext memory) {
        UnavailableReason[] memory unavailableReasons = context
            .response
            .orders
            .unavailableReasons(context.maximumFulfilled, context.seaport);
        bytes32[] memory orderHashes = context.response.orders.getOrderHashes(
            address(context.seaport)
        );
        context.response.orderDetails = context.response.orders.getOrderDetails(
            context.response.criteriaResolvers,
            orderHashes,
            unavailableReasons
        );
        return context;
    }

    /**
     * @dev Validate each order using SeaportValidator and add the results to
     *      the response.
     */
    function withErrors(
        OrderHelperContext memory context
    ) internal returns (OrderHelperContext memory) {
        AdvancedOrder[] memory orders = context.response.orders;

        ErrorsAndWarnings[] memory errors = new ErrorsAndWarnings[](
            orders.length
        );
        for (uint256 i; i < orders.length; i++) {
            errors[i] = context.validator.isValidOrder(
                orders[i].toOrder(),
                address(context.seaport)
            );
        }
        context.response.validationErrors = errors;
        return context;
    }

    /**
     * @dev Calculate fulfillments and match components for the provided orders
     *      and add them to the response.
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
        ) = context.response.orderDetails.getFulfillments(
                context.recipient,
                context.caller
            );

        (, , MatchComponent[] memory remainders) = context
            .response
            .orderDetails
            .getMatchedFulfillments();

        context.response.offerFulfillments = offerFulfillments;
        context.response.considerationFulfillments = considerationFulfillments;
        context.response.fulfillments = fulfillments;
        context.response.unspentOfferComponents = unspentOfferComponents;
        context
            .response
            .unmetConsiderationComponents = unmetConsiderationComponents;
        context.response.remainders = remainders;
        return context;
    }

    /**
     * @dev Calculate executions for the provided orders and add them to the
     *      response.
     */
    function withExecutions(
        OrderHelperContext memory context
    ) internal view returns (OrderHelperContext memory) {
        bytes4 _suggestedAction = context.response.suggestedAction;
        FulfillmentDetails memory fulfillmentDetails = FulfillmentDetails({
            orders: context.response.orderDetails,
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
                context.response.offerFulfillments,
                context.response.considerationFulfillments,
                context.response.orderDetails
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
                context.response.fulfillments
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
        context.response.explicitExecutions = explicitExecutions;
        context.response.implicitExecutions = implicitExecutions;
        context.response.implicitExecutionsPre = implicitExecutionsPre;
        context.response.implicitExecutionsPost = implicitExecutionsPost;
        context.response.nativeTokensReturned = nativeTokensReturned;
        return context;
    }

    /**
     * @dev Choose a suggested fulfillment method based on the structure of the
     *      orders and add it to the response.
     */
    function withSuggestedAction(
        OrderHelperContext memory context
    ) internal view returns (OrderHelperContext memory) {
        context.response.suggestedAction = action(context);
        context.response.suggestedActionName = actionName(context);
        return context;
    }

    /**
     * @dev Add the human-readable name of the selected fulfillment method to
     *      the response.
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
        Family family = context.response.orders.getFamily();

        bool invalidOfferItemsLocated = mustUseMatch(context);

        Structure structure = context.response.orders.getStructure(
            address(context.seaport)
        );

        bool hasUnavailable = context.maximumFulfilled <
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

        bool cannotMatch = (context.response.remainders.length != 0 ||
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
