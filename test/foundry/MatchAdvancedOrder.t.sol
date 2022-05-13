// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { Order, Fulfillment } from "../../contracts/lib/ConsiderationStructs.sol";
import { Consideration } from "../../contracts/Consideration.sol";
import { AdvancedOrder, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters, CriteriaResolver, FulfillmentComponent } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";

contract MatchAdvancedOrder is BaseOrderTest {
    struct FuzzInputs {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128 amount;
        bool useConduit;
    }

    struct Context {
        Consideration consideration;
        FuzzInputs args;
    }

    function testMatchAdvancedOrdersWithEmptyCriteriaResolversEthToErc721(
        FuzzInputs memory args
    ) public {
        _testMatchAdvancedOrdersWithEmptyCriteriaResolversEthToErc721(
            Context(referenceConsideration, args)
        );
        _testMatchAdvancedOrdersWithEmptyCriteriaResolversEthToErc721(
            Context(consideration, args)
        );
    }

    function _testMatchAdvancedOrdersWithEmptyCriteriaResolversEthToErc721(
        Context memory context
    )
        internal
        onlyPayable(context.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(context.args.amount > 0);

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
                context.args.amount,
                context.args.amount,
                payable(alice)
            )
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
        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
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

        OrderComponents memory mirrorOrderComponents = getOrderComponents(
            mirrorOrderParameters,
            context.consideration.getNonce(cal)
        );

        bytes memory mirrorSignature = signOrder(
            context.consideration,
            calPk,
            context.consideration.getOrderHash(mirrorOrderComponents)
        );

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
        advancedOrders[0] = AdvancedOrder(
            orderParameters,
            uint120(1),
            uint120(1),
            signature,
            "0x"
        );
        advancedOrders[1] = AdvancedOrder(
            mirrorOrderParameters,
            uint120(1),
            uint120(1),
            mirrorSignature,
            "0x"
        );

        firstOrderFirstItem = FulfillmentComponent(0, 0);
        secondOrderFirstItem = FulfillmentComponent(1, 0);

        firstOrderFirstItemArray.push(firstOrderFirstItem);
        secondOrderFirstItemArray.push(secondOrderFirstItem);

        firstFulfillment.offerComponents = firstOrderFirstItemArray;
        firstFulfillment.considerationComponents = secondOrderFirstItemArray;

        secondFulfillment.offerComponents = secondOrderFirstItemArray;
        secondFulfillment.considerationComponents = firstOrderFirstItemArray;

        fulfillments.push(firstFulfillment);
        fulfillments.push(secondFulfillment);

        context.consideration.matchAdvancedOrders{ value: context.args.amount }(
            advancedOrders,
            new CriteriaResolver[](0), // no criteria
            fulfillments
        );
    }
}
