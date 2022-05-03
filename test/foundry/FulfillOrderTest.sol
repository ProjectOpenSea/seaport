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
        uint128 _ethAmt1,
        uint128 _ethAmt2,
        uint128 _ethAmt3,
        bool _useConduit
    ) public {
        vm.assume(_ethAmt1 > 0 && _ethAmt2 > 0 && _ethAmt3 > 0);
        vm.assume(
            uint256(_ethAmt1) + uint256(_ethAmt2) + uint256(_ethAmt3) <=
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
            uint256(_ethAmt1),
            uint256(_ethAmt1),
            payable(alice)
        );
        considerationItems[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethAmt2),
            uint256(_ethAmt2),
            payable(_zone)
        );
        considerationItems[2] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethAmt3),
            uint256(_ethAmt3),
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
        Order memory order = Order(orderParameters, signature);
        uint256 sum = _ethAmt1 + _ethAmt2 + _ethAmt3;
        consideration.fulfillOrder{ value: sum }(order, conduitKey);
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
