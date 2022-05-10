// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

// import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
// import { Order, Fulfillment } from "../../contracts/lib/ConsiderationStructs.sol";
// import { Consideration } from "../../contracts/Consideration.sol";
// import { AdvancedOrder, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters, CriteriaResolver, FulfillmentComponent } from "../../contracts/lib/ConsiderationStructs.sol";
// import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
// import { TestERC721 } from "../../contracts/test/TestERC721.sol";
// import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
// import { TestERC20 } from "../../contracts/test/TestERC20.sol";
// import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
// import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";

// contract MatchOrders is BaseOrderTest {
//     struct FuzzInputsCommon {
//         address zone;
//         uint256 id;
//         bytes32 zoneHash;
//         uint256 salt;
//         uint128[3] paymentAmts;
//         Order[] orders;
//         Fulfillment[] fulfillments;
//         uint128[3] paymentAmnts;
//         bool useConduit;
//     }

//     struct Context {
//         Consideration consideration;
//         FuzzInputsCommon args;
//     }

//     function testMatchOrdersEthToErc721(FuzzInputsCommon memory inputs) public {
//         _testSingleMatchOrdersEthToErc721(
//             Context(referenceConsideration, inputs)
//         );
//         _testSingleMatchOrdersEthToErc721(Context(consideration, inputs));
//     }

//     function _testSingleMatchOrdersEthToErc721(Context memory context)
//         internal
//         resetTokenBalancesBetweenRuns
//     {
//         vm.assume(
//             context.args.paymentAmts[0] > 0 &&
//                 context.args.paymentAmts[1] > 0 &&
//                 context.args.paymentAmts[2] > 0
//         );
//         vm.assume(
//             uint256(context.args.paymentAmts[0]) +
//                 uint256(context.args.paymentAmts[1]) +
//                 uint256(context.args.paymentAmts[2]) <=
//                 2**128 - 1
//         );
//         bytes32 conduitKey = context.args.useConduit
//             ? conduitKeyOne
//             : bytes32(0);

//         test721_1.mint(alice, context.args.id);

//         offerItems.push(
//             OfferItem(ItemType.ERC721, address(test721_1), 0, 1, 1)
//         );
//         considerationItems.push(
//             ConsiderationItem(
//                 ItemType.NATIVE,
//                 address(0),
//                 0,
//                 uint256(1),
//                 uint256(1),
//                 payable(alice)
//             )
//         );
//         considerationItems.push(
//             ConsiderationItem(
//                 ItemType.NATIVE,
//                 address(0),
//                 0,
//                 uint256(1),
//                 uint256(1),
//                 payable(context.args.zone)
//             )
//         );
//         considerationItems.push(
//             ConsiderationItem(
//                 ItemType.NATIVE,
//                 address(0),
//                 0,
//                 uint256(context.args.paymentAmts[2]),
//                 uint256(context.args.paymentAmts[2]),
//                 payable(cal)
//             )
//         );

//         OrderComponents memory orderComponents = OrderComponents(
//             alice,
//             context.args.zone,
//             offerItems,
//             considerationItems,
//             OrderType.FULL_OPEN,
//             block.timestamp,
//             block.timestamp + 1,
//             context.args.zoneHash,
//             context.args.salt,
//             conduitKey,
//             context.consideration.getNonce(alice)
//         );
//         bytes memory signature = signOrder(
//             context.consideration,
//             alicePk,
//             context.consideration.getOrderHash(orderComponents)
//         );

//         OfferItem[] memory mirrorOfferItems = new OfferItem[](
//             considerationItems.length
//         );
//         for (uint256 i = 0; i < considerationItems.length; i++) {
//             mirrorOfferItems[i] = OfferItem(
//                 considerationItems[i].itemType,
//                 considerationItems[i].token,
//                 considerationItems[i].identifierOrCriteria,
//                 considerationItems[i].startAmount,
//                 considerationItems[i].endAmount
//             );
//         }

//         ConsiderationItem[]
//             memory mirrorConsiderationItems = new ConsiderationItem[](
//                 offerItems.length
//             );
//         for (uint256 i = 0; i < offerItems.length; i++) {
//             mirrorConsiderationItems[i] = ConsiderationItem(
//                 offerItems[i].itemType,
//                 offerItems[i].token,
//                 offerItems[i].identifierOrCriteria,
//                 offerItems[i].startAmount,
//                 offerItems[i].endAmount,
//                 payable(cal)
//             );
//         }

//         OrderComponents memory mirrorOrderComponents = OrderComponents(
//             cal,
//             context.args.zone,
//             mirrorOfferItems,
//             mirrorConsiderationItems,
//             OrderType.FULL_OPEN,
//             block.timestamp,
//             block.timestamp + 1,
//             context.args.zoneHash,
//             context.args.salt,
//             conduitKey,
//             context.consideration.getNonce(cal)
//         );
//         bytes memory mirrorSignature = signOrder(
//             context.consideration,
//             calPk,
//             context.consideration.getOrderHash(mirrorOrderComponents)
//         );

//         OrderParameters memory orderParameters = OrderParameters(
//             address(alice),
//             context.args.zone,
//             offerItems,
//             considerationItems,
//             OrderType.FULL_OPEN,
//             block.timestamp,
//             block.timestamp + 1,
//             context.args.zoneHash,
//             context.args.salt,
//             conduitKey,
//             considerationItems.length
//         );

//         OrderParameters memory mirrorOrderParameters = OrderParameters(
//             address(cal),
//             context.args.zone,
//             mirrorOfferItems,
//             mirrorConsiderationItems,
//             OrderType.FULL_OPEN,
//             block.timestamp,
//             block.timestamp + 1,
//             context.args.zoneHash,
//             uint256(10),
//             conduitKey,
//             mirrorConsiderationItems.length
//         );

//         Order[] memory orders = new Order[](2);
//         orders[0] = Order(orderParameters, signature);
//         orders[1] = Order(mirrorOrderParameters, mirrorSignature);

//         firstOrderFirstItemArray.push(FulfillmentComponent(0, 0));
//         firstOrderSecondItemArray.push(FulfillmentComponent(0, 1));
//         firstOrderThirdItemArray.push(FulfillmentComponent(0, 2));
//         secondOrderFirstItemArray.push(FulfillmentComponent(1, 0));

//         fulfillments.push(
//             Fulfillment(firstOrderFirstItemArray, secondOrderFirstItemArray)
//         );
//         fulfillments.push(
//             Fulfillment(secondOrderFirstItemArray, firstOrderFirstItemArray)
//         );
//         fulfillments.push(
//             Fulfillment(secondOrderFirstItemArray, firstOrderSecondItemArray)
//         );
//         fulfillments.push(
//             Fulfillment(secondOrderFirstItemArray, firstOrderThirdItemArray)
//         );

//         context.consideration.matchOrders{
//             value: context.args.paymentAmts[0] +
//                 context.args.paymentAmts[1] +
//                 context.args.paymentAmts[2]
//         }(orders, fulfillments);
//     }
// }
