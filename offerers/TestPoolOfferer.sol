// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    ERC20Interface,
    ERC721Interface
} from "seaport/interfaces/AbridgedTokenInterfaces.sol";

import {
    ContractOffererInterface
} from "seaport/interfaces/ContractOffererInterface.sol";

import { ItemType } from "seaport/lib/ConsiderationEnums.sol";

import { SpentItem, ReceivedItem } from "seaport/lib/ConsiderationStructs.sol";

import {
    EnumerableSet
} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {
    IERC721
} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {
    IERC20
} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
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
        for (uint256 i; i < _tokenIds.length; ++i) {
            tokenIds.add(_tokenIds[i]);
        }
        // tokenIds = _tokenIds;
        erc20 = _erc20;
        balance = amount;
        k = amount * scale * _tokenIds.length;

        // Make the necessary approvals.
        IERC20(erc20).approve(seaport, type(uint256).max);
        IERC721(erc721).setApprovalForAll(seaport, true);
    }

    /**
     * @dev Generate an order based on the minimumReceived and maximumSpent
     *      arrays. This function can only be called by Seaport.
     *
     * @param -                The address of the fulfiller.
     * @param minimumReceived  An array of SpentItem structs representing the
     *                         minimum amount that the offerer is willing to
     *                         receive.
     * @param maximumSpent     An array of SpentItem structs representing the
     *                         maximum amount that the offerer is willing to
     *                         spend.
     *
     * @return offer           An array of SpentItem structs representing the
     *                         offer.
     * @return consideration   An array of ReceivedItem structs representing the
     *                         consideration.
     */
    function generateOrder(
        address /* fulfiller */,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Only Seaport may call this function.
        if (msg.sender != _SEAPORT) {
            revert OnlySeaport();
        }
        // If true, this offerer is spending NFTs and receiving ERC20.
        bool nftOffer;
        uint256 newBalance;
        (
            offer,
            consideration,
            newBalance,
            nftOffer
        ) = _generateOfferAndConsideration(minimumReceived, maximumSpent);

        // Update token ids and balances.
        // Note that no tokens will actually be exchanged until Seaport executes
        // fulfillments.
        if (nftOffer) {
            // Remove outgoing tokenIDs from pool and assign concrete IDs to any
            // criteria-based "wildcard" erc721 items.
            _processNftOffer(offer);
        } else {
            // Add incoming NFT ids to pool.
            _processNftConsideration(consideration);
        }
        // Update internal erc20 balance.
        balance = newBalance;
    }

    /** @dev Generate an offer and consideration based on the minimumReceived
     *  and maximumSpent arrays.
     *
     *  @param minimumReceived An array of SpentItem structs representing the
     *                         minimum amount that the offerer is willing to
     *                         receive.
     *  @param maximumSpent    An array of SpentItem structs representing the
     *                         maximum amount that the offerer is willing to
     *                         spend.
     *
     *  @return offer          An array of SpentItem structs representing the
     *                         offer.
     *  @return consideration  An array of ReceivedItem structs representing the
     *                         consideration.
     */
    function previewOrder(
        address,
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
        // Declare a local variable to track whether the offer is an NFT offer.
        bool nftOffer;

        // Generate the offer and consideration, and store the result in the
        // offer and consideration variables.
        // The _generateOfferAndConsideration function also returns a bool
        // indicating whether the offer is an NFT offer.
        (offer, consideration, , nftOffer) = _generateOfferAndConsideration(
            minimumReceived,
            maximumSpent
        );

        // If it's an NFT offer, call the _previewNftOffer function with the
        // offer as an argument.
        if (nftOffer) _previewNftOffer(offer);
    }

    /**
     * @dev Ratify an order.
     *
     * @param -               An array of SpentItem structs representing the
     *                        offer.
     * @param -               An array of ReceivedItem structs representing the
     *                        consideration.
     * @param -               The context of the order.
     * @param -               An array of order hashes.
     * @param -               The contract nonce.
     *
     * @return -              The magic value of the ratifyOrder
     *                        function.
     */
    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */,
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external pure override returns (bytes4 /* ratifyOrderMagicValue */) {
        return ContractOffererInterface.ratifyOrder.selector;
    }

    /**
     * @dev Get the metadata for this contract.
     *
     * @return schemaID   The ID of the schema for the metadata.
     * @return name       The name of the contract.
     * @return metadata   The metadata for the contract, encoded based on the
     *                    schema.
     */
    function getMetadata()
        external
        pure
        override
        returns (
            uint256 schemaID, // maps to a Seaport standard's ID
            string memory name,
            bytes memory metadata // decoded based on the schemaID
        )
    {
        return (7117, "TestPoolOfferer", "");
    }

    /**
     * @dev Add incoming tokens to the set of IDs in the pool.
     *
     * @param maximumSpent An array of ReceivedItem structs representing the
     *                     maximum amount that the offerer is willing to spend.
     */
    function _processNftConsideration(
        ReceivedItem[] memory maximumSpent
    ) internal {
        // Iterate over each item in the maximumSpent array.
        for (uint256 i = 0; i < maximumSpent.length; ++i) {
            // Retrieve the maximum spent item.
            ReceivedItem memory maximumSpentItem = maximumSpent[i];

            // Attempt to add the item's identifier to the `tokenIds` set.
            bool added = tokenIds.add(maximumSpentItem.identifier);

            // If the item's identifier was not added to the set, it means that
            // it was already in the pool. In that case, revert the transaction.
            if (!added) {
                revert InvalidTokenId(maximumSpentItem.identifier);
            }
        }
    }

    /**
    * @dev Remove outgoing tokens from the set of IDs in the pool.
    *
    * @param minimumReceived An array of SpentItem structs representing the
    *                        minimum amount that the offerer is willing to
    *                        receive.
    */
    function _processNftOffer(SpentItem[] memory minimumReceived) internal {
        // Declare a local variable to track the index of the criteria-based
        // "wildcard" items.
        // uint256 criteriaIndex;

        // Iterate over each item in the minimumReceived array.
        for (uint256 i = 0; i < minimumReceived.length; ++i) {
            // Retrieve the minimum received item.
            SpentItem memory minimumReceivedItem = minimumReceived[i];

            // Declare a local variable to hold the identifier of the item.
            uint256 identifier;

            // If the item type is ERC721, set the identifier to the item's
            // identifier. Otherwise, the item is a wildcard token.
            if (minimumReceivedItem.itemType == ItemType.ERC721) {
                identifier = minimumReceivedItem.identifier;
            } else {
                // For wildcard tokens, always pick the token ID in the first
                // position of the set.
                identifier = tokenIds.at(0);

                // Set the item type to ERC721 and the identifier to the token
                // ID.
                minimumReceivedItem.itemType = ItemType.ERC721;
                minimumReceivedItem.identifier = identifier;

                // Increment the criteria index.
                // ++criteriaIndex;
            }

            // Attempt to remove the item's identifier from the `tokenIds` set.
            bool removed = tokenIds.remove(identifier);

            // If a token was not removed it means that the token is not or is
            // no longer in the pool. Note that criteria-based "wildcard" items
            // should follow concrete items in the offer array to avoid
            // circumstances where the offerer tries to spend the same ID twice.
            if (!removed) {
                revert InvalidTokenId(identifier);
            }
        }
    }

    /**
    * @dev Preview an NFT offer by assigning concrete token IDs to any
    *      criteria-based "wildcard" erc721 items.
    *
    * @param minimumReceived An array of SpentItem structs representing the
    *                        minimum amount that the offerer is willing to
    *                        receive.
    */
    function _previewNftOffer(
        SpentItem[] memory minimumReceived
    ) internal view {
        // Declare a local variable to track the index of the criteria-based
        // "wildcard" items.
        uint256 criteriaIndex;

        // Iterate over each item in the minimumReceived array.
        for (uint256 i = 0; i < minimumReceived.length; ++i) {
            // Retrieve the minimum received item.
            SpentItem memory minimumReceivedItem = minimumReceived[i];

            // If the item type is ERC721_WITH_CRITERIA, it means that the item
            // is a wildcard token. In that case, assign a concrete token ID
            // to the item.
            if (minimumReceivedItem.itemType == ItemType.ERC721_WITH_CRITERIA) {
                // Pick the next token ID in the set, starting at index 0.
                minimumReceivedItem.itemType = ItemType.ERC721;
                minimumReceivedItem.identifier = tokenIds.at(criteriaIndex);

                // Increment the criteria index.
                ++criteriaIndex;
            }
        }
    }


    /** @dev Generate offer and consideration items based on the number of
     *       ERC721 tokens offered or requested.
     *
     *  @param minimumReceived An array of SpentItem structs representing the
     *                         minimum amount that the offerer is willing to
     *                         receive.
     *  @param maximumSpent    An array of SpentItem structs representing the
     *                         maximum amount that the offerer is willing to
     *                         spend.
     *
     *  @return offer          An array of SpentItem structs representing the
     *                         offer.
     *  @return consideration  An array of ReceivedItem structs representing the
     *                         consideration.
     *  @return newBalance     The new balance of the contract.
     *  @return nftOffer       Whether the offer is an NFT offer.
     */
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
        // Validate that all tokens in each set are "homogenous"
        // (ERC20 or ERC721/_WITH_CRITERIA).
        _validateSpentItems(minimumReceived, true);
        _validateSpentItems(maximumSpent, false);

        // If the fulfiller is spending ERC20 tokens, calculate how much is
        // needed for the number of tokens specified in minimumReceived.
        if (maximumSpent[0].itemType == ItemType.ERC20) {
            // Calculate the number of new tokens.
            uint256 newNumTokens = tokenIds.length() - minimumReceived.length;

            // Calculate the new balance. k is set above, it's: amount * scale *
            // _tokenIds.length.
            newBalance = k / (scale * newNumTokens);

            // Calculate the amount of ERC20 tokens to pay for N items.
            uint256 considerationAmount = newBalance - balance;

            // Generate the offer and consideration.
            consideration = new ReceivedItem[](1);
            consideration[0] = ReceivedItem({
                itemType: ItemType.ERC20,
                token: erc20,
                identifier: 0,
                amount: considerationAmount,
                recipient: payable(address(this))
            });
            offer = minimumReceived;

            // Set the nftOffer flag to true.
            nftOffer = true;
        } else {
            // Otherwise, if fulfiller is spending ERC721 tokens, calculate the
            // amount of ERC20 tokens to pay for N items.

            // Calculate the number of new tokens.
            uint256 newNumTokens = tokenIds.length() + maximumSpent.length;

            // Calculate the new balance. k is set above, it's: amount * scale *
            // _tokenIds.length.
            newBalance = k / (scale * newNumTokens);

            // Calculate the amount of ERC20 tokens to pay for N items.
            uint256 paymentAmount = balance - newBalance;

            // Generate the offer and consideration.
            offer = new SpentItem[](1);
            offer[0] = SpentItem({
                itemType: ItemType.ERC20,
                token: erc20,
                identifier: 0,
                amount: paymentAmount
            });
            consideration = _convertSpentErc721sToReceivedItems(maximumSpent);

            // nftOffer is false by default.
        }
    }

    /**
     * @dev Validate that the SpentItem array contains a valid type, then
     *      iterate over the items and validate them individually.
     * 
     * @param minimumReceived An array of SpentItem structs to validate.
     * @param offer           A boolean value indicating whether the items are
     *                        part of an offer or consideration.
     */
    function _validateSpentItems(
        SpentItem[] calldata minimumReceived,
        bool offer
    ) internal view {
        // Store the first item's type.
        ItemType homogenousType = minimumReceived[0].itemType;

        // If the first item is an ERC721_WITH_CRITERIA item, set the
        // homogenousType to ERC721.
        if (homogenousType == ItemType.ERC721_WITH_CRITERIA) {
            homogenousType = ItemType.ERC721;
        }

        // Check if the item type is valid (either ERC721 or ERC20).
        if (
            homogenousType != ItemType.ERC721 &&
            homogenousType != ItemType.ERC20
        ) {
            revert InvalidItemType();
        }

        // Set the `nft` variable to `true` if the item type is ERC721,
        // `false` otherwise.
        bool nft = homogenousType == ItemType.ERC721;

        // Loop over the remaining items in the `minimumReceived` array and
        // validate each one.
        for (uint256 i = 1; i < minimumReceived.length; ++i) {
            _validateSpentItem(minimumReceived[i], homogenousType, nft, offer);
        }
    }

    /** @dev Validates each SpentItem. Ensures that the item type is valid, all
     *        tokens are homogenous, and that the addresses are those we expect.
     *
     * @param offerItem      The item to validate.
     * @param homogenousType The item type that should be homogenous.
     * @param nft            Whether the item is a non-fungible token.
     * @param offer          A bool indicating whether the minimumReceived
     *                       array is the offer or the consideration. This is
     *                       used to determine if ERC721_WITH_CRITERIA items
     *                       are allowed.
     */
    function _validateSpentItem(
        SpentItem calldata offerItem,
        ItemType homogenousType,
        bool nft,
        bool offer
    ) internal view {
        // Ensure that item type is valid.
        ItemType offerItemType = offerItem.itemType;
        if (offerItemType == ItemType.ERC721_WITH_CRITERIA) {
            // maximumSpent items must not be criteria items, since they will
            // not be resolved.
            if (!offer) {
                revert InvalidItemType();
            }
            offerItemType = ItemType.ERC721;
        }

        // Don't allow mixing of ERC20 and ERC721 items.
        if (offerItemType != homogenousType) {
            revert InvalidItemType();
        }

        // Validate that the token address is correct.
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


    /**
     * @dev Converts a set of SpentItem structs representing ERC721 tokens to
     * a set of ReceivedItem structs.
     *
     * @param spentItems An array of SpentItem structs representing the tokens
     * to be converted.
     *
     * @return receivedItems An array of ReceivedItem structs representing the
     * converted tokens.
     */
    function _convertSpentErc721sToReceivedItems(
        SpentItem[] calldata spentItems
    ) internal view returns (ReceivedItem[] memory receivedItems) {
        // Initialize array of received items.
        receivedItems = new ReceivedItem[](spentItems.length);
        // Loop through spent items and convert each to a received item.
        for (uint256 i = 0; i < spentItems.length; ++i) {
            SpentItem calldata spentItem = spentItems[i];
            // Create new received item and populate with data from spent item.
            receivedItems[i] = ReceivedItem({
                itemType: ItemType.ERC721,
                token: erc721,
                identifier: spentItem.identifier,
                amount: spentItem.amount,
                recipient: payable(address(this))
            });
        }
    }

    /**
     * @dev Transfers the contract's entire ERC20 and ERC721 balances to the
     * contract's owner.
     */
    function withdrawAll() external onlyOwner {
        // Get the contract's ERC20 balance.
        IERC20 ierc20 = IERC20(erc20);
        uint256 erc20Balance = ierc20.balanceOf(address(this));

        // Get the contract's owner address.
        address owner = owner();

        // Transfer the ERC20 balance to the contract's owner.
        ierc20.transfer(owner, erc20Balance);

        // Transfer each ERC721 token to the contract's owner.
        while (tokenIds.length() > 0) {
            uint256 tokenId = tokenIds.at(0);
            IERC721(erc721).transferFrom(address(this), owner, tokenId);

            // Remove the token from the set.
            tokenIds.remove(tokenId);
        }

        // Set the contract's ERC20 balance to 0.
        balance = 0;
    }
}
