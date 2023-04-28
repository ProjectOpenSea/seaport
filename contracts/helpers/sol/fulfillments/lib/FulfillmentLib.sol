// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    FulfillmentComponent,
    Fulfillment,
    Order,
    AdvancedOrder,
    OrderParameters,
    SpentItem,
    ReceivedItem,
    CriteriaResolver
} from "../../SeaportStructs.sol";

import { ItemType, Side } from "../../SeaportEnums.sol";

import { OrderDetails } from "./Structs.sol";

struct ItemReference {
    uint256 orderIndex;
    uint256 itemIndex;
    Side side;
    bytes32 dataHash; // itemType ++ token ++ identifier
    bytes32 fullHash; // dataHash ++ [offerer ++ conduitKey || recipient]
    uint256 amount;
    bool is721;
}

library FulfillmentLib {
    function getItemReferences(
        OrderDetails[] memory orderDetails
    ) internal pure returns (ItemReference[] memory itemReferences) {
        itemReferences = new ItemReference[](getTotalItems(orderDetails));

        uint256 itemReferenceIndex = 0;

        for (
            uint256 orderIndex = 0;
            orderIndex < orderDetails.length;
            ++orderIndex
        ) {
            OrderDetails memory order = orderDetails[orderIndex];
            for (
                uint256 itemIndex = 0;
                itemIndex < order.offer.length;
                ++itemIndex
            ) {
                itemReferences[itemReferenceIndex++] = getItemReference(
                    orderIndex,
                    itemIndex,
                    order.offerer,
                    order.conduitKey,
                    order.offer[itemIndex]
                );
            }
            for (
                uint256 itemIndex = 0;
                itemIndex < order.consideration.length;
                ++itemIndex
            ) {
                itemReferences[itemReferenceIndex++] = getItemReference(
                    orderIndex,
                    itemIndex,
                    order.consideration[itemIndex]
                );
            }
        }
    }

    function getTotalItems(
        OrderDetails[] memory orderDetails
    ) internal pure returns (uint256) {
        uint256 totalItems = 0;

        for (uint256 i = 0; i < orderDetails.length; ++i) {
            totalItems += getTotalItems(orderDetails[i]);
        }

        return totalItems;
    }

    function getTotalItems(
        OrderDetails memory order
    ) internal pure returns (uint256) {
        return (order.offer.length + order.consideration.length);
    }

    function getItemReference(
        uint256 orderIndex,
        uint256 itemIndex,
        address offerer,
        bytes32 conduitKey,
        SpentItem memory item
    ) internal pure returns (ItemReference memory) {
        bytes32 dataHash = keccak256(
            abi.encodePacked(item.itemType, item.token, item.identifier)
        );

        bytes32 fullHash = keccak256(
            abi.encodePacked(dataHash, offerer, conduitKey)
        );

        return
            ItemReference({
                orderIndex: orderIndex,
                itemIndex: itemIndex,
                side: Side.OFFER,
                dataHash: dataHash,
                fullHash: fullHash,
                amount: item.amount,
                is721: item.itemType == ItemType.ERC721
            });
    }

    function getItemReference(
        uint256 orderIndex,
        uint256 itemIndex,
        ReceivedItem memory item
    ) internal pure returns (ItemReference memory) {
        bytes32 dataHash = keccak256(
            abi.encodePacked(item.itemType, item.token, item.identifier)
        );

        bytes32 fullHash = keccak256(
            abi.encodePacked(dataHash, item.recipient)
        );

        return
            ItemReference({
                orderIndex: orderIndex,
                itemIndex: itemIndex,
                side: Side.CONSIDERATION,
                dataHash: dataHash,
                fullHash: fullHash,
                amount: item.amount,
                is721: item.itemType == ItemType.ERC721
            });
    }
}
