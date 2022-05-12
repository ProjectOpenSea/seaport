// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { Consideration } from "../../contracts/Consideration.sol";
import { Order, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters, FulfillmentComponent } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";

contract FulfillAvailableOrder is BaseOrderTest {
    struct FuzzInputs {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
    }

    struct Context {
        Consideration consideration;
        FuzzInputs args;
    }

    function testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
        FuzzInputs memory args
    ) public {
        _testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
            Context(consideration, args)
        );
        _testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
            Context(referenceConsideration, args)
        );
    }

    function _testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
        Context memory context
    )
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            context.args.paymentAmts[0] > 0 &&
                context.args.paymentAmts[1] > 0 &&
                context.args.paymentAmts[2] > 0
        );
        vm.assume(
            uint256(context.args.paymentAmts[0]) +
                uint256(context.args.paymentAmts[1]) +
                uint256(context.args.paymentAmts[2]) <=
                2**128 - 1
        );

        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, context.args.id);
        offerItems.push(
            OfferItem(
                ItemType.ERC721,
                address(test721_1),
                context.args.id,
                1,
                1
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[0]),
                uint256(context.args.paymentAmts[0]),
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[1]),
                uint256(context.args.paymentAmts[1]),
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[2]),
                uint256(context.args.paymentAmts[2]),
                payable(cal)
            )
        );
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            context.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        firstOfferFulfillment.push(FulfillmentComponent(0, 0));
        offerFulfillments.push(firstOfferFulfillment);

        firstConsiderationFulfillment.push(FulfillmentComponent(0, 0));
        considerationFulfillments.push(firstConsiderationFulfillment);

        secondConsiderationFulfillment.push(FulfillmentComponent(0, 1));
        considerationFulfillments.push(secondConsiderationFulfillment);

        thirdConsiderationFulfillment.push(FulfillmentComponent(0, 2));
        considerationFulfillments.push(thirdConsiderationFulfillment);

        assertTrue(considerationFulfillments.length == 3);

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        Order[] memory orders = new Order[](1);
        orders[0] = Order(orderParameters, signature);

        context.consideration.fulfillAvailableOrders{
            value: context.args.paymentAmts[0] +
                context.args.paymentAmts[1] +
                context.args.paymentAmts[2]
        }(
            orders,
            offerFulfillments,
            considerationFulfillments,
            conduitKey,
            100
        );
    }

    // function _testFulfillAndAggregateMultipleOrdersViaFulfillAvailableAdvancedOrders(
    //     Context memory context,
    //     uint240 amount,
    //     uint16 numOrders
    // )
    //     internal
    //     onlyPayable(context.args.zone)
    //     topUp
    //     resetTokenBalancesBetweenRuns
    // {
    //     vm.assume(
    //         context.args.paymentAmts[0] > 0 &&
    //             context.args.paymentAmts[1] > 0 &&
    //             context.args.paymentAmts[2] > 0
    //     );
    //     vm.assume(amount > 0);
    //     vm.assume(uint256(amount) * numOrders <= 2**256 - 1);
    //     vm.assume(
    //         uint256(context.args.paymentAmts[0]) +
    //             uint256(context.args.paymentAmts[1]) +
    //             uint256(context.args.paymentAmts[2]) <=
    //             2**128 - 1
    //     );

    //     bytes32 conduitKey = context.args.useConduit
    //         ? conduitKeyOne
    //         : bytes32(0);

    // }
}
