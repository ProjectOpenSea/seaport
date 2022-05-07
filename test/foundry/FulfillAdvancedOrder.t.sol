// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { Consideration } from "../../contracts/Consideration.sol";
import { AdvancedOrder, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters, CriteriaResolver } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";

contract FulfillAdvancedOrder is BaseOrderTest {
    OrderInfo orderInfo;
    // todo: add numer/denom, swap if numer > denom
    struct AdvancedOrderInputs {
        uint256 tokenId;
        address zone;
        bytes32 zoneHash;
        uint256 salt;
        uint16 offerAmt;
        // uint16 fulfillAmt;
        uint128[3] ethAmts;
        bool useConduit;
    }

    struct TestAdvancedOrder {
        Consideration consideration;
        AdvancedOrderInputs args;
    }

    struct OrderInfo {
        bytes32 signature;
        bytes32 orderHash;
        bool isValidated;
        bool isCancelled;
    }

    function setUp() public virtual override {
        super.setUp();
        delete orderInfo;
    }

    function testAdvancedPartial1155(AdvancedOrderInputs memory args) public {
        _advancedPartial1155(TestAdvancedOrder(consideration, args));
        delete orderInfo;
        _advancedPartial1155(TestAdvancedOrder(referenceConsideration, args));
    }

    function _advancedPartial1155(TestAdvancedOrder memory testAdvancedOrder)
        internal
        onlyPayable(testAdvancedOrder.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            testAdvancedOrder.args.ethAmts[0] > 0 &&
                testAdvancedOrder.args.ethAmts[1] > 0 &&
                testAdvancedOrder.args.ethAmts[2] > 0
        );
        vm.assume(
            uint256(testAdvancedOrder.args.ethAmts[0]) +
                uint256(testAdvancedOrder.args.ethAmts[1]) +
                uint256(testAdvancedOrder.args.ethAmts[2]) <=
                2**128 - 1
        );
        vm.assume(testAdvancedOrder.args.offerAmt > 0);
        // vm.assume(testAdvancedOrder.args.fulfillAmt > 0);
        // vm.assume(
        //     testAdvancedOrder.args.offerAmt > testAdvancedOrder.args.fulfillAmt
        // );
        // todo: swap fulfillment and tokenAmount if we exceed global rejects with above assume
        // if (testAdvancedOrder.args.offerAmt < testAdvancedOrder.args.fulfillAmt) {
        //     uint256 temp = testAdvancedOrder.args.fulfillAmt;
        //     testAdvancedOrder.args.fulfillAmt = testAdvancedOrder.args.offerAmt;
        //     testAdvancedOrder.args.offerAmt = temp;
        // }

        // require(testAdvancedOrder.args.salt != 5, "bad");
        bytes32 conduitKey = testAdvancedOrder.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        // mint offerAmt tokens
        test1155_1.mint(
            alice,
            testAdvancedOrder.args.tokenId,
            testAdvancedOrder.args.offerAmt * uint256(10) // mint 10x as many
        );

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                testAdvancedOrder.args.tokenId,
                testAdvancedOrder.args.offerAmt * uint256(10),
                testAdvancedOrder.args.offerAmt * uint256(10)
            )
        );

        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                testAdvancedOrder.args.offerAmt * uint256(100),
                testAdvancedOrder.args.offerAmt * uint256(100),
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                testAdvancedOrder.args.offerAmt * uint256(10),
                testAdvancedOrder.args.offerAmt * uint256(10),
                payable(testAdvancedOrder.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                testAdvancedOrder.args.offerAmt * uint256(20),
                testAdvancedOrder.args.offerAmt * uint256(20),
                payable(cal)
            )
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            testAdvancedOrder.args.zone,
            offerItems,
            considerationItems,
            OrderType.PARTIAL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            testAdvancedOrder.args.zoneHash,
            testAdvancedOrder.args.salt,
            conduitKey,
            testAdvancedOrder.consideration.getNonce(alice)
        );
        bytes32 orderHash = testAdvancedOrder.consideration.getOrderHash(
            orderComponents
        );

        bytes memory signature = signOrder(
            testAdvancedOrder.consideration,
            alicePk,
            orderHash
        );

        {
            (
                bool isValidated,
                bool isCancelled,
                uint256 totalFilled,
                uint256 totalSize
            ) = testAdvancedOrder.consideration.getOrderStatus(orderHash);
            assertFalse(isValidated);
            assertFalse(isCancelled);
            assertEq(totalFilled, 0);
            assertEq(totalSize, 0);
        }

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            testAdvancedOrder.args.zone,
            offerItems,
            considerationItems,
            OrderType.PARTIAL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            testAdvancedOrder.args.zoneHash,
            testAdvancedOrder.args.salt,
            conduitKey,
            considerationItems.length
        );
        uint256 value = testAdvancedOrder.args.offerAmt * uint128(130);
        uint120 numer = uint120(testAdvancedOrder.args.offerAmt) * 2;
        uint120 denom = uint120(testAdvancedOrder.args.offerAmt) * 10;
        testAdvancedOrder.consideration.fulfillAdvancedOrder{ value: value }(
            AdvancedOrder(orderParameters, numer, denom, signature, ""),
            new CriteriaResolver[](0),
            conduitKey
        );

        {
            (
                bool isValidated,
                bool isCancelled,
                uint256 totalFilled,
                uint256 totalSize
            ) = testAdvancedOrder.consideration.getOrderStatus(orderHash);
            assertTrue(isValidated);
            assertFalse(isCancelled);
            assertEq(totalFilled, numer);
            assertEq(totalSize, denom);
        }
    }
}
