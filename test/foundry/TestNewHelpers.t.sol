// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { ConsiderationInterface } from
    "../../contracts/interfaces/ConsiderationInterface.sol";
import {
    BasicOrderParameters,
    Order,
    AdvancedOrder,
    CriteriaResolver,
    Fulfillment,
    OrderParameters,
    FulfillmentComponent
} from "../../contracts/lib/ConsiderationStructs.sol";
import { BasicOrderType } from "../../contracts/lib/ConsiderationEnums.sol";

contract TestNewHelpersTest is BaseOrderTest {
    struct Context {
        ConsiderationInterface seaport;
    }

    /**
     * @dev to run tests against both the optimized and reference
     * implementations with the exact same params, and to ensure setup works
     * the same way, we use a stateless function that takes a context and then
     * reverts after logic has been performed with the status of the HEVM
     * failure slot. Each test file should have a test function that performs
     * this call with its relevant Context struct, and then asserts that the
     * revert bytes indicate no assertions failed.
     */
    function test(
        function(Context memory) external f,
        Context memory context
    ) internal {
        try f(context) {
            fail("Test logic should have reverted with assertion status");
        } catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    /**
     * @dev A test should invoke the `test` function for both optimized and
     * reference implementations by passing the relevant execution method and a
     * Context struct.
     */
    function testBasicOrder() public {
        test(this.execBasicOrder, Context({seaport: consideration}));
        test(this.execBasicOrder, Context({seaport: referenceConsideration}));
    }

    /**
     * @dev actual test logic should live in an external function marked with
     * the "stateless" modifier, which reverts after execution with the value
     * in the HEVM failure slot. Reverting with this value allows us to
     * revert state changes (which *includes* HEVM assertion failure status,
     * which will otherwise get reverted) and still assert that the test logic
     * passed.
     */
    function execBasicOrder(Context memory context) external stateless {
        string memory label = "offerer";
        _setUpSingleOrderOfferConsiderationItems(label);
        // create a signed order - this will configure baseOrderParameters and
        // baseOrderComponents
        // we will use BaseOrderComponents to configure the BaseOrderParameters
        // and re-use the signature
        Order memory order = createSignedOrder(context.seaport, label);
        BasicOrderParameters memory basicOrderParameters =
        toBasicOrderParameters(order, BasicOrderType.ERC721_TO_ERC20_FULL_OPEN);

        context.seaport.fulfillBasicOrder({parameters: basicOrderParameters});
    }

    function testFulfillOrder() public {
        test(this.execFulfillOrder, Context({seaport: consideration}));
        test(this.execFulfillOrder, Context({seaport: referenceConsideration}));
    }

    function execFulfillOrder(Context memory context) external stateless {
        string memory label = "offerer";
        _setUpSingleOrderOfferConsiderationItems(label);
        // create a signed order - this will configure baseOrderParameters and
        // baseOrderComponents
        // we will use BaseOrderComponents to configure the BaseOrderParameters
        // and re-use the signature
        Order memory order = createSignedOrder(context.seaport, label);

        context.seaport.fulfillOrder({
            order: order,
            fulfillerConduitKey: bytes32(0)
        });
    }

    function testFulfillAdvancedOrder() public {
        test(this.execFulfillAdvancedOrder, Context({seaport: consideration}));
        test(
            this.execFulfillAdvancedOrder,
            Context({seaport: referenceConsideration})
        );
    }

    function execFulfillAdvancedOrder(Context memory context)
        external
        stateless
    {
        string memory label = "offerer";
        _setUpSingleOrderOfferConsiderationItems(label);
        // create a signed order - this will configure baseOrderParameters and
        // baseOrderComponents
        // we will use BaseOrderComponents to configure the BaseOrderParameters
        // and re-use the signature
        Order memory order = createSignedOrder(context.seaport, label);

        context.seaport.fulfillAdvancedOrder({
            advancedOrder: toAdvancedOrder(order),
            criteriaResolvers: new CriteriaResolver[](0),
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testMatchOrders() public {
        test(this.execMatchOrders, Context({seaport: consideration}));
        test(this.execMatchOrders, Context({seaport: referenceConsideration}));
    }

    function execMatchOrders(Context memory context) external stateless {
        string memory label = "offerer";
        _setUpMatchOrderOfferConsiderationItems(label);
        // create a signed order - this will configure baseOrderParameters and
        // baseOrderComponents
        // we will use BaseOrderComponents to configure the BaseOrderParameters
        // and re-use the signature
        Order memory order = createSignedOrder(context.seaport, label);
        (Order memory mirror, Fulfillment[] memory matchFulfillments) =
            createMirrorOrderAndFulfillments(context.seaport, order.parameters);

        Order[] memory orders = new Order[](2);

        orders[0] = order;
        orders[1] = mirror;

        context.seaport.matchOrders({
            orders: orders,
            fulfillments: matchFulfillments
        });
    }

    function testFulfillAvailableOrders() public {
        test(this.execFulfillAvailableOrders, Context({seaport: consideration}));
        test(
            this.execFulfillAvailableOrders,
            Context({seaport: referenceConsideration})
        );
    }

    function execFulfillAvailableOrders(Context memory context)
        external
        stateless
    {
        string memory label1 = "offerer";
        string memory label2 = "offerer 2";
        _setUpSingleOrderOfferConsiderationItems(label1, 1);
        // caveat: need to create order explicitly after configuring since it
        // relies on storage that may not be cleared
        Order memory order = createSignedOrder(context.seaport, label1);

        _setUpSingleOrderOfferConsiderationItems(label2, 2);
        Order memory order2 = createSignedOrder(context.seaport, label2);

        Order[] memory orders = new Order[](2);
        orders[0] = order;
        orders[1] = order2;
        OrderParameters[] memory parameters = new OrderParameters[](2);
        parameters[0] = order.parameters;
        parameters[1] = order2.parameters;
        (
            FulfillmentComponent[][] memory offerFulfillments,
            FulfillmentComponent[][] memory considerationFulfillments
        ) = createFulfillments(parameters);

        context.seaport.fulfillAvailableOrders({
            orders: orders,
            offerFulfillments: offerFulfillments,
            considerationFulfillments: considerationFulfillments,
            fulfillerConduitKey: bytes32(0),
            maximumFulfilled: 2
        });
    }

    function _setUpSingleOrderOfferConsiderationItems(string memory label)
        internal
    {
        _setUpSingleOrderOfferConsiderationItems(label, 1);
    }

    function _setUpSingleOrderOfferConsiderationItems(
        string memory label,
        uint256 id
    ) internal {
        // make a labelled + reproducible address with ether, erc20s, and
        // approvals for all erc20/erc721/erc1155
        address offerer = makeAddrWithAllocationsAndApprovals(label);

        // add a single erc20 offer item - start/end amounts the same, defaults
        // to token1
        addErc20OfferItem({amount: 100});

        // add a single considerationitem - defaults to test721_1
        addErc721ConsiderationItem({recipient: payable(offerer), tokenId: id});
        test721_1.mint(address(this), id);
    }

    function _setUpMatchOrderOfferConsiderationItems(string memory label)
        internal
    {
        // make a labelled + reproducible address with ether, erc20s, and
        // approvals for all erc20/erc721/erc1155
        address offerer = makeAddrWithAllocationsAndApprovals(label);
        address mirror = makeAddrWithAllocationsAndApprovals("mirror offerer");

        // add a single erc20 offer item - start/end amounts the same, defaults
        // to token1
        addErc20OfferItem({amount: 100});

        // add a single considerationitem - defaults to test721_1
        addErc721ConsiderationItem({recipient: payable(offerer), tokenId: 1});
        test721_1.mint(mirror, 1);
    }

    // function _setUpFulfillAvailableOfferConsiderationItems(string)
}
