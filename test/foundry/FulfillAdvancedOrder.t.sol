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

contract FulfillAdvancedOrder is BaseOrderTest {
    struct TestAdvancedOrder {
        uint256 tokenId;
        address zone;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] ethAmts;
        bool useConduit;
    }

    /**
     * TODO: actually test advanced :)
     */
    function testAdvancedSingleERC721(
        TestAdvancedOrder memory testAdvancedOrder
    ) public {
        vm.record();
        _advancedSingleERC721(consideration, testAdvancedOrder);
        _resetTokensAndEthForTestAccounts();
        _advancedSingleERC721(
            Consideration(address(referenceConsideration)),
            testAdvancedOrder
        );
    }

    function _advancedSingleERC721(
        Consideration _consideration,
        TestAdvancedOrder memory testAdvancedOrder
    ) internal onlyPayable(testAdvancedOrder.zone) topUp {
        vm.assume(
            testAdvancedOrder.ethAmts[0] > 0 &&
                testAdvancedOrder.ethAmts[1] > 0 &&
                testAdvancedOrder.ethAmts[2] > 0
        );
        vm.assume(
            uint256(testAdvancedOrder.ethAmts[0]) +
                uint256(testAdvancedOrder.ethAmts[1]) +
                uint256(testAdvancedOrder.ethAmts[2]) <=
                2**128 - 1
        );

        // require(testAdvancedOrder.salt != 5, "bad");
        bytes32 conduitKey = testAdvancedOrder.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, testAdvancedOrder.tokenId);
        OfferItem[] memory offerItem = singleOfferItem(
            ItemType.ERC721,
            address(test721_1),
            testAdvancedOrder.tokenId,
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
            uint256(testAdvancedOrder.ethAmts[0]),
            uint256(testAdvancedOrder.ethAmts[0]),
            payable(alice)
        );
        considerationItems[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(testAdvancedOrder.ethAmts[1]),
            uint256(testAdvancedOrder.ethAmts[1]),
            payable(testAdvancedOrder.zone) // TODO: should we fuzz on zone? do royalties get paid to zone??
        );
        considerationItems[2] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(testAdvancedOrder.ethAmts[2]),
            uint256(testAdvancedOrder.ethAmts[2]),
            payable(cal)
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            testAdvancedOrder.zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            testAdvancedOrder.zoneHash,
            testAdvancedOrder.salt,
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
            testAdvancedOrder.zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            testAdvancedOrder.zoneHash,
            testAdvancedOrder.salt,
            conduitKey,
            considerationItems.length
        );
        _consideration.fulfillOrder{
            value: testAdvancedOrder.ethAmts[0] +
                testAdvancedOrder.ethAmts[1] +
                testAdvancedOrder.ethAmts[2]
        }(Order(orderParameters, signature), conduitKey);
        emit log_named_uint(
            "ending balance of this",
            test721_1.balanceOf(address(this))
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
