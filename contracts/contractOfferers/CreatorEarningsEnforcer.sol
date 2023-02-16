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
 * @title CreatorEarningsEnforcer
 * @author 0age
 * @notice CreatorEarningsEnforcer is a basic proof of concept for an NFT that
 *         also acts as a Seaport contract offerer. It only allows operators to
 *         transfer tokens if a flag has been activated by Seaport as part of a
 *         call to generateOrder requesting permission to move the token; that
 *         flag will then be unset once fulfillment is completed. This contract
 *         can specify a consideration item as a condition when generating the
 *         order, which must be received by the named recipient as part of the
 *         set of fulfillments.
 */
contract CreatorEarningsEnforcer is
    ContractOffererInterface,
    ERC721("CreatorEarningsEnforcer", "CEE")
{
    address private immutable _SEAPORT;
    address payable private immutable _CREATOR;

    mapping(uint256 => bool) _canTransfer;

    error InvalidCaller(address caller);
    error UnsupportedExtraDataVersion(uint8 version);
    error InvalidExtraDataEncoding(uint8 version);
    error NotImplemented();
    error CreatorEarningsMustBeEnforced();
    error OnlyCreator();

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
     * @custom:param minimumReceived The Minimum items that the caller must
     *                               receive. Must be empty.
     * @custom:param maximumSpent    Maximum items the caller is willing to
     *                               spend. Must meet or exceed the requirement.
     * @param context                Additional context of the order, comprised
     *                               of the NFT tokenID with transfer activation
     *                               (32 bytes) including the 0x00 version byte.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration A tuple containing the consideration items.
     */
    function generateOrder(
        address /* fulfiller */,
        SpentItem[] calldata /* minimumReceived */,
        SpentItem[] calldata /* maximumSpent */,
        bytes calldata context // encoded based on the schemaID
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Get the length of the context array from calldata (masked).
        uint256 contextLength;
        assembly {
            contextLength := and(calldataload(context.offset), 0xfffffff)
        }

        {
            // Declare an error buffer; first check is that caller is Seaport.
            uint256 errorBuffer = _cast(msg.sender == _SEAPORT);

            // Next, check for sip-6 version byte.
            errorBuffer |= errorBuffer ^ (_cast(context[0] == 0x00) << 1);

            // Next, check for correct context length.
            unchecked {
                errorBuffer |= errorBuffer ^ (_cast(contextLength == 33) << 2);
            }

            // Handle decoding errors.
            if (errorBuffer != 0) {
                uint8 version = uint8(context[0]);

                if (errorBuffer << 255 != 0) {
                    revert InvalidCaller(msg.sender);
                } else if (errorBuffer << 254 != 0) {
                    revert UnsupportedExtraDataVersion(version);
                } else if (errorBuffer << 253 != 0) {
                    revert InvalidExtraDataEncoding(version);
                }
            }
        }

        // Extract the tokenId in question from context.
        uint256 tokenId = abi.decode(context[1:33], (uint256));

        // Populate the enforced creator earnings as the consideration.
        ReceivedItem[] memory creatorEarnings = new ReceivedItem[](1);
        creatorEarnings[0] = _getEnforcedCreatorEarnings();

        // Toggle the flag to indicate that the token can be transferred for the
        // duration of the Seaport fulfillment.
        _canTransfer[tokenId] = true;

        return (new SpentItem[](0), creatorEarnings);
    }

    /**
     * @dev Ratifies an order with the specified offer, consideration, and
     *      optional context (supplied as extraData).
     *
     * @custom:param offer         The offer items.
     * @custom:param consideration The consideration items.
     * @param context              Additional context of the order.
     * @custom:param orderHashes   The hashes to ratify.
     * @custom:param contractNonce The nonce of the contract.
     *
     * @return The magic value required by Seaport.
     */
    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata context, // encoded based on the schemaID
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external override returns (bytes4) {
        // Ensure that Seaport is the caller.
        if (msg.sender != _SEAPORT) {
            revert InvalidCaller(msg.sender);
        }

        // Extract the tokenId in question from context.
        uint256 tokenId = abi.decode(context[1:33], (uint256));

        // Toggle flag to indicate that the token can no longer be transferred.
        _canTransfer[tokenId] = false;

        // Utilize assembly to efficiently return the ratifyOrder magic value.
        assembly {
            mstore(0, 0xf4dd92ce)
            return(0x1c, 0x04)
        }
    }

    function mint(address to, uint256 tokenId) public returns (bool) {
        if (msg.sender != _CREATOR) {
            revert OnlyCreator();
        }

        _mint(to, tokenId);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        require(from == _ownerOf[tokenId], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        // Note: the creator could optionally toggle the _canTransfer check or
        // the auto-approval for Seaport.
        require(
            msg.sender == from ||
                (_canTransfer[tokenId] &&
                    (msg.sender == _SEAPORT ||
                        isApprovedForAll[from][msg.sender] ||
                        msg.sender == getApproved[tokenId])),
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[tokenId] = to;

        delete getApproved[tokenId];

        emit Transfer(from, to, tokenId);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "tokenURI";
    }

    /**
     * @dev View function to preview an order generated in response to a minimum
     *      set of received items, maximum set of spent items, and context
     *      (supplied as extraData).
     *
     * @custom:param caller      The address of the caller (e.g. Seaport).
     * @custom:paramfulfiller    The address of the fulfiller (e.g. the account
     *                           calling Seaport).
     * @custom:param minReceived The minimum items that the caller is willing to
     *                           receive.
     * @custom:param maxSpent    The maximum items caller is willing to spend.
     * @custom:param context     Additional context of the order.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration A tuple containing the consideration items.
     */
    function previewOrder(
        address,
        address,
        SpentItem[] calldata,
        SpentItem[] calldata,
        bytes calldata
    )
        external
        pure
        override
        returns (SpentItem[] memory, ReceivedItem[] memory)
    {
        revert NotImplemented();
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
        schemas = new Schema[](0);
        return ("CreatorEarningsEnforcer", schemas);
    }

    /**
     * @dev Internal function to get the required creator earnings payment.
     *
     * @return The required received item.
     */
    function _getEnforcedCreatorEarnings()
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
