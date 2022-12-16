// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import {
    ConsiderationInterface
} from "../../contracts/interfaces/ConsiderationInterface.sol";
import {
    BasicOrderParameters,
    Order,
    AdvancedOrder,
    CriteriaResolver
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
        test(this.execBasicOrder, Context({ seaport: consideration }));
        test(this.execBasicOrder, Context({ seaport: referenceConsideration }));
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
        // create a signed order - this will configure baseOrderParameters and baseOrderComponents
        // we will use BaseOrderComponents to configure the BaseOrderParameters and re-use the signature
        Order memory order = createSignedOrder(context.seaport, label);
        BasicOrderParameters
            memory basicOrderParameters = toBasicOrderParameters(
                order,
                BasicOrderType.ERC721_TO_ERC20_FULL_OPEN
            );

        context.seaport.fulfillBasicOrder({ parameters: basicOrderParameters });
    }

    function testFulfillOrder() public {
        test(this.execFulfillOrder, Context({ seaport: consideration }));
        test(
            this.execFulfillOrder,
            Context({ seaport: referenceConsideration })
        );
    }

    function execFulfillOrder(Context memory context) external stateless {
        string memory label = "offerer";
        _setUpSingleOrderOfferConsiderationItems(label);
        // create a signed order - this will configure baseOrderParameters and baseOrderComponents
        // we will use BaseOrderComponents to configure the BaseOrderParameters and re-use the signature
        Order memory order = createSignedOrder(context.seaport, label);

        context.seaport.fulfillOrder({
            order: order,
            fulfillerConduitKey: bytes32(0)
        });
    }

    function testFulfillAdvancedOrder() public {
        test(
            this.execFulfillAdvancedorder,
            Context({ seaport: consideration })
        );
        test(
            this.execFulfillAdvancedorder,
            Context({ seaport: referenceConsideration })
        );
    }

    function execFulfillAdvancedorder(
        Context memory context
    ) external stateless {
        string memory label = "offerer";
        _setUpSingleOrderOfferConsiderationItems(label);
        // create a signed order - this will configure baseOrderParameters and baseOrderComponents
        // we will use BaseOrderComponents to configure the BaseOrderParameters and re-use the signature
        Order memory order = createSignedOrder(context.seaport, label);

        context.seaport.fulfillAdvancedOrder({
            advancedOrder: toAdvancedOrder(order),
            criteriaResolvers: new CriteriaResolver[](0),
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function _setUpSingleOrderOfferConsiderationItems(
        string memory label
    ) internal {
        // make a labelled + reproducible address with ether, erc20s, and approvals for all erc20/erc721/erc1155
        address offerer = makeAddrWithAllocationsAndApprovals(label);

        // add a single erc20 offer item - start/end a mounts the same, defaults to token1
        addErc20OfferItem({ amount: 100 });

        // add a single considerationitem - defaults to test721_1
        addErc721ConsiderationItem({ recipient: payable(offerer), tokenId: 1 });
        test721_1.mint(address(this), 1);
    }
}
