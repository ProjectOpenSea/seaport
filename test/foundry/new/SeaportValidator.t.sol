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
    TimeIssue,
    NativeIssue
} from "../../../contracts/helpers/order-validator/SeaportValidator.sol";

import {
    ConduitControllerInterface
} from "seaport-sol/src/ConduitControllerInterface.sol";

import {
    SeaportValidatorHelper
} from "../../../contracts/helpers/order-validator/lib/SeaportValidatorHelper.sol";

import {
    IssueStringHelpers
} from "../../../contracts/helpers/order-validator/lib/SeaportValidatorTypes.sol";

import {
    ConsiderationItemLib,
    OfferItemLib,
    OrderParametersLib,
    OrderComponentsLib,
    OrderLib,
    OrderType,
    AdvancedOrderLib,
    ItemType
} from "seaport-sol/src/SeaportSol.sol";

import {
    ConsiderationItem,
    OfferItem,
    OrderParameters,
    OrderComponents,
    Order,
    AdvancedOrder
} from "seaport-sol/src/SeaportStructs.sol";

import { BaseOrderTest } from "./BaseOrderTest.sol";
import { SeaportValidatorTest } from "./SeaportValidatorTest.sol";

contract SeaportValidatorTestSuite is BaseOrderTest, SeaportValidatorTest {
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

    using IssueStringHelpers for uint16;
    using ErrorsAndWarningsLib for ErrorsAndWarnings;

    string constant SINGLE_ERC20 = "SINGLE_ERC20";
    string constant SINGLE_ERC1155 = "SINGLE_ERC1155";
    string constant SINGLE_NATIVE = "SINGLE_NATIVE";
    string constant SINGLE_ERC721_SINGLE_ERC20 = "SINGLE_ERC721_SINGLE_ERC20";
    string constant SINGLE_ERC721_SINGLE_NATIVE = "SINGLE_ERC721_SINGLE_NATIVE";
    string constant SINGLE_ERC721_SINGLE_ERC721 = "SINGLE_ERC721_SINGLE_ERC721";

    address internal noTokens = makeAddr("no tokens/approvals");

    function setUp() public override(BaseOrderTest, SeaportValidatorTest) {
        super.setUp();

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

        // Set up and store order with single native offer item
        offer = new OfferItem[](1);
        offer[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.NATIVE)
            .withToken(address(0))
            .withIdentifierOrCriteria(0)
            .withAmount(1);
        parameters = OrderComponentsLib
            .fromDefault(STANDARD)
            .toOrderParameters()
            .withOffer(offer);
        OrderLib.empty().withParameters(parameters).saveDefault(SINGLE_NATIVE);

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

        // Set up and store order with single ERC721 offer item
        // and single ERC20 consideration item
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

    function test_isValidOrder_erc721_criteriaNotPartialFill() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.offer[0].itemType = ItemType.ERC721_WITH_CRITERIA;
        order.parameters.offer[0].startAmount = 2;
        order.parameters.offer[0].endAmount = 10;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(OfferIssue.AmountVelocityHigh)
            .addError(ERC721Issue.CriteriaNotPartialFill)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(OfferIssue.AmountStepLarge)
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

    function test_isValidOrder_statusIssue_cancelled() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);

        OrderComponents[] memory orderComponents = new OrderComponents[](1);
        orderComponents[0] = order.parameters.toOrderComponents(
            seaport.getCounter(order.parameters.offerer)
        );
        vm.prank(order.parameters.offerer);
        seaport.cancel(orderComponents);

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(StatusIssue.Cancelled)
            .addError(ERC721Issue.NotOwner)
            .addError(ERC721Issue.NotApproved)
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

    function test_isValidOrder_timeIssue_notActive_shortOrder() public {
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

    function test_isValidOrder_signatureIssue_invalid() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);

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

    function test_isValidOrder_offerIssue_zeroItems() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.offer = new OfferItem[](0);

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

    function test_isValidOrder_offerIssue_moreThanOneItem() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.offerer = address(this);

        erc721s[0].mint(address(this), 1);
        erc721s[0].mint(address(this), 2);
        erc721s[0].setApprovalForAll(address(seaport), true);

        OfferItem[] memory offer = new OfferItem[](2);
        offer[0] = order.parameters.offer[0];
        offer[1] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(2)
            .withAmount(1);

        order.parameters.offer = offer;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(OfferIssue.MoreThanOneItem)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_offerIssue_amountZero() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.offer[0].startAmount = 0;
        order.parameters.offer[0].endAmount = 0;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(OfferIssue.AmountZero)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_offerIssue_nativeItem() public {
        Order memory order = OrderLib.fromDefault(SINGLE_NATIVE);
        order.parameters.offerer = address(this);

        vm.deal(address(this), 1 ether);

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(OfferIssue.NativeItem)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_offerIssue_duplicateItem() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC721);
        order.parameters.offerer = address(this);

        erc721s[0].mint(address(this), 1);
        erc721s[0].setApprovalForAll(address(seaport), true);

        OfferItem[] memory offer = new OfferItem[](2);
        offer[0] = order.parameters.offer[0];
        offer[1] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withToken(address(erc721s[0]))
            .withIdentifierOrCriteria(1)
            .withAmount(1);

        order.parameters.offer = offer;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(OfferIssue.DuplicateItem)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(OfferIssue.MoreThanOneItem)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_offerIssue_amountVelocityHigh() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC20);

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withIdentifierOrCriteria(0)
            .withStartAmount(1e16)
            .withEndAmount(1e25);

        order.parameters.offer = offer;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(OfferIssue.AmountVelocityHigh)
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(TimeIssue.ShortOrder)
            .addWarning(ConsiderationIssue.ZeroItems);

        assertEq(actual, expected);
    }

    function test_isValidOrder_offerIssue_amountStepLarge() public {
        Order memory order = OrderLib.fromDefault(SINGLE_ERC20);
        order.parameters.offerer = address(this);
        order.parameters.startTime = block.timestamp;
        order.parameters.endTime = block.timestamp + 60 * 60 * 24;

        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withIdentifierOrCriteria(0)
            .withStartAmount(1e10)
            .withEndAmount(1e11);

        order.parameters.offer = offer;

        ErrorsAndWarnings memory actual = validator.isValidOrder(
            order,
            address(seaport)
        );

        ErrorsAndWarnings memory expected = ErrorsAndWarningsLib
            .empty()
            .addError(SignatureIssue.Invalid)
            .addError(GenericIssue.InvalidOrderFormat)
            .addWarning(OfferIssue.AmountStepLarge)
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
            "Unexpected number of errors"
        );
        assertEq(
            left.warnings.length,
            right.warnings.length,
            "Unexpected number of warnings"
        );
        for (uint256 i = 0; i < left.errors.length; i++) {
            assertEq(
                left.errors[i].toIssueString(),
                right.errors[i].toIssueString(),
                "Unexpected error"
            );
        }
        for (uint256 i = 0; i < left.warnings.length; i++) {
            assertEq(
                left.warnings[i].toIssueString(),
                right.warnings[i].toIssueString(),
                "Unexpected warning"
            );
        }
    }
}
