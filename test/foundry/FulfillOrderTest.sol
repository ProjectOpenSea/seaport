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

    function testFulfillOrderEthToERC721(ToErc721Struct memory _toErc721Struct)
        public
    {
        _testFulfillOrderEthToERC721(consideration, _toErc721Struct);
        _testFulfillOrderEthToERC721(referenceConsideration, _toErc721Struct);
    }

    function testFulfillOrderEthToERC1155(
        ToErc1155Struct memory _toErc1155Struct
    ) public {
        _testFulfillOrderEthToERC1155(consideration, _toErc1155Struct);
        _testFulfillOrderEthToERC1155(referenceConsideration, _toErc1155Struct);
    }

    function _testFulfillOrderEthToERC721(
        Consideration _consideration,
        ToErc721Struct memory toErc721Struct
    )
        internal
        onlyPayable(toErc721Struct.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(
            toErc721Struct.paymentAmts[0] > 0 &&
                toErc721Struct.paymentAmts[1] > 0 &&
                toErc721Struct.paymentAmts[2] > 0
        );
        vm.assume(
            uint256(toErc721Struct.paymentAmts[0]) +
                uint256(toErc721Struct.paymentAmts[1]) +
                uint256(toErc721Struct.paymentAmts[2]) <=
                2**128 - 1
        );
        bytes32 conduitKey = toErc721Struct.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, toErc721Struct.id);
        OfferItem[] memory offerItem = singleOfferItem(
            ItemType.ERC721,
            address(test721_1),
            toErc721Struct.id,
            1,
            1
        );
        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            3
        );
        considerationItems[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(toErc721Struct.paymentAmts[0]),
            uint256(toErc721Struct.paymentAmts[0]),
            payable(alice)
        );
        considerationItems[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(toErc721Struct.paymentAmts[1]),
            uint256(toErc721Struct.paymentAmts[1]),
            payable(toErc721Struct.zone) // TODO: should we fuzz on zone? do royalties get paid to zone??
        );
        considerationItems[2] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(toErc721Struct.paymentAmts[2]),
            uint256(toErc721Struct.paymentAmts[2]),
            payable(cal)
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            toErc721Struct.zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            toErc721Struct.zoneHash,
            toErc721Struct.salt,
            conduitKey,
            _consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            _consideration,
            alicePk,
            _consideration.getOrderHash(orderComponents)
        );
        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            toErc721Struct.zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            toErc721Struct.zoneHash,
            toErc721Struct.salt,
            conduitKey,
            considerationItems.length
        );
        _consideration.fulfillOrder{
            value: toErc721Struct.paymentAmts[0] +
                toErc721Struct.paymentAmts[1] +
                toErc721Struct.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey); // TODO: over/underflow error
    }

    function _testFulfillOrderEthToERC1155(
        Consideration _consideration,
        ToErc1155Struct memory _ethToERC1155
    )
        internal
        onlyPayable(_ethToERC1155.zone)
        topUp
        resetTokenBalancesBetweenRuns
    {
        vm.assume(_ethToERC1155.erc1155Amt > 0);
        vm.assume(
            _ethToERC1155.paymentAmts[0] > 0 &&
                _ethToERC1155.paymentAmts[1] > 0 &&
                _ethToERC1155.paymentAmts[2] > 0
        );
        vm.assume(
            uint256(_ethToERC1155.paymentAmts[0]) +
                uint256(_ethToERC1155.paymentAmts[1]) +
                uint256(_ethToERC1155.paymentAmts[2]) <=
                2**128 - 1
        );
        bytes32 conduitKey = _ethToERC1155.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, _ethToERC1155.id, _ethToERC1155.erc1155Amt);
        OfferItem[] memory offerItem = singleOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            _ethToERC1155.id,
            _ethToERC1155.erc1155Amt,
            _ethToERC1155.erc1155Amt
        );

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            3
        );
        considerationItems[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethToERC1155.paymentAmts[0]),
            uint256(_ethToERC1155.paymentAmts[0]),
            payable(alice)
        );
        considerationItems[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethToERC1155.paymentAmts[1]),
            uint256(_ethToERC1155.paymentAmts[1]),
            payable(_ethToERC1155.zone)
        );
        considerationItems[2] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethToERC1155.paymentAmts[2]),
            uint256(_ethToERC1155.paymentAmts[2]),
            payable(cal)
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            _ethToERC1155.zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            _ethToERC1155.zoneHash,
            _ethToERC1155.salt,
            conduitKey,
            _consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            _consideration,
            alicePk,
            _consideration.getOrderHash(orderComponents)
        );
        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            _ethToERC1155.zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            _ethToERC1155.zoneHash,
            _ethToERC1155.salt,
            conduitKey,
            considerationItems.length
        );
        _consideration.fulfillOrder{
            value: _ethToERC1155.paymentAmts[0] +
                _ethToERC1155.paymentAmts[1] +
                _ethToERC1155.paymentAmts[2]
        }(Order(orderParameters, signature), conduitKey); // TODO: over/underflow error in referenceConsideration differential test
    }

    function _testFulfillOrderSingleERC20ToSingleERC1155(
        Consideration _consideration,
        ToErc1155Struct memory toErc1155Struct
    ) internal onlyPayable(toErc1155Struct.zone) topUp {
        vm.assume(toErc1155Struct.erc1155Amt > 0);
        vm.assume(
            toErc1155Struct.paymentAmts[0] > 0 &&
                toErc1155Struct.paymentAmts[1] > 0 &&
                toErc1155Struct.paymentAmts[2] > 0
        );
        vm.assume(
            uint256(toErc1155Struct.paymentAmts[0]) +
                uint256(toErc1155Struct.paymentAmts[1]) +
                uint256(toErc1155Struct.paymentAmts[2]) <=
                2**128 - 1
        );
        bytes32 conduitKey = toErc1155Struct.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, toErc1155Struct.id, toErc1155Struct.erc1155Amt);

        OfferItem[] memory offerItem = singleOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            toErc1155Struct.id,
            toErc1155Struct.erc1155Amt,
            toErc1155Struct.erc1155Amt
        );

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            3
        );
        considerationItems[0] = ConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            uint256(toErc1155Struct.paymentAmts[0]),
            uint256(toErc1155Struct.paymentAmts[0]),
            payable(alice)
        );
        considerationItems[1] = ConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            uint256(toErc1155Struct.paymentAmts[1]),
            uint256(toErc1155Struct.paymentAmts[1]),
            payable(toErc1155Struct.zone)
        );
        considerationItems[2] = ConsiderationItem(
            ItemType.ERC20,
            address(token1),
            0,
            uint256(toErc1155Struct.paymentAmts[2]),
            uint256(toErc1155Struct.paymentAmts[2]),
            payable(cal)
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            toErc1155Struct.zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            toErc1155Struct.zoneHash,
            toErc1155Struct.salt,
            conduitKey,
            _consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            _consideration,
            alicePk,
            _consideration.getOrderHash(orderComponents)
        );

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            toErc1155Struct.zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            toErc1155Struct.zoneHash,
            toErc1155Struct.salt,
            conduitKey,
            considerationItems.length
        );

        _consideration.fulfillOrder(
            Order(orderParameters, signature),
            conduitKey
        );
    }
}
