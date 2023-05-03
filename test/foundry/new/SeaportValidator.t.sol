// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationIssue,
    ErrorsAndWarnings,
    GenericIssue,
    ERC20Issue,
    ERC721Issue,
    IssueParser,
    OfferIssue,
    SeaportValidator,
    SignatureIssue,
    TimeIssue
} from "../../../contracts/helpers/order-validator/SeaportValidator.sol";

import {
    OfferItemLib,
    OrderParametersLib,
    OrderComponentsLib,
    OrderLib,
    AdvancedOrderLib,
    ItemType
} from "seaport-sol/SeaportSol.sol";

import {
    OfferItem,
    OrderParameters,
    OrderComponents,
    Order,
    AdvancedOrder
} from "seaport-sol/SeaportStructs.sol";

import { BaseOrderTest } from "./BaseOrderTest.sol";

contract SeaportValidatorTest is BaseOrderTest {
    using OfferItemLib for OfferItem;
    using OrderParametersLib for OrderParameters;
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using AdvancedOrderLib for AdvancedOrder;

    using IssueParser for ConsiderationIssue;
    using IssueParser for ERC20Issue;
    using IssueParser for ERC721Issue;
    using IssueParser for GenericIssue;
    using IssueParser for OfferIssue;
    using IssueParser for SignatureIssue;
    using IssueParser for TimeIssue;

    SeaportValidator internal validator;

    function setUp() public override {
        super.setUp();
        validator = new SeaportValidator(address(conduitController));
    }

    function test_empty_isValidOrder() public {
        Order memory order = OrderLib.empty();
        ErrorsAndWarnings memory validation = validator.isValidOrder(
            order,
            address(seaport)
        );
        uint16[] memory errors = validation.errors;
        uint16[] memory warnings = validation.warnings;

        assertEq(errors[0], TimeIssue.EndTimeBeforeStartTime.parseInt());
        assertEq(errors[1], SignatureIssue.Invalid.parseInt());
        assertEq(errors[2], GenericIssue.InvalidOrderFormat.parseInt());

        assertEq(warnings[0], OfferIssue.ZeroItems.parseInt());
        assertEq(warnings[1], ConsiderationIssue.ZeroItems.parseInt());
    }

    function test_empty_isValidOrderReadOnly() public {
        Order memory order = OrderLib.empty();
        ErrorsAndWarnings memory validation = validator.isValidOrderReadOnly(
            order,
            address(seaport)
        );
        uint16[] memory errors = validation.errors;
        uint16[] memory warnings = validation.warnings;

        assertEq(errors[0], TimeIssue.EndTimeBeforeStartTime.parseInt());
        assertEq(errors[1], GenericIssue.InvalidOrderFormat.parseInt());

        assertEq(warnings[0], OfferIssue.ZeroItems.parseInt());
        assertEq(warnings[1], ConsiderationIssue.ZeroItems.parseInt());
    }

    function test_default_full_isValidOrder() public {
        Order memory order = OrderLib.empty().withParameters(
            OrderComponentsLib.fromDefault(STANDARD).toOrderParameters()
        );
        ErrorsAndWarnings memory validation = validator.isValidOrder(
            order,
            address(seaport)
        );
        uint16[] memory errors = validation.errors;
        uint16[] memory warnings = validation.warnings;

        assertEq(errors[0], SignatureIssue.Invalid.parseInt());
        assertEq(errors[1], GenericIssue.InvalidOrderFormat.parseInt());

        assertEq(warnings[0], TimeIssue.ShortOrder.parseInt());
        assertEq(warnings[1], OfferIssue.ZeroItems.parseInt());
    }

    function test_default_full_isValidOrder_identifierNonZero() public {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withAmount(1)
            .withIdentifierOrCriteria(1);
        OrderParameters memory parameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOffer(offer);
        Order memory order = OrderLib.empty().withParameters(parameters);
        ErrorsAndWarnings memory validation = validator.isValidOrder(
            order,
            address(seaport)
        );
        uint16[] memory errors = validation.errors;
        uint16[] memory warnings = validation.warnings;

        assertEq(errors[0], ERC20Issue.IdentifierNonZero.parseInt());
        assertEq(errors[1], ERC20Issue.InvalidToken.parseInt());
        assertEq(errors[2], SignatureIssue.Invalid.parseInt());
        assertEq(errors[3], GenericIssue.InvalidOrderFormat.parseInt());

        assertEq(warnings[0], TimeIssue.ShortOrder.parseInt());
        assertEq(warnings[1], ConsiderationIssue.ZeroItems.parseInt());
    }

    function test_default_full_isValidOrder_invalidToken() public {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withAmount(1)
            .withToken(address(0));
        OrderParameters memory parameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOffer(offer);
        Order memory order = OrderLib.empty().withParameters(parameters);
        ErrorsAndWarnings memory validation = validator.isValidOrder(
            order,
            address(seaport)
        );
        uint16[] memory errors = validation.errors;
        uint16[] memory warnings = validation.warnings;

        assertEq(errors[0], ERC20Issue.InvalidToken.parseInt());
        assertEq(errors[1], SignatureIssue.Invalid.parseInt());
        assertEq(errors[2], GenericIssue.InvalidOrderFormat.parseInt());

        assertEq(warnings[0], TimeIssue.ShortOrder.parseInt());
        assertEq(warnings[1], ConsiderationIssue.ZeroItems.parseInt());
    }

    function test_default_full_isValidOrder_amountNotOne() public {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withAmount(3);
        OrderParameters memory parameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOffer(offer);
        Order memory order = OrderLib.empty().withParameters(parameters);
        ErrorsAndWarnings memory validation = validator.isValidOrder(
            order,
            address(seaport)
        );
        uint16[] memory errors = validation.errors;
        uint16[] memory warnings = validation.warnings;

        assertEq(errors[0], ERC721Issue.AmountNotOne.parseInt());
        assertEq(errors[1], ERC721Issue.InvalidToken.parseInt());
        assertEq(errors[2], SignatureIssue.Invalid.parseInt());
        assertEq(errors[3], GenericIssue.InvalidOrderFormat.parseInt());

        assertEq(warnings[0], TimeIssue.ShortOrder.parseInt());
        assertEq(warnings[1], ConsiderationIssue.ZeroItems.parseInt());
    }

    function test_default_full_isValidOrderReadOnly() public {
        Order memory order = OrderLib.empty().withParameters(
            OrderComponentsLib.fromDefault(STANDARD).toOrderParameters()
        );
        ErrorsAndWarnings memory validation = validator.isValidOrderReadOnly(
            order,
            address(seaport)
        );
        uint16[] memory errors = validation.errors;
        uint16[] memory warnings = validation.warnings;

        assertEq(errors[0], GenericIssue.InvalidOrderFormat.parseInt());

        assertEq(warnings[0], TimeIssue.ShortOrder.parseInt());
        assertEq(warnings[1], OfferIssue.ZeroItems.parseInt());
    }
}
