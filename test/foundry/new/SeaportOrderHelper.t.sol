// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationItemLib,
    OfferItemLib,
    OrderParametersLib,
    OrderComponentsLib,
    OrderLib,
    OrderType,
    AdvancedOrderLib,
    ItemType,
    SeaportInterface,
    CriteriaResolver
} from "seaport-sol/SeaportSol.sol";

import {
    ConsiderationItem,
    OfferItem,
    OrderParameters,
    OrderComponents,
    Order,
    AdvancedOrder
} from "seaport-sol/SeaportStructs.sol";

import {
    SeaportValidatorInterface
} from "../../../contracts/helpers/order-validator/SeaportValidator.sol";

import {
    Response,
    SeaportOrderHelper
} from "../../../contracts/helpers/order-helper/SeaportOrderHelper.sol";

import { BaseOrderTest } from "./BaseOrderTest.sol";

contract SeaportOrderHelperTest is BaseOrderTest {
    using ConsiderationItemLib for ConsiderationItem;
    using OfferItemLib for OfferItem;
    using OrderParametersLib for OrderParameters;
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using AdvancedOrderLib for AdvancedOrder;

    string constant SINGLE_ERC721_SINGLE_NATIVE = "SINGLE_ERC721_SINGLE_NATIVE";

    function setUp() public override {
        super.setUp();

        OrderLib
            .empty()
            .withParameters(
                OrderComponentsLib.fromDefault(STANDARD).toOrderParameters()
            )
            .saveDefault(STANDARD);

        // Set up and store order with single ERC721 offer item
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(1);
        OrderParameters memory parameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOffer(offer);
        parameters.saveDefault(SINGLE_ERC721);
        OrderLib.empty().withParameters(parameters).saveDefault(SINGLE_ERC721);

        // Set up and store order with single ERC721 offer item
        // and single native consideration item
        ConsiderationItem[] memory _consideration = new ConsiderationItem[](1);
        _consideration[0] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.NATIVE)
            .withToken(address(0))
            .withAmount(1);
        parameters = OrderParametersLib
            .fromDefault(SINGLE_ERC721)
            .withConsideration(_consideration)
            .withTotalOriginalConsiderationItems(1);
        OrderLib.empty().withParameters(parameters).saveDefault(
            SINGLE_ERC721_SINGLE_NATIVE
        );
    }

    function test_basicOrder() public {
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = OrderLib
            .fromDefault(SINGLE_ERC721_SINGLE_NATIVE)
            .toAdvancedOrder(1, 1, "");

        Response memory res = orderHelper.run(
            orders,
            offerer1.addr,
            address(this),
            1,
            0,
            new CriteriaResolver[](0)
        );
        assertEq(
            res.suggestedAction,
            seaport.fulfillBasicOrder_efficient_6GL6yc.selector,
            "unexpected action selected"
        );
        assertEq(
            res.suggestedActionName,
            "fulfillBasicOrder_efficient_6GL6yc",
            "unexpected actionName selected"
        );
        assertEq(
            res.validationErrors.length,
            1,
            "unexpected validationErrors length"
        );
        assertEq(
            res.validationErrors[0].errors.length,
            4,
            "unexpected validationErrors[0].errors length"
        );
        assertEq(
            res.validationErrors[0].warnings.length,
            1,
            "unexpected validationErrors[0].warnings length"
        );
        assertEq(res.orderDetails.length, 1, "unexpected orderDetails length");
        assertEq(
            res.offerFulfillments.length,
            1,
            "unexpected offerFulfillments length"
        );
        assertEq(
            res.considerationFulfillments.length,
            1,
            "unexpected considerationFulfillments length"
        );
        assertEq(res.fulfillments.length, 0, "unexpected fulfillments length");
        assertEq(
            res.unspentOfferComponents.length,
            1,
            "unexpected unspentOfferComponents length"
        );
        assertEq(
            res.unmetConsiderationComponents.length,
            1,
            "unexpected unmetConsiderationComponents length"
        );
        assertEq(
            res.explicitExecutions.length,
            0,
            "unexpected explicitExecutions length"
        );
        assertEq(
            res.implicitExecutions.length,
            3,
            "unexpected implicitExecutions length"
        );
        assertEq(
            res.implicitExecutionsPre.length,
            0,
            "unexpected implicitExecutionsPre length"
        );
        assertEq(
            res.implicitExecutionsPost.length,
            0,
            "unexpected implicitExecutionsPost length"
        );
        assertEq(
            res.nativeTokensReturned,
            0,
            "unexpected nativeTokensReturned amount"
        );
    }

    function test_simpleOrder() public {
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = OrderLib.fromDefault(SINGLE_ERC721).toAdvancedOrder(
            1,
            1,
            ""
        );

        Response memory res = orderHelper.run(
            orders,
            offerer1.addr,
            address(this),
            0,
            0,
            new CriteriaResolver[](0)
        );
        assertEq(
            res.suggestedAction,
            seaport.fulfillOrder.selector,
            "unexpected action selected"
        );
        assertEq(
            res.suggestedActionName,
            "fulfillOrder",
            "unexpected actionName selected"
        );
        assertEq(
            res.validationErrors.length,
            1,
            "unexpected validationErrors length"
        );
        assertEq(
            res.validationErrors[0].errors.length,
            4,
            "unexpected validationErrors[0].errors length"
        );
        assertEq(
            res.validationErrors[0].warnings.length,
            2,
            "unexpected validationErrors[0].warnings length"
        );
        assertEq(res.orderDetails.length, 1, "unexpected orderDetails length");
        assertEq(
            res.offerFulfillments.length,
            1,
            "unexpected offerFulfillments length"
        );
        assertEq(
            res.considerationFulfillments.length,
            0,
            "unexpected considerationFulfillments length"
        );
        assertEq(res.fulfillments.length, 0, "unexpected fulfillments length");
        assertEq(
            res.unspentOfferComponents.length,
            1,
            "unexpected unspentOfferComponents length"
        );
        assertEq(
            res.unmetConsiderationComponents.length,
            0,
            "unexpected unmetConsiderationComponents length"
        );
        assertEq(
            res.explicitExecutions.length,
            0,
            "unexpected explicitExecutions length"
        );
        assertEq(
            res.implicitExecutions.length,
            1,
            "unexpected implicitExecutions length"
        );
        assertEq(
            res.implicitExecutionsPre.length,
            0,
            "unexpected implicitExecutionsPre length"
        );
        assertEq(
            res.implicitExecutionsPost.length,
            0,
            "unexpected implicitExecutionsPost length"
        );
        assertEq(
            res.nativeTokensReturned,
            0,
            "unexpected nativeTokensReturned amount"
        );
    }
}
