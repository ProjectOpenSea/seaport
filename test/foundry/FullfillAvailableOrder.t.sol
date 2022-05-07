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
    struct ToErc721Struct {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
    }

    struct ConsiderationToErc721Struct {
        Consideration consideration;
        ToErc721Struct args;
    }

    function testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
        ToErc721Struct memory testStruct
    ) public {
        _testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
            ConsiderationToErc721Struct(consideration, testStruct)
        );
        _testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
            ConsiderationToErc721Struct(referenceConsideration, testStruct)
        );
    }

    function _testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
        ConsiderationToErc721Struct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            testStruct.args.paymentAmts[0] > 0 &&
                testStruct.args.paymentAmts[1] > 0 &&
                testStruct.args.paymentAmts[2] > 0
        );
        vm.assume(
            uint256(testStruct.args.paymentAmts[0]) +
                uint256(testStruct.args.paymentAmts[1]) +
                uint256(testStruct.args.paymentAmts[2]) <=
                2**128 - 1
        );

        bytes32 conduitKey = testStruct.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, testStruct.args.id);
        offerItems.push(
            OfferItem(
                ItemType.ERC721,
                address(test721_1),
                testStruct.args.id,
                1,
                1
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(testStruct.args.paymentAmts[0]),
                uint256(testStruct.args.paymentAmts[0]),
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(testStruct.args.paymentAmts[1]),
                uint256(testStruct.args.paymentAmts[1]),
                payable(testStruct.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(testStruct.args.paymentAmts[2]),
                uint256(testStruct.args.paymentAmts[2]),
                payable(cal)
            )
        );
        OrderComponents memory orderComponents = OrderComponents(
            alice,
            testStruct.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            testStruct.args.zoneHash,
            testStruct.args.salt,
            conduitKey,
            testStruct.consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            testStruct.consideration,
            alicePk,
            testStruct.consideration.getOrderHash(orderComponents)
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
            testStruct.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            testStruct.args.zoneHash,
            testStruct.args.salt,
            conduitKey,
            considerationItems.length
        );

        Order[] memory orders = new Order[](1);
        orders[0] = Order(orderParameters, signature);

        testStruct.consideration.fulfillAvailableOrders{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(
            orders,
            offerFulfillments,
            considerationFulfillments,
            conduitKey,
            100
        );
    }
}
