// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem
} from "../lib/ConsiderationStructs.sol";

import { ERC721 } from "@rari-capital/solmate/src/tokens/ERC721.sol";

/**
 * @title SeaportExtendedNFT
 * @author 0age
 * @notice SeaportExtendedNFT is a basic proof of concept for an ERC721 NFT that
 *         also acts as a Seaport contract offerer. It only allows operators to
 *         transfer tokens if a flag has been activated by Seaport as part of a
 *         call to generateOrder requesting permission to move the token; that
 *         flag will then be unset once fulfillment is completed. This contract
 *         can specify a consideration item as a condition when generating the
 *         order, which must be received by the named recipient as part of the
 *         set of fulfillments. The contract also performs primary sales via the
 *         same mechanic using a lazy-minting approach.
 */
contract SeaportExtendedNFT is
    ContractOffererInterface,
    ERC721("SeaportExtendedNFT", "SXT")
{
    address private immutable _SEAPORT;
    address payable private immutable _CREATOR;

    // Track current transferability of tokens and make available externally.
    mapping(uint256 => bool) public canTransfer;

    error InvalidCaller(address caller);
    error UnsupportedExtraDataVersion(uint8 version);
    error InvalidExtraDataEncoding(uint8 version);
    error InvalidSubstandard(uint8 substandard);
    error NotImplemented();
    error CreatorEarningsMustBeEnforced();

    constructor(address seaport, address payable creatorAccount) {
        // Note: this could optionally be a mapping of whitelisted marketplaces.
        _SEAPORT = seaport;

        // Note: this could optionally support an array of recipients.
        _CREATOR = creatorAccount;
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items, and optional context (supplied as extraData).
     *
     * @custom:param fulfiller       The address of the fulfiller.
     * @param minimumReceived        The Minimum items that the caller must
     *                               receive. If empty, the fulfiller receives
     *                               the ability to transfer the NFT in question
     *                               for a secondary fee; if a single item is
     *                               provided and that item is an unminted NFT,
     *                               the fulfiller receives the ability to
     *                               transfer the NFT in question for a primary
     *                               fee.
     * @custom:param maximumSpent    Maximum items the caller is willing to
     *                               spend. Must meet or exceed the requirement.
     * @param context                Additional context of the order, comprised
     *                               of the NFT tokenID with transfer activation
     *                               (32 bytes) including the 0x00 version byte.
     *                               Unminted tokens do not need to supply any
     *                               context as the minimumReceived item holds
     *                               all necessary information.
     *
     * @return offer         An array containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function generateOrder(
        address /* fulfiller */,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata /* maximumSpent */,
        bytes calldata context // encoded based on the schemaID
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Derive the offer, consideration, and transferable tokenId.
        uint256 tokenId;
        (offer, consideration, tokenId) = _processOrder(
            msg.sender,
            minimumReceived,
            context
        );

        // Toggle the flag to indicate that the token can be transferred for the
        // duration of the Seaport fulfillment.
        canTransfer[tokenId] = true;
    }

    /**
     * @dev Ratifies an order with the specified offer, consideration, and
     *      optional context (supplied as extraData).
     *
     * @param offer                The offer items. One item will be present in
     *                             cases where a token has been minted.
     * @custom:param consideration The consideration items.
     * @param context              Additional context of the order.
     * @custom:param orderHashes   The hashes to ratify.
     * @custom:param contractNonce The nonce of the contract.
     *
     * @return The magic value required by Seaport.
     */
    function ratifyOrder(
        SpentItem[] calldata offer,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata context, // encoded based on the schemaID
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external override returns (bytes4) {
        // Ensure that Seaport is the caller.
        if (msg.sender != _SEAPORT) {
            revert InvalidCaller(msg.sender);
        }

        // Clear canTransfer flag in cases where tokens are not being minted.
        if (offer.length == 0) {
            // Extract the tokenId in question from context.
            uint256 tokenId = abi.decode(context[2:34], (uint256));

            // Toggle flag to indicate that token can no longer be transferred.
            canTransfer[tokenId] = false;
        }

        // Utilize assembly to efficiently return the ratifyOrder magic value.
        assembly {
            mstore(0, 0xf4dd92ce)
            return(0x1c, 0x04)
        }
    }

    /**
     * @dev Transfers the token. Unminted tokens transferred from this contract
     *      via Seaport (which are only offered via contract orders with an
     *      accompanying consideration item) will be lazily minted; otherwise,
     *      a flag indicating that a contract order with an accompanying
     *      consideration item has been generated must be present on the token.
     *
     * @param from    The address of the source of the token.
     * @param to      The address of the recipient of the token.
     * @param tokenId A uint256 value representing the ID of the token.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        // Handle lazy minting. This contract will only authorize Seaport to
        // transfer tokens on its behalf by declaring an offer item as part of a
        // contract order that includes a consideration item for a primary sale.
        if (from == address(this) && msg.sender == _SEAPORT) {
            // Mint the token to the recipient if it is not currently minted.
            _mint(to, tokenId);

            // Return early.
            return;
        }

        require(from == _ownerOf[tokenId], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        // Note: the creator could optionally toggle the canTransfer check or
        // the auto-approval for Seaport.
        require(
            msg.sender == from ||
                (canTransfer[tokenId] &&
                    (msg.sender == _SEAPORT ||
                        isApprovedForAll[from][msg.sender] ||
                        msg.sender == getApproved[tokenId])),
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because ownership is
        // checked above and recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[tokenId] = to;

        delete getApproved[tokenId];

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev View function to preview an order generated in response to a minimum
     *      set of received items, maximum set of spent items, and context
     *      (supplied as extraData).
     *
     * @param caller              The address of the caller (e.g. Seaport).
     * @custom:param fulfiller    The address of the fulfiller.
     * @param minimumReceived     The Minimum items that the caller must
     *                            receive. If empty, the fulfiller receives the
     *                            ability to transfer the NFT in question for a
     *                            secondary fee; if a single item is provided
     *                            and that item is an unminted NFT, the
     *                            fulfiller receives the ability to transfer
     *                            the NFT in question for a primary fee.
     * @custom:param maximumSpent Maximum items the caller is willing to spend.
     *                            Must meet or exceed the requirement.
     * @param context             Additional context of the order, comprised of
     *                            the NFT tokenID with transfer activation
     *                            (32 bytes) including the 0x00 version byte.
     *                            Unminted tokens do not need to supply any
     *                            context as the minimumReceived item holds all
     *                            necessary information.
     *
     * @return offer         An array containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function previewOrder(
        address caller,
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata,
        bytes calldata context
    )
        external
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Derive the offer and consideration.
        (offer, consideration, ) = _processOrder(
            caller,
            minimumReceived,
            context
        );
    }

    /**
     * @dev Gets the metadata for this contract offerer.
     *
     * @return name    The name of the contract offerer.
     * @return schemas The schemas supported by the contract offerer.
     */
    function getSeaportMetadata()
        external
        pure
        override
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        )
    {
        schemas = new Schema[](1);

        schemas[0].id = 10;

        // Encode the SIP-10 information.
        uint256[] memory substandards = new uint256[](2);
        substandards[0] = 0;
        substandards[1] = 1;
        schemas[0].metadata = abi.encode(substandards, "No documentation");

        return ("SeaportExtendedNFT", schemas);
    }

    /**
     * @dev Gets the tokenURI for a given tokenId. Simple stub for this example.
     */
    function tokenURI(uint256) public pure override returns (string memory) {
        return "tokenURI";
    }

    /**
     * @dev Generates an order with the specified enforced consideration items.
     *
     * @param caller                 The address of the caller; must be Seaport.
     * @param minimumReceived        The Minimum items that the caller must
     *                               receive. If empty, the fulfiller receives
     *                               the ability to transfer the NFT in question
     *                               for a secondary fee; if a single item is
     *                               provided and that item is an unminted NFT,
     *                               the fulfiller receives the ability to
     *                               transfer the NFT in question for a primary
     *                               fee.
     * @param context                Additional context of the order, comprised
     *                               of the NFT tokenID with transfer activation
     *                               (32 bytes) including the 0x00 version byte.
     *                               Unminted tokens do not need to supply any
     *                               context as the minimumReceived item holds
     *                               all necessary information.
     *
     * @return               An array containing the offer items.
     * @return consideration An array containing the consideration items.
     * @return tokenId       The tokenId of the transferable token.
     */
    function _processOrder(
        address caller,
        SpentItem[] calldata minimumReceived,
        bytes calldata context
    )
        internal
        view
        returns (
            SpentItem[] memory,
            ReceivedItem[] memory consideration,
            uint256 tokenId
        )
    {
        // Declare an error buffer; first check is that caller is Seaport.
        uint256 errorBuffer = _cast(caller == _SEAPORT);

        // Declare array for returned consideration containing creator earnings.
        consideration = new ReceivedItem[](1);

        // Handle cases where a new, unminted NFT is being requested.
        if (
            errorBuffer != 0 &&
            minimumReceived.length == 1 &&
            minimumReceived[0].itemType == ItemType.ERC721 &&
            minimumReceived[0].token == address(this)
        ) {
            SpentItem calldata item = minimumReceived[0];
            // Ensure the item is spending this NFT; otherwise, tokens that are
            // held by this contract that Seaport has approval to transfer can
            // be taken.
            if (
                item.itemType == ItemType.ERC721 && item.token == address(this)
            ) {
                // Populate the enforced creator earnings as the consideration.
                consideration[0] = _getEnforcedPrimaryCreatorEarnings();
                return (minimumReceived, consideration, tokenId);
            }
        }

        // Get the length of the context array from calldata (masked).
        uint256 contextLength;
        assembly {
            contextLength := and(calldataload(context.offset), 0xfffffff)
        }

        {
            // Next, check for sip-6 version byte.
            errorBuffer |= errorBuffer ^ (_cast(context[0] == 0x00) << 1);

            // Next, check for supported substandard.
            errorBuffer |= errorBuffer ^ (_cast(context[1] == 0x01) << 2);

            // Next, check for correct context length.
            unchecked {
                errorBuffer |= errorBuffer ^ (_cast(contextLength == 34) << 3);
            }

            // Handle decoding errors.
            if (errorBuffer != 0) {
                uint8 version = uint8(context[0]);

                if (errorBuffer << 255 != 0) {
                    revert InvalidCaller(msg.sender);
                } else if (errorBuffer << 254 != 0) {
                    revert UnsupportedExtraDataVersion(version);
                } else if (errorBuffer << 253 != 0) {
                    revert InvalidSubstandard(uint8(context[1]));
                } else if (errorBuffer << 252 != 0) {
                    revert InvalidExtraDataEncoding(version);
                }
            }
        }

        // Extract the tokenId in question from context.
        tokenId = abi.decode(context[2:34], (uint256));

        // Populate the enforced creator earnings as the consideration.
        consideration[0] = _getEnforcedSecondaryCreatorEarnings();

        return (new SpentItem[](0), consideration, tokenId);
    }

    /**
     * @dev Internal function to get the required creator earnings payment on a
     *      transfer from this contract resulting in minting an unminted NFT.
     *
     * @return The required received item.
     */
    function _getEnforcedPrimaryCreatorEarnings()
        internal
        view
        returns (ReceivedItem memory)
    {
        // NOTE: this can utilize any number of mechanics, including a reference
        // to the sale price in question, an oracle, a harbinger-like method, a
        // VRGDA function, a registry lookup, or any other arbitrary method.
        return
            ReceivedItem({
                itemType: ItemType.NATIVE,
                token: address(0),
                identifier: uint256(0),
                amount: 0.1 ether,
                recipient: _CREATOR
            });
    }

    /**
     * @dev Internal function to get the required creator earnings payment on a
     *      standard transfer from an operator account.
     *
     * @return The required received item.
     */
    function _getEnforcedSecondaryCreatorEarnings()
        internal
        view
        returns (ReceivedItem memory)
    {
        // NOTE: this can utilize any number of mechanics, including a reference
        // to the sale price in question, an oracle, a harbinger-like method, a
        // VRGDA function, a registry lookup, or any other arbitrary method.
        return
            ReceivedItem({
                itemType: ItemType.NATIVE,
                token: address(0),
                identifier: uint256(0),
                amount: 0.01 ether,
                recipient: _CREATOR
            });
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }
}
