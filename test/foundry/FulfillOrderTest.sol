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
    struct EthToERC721Struct {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] ethAmts;
        bool useConduit;
    }

    function testFulfillOrderEthToERC721(
        EthToERC721Struct memory _ethToERC721Struct
    ) public {
        _testFulfillOrderEthToERC721(consideration, _ethToERC721Struct);
        _testFulfillOrderEthToERC721(
            Consideration(address(referenceConsideration)),
            _ethToERC721Struct
        );
    }

    function _testFulfillOrderEthToERC721(
        Consideration _consideration,
        EthToERC721Struct memory _ethToERC721
    ) public onlyPayable(_ethToERC721.zone) topUp {
        vm.assume(
            _ethToERC721.ethAmts[0] > 0 &&
                _ethToERC721.ethAmts[1] > 0 &&
                _ethToERC721.ethAmts[2] > 0
        );
        vm.assume(
            uint256(_ethToERC721.ethAmts[0]) +
                uint256(_ethToERC721.ethAmts[1]) +
                uint256(_ethToERC721.ethAmts[2]) <=
                2**128 - 1
        );
        bytes32 conduitKey = _ethToERC721.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, _ethToERC721.id);
        OfferItem[] memory offerItem = singleOfferItem(
            ItemType.ERC721,
            address(test721_1),
            _ethToERC721.id,
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
            uint256(_ethToERC721.ethAmts[0]),
            uint256(_ethToERC721.ethAmts[0]),
            payable(alice)
        );
        considerationItems[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethToERC721.ethAmts[1]),
            uint256(_ethToERC721.ethAmts[1]),
            payable(_ethToERC721.zone) // TODO: should we fuzz on zone? do royalties get paid to zone??
        );
        considerationItems[2] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethToERC721.ethAmts[2]),
            uint256(_ethToERC721.ethAmts[2]),
            payable(cal)
        );

        OrderComponents memory orderComponents = OrderComponents(
            alice,
            _ethToERC721.zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            _ethToERC721.zoneHash,
            _ethToERC721.salt,
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
            _ethToERC721.zone,
            offerItem,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            _ethToERC721.zoneHash,
            _ethToERC721.salt,
            conduitKey,
            considerationItems.length
        );
        _consideration.fulfillOrder{
            value: _ethToERC721.ethAmts[0] +
                _ethToERC721.ethAmts[1] +
                _ethToERC721.ethAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    struct EthToERC1155Struct {
        address zone;
        uint256 id;
        uint256 amount;
        bytes32 zoneHash;
        uint256 salt;
        uint128[3] ethAmts;
        bool useConduit;
    }

    function testFulfillOrderEthToERC1155(
        EthToERC1155Struct memory _ethToERC1155Struct
    ) public {
        _testFulfillOrderEthToERC1155(consideration, _ethToERC1155Struct);
        _testFulfillOrderEthToERC1155(
            Consideration(address(referenceConsideration)),
            _ethToERC1155Struct
        );
    }

    function _testFulfillOrderEthToERC1155(
        Consideration _consideration,
        EthToERC1155Struct memory _ethToERC1155
    ) public onlyPayable(_ethToERC1155.zone) topUp {
        vm.assume(_ethToERC1155.amount > 0);
        vm.assume(
            _ethToERC1155.ethAmts[0] > 0 &&
                _ethToERC1155.ethAmts[1] > 0 &&
                _ethToERC1155.ethAmts[2] > 0
        );
        vm.assume(
            uint256(_ethToERC1155.ethAmts[0]) +
                uint256(_ethToERC1155.ethAmts[1]) +
                uint256(_ethToERC1155.ethAmts[2]) <=
                2**128 - 1
        );
        bytes32 conduitKey = _ethToERC1155.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, _ethToERC1155.id, _ethToERC1155.amount);
        OfferItem[] memory offerItem = singleOfferItem(
            ItemType.ERC1155,
            address(test1155_1),
            _ethToERC1155.id,
            _ethToERC1155.amount,
            _ethToERC1155.amount
        );

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            3
        );
        considerationItems[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethToERC1155.ethAmts[0]),
            uint256(_ethToERC1155.ethAmts[0]),
            payable(alice)
        );
        considerationItems[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethToERC1155.ethAmts[1]),
            uint256(_ethToERC1155.ethAmts[1]),
            payable(_ethToERC1155.zone) // TODO: should we fuzz on zone? do royalties get paid to zone??
        );
        considerationItems[2] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            uint256(_ethToERC1155.ethAmts[2]),
            uint256(_ethToERC1155.ethAmts[2]),
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
<<<<<<< HEAD
            consideration,
=======
            _consideration,
>>>>>>> f71f62e (modified test functions to take in structs)
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
            value: _ethToERC1155.ethAmts[0] +
                _ethToERC1155.ethAmts[1] +
                _ethToERC1155.ethAmts[2]
        }(Order(orderParameters, signature), conduitKey);
    }

    // function _testFulfillOrderERC20ToERC1155(
    //     Consideration _consideration,
    //     address _zone,
    //     uint256 _id,
    //     uint256 _amount,
    //     bytes32 _zoneHash,
    //     uint256 _salt,
    //     uint128[3] memory _erc20Amts,
    //     bool _useConduit
    // ) public onlyPayble(_zone) topUp {}

    // function testFailSingleERC721NonPayableZone() public {
    //     // fuzzer completely ignores params that fail vm.assume,
    //     // so confirm that this invalid param does fail
    //     testSingleERC721(
    //         consideration,
    //         address(test721_1),
    //         11091106379292436006407652670679179902088932118277811194146176427645468672,
    //         0x00000000000000000000000000000000000657137d140ac73d37f3c9267132fd,
    //         11737039766497076565,
    //         [
    //             1329227995784915872903807060280344576,
    //             2941925602480186165443492,
    //             276220320249354716809723209050602608289
    //         ],
    //         false
    //     );
    // }

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
