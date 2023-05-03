// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationIssue,
    ErrorsAndWarnings,
    ErrorsAndWarningsLib,
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

    using ErrorsAndWarningsLib for ErrorsAndWarnings;

    SeaportValidator internal validator;

    function setUp() public override {
        super.setUp();
        validator = new SeaportValidator(address(conduitController));
    }

    function test_empty_isValidOrder() public {
        Order memory order = OrderLib.empty();
        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );
        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(TimeIssue.EndTimeBeforeStartTime)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(OfferIssue.ZeroItems)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_empty_isValidOrderReadOnly() public {
        Order memory order = OrderLib.empty();
        ErrorsAndWarnings memory actual = validator.isValidOrderReadOnly(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(TimeIssue.EndTimeBeforeStartTime)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(OfferIssue.ZeroItems)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_default_full_isValidOrder() public {
        Order memory order = OrderLib.empty().withParameters(
            OrderComponentsLib.fromDefault(STANDARD).toOrderParameters()
        );
        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(OfferIssue.ZeroItems)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
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

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC20Issue.IdentifierNonZero)
            .addError(ERC20Issue.InvalidToken)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
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

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC20Issue.InvalidToken)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
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

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC721Issue.AmountNotOne)
            .addError(ERC721Issue.InvalidToken)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_default_full_isValidOrderReadOnly() public {
        Order memory order = OrderLib.empty().withParameters(
            OrderComponentsLib.fromDefault(STANDARD).toOrderParameters()
        );
        ErrorsAndWarnings memory actual = validator.isValidOrderReadOnly(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(OfferIssue.ZeroItems)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function assertEq(
        ErrorsAndWarnings memory left,
        ErrorsAndWarnings memory right
    ) internal {
        assertEq(
            left.errors.length,
            right.errors.length,
            "unexpected number of errors"
        );
        assertEq(
            left.warnings.length,
            right.warnings.length,
            "unexpected number of warnings"
        );
        for (uint i = 0; i < left.errors.length; i++) {
            assertEq(left.errors[i], right.errors[i], "unexpected error");
        }
        for (uint i = 0; i < left.warnings.length; i++) {
            assertEq(left.warnings[i], right.warnings[i], "unexpected warning");
        }
    }
}
