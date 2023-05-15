// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    AdvancedOrderLib,
    CriteriaResolver,
    Fulfillment,
    FulfillmentComponent,
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
    SpentItem,
    ReceivedItem
} from "seaport-sol/SeaportStructs.sol";

import { ItemType, Side, OrderType } from "seaport-sol/SeaportEnums.sol";

import { Family, OrderStructureLib, Structure } from "./OrderStructureLib.sol";

import {
    FulfillmentGeneratorLib
} from "seaport-sol/fulfillments/lib/FulfillmentLib.sol";

import {
    SeaportValidatorInterface,
    ErrorsAndWarnings
} from "../../order-validator/SeaportValidator.sol";

struct ExecutionState {
    address caller;
    address recipient;
    AdvancedOrder[] orders;
    OrderDetails[] orderDetails;
    bool hasRemainders;
}

struct OrderHelperContext {
    SeaportInterface seaport;
    SeaportValidatorInterface validator;
    ExecutionState executionState;
    Response response;
}

struct Response {
    bytes4 action;
    string actionName;
    ErrorsAndWarnings[] validationErrors;
    OrderDetails[] orderDetails;
    FulfillmentComponent[][] offerFulfillments;
    FulfillmentComponent[][] considerationFulfillments;
    Fulfillment[] fulfillments;
    MatchComponent[] unspentOfferComponents;
    MatchComponent[] unmetConsiderationComponents;
}

library OrderHelperContextLib {
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;
    using FulfillmentGeneratorLib for OrderDetails[];

    using OrderStructureLib for AdvancedOrder;
    using OrderStructureLib for AdvancedOrder[];

    function from(
        AdvancedOrder[] memory orders,
        SeaportInterface seaport,
        SeaportValidatorInterface validator,
        address caller,
        address recipient
    ) internal view returns (OrderHelperContext memory) {
        UnavailableReason[] memory unavailableReasons = new UnavailableReason[](
            orders.length
        );
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);
        bytes32[] memory orderHashes = orders.getOrderHashes(address(seaport));
        OrderDetails[] memory orderDetails = orders.getOrderDetails(
            criteriaResolvers,
            orderHashes,
            unavailableReasons
        );
        return
            OrderHelperContext({
                seaport: seaport,
                validator: validator,
                executionState: ExecutionState({
                    caller: caller,
                    recipient: recipient,
                    orders: orders,
                    orderDetails: orderDetails,
                    hasRemainders: false
                }),
                response: Response({
                    action: bytes4(0),
                    actionName: "",
                    validationErrors: new ErrorsAndWarnings[](0),
                    orderDetails: orderDetails,
                    offerFulfillments: new FulfillmentComponent[][](0),
                    considerationFulfillments: new FulfillmentComponent[][](0),
                    fulfillments: new Fulfillment[](0),
                    unspentOfferComponents: new MatchComponent[](0),
                    unmetConsiderationComponents: new MatchComponent[](0)
                })
            });
    }

    function withErrors(
        OrderHelperContext memory context
    ) internal returns (OrderHelperContext memory) {
        AdvancedOrder[] memory orders = context.executionState.orders;

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
        ) = context.executionState.orderDetails.getFulfillments(
                context.executionState.recipient,
                context.executionState.caller
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

    function withAction(
        OrderHelperContext memory context
    ) internal view returns (OrderHelperContext memory) {
        context.response.action = action(context);
        context.response.actionName = actionName(context);
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
        Family family = context.executionState.orders.getFamily();

        bool invalidOfferItemsLocated = mustUseMatch(context);

        Structure structure = context.executionState.orders.getStructure(
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

        (, , MatchComponent[] memory remainders) = context
            .executionState
            .orderDetails
            .getMatchedFulfillments();

        context.executionState.hasRemainders = remainders.length != 0;

        bool cannotMatch = (context.executionState.hasRemainders);

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
        OrderDetails[] memory orders = context.executionState.orderDetails;

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

        if (context.executionState.caller == context.executionState.recipient) {
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
