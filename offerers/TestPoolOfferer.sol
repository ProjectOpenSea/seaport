// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    ERC20Interface,
    ERC721Interface
} from "seaport/interfaces/AbridgedTokenInterfaces.sol";

import { ContractOffererInterface } from
    "seaport/interfaces/ContractOffererInterface.sol";

import { ItemType } from "seaport/lib/ConsiderationEnums.sol";

import {
    SpentItem,
    ReceivedItem,
    InventoryUpdate
} from "seaport/lib/ConsiderationStructs.sol";
import { EnumerableSet } from
    "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { IERC721 } from
    "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract TestPoolOfferer is ContractOffererInterface, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    error OnlySeaport();
    error NotImplemented();
    error InvalidItemType();
    error InvalidToken();
    error InvalidTokenId(uint256 id);

    address immutable _SEAPORT;
    address immutable erc721;
    EnumerableSet.UintSet tokenIds;
    address immutable erc20;
    uint256 balance;
    uint256 immutable k;
    uint256 constant scale = 10_000;

    constructor(
        address seaport,
        address _erc721,
        uint256[] memory _tokenIds,
        address _erc20,
        uint256 amount,
        address initialOwner
    ) {
        // Set immutable values and storage variables.
        _SEAPORT = seaport;
        erc721 = _erc721;
        for (uint256 i; i < _tokenIds.length; i++) {
            tokenIds.add(_tokenIds[i]);
        }
        // tokenIds = _tokenIds;
        erc20 = _erc20;
        balance = amount;
        k = amount * scale * _tokenIds.length;

        IERC20(erc20).approve(seaport, type(uint256).max);
        IERC721(erc721).setApprovalForAll(seaport, true);
    }

    function generateOrder(
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // only Seaport may call this function
        if (msg.sender != _SEAPORT) {
            revert OnlySeaport();
        }
        // if true, this offerer is spending NFTs and receiving ERC20
        bool nftOffer;
        uint256 newBalance;
        (offer, consideration, newBalance, nftOffer) =
            _generateOfferAndConsideration(minimumReceived, maximumSpent);

        // update token ids and balances
        // note that no tokens will actually be exchanged until Seaport executes fulfillments
        if (nftOffer) {
            // remove outgoing tokenIDs from pool and assign concrete IDs to any criteria-based "wildcard" erc721 items
            _processNftOffer(offer);
        } else {
            // add incoming NFT ids to pool
            _processNftConsideration(consideration);
        }
        // update internal erc20 balance
        balance = newBalance;
    }

    function previewOrder(
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata
    )
        external
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        bool nftOffer;
        (offer, consideration,, nftOffer) =
            _generateOfferAndConsideration(minimumReceived, maximumSpent);
        if (nftOffer) _previewNftOffer(offer);
    }

    function getInventory()
        external
        pure
        override
        returns (SpentItem[] memory, SpentItem[] memory)
    {
        revert NotImplemented();
    }

    /// @dev add incoming tokens to the set of IDs in the pool
    function _processNftConsideration(ReceivedItem[] memory maximumSpent)
        internal
    {
        for (uint256 i = 0; i < maximumSpent.length; i++) {
            ReceivedItem memory maximumSpentItem = maximumSpent[i];
            bool added = tokenIds.add(maximumSpentItem.identifier);
            // if a token was not added it means that it was already in the pool
            if (!added) {
                revert InvalidTokenId(maximumSpentItem.identifier);
            }
        }
    }

    /// @dev remove outgoing tokens from the set of IDs in the pool
    function _processNftOffer(SpentItem[] memory minimumReceived) internal {
        // uint256 criteriaIndex;
        for (uint256 i = 0; i < minimumReceived.length; i++) {
            SpentItem memory minimumReceivedItem = minimumReceived[i];
            uint256 identifier;
            if (minimumReceivedItem.itemType == ItemType.ERC721) {
                identifier = minimumReceivedItem.identifier;
            } else {
                // for wildcard tokens, always pick the token ID in the first position of the set
                identifier = tokenIds.at(0);
                minimumReceivedItem.itemType = ItemType.ERC721;
                minimumReceivedItem.identifier = identifier;
                // ++criteriaIndex;
            }
            bool removed = tokenIds.remove(identifier);
            // if a token was not removed it means that the token is not or is no longer in the pool
            // note that criteria-based "wildcard" items should follow concrete items in the offer array
            // to avoid circumstances where the offerer tries to spend the same ID twice
            if (!removed) {
                revert InvalidTokenId(identifier);
            }
        }
    }

    function _previewNftOffer(SpentItem[] memory minimumReceived)
        internal
        view
    {
        uint256 criteriaIndex;
        for (uint256 i = 0; i < minimumReceived.length; i++) {
            SpentItem memory minimumReceivedItem = minimumReceived[i];
            // assign concrete IDs to any criteria-based "wildcard" erc721 items
            if (minimumReceivedItem.itemType == ItemType.ERC721_WITH_CRITERIA) {
                // pick the next token ID in the set, starting at index 0
                minimumReceivedItem.itemType = ItemType.ERC721;
                minimumReceivedItem.identifier = tokenIds.at(criteriaIndex);
                ++criteriaIndex;
            }
        }
    }

    /// @dev generate offer and consideration items based on the number of ERC721 tokens offered or requested
    function _generateOfferAndConsideration(
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent
    )
        internal
        view
        returns (
            SpentItem[] memory offer,
            ReceivedItem[] memory consideration,
            uint256 newBalance,
            bool nftOffer
        )
    {
        // validate that all tokenns in each set are "homogenous" (ERC20 or ERC721/_WITH_CRITERIA)
        _validateSpentItems(minimumReceived, true);
        _validateSpentItems(maximumSpent, false);

        // if fulfiller is spending ERC20 tokens, calculate how much is needed for the number of tokens specified
        // in minimumReceived
        if (maximumSpent[0].itemType == ItemType.ERC20) {
            uint256 newNumTokens = tokenIds.length() - minimumReceived.length;
            newBalance = k / (scale * newNumTokens);
            uint256 considerationAmount = newBalance - balance;
            consideration = new ReceivedItem[](1);
            consideration[0] = ReceivedItem({
                itemType: ItemType.ERC20,
                token: erc20,
                identifier: 0,
                amount: considerationAmount,
                recipient: payable(address(this))
            });
            offer = minimumReceived;
            nftOffer = true;
        } else {
            // otherwise, if fulfiller is spending ERC721 tokens, calculate the amount of ERC20 tokens to pay for
            // N items
            uint256 newNumTokens = tokenIds.length() + maximumSpent.length;
            newBalance = k / (scale * newNumTokens);
            uint256 paymentAmount = balance - newBalance;
            offer = new SpentItem[](1);
            offer[0] = SpentItem({
                itemType: ItemType.ERC20,
                token: erc20,
                identifier: 0,
                amount: paymentAmount
            });
            consideration = _convertSpentErc721sToReceivedItems(maximumSpent);
        }
    }

    function _validateSpentItems(
        SpentItem[] calldata minimumReceived,
        bool offer
    ) internal view {
        ItemType homogenousType = minimumReceived[0].itemType;
        if (homogenousType == ItemType.ERC721_WITH_CRITERIA) {
            homogenousType = ItemType.ERC721;
        }
        if (
            homogenousType != ItemType.ERC721
                && homogenousType != ItemType.ERC20
        ) {
            revert InvalidItemType();
        }
        bool nft = homogenousType == ItemType.ERC721;
        for (uint256 i = 1; i < minimumReceived.length; ++i) {
            _validateSpentItem(minimumReceived[i], homogenousType, nft, offer);
        }
    }

    /// @dev validate SpentItem
    function _validateSpentItem(
        SpentItem calldata offerItem,
        ItemType homogenousType,
        bool nft,
        bool offer
    ) internal view {
        // Ensure that item type is valid.
        ItemType offerItemType = offerItem.itemType;
        if (offerItemType == ItemType.ERC721_WITH_CRITERIA) {
            // maximumSpent items must not be criteria items, since they will not be resolved
            if (!offer) {
                revert InvalidItemType();
            }
            offerItemType = ItemType.ERC721;
        }
        // don't allow mixing of ERC20 and ERC721 items
        if (offerItemType != homogenousType) {
            revert InvalidItemType();
        }
        // validate that the token address is correct
        if (nft) {
            if (offerItem.token != erc721) {
                revert InvalidToken();
            }
        } else {
            if (offerItem.token != erc20) {
                revert InvalidToken();
            }
        }
    }

    function _convertSpentErc721sToReceivedItems(
        SpentItem[] calldata spentItems
    ) internal view returns (ReceivedItem[] memory receivedItems) {
        receivedItems = new ReceivedItem[](spentItems.length);
        for (uint256 i = 0; i < spentItems.length; i++) {
            SpentItem calldata spentItem = spentItems[i];
            receivedItems[i] = ReceivedItem({
                itemType: ItemType.ERC721,
                token: erc721,
                identifier: spentItem.identifier,
                amount: spentItem.amount,
                recipient: payable(address(this))
            });
        }
    }
}
