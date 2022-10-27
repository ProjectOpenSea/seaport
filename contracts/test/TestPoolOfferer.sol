// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC20Interface, ERC721Interface} from "../interfaces/AbridgedTokenInterfaces.sol";

import {ContractOffererInterface} from "../interfaces/ContractOffererInterface.sol";

import {ItemType} from "../lib/ConsiderationEnums.sol";

import {SpentItem, ReceivedItem, InventoryUpdate} from "../lib/ConsiderationStructs.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TestPoolOfferer is ContractOffererInterface {
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

    constructor(address seaport, address _erc721, uint256[] memory _tokenIds, address _erc20, uint256 amount) {
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

    function generateOrder(SpentItem[] calldata minimumReceived, SpentItem[] calldata maximumSpent, bytes calldata)
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        if (msg.sender != _SEAPORT) {
            revert OnlySeaport();
        }
        bool nftOffer;
        uint256 newBalance;
        (offer, consideration, newBalance, nftOffer) = _generateOfferAndConsideration(minimumReceived, maximumSpent);

        // update token ids and balances
        if (nftOffer) {
            _processNftOffer(offer);
        } else {
            _processNftConsideration(consideration);
        }
        balance = newBalance;
    }

    function previewOrder(
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata
    ) external view override returns (SpentItem[] memory offer, ReceivedItem[] memory consideration) {
        (offer, consideration,,) = _generateOfferAndConsideration(minimumReceived, maximumSpent);
    }

    function getInventory() external pure override returns (SpentItem[] memory, SpentItem[] memory) {
        revert NotImplemented();
    }

    /// @dev add incoming tokens to the set of IDs in the pool
    function _processNftConsideration(ReceivedItem[] memory maximumSpent) internal {
        for (uint256 i = 0; i < maximumSpent.length; i++) {
            ReceivedItem memory maximumSpentItem = maximumSpent[i];
            bool added = tokenIds.add(maximumSpentItem.identifier);
            if (!added) {
                revert InvalidTokenId(maximumSpentItem.identifier);
            }
        }
    }

    /// @dev remove outgoing tokens from the set of IDs in the pool
    function _processNftOffer(SpentItem[] memory minimumReceived) internal {
        for (uint256 i = 0; i < minimumReceived.length; i++) {
            SpentItem memory minimumReceivedItem = minimumReceived[i];
            bool removed = tokenIds.remove(minimumReceivedItem.identifier);
            if (!removed) {
                revert InvalidTokenId(minimumReceivedItem.identifier);
            }
        }
    }

    /// @dev generate offer and consideration items based on the number of ERC721 tokens offered or requested
    function _generateOfferAndConsideration(SpentItem[] calldata minimumReceived, SpentItem[] calldata maximumSpent)
        internal
        view
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration, uint256 newBalance, bool nftOffer)
    {
        _validateSpentItems(minimumReceived);
        _validateSpentItems(maximumSpent);

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
            offer[0] = SpentItem({itemType: ItemType.ERC20, token: erc20, identifier: 0, amount: paymentAmount});
            consideration = _convertSpentTokensToReceivedItems(maximumSpent);
        }
    }

    function _validateSpentItems(SpentItem[] memory minimumReceived) internal view {
        ItemType homogenousType = minimumReceived[0].itemType;
        if (homogenousType != ItemType.ERC721 && homogenousType != ItemType.ERC20) {
            revert InvalidItemType();
        }
        bool nft = homogenousType == ItemType.ERC721;
        for (uint256 i = 1; i < minimumReceived.length; ++i) {
            _validateSpentItem(minimumReceived[i], homogenousType, nft);
        }
    }

    /// @dev validate SpentItem
    function _validateSpentItem(SpentItem memory offerItem, ItemType homogenousType, bool nft) internal view {
        // Ensure that item type is valid.
        if (offerItem.itemType != homogenousType) {
            revert InvalidItemType();
        }
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

    function _convertSpentTokensToReceivedItems(SpentItem[] calldata spentItems)
        internal
        view
        returns (ReceivedItem[] memory receivedItems)
    {
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
