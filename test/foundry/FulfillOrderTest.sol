// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { OrderType, BasicOrderType, ItemType, Side } from "../../contracts/lib/ConsiderationEnums.sol";
import { AdditionalRecipient } from "../../contracts/lib/ConsiderationStructs.sol";
import { Consideration } from "../../contracts/Consideration.sol";
import { Order, OfferItem, OrderParameters, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { TestERC721 } from "../../contracts/test/TestERC721.sol";
import { TestERC1155 } from "../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";
import { ProxyRegistry } from "./interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "./interfaces/OwnableDelegateProxy.sol";

contract FulfillOrderTest is BaseOrderTest {
    struct ToErc721Struct {
        address zone;
        uint128 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
    }

    struct ToErc1155Struct {
        address zone;
        uint128 id;
        uint256 erc1155Amt;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
    }

    struct ToErc721WithSingleTipStruct {
        address zone;
        uint128 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
        uint128 tipAmt;
    }

    struct ToErc721WithMultipleTipsStruct {
        address zone;
        uint128 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
        uint8 numberOfTips;
    }

    struct ToErc1155WithSingleTipStruct {
        address zone;
        uint128 id;
        uint256 erc1155Amt;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
        uint128 tipAmt;
    }

    struct ToErc1155WithMultipleTipsStruct {
        address zone;
        uint128 id;
        uint256 erc1155Amt;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
        uint8 numberOfTips;
    }

    struct ConsiderationToErc721Struct {
        Consideration consideration;
        ToErc721Struct args;
    }

    struct ConsiderationToErc1155Struct {
        Consideration consideration;
        ToErc1155Struct args;
    }

    struct ConsiderationToErc721WithSingleTipStruct {
        Consideration consideration;
        ToErc721WithSingleTipStruct args;
    }

    struct ConsiderationToErc1155WithSingleTipStruct {
        Consideration consideration;
        ToErc1155WithSingleTipStruct args;
    }

    struct ConsiderationToErc721WithMultipleTipsStruct {
        Consideration consideration;
        ToErc721WithMultipleTipsStruct args;
    }

    struct ConsiderationToErc1155WithMultipleTipsStruct {
        Consideration consideration;
        ToErc1155WithMultipleTipsStruct args;
    }

    function testFulfillOrderEthToErc721(ToErc721Struct memory testStruct)
        public
    {
        _testFulfillOrderEthToErc721(
            ConsiderationToErc721Struct(referenceConsideration, testStruct)
        );
        _testFulfillOrderEthToErc721(
            ConsiderationToErc721Struct(consideration, testStruct)
        );
    }

    function testFulfillOrderEthToErc1155(ToErc1155Struct memory testStruct)
        public
    {
        _testFulfillOrderEthToErc1155(
            ConsiderationToErc1155Struct(referenceConsideration, testStruct)
        );
        _testFulfillOrderEthToErc1155(
            ConsiderationToErc1155Struct(consideration, testStruct)
        );
    }

    function testFulfillOrderEthToErc721WithSingleTip(
        ToErc721WithSingleTipStruct memory testStruct
    ) public {
        _testFulfillOrderEthToErc721WithSingleEthTip(
            ConsiderationToErc721WithSingleTipStruct(
                referenceConsideration,
                testStruct
            )
        );
        _testFulfillOrderEthToErc721WithSingleEthTip(
            ConsiderationToErc721WithSingleTipStruct(consideration, testStruct)
        );
    }

    function testFulfillOrderEthToErc1155WithSingleTip(
        ToErc1155WithSingleTipStruct memory testStruct
    ) public {
        _testFulfillOrderEthToErc1155WithSingleEthTip(
            ConsiderationToErc1155WithSingleTipStruct(
                referenceConsideration,
                testStruct
            )
        );
        _testFulfillOrderEthToErc1155WithSingleEthTip(
            ConsiderationToErc1155WithSingleTipStruct(consideration, testStruct)
        );
    }

    function testFulfillOrderEthToErc721WithMultipleTips(
        ToErc721WithMultipleTipsStruct memory testStruct
    ) public {
        _testFulfillOrderEthToErc721WithMultipleEthTips(
            ConsiderationToErc721WithMultipleTipsStruct(
                referenceConsideration,
                testStruct
            )
        );
        _testFulfillOrderEthToErc721WithMultipleEthTips(
            ConsiderationToErc721WithMultipleTipsStruct(
                consideration,
                testStruct
            )
        );
    }

    function testFulfillOrderEthToErc1155WithMultipleTips(
        ToErc1155WithMultipleTipsStruct memory testStruct
    ) public {
        _testFulfillOrderEthToErc1155WithMultipleEthTips(
            ConsiderationToErc1155WithMultipleTipsStruct(
                referenceConsideration,
                testStruct
            )
        );
        _testFulfillOrderEthToErc1155WithMultipleEthTips(
            ConsiderationToErc1155WithMultipleTipsStruct(
                consideration,
                testStruct
            )
        );
    }

    function testFulfillOrderSingleErc20ToSingleErc1155(
        ToErc1155Struct memory testStruct
    ) public {
        _testFulfillOrderSingleErc20ToSingleErc1155(
            ConsiderationToErc1155Struct(referenceConsideration, testStruct)
        );
        _testFulfillOrderSingleErc20ToSingleErc1155(
            ConsiderationToErc1155Struct(consideration, testStruct)
        );
    }

    function testFulfillOrderEthToErc721WithErc721Tips(
        ToErc721WithMultipleTipsStruct memory testStruct
    ) public {
        _testFulfillOrderEthToErc721WithErc721Tips(
            ConsiderationToErc721WithMultipleTipsStruct(
                referenceConsideration,
                testStruct
            )
        );
        _testFulfillOrderEthToErc721WithErc721Tips(
            ConsiderationToErc721WithMultipleTipsStruct(
                consideration,
                testStruct
            )
        );
    }

    function testFulfillOrderEthToErc1155WithErc721Tips(
        ToErc1155WithMultipleTipsStruct memory testStruct
    ) public {
        _testFulfillOrderEthToErc1155WithErc721Tips(
            ConsiderationToErc1155WithMultipleTipsStruct(
                referenceConsideration,
                testStruct
            )
        );
        _testFulfillOrderEthToErc1155WithErc721Tips(
            ConsiderationToErc1155WithMultipleTipsStruct(
                consideration,
                testStruct
            )
        );
    }

    function testFulfillOrderEthToErc721WithErc1155Tips(
        ToErc721WithMultipleTipsStruct memory testStruct
    ) public {
        _testFulfillOrderEthToErc721WithErc1155Tips(
            ConsiderationToErc721WithMultipleTipsStruct(
                referenceConsideration,
                testStruct
            )
        );
        _testFulfillOrderEthToErc721WithErc1155Tips(
            ConsiderationToErc721WithMultipleTipsStruct(
                consideration,
                testStruct
            )
        );
    }

    function testFulfillOrderEthToErc1155WithErc1155Tips(
        ToErc1155WithMultipleTipsStruct memory testStruct
    ) public {
        _testFulfillOrderEthToErc1155WithErc1155Tips(
            ConsiderationToErc1155WithMultipleTipsStruct(
                referenceConsideration,
                testStruct
            )
        );
        _testFulfillOrderEthToErc1155WithErc1155Tips(
            ConsiderationToErc1155WithMultipleTipsStruct(
                consideration,
                testStruct
            )
        );
    }

    function testFulfillOrderEthToErc721WithErc20Tips(
        ToErc721WithMultipleTipsStruct memory testStruct
    ) public {
        _testFulfillOrderEthToErc721WithErc20Tips(
            ConsiderationToErc721WithMultipleTipsStruct(
                referenceConsideration,
                testStruct
            )
        );
        _testFulfillOrderEthToErc721WithErc20Tips(
            ConsiderationToErc721WithMultipleTipsStruct(
                consideration,
                testStruct
            )
        );
    }

    function testFulfillOrderEthToErc1155WithErc20Tips(
        ToErc1155WithMultipleTipsStruct memory testStruct
    ) public {
        _testFulfillOrderEthToErc1155WithErc20Tips(
            ConsiderationToErc1155WithMultipleTipsStruct(
                referenceConsideration,
                testStruct
            )
        );
        _testFulfillOrderEthToErc1155WithErc20Tips(
            ConsiderationToErc1155WithMultipleTipsStruct(
                consideration,
                testStruct
            )
        );
    }

    function testFulfillOrderEthToErc721FullRestricted(
        ToErc721Struct memory testStruct
    ) public {
        _testFulfillOrderEthToErc721FullRestricted(
            ConsiderationToErc721Struct(referenceConsideration, testStruct)
        );
        _testFulfillOrderEthToErc721FullRestricted(
            ConsiderationToErc721Struct(consideration, testStruct)
        );
    }

    function _testFulfillOrderEthToErc721(
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
                payable(testStruct.args.zone) // TODO: should we fuzz on zone? do royalties get paid to zone??
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
        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc1155(
        ConsiderationToErc1155Struct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(testStruct.args.erc1155Amt > 0);
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

        test1155_1.mint(alice, testStruct.args.id, testStruct.args.erc1155Amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                testStruct.args.id,
                testStruct.args.erc1155Amt,
                testStruct.args.erc1155Amt
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
        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderSingleErc20ToSingleErc1155(
        ConsiderationToErc1155Struct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(testStruct.args.erc1155Amt > 0);
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

        test1155_1.mint(alice, testStruct.args.id, testStruct.args.erc1155Amt);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                testStruct.args.id,
                testStruct.args.erc1155Amt,
                testStruct.args.erc1155Amt
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

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc721WithSingleEthTip(
        ConsiderationToErc721WithSingleTipStruct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            testStruct.args.paymentAmts[0] > 0 &&
                testStruct.args.paymentAmts[1] > 0 &&
                testStruct.args.paymentAmts[2] > 0 &&
                testStruct.args.tipAmt > 0
        );
        vm.assume(
            uint256(testStruct.args.paymentAmts[0]) +
                uint256(testStruct.args.paymentAmts[1]) +
                uint256(testStruct.args.paymentAmts[2]) +
                uint256(testStruct.args.tipAmt) <=
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
                payable(testStruct.args.zone) // TODO: should we fuzz on zone? do royalties get paid to zone??
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

        // Add tip
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                testStruct.args.tipAmt,
                testStruct.args.tipAmt,
                payable(bob)
            )
        );

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
            considerationItems.length - 1
        );

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2] +
                testStruct.args.tipAmt
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc1155WithSingleEthTip(
        ConsiderationToErc1155WithSingleTipStruct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(testStruct.args.erc1155Amt > 0);
        vm.assume(
            testStruct.args.paymentAmts[0] > 0 &&
                testStruct.args.paymentAmts[1] > 0 &&
                testStruct.args.paymentAmts[2] > 0 &&
                testStruct.args.tipAmt > 0
        );
        vm.assume(
            uint256(testStruct.args.paymentAmts[0]) +
                uint256(testStruct.args.paymentAmts[1]) +
                uint256(testStruct.args.paymentAmts[2]) +
                uint256(testStruct.args.tipAmt) <=
                2**128 - 1
        );
        bytes32 conduitKey = testStruct.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, testStruct.args.id, testStruct.args.erc1155Amt);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                testStruct.args.id,
                testStruct.args.erc1155Amt,
                testStruct.args.erc1155Amt
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

        // Add tip
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                testStruct.args.tipAmt,
                testStruct.args.tipAmt,
                payable(bob)
            )
        );

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
            considerationItems.length - 1
        );

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2] +
                testStruct.args.tipAmt
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc721WithMultipleEthTips(
        ConsiderationToErc721WithMultipleTipsStruct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            testStruct.args.numberOfTips > 1 &&
                testStruct.args.numberOfTips < 64
        );
        vm.assume(
            testStruct.args.paymentAmts[0] > 0 &&
                testStruct.args.paymentAmts[1] > 0 &&
                testStruct.args.paymentAmts[2] > 0
        );
        vm.assume(
            uint256(testStruct.args.paymentAmts[0]) +
                uint256(testStruct.args.paymentAmts[1]) +
                uint256(testStruct.args.paymentAmts[2]) +
                uint256(testStruct.args.numberOfTips) *
                ((1 + testStruct.args.numberOfTips) / 2) <= // avg of tip amounts from 1 to numberOfTips eth
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

        uint128 sumOfTips;
        for (uint128 i = 1; i < testStruct.args.numberOfTips + 1; i++) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            sumOfTips += i;
            considerationItems.push(
                ConsiderationItem(
                    ItemType.NATIVE,
                    address(0),
                    0,
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - testStruct.args.numberOfTips
        );

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2] +
                sumOfTips
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc1155WithMultipleEthTips(
        ConsiderationToErc1155WithMultipleTipsStruct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            testStruct.args.numberOfTips > 1 &&
                testStruct.args.numberOfTips < 64
        );
        vm.assume(testStruct.args.erc1155Amt > 0);
        vm.assume(
            testStruct.args.paymentAmts[0] > 0 &&
                testStruct.args.paymentAmts[1] > 0 &&
                testStruct.args.paymentAmts[2] > 0
        );
        vm.assume(
            uint256(testStruct.args.paymentAmts[0]) +
                uint256(testStruct.args.paymentAmts[1]) +
                uint256(testStruct.args.paymentAmts[2]) +
                uint256(testStruct.args.numberOfTips) *
                ((1 + testStruct.args.numberOfTips) / 2) <= // avg of tip amounts from 1 to numberOfTips eth
                2**128 - 1
        );
        bytes32 conduitKey = testStruct.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, testStruct.args.id, testStruct.args.erc1155Amt);

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                testStruct.args.id,
                testStruct.args.erc1155Amt,
                testStruct.args.erc1155Amt
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

        uint128 sumOfTips;
        // push tip of amount i eth to considerationitems
        for (uint128 i = 1; i < testStruct.args.numberOfTips + 1; i++) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            sumOfTips += i;
            considerationItems.push(
                ConsiderationItem(
                    ItemType.NATIVE,
                    address(0),
                    0,
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - testStruct.args.numberOfTips
        );

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2] +
                sumOfTips
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc721WithErc721Tips(
        ConsiderationToErc721WithMultipleTipsStruct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            testStruct.args.numberOfTips > 0 &&
                testStruct.args.numberOfTips < 64
        );
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

        // mint erc721s to the test contract and push tips to considerationItems
        for (uint128 i = 1; i < testStruct.args.numberOfTips + 1; i++) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            test721_2.mint(address(this), i); // mint test721_2 tokens to avoid collision with fuzzed test721_1 tokenId
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC721,
                    address(test721_2),
                    i,
                    1,
                    1,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - testStruct.args.numberOfTips
        );

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc1155WithErc721Tips(
        ConsiderationToErc1155WithMultipleTipsStruct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            testStruct.args.numberOfTips > 1 &&
                testStruct.args.numberOfTips < 64
        );
        vm.assume(testStruct.args.erc1155Amt > 0);
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

        test1155_1.mint(alice, testStruct.args.id, testStruct.args.erc1155Amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                testStruct.args.id,
                testStruct.args.erc1155Amt,
                testStruct.args.erc1155Amt
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

        // mint erc721s to the test contract and push tips to considerationItems
        for (uint128 i = 1; i < testStruct.args.numberOfTips + 1; i++) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            test721_2.mint(address(this), i); // mint test721_2 tokens to avoid collision with fuzzed test721_1 tokenId
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC721,
                    address(test721_2),
                    i,
                    1,
                    1,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - testStruct.args.numberOfTips
        );

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc721WithErc1155Tips(
        ConsiderationToErc721WithMultipleTipsStruct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            testStruct.args.numberOfTips > 0 &&
                testStruct.args.numberOfTips < 64
        );
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

        for (
            uint256 i = 1;
            i < testStruct.args.numberOfTips + uint256(1);
            i++
        ) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            test1155_1.mint(address(this), testStruct.args.id + uint256(i), i);
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC1155,
                    address(test1155_1),
                    testStruct.args.id + uint256(i),
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - testStruct.args.numberOfTips
        );

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc1155WithErc1155Tips(
        ConsiderationToErc1155WithMultipleTipsStruct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            testStruct.args.numberOfTips > 1 &&
                testStruct.args.numberOfTips < 64
        );
        vm.assume(testStruct.args.erc1155Amt > 0);
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

        test1155_1.mint(alice, testStruct.args.id, testStruct.args.erc1155Amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                testStruct.args.id,
                testStruct.args.erc1155Amt,
                testStruct.args.erc1155Amt
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

        for (
            uint256 i = 1;
            i < testStruct.args.numberOfTips + uint256(1);
            i++
        ) {
            uint256 tipPk = 0xb0b + i;
            address tipAddr = vm.addr(tipPk);
            test1155_1.mint(address(this), testStruct.args.id + uint256(i), i);
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC1155,
                    address(test1155_1),
                    testStruct.args.id + uint256(i),
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - testStruct.args.numberOfTips
        );

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc721WithErc20Tips(
        ConsiderationToErc721WithMultipleTipsStruct memory testStruct
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

        for (
            uint256 i = 1;
            i < testStruct.args.numberOfTips + uint256(1);
            i++
        ) {
            uint256 tipPk = i;
            address tipAddr = vm.addr(tipPk);
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC20,
                    address(token1),
                    0, // ignored for ERC20
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - testStruct.args.numberOfTips
        );

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc1155WithErc20Tips(
        ConsiderationToErc1155WithMultipleTipsStruct memory testStruct
    )
        internal
        onlyPayable(testStruct.args.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            testStruct.args.numberOfTips > 1 &&
                testStruct.args.numberOfTips < 64
        );
        vm.assume(testStruct.args.erc1155Amt > 0);
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

        test1155_1.mint(alice, testStruct.args.id, testStruct.args.erc1155Amt);
        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                testStruct.args.id,
                testStruct.args.erc1155Amt,
                testStruct.args.erc1155Amt
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

        for (
            uint256 i = 1;
            i < testStruct.args.numberOfTips + uint256(1);
            i++
        ) {
            uint256 tipPk = i;
            address tipAddr = vm.addr(tipPk);
            considerationItems.push(
                ConsiderationItem(
                    ItemType.ERC20,
                    address(token1),
                    0, // ignored for ERC20
                    i,
                    i,
                    payable(tipAddr)
                )
            );
        }

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
            considerationItems.length - testStruct.args.numberOfTips
        );

        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function _testFulfillOrderEthToErc721FullRestricted(
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
            OrderType.FULL_RESTRICTED,
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

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            testStruct.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_RESTRICTED,
            block.timestamp,
            block.timestamp + 1,
            testStruct.args.zoneHash,
            testStruct.args.salt,
            conduitKey,
            considerationItems.length
        );
        vm.prank(alice);
        testStruct.consideration.fulfillOrder{
            value: testStruct.args.paymentAmts[0] +
                testStruct.args.paymentAmts[1] +
                testStruct.args.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }
}
