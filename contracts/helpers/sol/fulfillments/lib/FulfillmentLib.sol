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

enum ItemCategory {
    NATIVE,
    ERC721,
    OTHER
}

struct FulfillmentItem {
    uint256 orderIndex;
    uint256 itemIndex;
    uint256 amount;
    address account;
}

struct FulfillmentItems {
    ItemCategory itemCategory;
    uint256 totalAmount;
    FulfillmentItem[] items;
}

struct DualFulfillmentItems {
    FulfillmentItems[] offer;
    FulfillmentItems[] consideration;
}

struct FulfillAvailableDetails {
    DualFulfillmentItems items;
    address caller;
    address recipient;
}

struct MatchDetails {
    DualFulfillmentItems[] items;
    address recipient;
}

library FulfillmentPrepLib {
    using LibPRNG for LibPRNG.PRNG;
    using LibSort for uint256[];

    struct ItemReference {
        uint256 orderIndex;
        uint256 itemIndex;
        Side side;
        bytes32 dataHash; // itemType ++ token ++ identifier
        bytes32 fullHash; // dataHash ++ [offerer ++ conduitKey || recipient]
        uint256 amount;
        ItemCategory itemCategory;
        address account;
    }

    struct HashCount {
        bytes32 hash;
        uint256 count;
    }

    struct ItemReferenceGroup {
        bytes32 fullHash;
        ItemReference[] references;
        uint256 assigned;
    }

    struct MatchableItemReferenceGroup {
        bytes32 dataHash;
        ItemReferenceGroup[] offerGroups;
        ItemReferenceGroup[] considerationGroups;
        uint256 offerAssigned;
        uint256 considerationAssigned;
    }

    function getFulfillAvailableDetails(
        OrderDetails[] memory orderDetails,
        address recipient,
        address caller,
        uint256 seed
    ) internal pure returns (FulfillAvailableDetails memory) {
        (
            ItemReferenceGroup[] memory offerGroups,
            ItemReferenceGroup[] memory considerationGroups
        ) = splitBySide(
                bundleByAggregatable(getItemReferences(orderDetails, seed))
            );

        return
            getFulfillAvailableDetailsFromGroups(
                offerGroups,
                considerationGroups,
                recipient,
                caller
            );
    }

    function getMatchDetails(
        OrderDetails[] memory orderDetails,
        address recipient,
        uint256 seed
    ) internal pure returns (MatchDetails memory) {
        ItemReference[] memory itemReferences = getItemReferences(
            orderDetails,
            seed
        );

        return
            getMatchDetailsFromGroups(
                bundleByMatchable(
                    itemReferences,
                    bundleByAggregatable(itemReferences)
                ),
                recipient
            );
    }

    function getItemReferences(
        OrderDetails[] memory orderDetails,
        uint256 seed
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

        if (seed == 0) {
            return itemReferences;
        }

        return shuffleItemReferences(itemReferences, seed);
    }

    function bundleByAggregatable(
        ItemReference[] memory itemReferences
    ) internal pure returns (ItemReferenceGroup[] memory) {
        ItemReferenceGroup[] memory groups = allocateItemReferenceGroup(
            getUniqueFullHashes(itemReferences)
        );

        for (uint256 i = 0; i < itemReferences.length; ++i) {
            ItemReference memory itemReference = itemReferences[i];
            for (uint256 j = 0; j < groups.length; ++j) {
                ItemReferenceGroup memory group = groups[j];
                if (group.fullHash == itemReference.fullHash) {
                    group.references[group.assigned++] = itemReference;
                    break;
                }
            }
        }

        // Sanity check: ensure at least one reference item on each group
        for (uint256 i = 0; i < groups.length; ++i) {
            if (groups[i].references.length == 0) {
                revert("FulfillmentPrepLib: missing item reference in group");
            }
        }

        return groups;
    }

    function splitBySide(
        ItemReferenceGroup[] memory groups
    )
        internal
        pure
        returns (ItemReferenceGroup[] memory, ItemReferenceGroup[] memory)
    {
        // NOTE: lengths are overallocated; reduce after assignment.
        ItemReferenceGroup[] memory offerGroups = (
            new ItemReferenceGroup[](groups.length)
        );
        ItemReferenceGroup[] memory considerationGroups = (
            new ItemReferenceGroup[](groups.length)
        );
        uint256 offerItems = 0;
        uint256 considerationItems = 0;

        for (uint256 i = 0; i < groups.length; ++i) {
            ItemReferenceGroup memory group = groups[i];
            Side side = group.references[0].side;

            if (side == Side.OFFER) {
                offerGroups[offerItems++] = copy(group);
            } else if (side == Side.CONSIDERATION) {
                considerationGroups[considerationItems++] = copy(group);
            } else {
                revert("FulfillmentPrepLib: invalid side located (split)");
            }
        }

        // Reduce group lengths based on number of elements assigned.
        assembly {
            mstore(offerGroups, offerItems)
            mstore(considerationGroups, considerationItems)
        }

        return (offerGroups, considerationGroups);
    }

    function getFulfillAvailableDetailsFromGroups(
        ItemReferenceGroup[] memory offerGroups,
        ItemReferenceGroup[] memory considerationGroups,
        address recipient,
        address caller
    ) internal pure returns (FulfillAvailableDetails memory) {
        DualFulfillmentItems memory items = getDualFulfillmentItems(
            offerGroups,
            considerationGroups
        );

        return
            FulfillAvailableDetails({
                items: items,
                caller: caller,
                recipient: recipient
            });
    }

    function getMatchDetailsFromGroups(
        MatchableItemReferenceGroup[] memory matchableGroups,
        address recipient
    ) internal pure returns (MatchDetails memory) {
        DualFulfillmentItems[] memory items = new DualFulfillmentItems[](
            matchableGroups.length
        );

        for (uint256 i = 0; i < matchableGroups.length; ++i) {
            MatchableItemReferenceGroup memory matchableGroup = (
                matchableGroups[i]
            );

            items[i] = getDualFulfillmentItems(
                matchableGroup.offerGroups,
                matchableGroup.considerationGroups
            );
        }

        return MatchDetails({ items: items, recipient: recipient });
    }

    function getDualFulfillmentItems(
        ItemReferenceGroup[] memory offerGroups,
        ItemReferenceGroup[] memory considerationGroups
    ) internal pure returns (DualFulfillmentItems memory) {
        DualFulfillmentItems memory items = DualFulfillmentItems({
            offer: new FulfillmentItems[](offerGroups.length),
            consideration: new FulfillmentItems[](considerationGroups.length)
        });

        for (uint256 i = 0; i < offerGroups.length; ++i) {
            items.offer[i] = getFulfillmentItems(offerGroups[i].references);
        }

        for (uint256 i = 0; i < considerationGroups.length; ++i) {
            items.consideration[i] = getFulfillmentItems(
                considerationGroups[i].references
            );
        }

        return items;
    }

    function getFulfillmentItems(
        ItemReference[] memory itemReferences
    ) internal pure returns (FulfillmentItems memory) {
        // Sanity check: ensure there's at least one reference
        if (itemReferences.length == 0) {
            revert("FulfillmentPrepLib: empty item references supplied");
        }

        ItemReference memory firstReference = itemReferences[0];
        FulfillmentItems memory fulfillmentItems = FulfillmentItems({
            itemCategory: firstReference.itemCategory,
            totalAmount: 0,
            items: new FulfillmentItem[](itemReferences.length)
        });

        for (uint256 i = 0; i < itemReferences.length; ++i) {
            ItemReference memory itemReference = itemReferences[i];
            uint256 amount = itemReference.amount;
            fulfillmentItems.totalAmount += amount;
            fulfillmentItems.items[i] = FulfillmentItem({
                orderIndex: itemReference.orderIndex,
                itemIndex: itemReference.itemIndex,
                amount: amount,
                account: itemReference.account
            });
        }

        return fulfillmentItems;
    }

    function bundleByMatchable(
        ItemReference[] memory itemReferences,
        ItemReferenceGroup[] memory groups
    ) internal pure returns (MatchableItemReferenceGroup[] memory) {
        MatchableItemReferenceGroup[] memory matchableGroups = (
            allocateMatchableItemReferenceGroup(
                getUniqueDataHashes(itemReferences)
            )
        );

        for (uint256 i = 0; i < groups.length; ++i) {
            ItemReferenceGroup memory group = groups[i];
            ItemReference memory firstReference = group.references[0];
            for (uint256 j = 0; j < matchableGroups.length; ++j) {
                MatchableItemReferenceGroup memory matchableGroup = (
                    matchableGroups[j]
                );

                if (matchableGroup.dataHash == firstReference.dataHash) {
                    if (firstReference.side == Side.OFFER) {
                        matchableGroup.offerGroups[
                            matchableGroup.offerAssigned++
                        ] = copy(group);
                    } else if (firstReference.side == Side.CONSIDERATION) {
                        matchableGroup.considerationGroups[
                            matchableGroup.considerationAssigned++
                        ] = copy(group);
                    } else {
                        revert(
                            "FulfillmentPrepLib: invalid side located (match)"
                        );
                    }

                    break;
                }
            }
        }

        // Reduce reference group array lengths based on assigned elements.
        for (uint256 i = 0; i < matchableGroups.length; ++i) {
            MatchableItemReferenceGroup memory group = matchableGroups[i];
            uint256 offerAssigned = group.offerAssigned;
            uint256 considerationAssigned = group.considerationAssigned;
            ItemReferenceGroup[] memory offerGroups = (group.offerGroups);
            ItemReferenceGroup[] memory considerationGroups = (
                group.considerationGroups
            );

            assembly {
                mstore(offerGroups, offerAssigned)
                mstore(considerationGroups, considerationAssigned)
            }
        }

        return matchableGroups;
    }

    function allocateItemReferenceGroup(
        HashCount[] memory hashCount
    ) internal pure returns (ItemReferenceGroup[] memory) {
        ItemReferenceGroup[] memory group = new ItemReferenceGroup[](
            hashCount.length
        );

        for (uint256 i = 0; i < hashCount.length; ++i) {
            group[i] = ItemReferenceGroup({
                fullHash: hashCount[i].hash,
                references: new ItemReference[](hashCount[i].count),
                assigned: 0
            });
        }

        return group;
    }

    function allocateMatchableItemReferenceGroup(
        HashCount[] memory hashCount
    ) internal pure returns (MatchableItemReferenceGroup[] memory) {
        MatchableItemReferenceGroup[] memory group = (
            new MatchableItemReferenceGroup[](hashCount.length)
        );

        for (uint256 i = 0; i < hashCount.length; ++i) {
            // NOTE: reference group lengths are overallocated and will need to
            // be reduced once their respective elements have been assigned.
            uint256 count = hashCount[i].count;
            group[i] = MatchableItemReferenceGroup({
                dataHash: hashCount[i].hash,
                offerGroups: new ItemReferenceGroup[](count),
                considerationGroups: new ItemReferenceGroup[](count),
                offerAssigned: 0,
                considerationAssigned: 0
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
        return
            getItemReference(
                orderIndex,
                itemIndex,
                Side.OFFER,
                item.itemType,
                item.token,
                item.identifier,
                offerer,
                conduitKey,
                item.amount
            );
    }

    function getItemReference(
        uint256 orderIndex,
        uint256 itemIndex,
        ReceivedItem memory item
    ) internal pure returns (ItemReference memory) {
        return
            getItemReference(
                orderIndex,
                itemIndex,
                Side.CONSIDERATION,
                item.itemType,
                item.token,
                item.identifier,
                item.recipient,
                bytes32(0),
                item.amount
            );
    }

    function getItemReference(
        uint256 orderIndex,
        uint256 itemIndex,
        Side side,
        ItemType itemType,
        address token,
        uint256 identifier,
        address account,
        bytes32 conduitKey,
        uint256 amount
    ) internal pure returns (ItemReference memory) {
        bytes32 dataHash = keccak256(
            abi.encodePacked(itemType, token, identifier)
        );

        bytes32 fullHash;
        if (side == Side.OFFER) {
            fullHash = keccak256(
                abi.encodePacked(dataHash, account, conduitKey)
            );
        } else if (side == Side.CONSIDERATION) {
            fullHash = keccak256(abi.encodePacked(dataHash, account));
        } else {
            revert("FulfillmentPrepLib: invalid side located (get reference)");
        }

        ItemCategory itemCategory;
        if (itemType == ItemType.NATIVE) {
            itemCategory = ItemCategory.NATIVE;
        } else if (itemType == ItemType.ERC721) {
            itemCategory = ItemCategory.ERC721;
        } else if (itemType == ItemType.ERC20 || itemType == ItemType.ERC1155) {
            itemCategory = ItemCategory.OTHER;
        } else {
            revert("FulfillmentPrepLib: invalid item type located");
        }

        return
            ItemReference({
                orderIndex: orderIndex,
                itemIndex: itemIndex,
                side: side,
                dataHash: dataHash,
                fullHash: fullHash,
                amount: amount,
                itemCategory: itemCategory,
                account: account
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
                itemCategory: itemReference.itemCategory,
                account: itemReference.account
            });
    }

    function copy(
        ItemReference[] memory itemReferences
    ) internal pure returns (ItemReference[] memory) {
        ItemReference[] memory copiedReferences = new ItemReference[](
            itemReferences.length
        );

        for (uint256 i = 0; i < itemReferences.length; ++i) {
            copiedReferences[i] = copy(itemReferences[i]);
        }

        return copiedReferences;
    }

    function copy(
        ItemReferenceGroup memory group
    ) internal pure returns (ItemReferenceGroup memory) {
        return
            ItemReferenceGroup({
                fullHash: group.fullHash,
                references: copy(group.references),
                assigned: group.assigned
            });
    }
}
