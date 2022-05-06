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
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
    }
    struct ToErc1155Struct {
        address zone;
        uint256 id;
        uint256 erc1155Amt;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
    }

    struct ToErc721WithSingleTipStruct {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
        uint128 tipAmt;
    }

    struct ToErc1155WithSingleTipStruct {
        address zone;
        uint256 id;
        uint256 erc1155Amt;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
        uint128 tipAmt;
    }

    struct ToErc1155WithMultipleTipsStruct {
        address zone;
        uint256 id;
        uint256 erc1155Amt;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] paymentAmts;
        bool useConduit;
        uint16 numberOfTips;
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

    function testFulfillOrderEthToERC721(ToErc721Struct memory testStruct)
        public
    {
        _testFulfillOrderEthToERC721(
            ConsiderationToErc721Struct(consideration, testStruct)
        );
        _testFulfillOrderEthToERC721(
            ConsiderationToErc721Struct(referenceConsideration, testStruct)
        );
    }

    function testFulfillOrderEthToERC1155(ToErc1155Struct memory testStruct)
        public
    {
        _testFulfillOrderEthToERC1155(
            ConsiderationToErc1155Struct(consideration, testStruct)
        );
        _testFulfillOrderEthToERC1155(
            ConsiderationToErc1155Struct(referenceConsideration, testStruct)
        );
    }

    function testFulfillOrderEthToErc721WithSingleTip(
        ToErc721WithSingleTipStruct memory testStruct
    ) public {
        _testFulfillOrderEthToERC721WithSingleTip(
            ConsiderationToErc721WithSingleTipStruct(consideration, testStruct)
        );
        _testFulfillOrderEthToERC721WithSingleTip(
            ConsiderationToErc721WithSingleTipStruct(
                referenceConsideration,
                testStruct
            )
        );
    }

    function testFulfillOrderEthToErc1155WithSingleTip(
        ToErc1155WithSingleTipStruct memory testStruct
    ) public {
        _testFulfillOrderEthToERC1155WithSingleTip(
            ConsiderationToErc1155WithSingleTipStruct(consideration, testStruct)
        );
        _testFulfillOrderEthToERC1155WithSingleTip(
            ConsiderationToErc1155WithSingleTipStruct(
                referenceConsideration,
                testStruct
            )
        );
    }

    function _testFulfillOrderEthToERC721(
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

    function _testFulfillOrderEthToERC1155(
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
        }(Order(orderParameters, signature), conduitKey); // TODO: over/underflow error in referenceConsideration differential test
    }

    function _testFulfillOrderSingleERC20ToSingleERC1155(
        ConsiderationToErc1155Struct memory testStruct
    ) internal onlyPayable(testStruct.args.zone) topUp {
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

        testStruct.consideration.fulfillOrder(
            Order(orderParameters, signature),
            conduitKey
        );
    }

    function _testFulfillOrderEthToERC721WithSingleTip(
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

    function _testFulfillOrderEthToERC1155WithSingleTip(
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

    // function _testFulfillOrderSingleERC20ToSingleERC1155(
    //     Consideration _consideration,
    //     ToErc1155Struct memory toErc1155Struct
    // ) internal onlyPayable(toErc1155Struct.zone) topUp {
    //     vm.assume(toErc1155Struct.erc1155Amt > 0);
    //     vm.assume(
    //         toErc1155Struct.paymentAmts[0] > 0 &&
    //             toErc1155Struct.paymentAmts[1] > 0 &&
    //             toErc1155Struct.paymentAmts[2] > 0
    //     );
    //     vm.assume(
    //         uint256(toErc1155Struct.paymentAmts[0]) +
    //             uint256(toErc1155Struct.paymentAmts[1]) +
    //             uint256(toErc1155Struct.paymentAmts[2]) <=
    //             2**128 - 1
    //     );
    //     bytes32 conduitKey = toErc1155Struct.useConduit
    //         ? conduitKeyOne
    //         : bytes32(0);

    //     test1155_1.mint(alice, toErc1155Struct.id, toErc1155Struct.erc1155Amt);

    //     OfferItem[] memory offerItem.push(OfferItem(
    //         ItemType.ERC1155,
    //         address(test1155_1),
    //         toErc1155Struct.id,
    //         toErc1155Struct.erc1155Amt,
    //         toErc1155Struct.erc1155Amt
    //     ));

    //     ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
    //         3
    //     );
    //     considerationItems.push(ConsiderationItem(
    //         ItemType.ERC20,
    //         address(token1),
    //         0,
    //         uint256(toErc1155Struct.paymentAmts[0]),
    //         uint256(toErc1155Struct.paymentAmts[0]),
    //         payable(alice)
    //     ));
    //     considerationItems.push(ConsiderationItem(
    //         ItemType.ERC20,
    //         address(token1),
    //         0,
    //         uint256(toErc1155Struct.paymentAmts[1]),
    //         uint256(toErc1155Struct.paymentAmts[1]),
    //         payable(toErc1155Struct.zone)
    //     ));
    //     considerationItems.push(ConsiderationItem(
    //         ItemType.ERC20,
    //         address(token1),
    //         0,
    //         uint256(toErc1155Struct.paymentAmts[2]),
    //         uint256(toErc1155Struct.paymentAmts[2]),
    //         payable(cal)
    //     ));

    //     OrderComponents memory orderComponents = OrderComponents(
    //         alice,
    //         toErc1155Struct.zone,
    //         offerItem,
    //         considerationItems,
    //         OrderType.FULL_OPEN,
    //         block.timestamp,
    //         block.timestamp + 1,
    //         toErc1155Struct.zoneHash,
    //         toErc1155Struct.salt,
    //         conduitKey,
    //         _consideration.getNonce(alice)
    //     );
    //     bytes memory signature = signOrder(
    //         _consideration,
    //         alicePk,
    //         _consideration.getOrderHash(orderComponents)
    //     );

    //     OrderParameters memory orderParameters = OrderParameters(
    //         address(alice),
    //         toErc1155Struct.zone,
    //         offerItem,
    //         considerationItems,
    //         OrderType.FULL_OPEN,
    //         block.timestamp,
    //         block.timestamp + 1,
    //         toErc1155Struct.zoneHash,
    //         toErc1155Struct.salt,
    //         conduitKey,
    //         considerationItems.length
    //     );

    //     _consideration.fulfillOrder(
    //         Order(orderParameters, signature),
    //         conduitKey
    //     );
    // }
}
