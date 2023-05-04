// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConduitIssue,
    ConsiderationIssue,
    ErrorsAndWarnings,
    ErrorsAndWarningsLib,
    GenericIssue,
    ERC20Issue,
    ERC721Issue,
    ERC1155Issue,
    IssueParser,
    OfferIssue,
    SeaportValidator,
    SignatureIssue,
    StatusIssue,
    TimeIssue
} from "../../../contracts/helpers/order-validator/SeaportValidator.sol";

import {
    ConsiderationItemLib,
    OfferItemLib,
    OrderParametersLib,
    OrderComponentsLib,
    OrderLib,
    OrderType,
    AdvancedOrderLib,
    ItemType
} from "seaport-sol/SeaportSol.sol";

import {
    ConsiderationItem,
    OfferItem,
    OrderParameters,
    OrderComponents,
    Order,
    AdvancedOrder
} from "seaport-sol/SeaportStructs.sol";

import { BaseOrderTest } from "./BaseOrderTest.sol";

contract SeaportValidatorTest is BaseOrderTest {
    using ConsiderationItemLib for ConsiderationItem;
    using OfferItemLib for OfferItem;
    using OrderParametersLib for OrderParameters;
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using AdvancedOrderLib for AdvancedOrder;

    using IssueParser for ConduitIssue;
    using IssueParser for ConsiderationIssue;
    using IssueParser for ERC20Issue;
    using IssueParser for ERC721Issue;
    using IssueParser for GenericIssue;
    using IssueParser for OfferIssue;
    using IssueParser for SignatureIssue;
    using IssueParser for StatusIssue;
    using IssueParser for TimeIssue;

    using ErrorsAndWarningsLib for ErrorsAndWarnings;

    SeaportValidator internal validator;

    string constant SINGLE_ERC20 = "SINGLE_ERC20";
    string constant SINGLE_ERC1155 = "SINGLE_ERC1155";
    string constant SINGLE_ERC721_SINGLE_ERC20 = "SINGLE_ERC721_SINGLE_ERC20";
    string constant SINGLE_ERC721_SINGLE_ERC721 = "SINGLE_ERC721_SINGLE_ERC721";

    address internal noTokens = makeAddr("no tokens/approvals");

    function setUp() public override {
        super.setUp();
        validator = new SeaportValidator(address(conduitController));

        OrderLib
            .empty()
            .withParameters(
                OrderComponentsLib.fromDefault(STANDARD).toOrderParameters()
            )
            .saveDefault(STANDARD);

        // Set up and store order with single ERC20 offer item
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withAmount(1);
        OrderParameters memory parameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOffer(offer);
        OrderLib.empty().withParameters(parameters).saveDefault(SINGLE_ERC20);

        // Set up and store order with single ERC721 offer item
        offer = new OfferItem[](1);
        offer[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(1);
        parameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOffer(offer);
        parameters.saveDefault(SINGLE_ERC721);
        OrderLib.empty().withParameters(parameters).saveDefault(SINGLE_ERC721);

        // Set up and store order with single ERC1155 offer item
        offer = new OfferItem[](1);
        offer[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC1155)
            .withToken(address(erc1155s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(1);
        parameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOffer(offer);
        OrderLib.empty().withParameters(parameters).saveDefault(SINGLE_ERC1155);

        // Set up and store order with single ERC721 offer item
        // and single ERC20 consideration item
        ConsiderationItem[] memory _consideration = new ConsiderationItem[](1);
        _consideration[0] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withAmount(1);
        parameters = OrderParametersLib
            .fromDefault(SINGLE_ERC721)
            .withConsideration(_consideration)
            .withTotalOriginalConsiderationItems(1);
        OrderLib.empty().withParameters(parameters).saveDefault(
            SINGLE_ERC721_SINGLE_ERC20
        );

        // Set up and store order with single ERC721 offer item
        // and single ERC721 consideration item
        _consideration = new ConsiderationItem[](1);
        _consideration[0] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(2)
            .withAmount(1)
            .withRecipient(offerer1.addr);
        parameters = OrderParametersLib
            .fromDefault(SINGLE_ERC721)
            .withConsideration(_consideration)
            .withTotalOriginalConsiderationItems(1);
        OrderLib.empty().withParameters(parameters).saveDefault(
            SINGLE_ERC721_SINGLE_ERC721
        );
    }

    function test_empty_isValidOrder() public {
        ErrorsAndWarnings memory actual = validator.isValidOrder(
            OrderLib.empty(),
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
        ErrorsAndWarnings memory actual = validator.isValidOrderReadOnly(
            OrderLib.empty(),
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
        ErrorsAndWarnings memory actual = validator.isValidOrder(
            OrderLib.fromDefault(STANDARD),
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

    function test_isValidOrder_erc20_identifierNonZero() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC20);
        order.parameters.offer[0].identifierOrCriteria = 1;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC20Issue.IdentifierNonZero)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_erc20_invalidToken() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC20);
        order.parameters.offer[0].token = address(0);

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

    function test_isValidOrder_erc20_insufficientBalance() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC20);
        order.parameters.offerer = noTokens;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC20Issue.InsufficientAllowance)
            .addError(ERC20Issue.InsufficientBalance)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_erc20_insufficientAllowance() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC20);
        order.parameters.offerer = noTokens;
        erc20s[0].mint(noTokens, 1);

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC20Issue.InsufficientAllowance)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_erc721_amountNotOne() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.offer[0].startAmount = 3;
        order.parameters.offer[0].endAmount = 3;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC721Issue.AmountNotOne)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_erc721_invalidToken() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.offer[0].token = address(0);

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC721Issue.InvalidToken)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_erc721_identifierDNE() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721_SINGLE_ERC721);
        order.parameters.consideration[0].identifierOrCriteria = type(uint256)
            .max;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC721Issue.NotOwner)
            .addError(ERC721Issue.NotApproved)
            .addError(ERC721Issue.IdentifierDNE)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.OffererNotReceivingAtLeastOneItem);

        assertEq(actual, expected);
    }

    function test_isValidOrder_erc721_notOwner() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.offerer = noTokens;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC721Issue.NotOwner)
            .addError(ERC721Issue.NotApproved)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_erc721_notApproved() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.offerer = noTokens;
        erc721s[0].mint(noTokens, 1);

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC721Issue.NotApproved)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_erc1155_invalidToken() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC1155);
        order.parameters.offer[0].token = address(0);

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC1155Issue.InvalidToken)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_erc1155_insufficientBalance() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC1155);
        order.parameters.offerer = noTokens;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC1155Issue.NotApproved)
            .addError(ERC1155Issue.InsufficientBalance)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_erc1155_notApproved() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC1155);
        order.parameters.offerer = noTokens;
        erc1155s[0].mint(noTokens, 1, 1);

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC1155Issue.NotApproved)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_statusIssue_contractOrder() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.orderType = OrderType.CONTRACT;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC721Issue.NotOwner)
            .addError(ERC721Issue.NotApproved)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(StatusIssue.ContractOrder)
            .addWarning(ConsiderationIssue.ZeroItems)
            .addWarning(SignatureIssue.ContractOrder);

        assertEq(actual, expected);
    }

    function test_isValidOrder_timeIssue_endTimeBeforeStartTime() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.startTime = block.timestamp;
        order.parameters.endTime = block.timestamp - 1;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(TimeIssue.EndTimeBeforeStartTime)
            .addError(ERC721Issue.NotOwner)
            .addError(ERC721Issue.NotApproved)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_timeIssue_expired() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        vm.warp(block.timestamp + 2);
        order.parameters.startTime = block.timestamp - 2;
        order.parameters.endTime = block.timestamp - 1;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(TimeIssue.Expired)
            .addError(ERC721Issue.NotOwner)
            .addError(ERC721Issue.NotApproved)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_timeIssue_distantExpiration() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.startTime = block.timestamp;
        order.parameters.endTime = type(uint256).max;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC721Issue.NotOwner)
            .addError(ERC721Issue.NotApproved)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.DistantExpiration)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_timeIssue_notActive() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.startTime = block.timestamp + 1;
        order.parameters.endTime = block.timestamp + 2;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ERC721Issue.NotOwner)
            .addError(ERC721Issue.NotApproved)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.NotActive)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_conduitIssue_keyInvalid() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.conduitKey = keccak256("invalid conduit key");

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(ConduitIssue.KeyInvalid)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    // TODO: MissingSeaportChannel

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
