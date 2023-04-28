// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { LibSort } from "solady/src/utils/LibSort.sol";

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

struct HashCount {
    bytes32 hash;
    uint256 count;
}

struct ItemReferenceGroup {
    bytes32 hash;
    ItemReference[] references;
    uint256 assigned;
}

library FulfillmentLib {
    using LibPRNG for LibPRNG.PRNG;
    using LibSort for uint256[];

    function getItemReferences(
        OrderDetails[] memory orderDetails
    ) internal pure returns (ItemReference[] memory) {
        ItemReference[] memory itemReferences = new ItemReference[](
            getTotalItems(orderDetails)
        );

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

        return itemReferences;
    }

    function bundleByAggregatable(
        ItemReference[] memory itemReferences
    ) internal pure returns (ItemReferenceGroup[] memory) {
        ItemReferenceGroup[] memory group = allocateItemReferenceGroup(
            getUniqueFullHashes(itemReferences)
        );
    }

    function bundleByMatchable(
        ItemReference[] memory itemReferences
    ) internal pure returns (ItemReferenceGroup[] memory) {
        ItemReferenceGroup[] memory group = allocateItemReferenceGroup(
            getUniqueDataHashes(itemReferences)
        );
    }

    function allocateItemReferenceGroup(
        HashCount[] memory hashCount
    ) internal pure returns (ItemReferenceGroup[] memory) {
        ItemReferenceGroup[] memory group = new ItemReferenceGroup[](
            hashCount.length
        );

        for (uint256 i = 0; i < hashCount.length; ++i) {
            group[i] = ItemReferenceGroup({
                hash: hashCount[i].hash,
                references: new ItemReference[](hashCount[i].count),
                assigned: 0
            });
        }

        return group;
    }

    function getUniqueFullHashes(
        ItemReference[] memory itemReferences
    ) internal pure returns (HashCount[] memory) {
        uint256[] memory fullHashes = new uint256[](itemReferences.length);

        for (uint256 i = 0; i < itemReferences.length; ++i) {
            fullHashes[i] = uint256(itemReferences[i].fullHash);
        }

        return getHashCount(fullHashes);
    }

    function getUniqueDataHashes(
        ItemReference[] memory itemReferences
    ) internal pure returns (HashCount[] memory) {
        uint256[] memory dataHashes = new uint256[](itemReferences.length);

        for (uint256 i = 0; i < itemReferences.length; ++i) {
            dataHashes[i] = uint256(itemReferences[i].dataHash);
        }

        return getHashCount(dataHashes);
    }

    function getHashCount(
        uint256[] memory hashes
    ) internal pure returns (HashCount[] memory) {
        if (hashes.length == 0) {
            return new HashCount[](0);
        }

        hashes.sort();

        HashCount[] memory hashCount = new HashCount[](hashes.length);
        hashCount[0] = HashCount({ hash: bytes32(hashes[0]), count: 1 });

        uint256 hashCountPointer = 0;
        for (uint256 i = 1; i < hashes.length; ++i) {
            bytes32 element = bytes32(hashes[i]);

            if (element != hashCount[hashCountPointer].hash) {
                hashCount[++hashCountPointer] = HashCount({
                    hash: element,
                    count: 1
                });
            } else {
                ++hashCount[hashCountPointer].count;
            }
        }

        // update length of the hashCount array.
        assembly {
            mstore(hashCount, hashCountPointer)
        }

        return hashCount;
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

    function shuffleItemReferences(
        ItemReference[] memory itemReferences,
        uint256 seed
    ) internal pure returns (ItemReference[] memory) {
        ItemReference[] memory shuffledItemReferences = new ItemReference[](
            itemReferences.length
        );

        uint256[] memory indices = new uint256[](itemReferences.length);
        for (uint256 i = 0; i < indices.length; ++i) {
            indices[i] = i;
        }

        LibPRNG.PRNG memory prng;
        prng.seed(seed);
        prng.shuffle(indices);

        for (uint256 i = 0; i < indices.length; ++i) {
            shuffledItemReferences[i] = copy(itemReferences[indices[i]]);
        }

        return shuffledItemReferences;
    }

    function copy(
        ItemReference memory itemReference
    ) internal pure returns (ItemReference memory) {
        return
            ItemReference({
                orderIndex: itemReference.orderIndex,
                itemIndex: itemReference.itemIndex,
                side: itemReference.side,
                dataHash: itemReference.dataHash,
                fullHash: itemReference.fullHash,
                amount: itemReference.amount,
                is721: itemReference.is721
            });
    }
}
