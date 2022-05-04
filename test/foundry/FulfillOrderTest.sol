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
    function testSingleERC721(
        address _zone,
        uint256 _id,
        bytes32 _zoneHash,
        uint256 _salt,
        uint128[3] memory _ethAmts,
        bool _useConduit
    ) public onlyPayable(_zone) topUp {
        vm.assume(_ethAmts[0] > 0 && _ethAmts[1] > 0 && _ethAmts[2] > 0);
        vm.assume(
            uint256(_ethAmts[0]) +
                uint256(_ethAmts[1]) +
                uint256(_ethAmts[2]) <=
                2**128 - 1
        );
        bytes32 conduitKey = _useConduit ? conduitKeyOne : bytes32(0);

        test721_1.mint(alice, _id);
        OfferItem[] memory offerItem = singleOfferItem(
            ItemType.ERC721,
            address(test721_1),
            _id,
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
            uint256(_ethAmts[0]),
            uint256(_ethAmts[0]),
            payable(alice)
        );
        considerationItems[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethAmts[1]),
            uint256(_ethAmts[1]),
            payable(_zone) // TODO: should we fuzz on zone? do royalties get paid to zone??
        );
        considerationItems[2] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethAmts[2]),
            uint256(_ethAmts[2]),
            payable(cal)
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            _zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            _zoneHash,
            _salt,
            conduitKey,
            consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            alicePk,
            consideration.getOrderHash(orderComponents)
        );
        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            _zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            _zoneHash,
            _salt,
            conduitKey,
            considerationItems.length
        );
        consideration.fulfillOrder{
            value: _ethAmts[0] + _ethAmts[1] + _ethAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function testSingleERC1155(
        address _zone,
        uint256 _id,
        uint256 _amount,
        bytes32 _zoneHash,
        uint256 _salt,
        uint128[3] memory _ethAmts,
        bool _useConduit
    ) public onlyPayable(_zone) topUp {
        vm.assume(_amount > 0);
        vm.assume(_ethAmts[0] > 0 && _ethAmts[1] > 0 && _ethAmts[2] > 0);
        vm.assume(
            uint256(_ethAmts[0]) +
                uint256(_ethAmts[1]) +
                uint256(_ethAmts[2]) <=
                2**128 - 1
        );
        bytes32 conduitKey = _useConduit ? conduitKeyOne : bytes32(0);

        test1155_1.mint(alice, _id, _amount);
        OfferItem[] memory offerItem = singleOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            _id,
            _amount,
            _amount
        );
        
        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            3
        );
        considerationItems[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethAmts[0]),
            uint256(_ethAmts[0]),
            payable(alice)
        );
        considerationItems[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethAmts[1]),
            uint256(_ethAmts[1]),
            payable(_zone) // TODO: should we fuzz on zone? do royalties get paid to zone??
        );
        considerationItems[2] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethAmts[2]),
            uint256(_ethAmts[2]),
            payable(cal)
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            _zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            _zoneHash,
            _salt,
            conduitKey,
            consideration.getNonce(alice)
        );
        bytes memory signature = signOrder(
            alicePk,
            consideration.getOrderHash(orderComponents)
        );
        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            _zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            _zoneHash,
            _salt,
            conduitKey,
            considerationItems.length
        );
        consideration.fulfillOrder{
            value: _ethAmts[0] + _ethAmts[1] + _ethAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    function testFailSingleERC721NonPayableZone() public {
        // fuzzer completely ignores params that fail vm.assume,
        // so confirm that this invalid param does fail
        testSingleERC721(
            address(test721_1),
            11091106379292436006407652670679179902088932118277811194146176427645468672,
            0x00000000000000000000000000000000000657137d140ac73d37f3c9267132fd,
            11737039766497076565,
            [
                1329227995784915872903807060280344576,
                2941925602480186165443492,
                276220320249354716809723209050602608289
            ],
            false
        );
    }

    function getMaxConsiderationValue(
        ConsiderationItem[] memory considerationItems
    ) internal pure returns (uint256) {
        uint256 value = 0;
        for (uint256 i = 0; i < considerationItems.length; i++) {
            uint256 amount = considerationItems[i].startAmount >
                considerationItems[i].endAmount
                ? considerationItems[i].startAmount
                : considerationItems[i].endAmount;
            value += amount;
        }
        return value;
    }
}
