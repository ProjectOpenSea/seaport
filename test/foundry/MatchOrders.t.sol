// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { Order, Fulfillment } from "../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../contracts/interfaces/ConsiderationInterface.sol";
import { AdvancedOrder, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters, CriteriaResolver, FulfillmentComponent } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";

contract MatchOrders is BaseOrderTest {
    struct FuzzInputsCommon {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputsCommon args;
    }

    function testMatchOrdersSingleErc721OfferSingleEthConsideration(
        FuzzInputsCommon memory inputs
    ) public {
        _testMatchOrdersSingleErc721OfferSingleEthConsideration(
            Context(referenceConsideration, inputs)
        );
        _testMatchOrdersSingleErc721OfferSingleEthConsideration(
            Context(consideration, inputs)
        );
    }

    function _testMatchOrdersSingleErc721OfferSingleEthConsideration(
        Context memory context
    ) internal resetTokenBalancesBetweenRuns {
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
                uint256(1),
                uint256(1),
                payable(alice)
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

        OfferItem[] memory mirrorOfferItems = new OfferItem[](1);

        // push the original order's consideration item into mirrorOfferItems
        mirrorOfferItems[0] = OfferItem(
            considerationItems[0].itemType,
            considerationItems[0].token,
            considerationItems[0].identifierOrCriteria,
            considerationItems[0].startAmount,
            considerationItems[0].endAmount
        );

        ConsiderationItem[]
            memory mirrorConsiderationItems = new ConsiderationItem[](1);

        // push the original order's offer item into mirrorConsiderationItems
        mirrorConsiderationItems[0] = ConsiderationItem(
            offerItems[0].itemType,
            offerItems[0].token,
            offerItems[0].identifierOrCriteria,
            offerItems[0].startAmount,
            offerItems[0].endAmount,
            payable(cal)
        );

        OrderComponents memory mirrorOrderComponents = OrderComponents(
            cal,
            context.args.zone,
            mirrorOfferItems,
            mirrorConsiderationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            context.consideration.getNonce(cal)
        );
        bytes memory mirrorSignature = signOrder(
            context.consideration,
            calPk,
            context.consideration.getOrderHash(mirrorOrderComponents)
        );

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

        OrderParameters memory mirrorOrderParameters = OrderParameters(
            address(cal),
            context.args.zone,
            mirrorOfferItems,
            mirrorConsiderationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            mirrorConsiderationItems.length
        );

        Order[] memory orders = new Order[](2);
        orders[0] = Order(orderParameters, signature);
        orders[1] = Order(mirrorOrderParameters, mirrorSignature);

        fulfillmentComponent = FulfillmentComponent(0, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        firstFulfillment.offerComponents = fulfillmentComponents;
        secondFulfillment.considerationComponents = fulfillmentComponents;
        delete fulfillmentComponents;
        fulfillmentComponent = FulfillmentComponent(1, 0);
        fulfillmentComponents.push(fulfillmentComponent);
        firstFulfillment.considerationComponents = fulfillmentComponents;
        secondFulfillment.offerComponents = fulfillmentComponents;

        fulfillments.push(firstFulfillment);
        fulfillments.push(secondFulfillment);

        context.consideration.matchOrders{
            value: context.args.paymentAmts[0] +
                context.args.paymentAmts[1] +
                context.args.paymentAmts[2]
        }(orders, fulfillments);
    }
}
