// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    AdvancedOrderLib,
    CriteriaResolver,
    Fulfillment,
    FulfillmentComponent,
    FulfillmentDetails,
    MatchComponent,
    Order,
    OrderComponentsLib,
    OrderDetails,
    OrderLib,
    OrderParametersLib,
    SeaportInterface,
    UnavailableReason
} from "seaport-sol/SeaportSol.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    Execution,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-sol/SeaportStructs.sol";

import { ItemType, Side, OrderType } from "seaport-sol/SeaportEnums.sol";

import { Family, OrderStructureLib, Structure } from "./OrderStructureLib.sol";

import {
    FulfillmentGeneratorLib
} from "seaport-sol/fulfillments/lib/FulfillmentLib.sol";

import { ExecutionHelper } from "seaport-sol/executions/ExecutionHelper.sol";

import {
    SeaportValidatorInterface,
    ErrorsAndWarnings
} from "../../order-validator/SeaportValidator.sol";

struct OrderHelperContext {
    SeaportInterface seaport;
    SeaportValidatorInterface validator;
    address caller;
    address recipient;
    uint256 nativeTokensSupplied;
    bytes32 fulfillerConduitKey;
    AdvancedOrder[] orders;
    Response response;
}

struct Response {
    bytes4 suggestedAction;
    string suggestedActionName;
    ErrorsAndWarnings[] validationErrors;
    OrderDetails[] orderDetails;
    FulfillmentComponent[][] offerFulfillments;
    FulfillmentComponent[][] considerationFulfillments;
    Fulfillment[] fulfillments;
    MatchComponent[] unspentOfferComponents;
    MatchComponent[] unmetConsiderationComponents;
    MatchComponent[] remainders;
    Execution[] explicitExecutions;
    Execution[] implicitExecutions;
    Execution[] implicitExecutionsPre;
    Execution[] implicitExecutionsPost;
    uint256 nativeTokensReturned;
}

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

    function from(
        AdvancedOrder[] memory orders,
        SeaportInterface seaport,
        SeaportValidatorInterface validator,
        address caller,
        address recipient,
        uint256 nativeTokensSupplied
    ) internal pure returns (OrderHelperContext memory) {
        return
            OrderHelperContext({
                seaport: seaport,
                validator: validator,
                caller: caller,
                recipient: recipient,
                nativeTokensSupplied: nativeTokensSupplied,
                fulfillerConduitKey: bytes32(0),
                orders: orders,
                response: Response({
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

    function withDetails(
        OrderHelperContext memory context
    ) internal returns (OrderHelperContext memory) {
        ErrorsAndWarnings[] memory errors = new ErrorsAndWarnings[](
            context.orders.length
        );
        for (uint256 i; i < context.orders.length; i++) {
            errors[i] = context.validator.isValidOrder(
                context.orders[i].toOrder(),
                address(context.seaport)
            );
        }
        UnavailableReason[] memory unavailableReasons = new UnavailableReason[](
            context.orders.length
        );
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);
        bytes32[] memory orderHashes = context.orders.getOrderHashes(
            address(context.seaport)
        );
        context.response.orderDetails = context.orders.getOrderDetails(
            criteriaResolvers,
            orderHashes,
            unavailableReasons
        );
        return context;
    }

    function withErrors(
        OrderHelperContext memory context
    ) internal returns (OrderHelperContext memory) {
        AdvancedOrder[] memory orders = context.orders;

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

    function withExecutions(
        OrderHelperContext memory context
    ) internal pure returns (OrderHelperContext memory) {
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
            revert("OrderHelperContextLib: Unknown action");
        }
        context.response.explicitExecutions = explicitExecutions;
        context.response.implicitExecutions = implicitExecutions;
        context.response.implicitExecutionsPre = implicitExecutionsPre;
        context.response.implicitExecutionsPost = implicitExecutionsPost;
        context.response.nativeTokensReturned = nativeTokensReturned;
        return context;
    }

    function withSuggestedAction(
        OrderHelperContext memory context
    ) internal view returns (OrderHelperContext memory) {
        context.response.suggestedAction = action(context);
        context.response.suggestedActionName = actionName(context);
        return context;
    }

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

        revert("Unknown selector");
    }

    function action(
        OrderHelperContext memory context
    ) internal view returns (bytes4) {
        Family family = context.orders.getFamily();

        bool invalidOfferItemsLocated = mustUseMatch(context);

        Structure structure = context.orders.getStructure(
            address(context.seaport)
        );

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

        bool cannotMatch = (context.response.remainders.length != 0);

        if (cannotMatch && invalidOfferItemsLocated) {
            revert("OrderHelperLib: cannot fulfill provided combined order");
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
