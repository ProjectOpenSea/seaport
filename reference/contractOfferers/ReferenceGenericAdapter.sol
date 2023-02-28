// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ContractOffererInterface
} from "../../contracts/interfaces/ContractOffererInterface.sol";

import { ItemType } from "../../contracts/lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem
} from "../../contracts/lib/ConsiderationStructs.sol";

import { TokenTransferrer } from "../../contracts/lib/TokenTransferrer.sol";

import {
    ReferenceGenericAdapterSidecar
} from "./ReferenceGenericAdapterSidecar.sol";

/**
 * @title ReferenceGenericAdapter
 * @author 0age
 * @notice GenericAdapter is a proof of concept for a contract offerer that can
 *         source liquidity from arbitrary targets, such as other marketplaces,
 *         and make those liquidity sources available from within Seaport. It
 *         encapsulates arbitrary execution within a companion contract, called
 *         the "sidecar."  This is the reference implementation.
 */
contract ReferenceGenericAdapter is ContractOffererInterface, TokenTransferrer {
    address private immutable _SEAPORT;
    address private immutable _SIDECAR;
    address private immutable _FLASHLOAN_OFFERER;

    error InvalidCaller(address caller);
    error InvalidFulfiller(address fulfiller);
    error UnsupportedExtraDataVersion(uint8 version);
    error InvalidExtraDataEncoding(uint8 version);
    // 0xe5a0a42f
    error ApprovalFailed(address approvalToken);
    // 0x3204506f
    error CallFailed();
    // 0xbc806b96
    error NativeTokenTransferGenericFailure(address recipient, uint256 amount);
    error NotImplemented();

    constructor(address seaport, address flashloanOfferer) {
        _SEAPORT = seaport;
        _SIDECAR = address(new ReferenceGenericAdapterSidecar());
        _FLASHLOAN_OFFERER = flashloanOfferer;
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items, and optional context (supplied as extraData).
     *
     * @param fulfiller       The address of the fulfiller.
     * @param minimumReceived The minimum items that the caller must receive.
     *                        Any non-native tokens must be owned by this
     *                        contract with sufficient allowance granted from
     *                        this contract to Seaport; any native tokens must
     *                        have been supplied to Seaport.
     * @param maximumSpent    The maximum items the caller is willing to spend.
     *                        Each of these items will be transferred from the
     *                        fulfiller to the sidecar. Sufficient allowance
     *                        must first be granted to this contract by the
     *                        fulfiller before non-native tokens can be
     *                        transferred; native tokens must already reside on
     *                        this contract to be transferred. Note that unspent
     *                        items will be left in the sidecar in this
     *                        implementation and may be subsequently taken by
     *                        other parties.
     * @param context         Additional context of the order:
     *                          - totalApprovals: approvals to make (1 byte)
     *                              - approvalType (1 byte * totalApprovals)
     *                              - approvalToken (20 bytes * totalApprovals)
     *                          - payload: calldata (0+ bytes)
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration A tuple containing the consideration items.
     */
    function generateOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Get the length of the context array from calldata (masked).
        uint256 contextLength = uint256(bytes32(context[24:32]));

        uint256 approvalDataSize;
        {
            // Check is that caller is Seaport.
            if (msg.sender != _SEAPORT) {
                revert InvalidCaller(msg.sender);
            }

            // Check for sip-6 version byte.
            if (context[0] != 0x00) {
                revert UnsupportedExtraDataVersion(uint8(context[0]));
            }

            // Retrieve the number of approvals.
            uint256 approvalCount = uint256(bytes32(context[34 - 8:34]));
            // Each approval block is 21 bytes long.
            approvalDataSize = approvalCount * 21;

            // Check that the context length is acceptable.
            if (contextLength < 2 + approvalDataSize) {
                // If it's not, revert.
                revert InvalidExtraDataEncoding(uint8(context[0]));
            }
        }

        // Perform approvals (if any) followed by generic call to the target.
        // NOTE: this could optionally use minimumReceived along with a flag for
        // determining whether or not to iterate over the items and any missing
        // approvals.
        uint256 approvalDataEnds;
        {
            // Read the approval target from runtime code and place on stack.
            address approvalTarget = _SEAPORT;

            // Set up variables for use in the iterator.
            uint256 approvalDataInitialOffset = 33;
            approvalDataEnds = approvalDataInitialOffset + approvalDataSize;
            uint256 approvalDataBlockSize = 21;
            uint256 startingIndex;
            uint256 endingIndex;
            address approvalToken;
            bool success;

            // Iterate over each approval.
            for (uint256 i = 0; i < approvalDataSize; ) {
                i += approvalDataBlockSize;

                // TODO: Check all these contracts for off by one errors, etc.
                // TODO: Convert all comments to use indexes.

                // The first approval block starts at byte 33 and goes to byte
                // 54.  The next is 55-75, etc. `startingIndex` and
                // `endingIndex` define the range of bytes for the current
                // approval block.
                startingIndex =
                    approvalDataInitialOffset +
                    i -
                    approvalDataBlockSize;
                endingIndex = approvalDataInitialOffset + i;

                // The first byte of the approval block is the approval type.
                // The bytes at indexes 1-21 are the address of the token to
                // approve.
                approvalToken = address(
                    uint160(
                        bytes20(context[startingIndex + 1:startingIndex + 21])
                    )
                );

                // 0x00 flag for ERC20 and 0x01 flag for ERC721.
                if (context[startingIndex] == 0x00) {
                    // Approve the Seaport contract to transfer the maximum
                    // amount of the token.
                    (success, ) = approvalToken.call{ value: 0 }(
                        abi.encodeWithSignature(
                            "approve(address,uint256)",
                            approvalTarget,
                            uint256(2 ** 256 - 1)
                        )
                    );
                } else {
                    // Approve the Seaport contract to transfer all tokens.
                    (success, ) = approvalToken.call{ value: 0 }(
                        abi.encodeWithSignature(
                            "setApprovalForAll(address,bool)",
                            approvalTarget,
                            true
                        )
                    );
                }

                // Revert if the approval failed.
                if (!success) {
                    revert ApprovalFailed(approvalToken);
                }
            }
        }

        // Read the sidecar address from runtime code and place on the stack.
        address target = _SIDECAR;

        // Track cumulative native tokens to be spent.
        uint256 value;

        // Reset the fulfiller address to avoid stacc2dank.
        address _fulfiller = fulfiller;

        // Transfer each maximumSpent item to the sidecar.
        {
            uint256 totalTokensSpent = maximumSpent.length;
            // Iterate over each item.  Perform transfers or account for native
            // tokens.
            for (uint256 i = 0; i < totalTokensSpent; ) {
                SpentItem calldata item = maximumSpent[i];
                ItemType itemType = item.itemType;

                if (itemType == ItemType.NATIVE) {
                    // Increment native token amount (mask to prevent overflow).
                    unchecked {
                        value += item.amount & type(uint224).max;
                    }
                } else if (itemType == ItemType.ERC20) {
                    _performERC20Transfer(
                        item.token,
                        _fulfiller,
                        target,
                        item.amount
                    );
                } else if (itemType == ItemType.ERC721) {
                    _performERC721Transfer(
                        item.token,
                        _fulfiller,
                        target,
                        item.identifier
                    );
                } else {
                    _performERC1155Transfer(
                        item.token,
                        _fulfiller,
                        target,
                        item.identifier,
                        item.amount
                    );
                }

                unchecked {
                    ++i;
                }
            }
        }

        // Call sidecar, performing generic execution consuming supplied items.
        {
            uint256 payloadSize = contextLength - (2 + approvalDataSize);
            bytes calldata payload = context[approvalDataEnds:approvalDataEnds +
                payloadSize];

            // Call the sidecar with the supplied payload.
            (bool success, ) = target.call{ value: 0 }(
                abi.encodeWithSignature("execute(Calls[])", payload)
            );

            // Revert if the call failed.
            if (!success) {
                revert CallFailed();
            }
        }

        // Note: balances of minumumReceived items could be asserted here should
        // the sidecar execution output be unreliable. Alternatively, this check
        // can be performed from the sidecar itself as the final multicall step.

        // Return the minimumReceived items as the offer and an empty array as
        // the consideration.
        return (minimumReceived, new ReceivedItem[](0));
    }

    /**
     * @dev Allow for the flashloan offerer to retrieve native tokens that may
     *      have been left over on this contract, especially in the case where
     *      the request to generate the order fails and the order is skipped. As
     *      the flashloan offerer has already sent native tokens to the adapter
     *      beforehand, those native tokens will otherwise be stuck in the
     *      adapter for the duration of the fulfillment, and therefore at risk
     *      of being taken by another caller in a subsequent fulfillment.
     */
    function cleanup(address recipient) external payable returns (bytes4) {
        // Ensure that only designated flashloan offerer can call this function.
        if (msg.sender != _FLASHLOAN_OFFERER) {
            revert InvalidCaller(msg.sender);
        }

        // Send any available native token balance to the supplied recipient.
        if (address(this).balance > 0) {
            // Declare a variable indicating whether the call was successful.
            (bool success, ) = recipient.call{ value: address(this).balance }(
                ""
            );

            // If the call fails, revert.
            if (!success) {
                revert NativeTokenTransferGenericFailure(
                    recipient,
                    address(this).balance
                );
            }

            return this.cleanup.selector;
        }

        // Required to silence a compiler warning.
        return this.cleanup.selector;
    }

    /**
     * @dev Enable accepting native tokens. Note that it may be prudent to only
     *      allow for receipt of native tokens from either the sidecar or the
     *      flashloan offerer as an added precaution against accidental loss.
     */
    receive() external payable {}

    /**
     * @dev Enable accepting ERC721 tokens via safeTransfer.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external payable returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @dev Enable accepting ERC1155 tokens via safeTransfer.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external payable returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @dev Ratifies an order with the specified offer, consideration, and
     *      optional context (supplied as extraData).
     *
     * @custom:param offer         The offer items.
     * @custom:param consideration The consideration items.
     * @custom:param context       Additional context of the order.
     * @custom:param orderHashes   The hashes to ratify.
     * @custom:param contractNonce The nonce of the contract.
     *
     * @return ratifyOrderMagicValue The magic value returned by the contract
     *                               offerer.
     */
    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */, // encoded based on the schemaID
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external pure override returns (bytes4 ratifyOrderMagicValue) {
        // Silence compiler warning.
        ratifyOrderMagicValue = bytes4(0);
        return this.ratifyOrder.selector;
    }

    /**
     * @dev View function to preview an order generated in response to a minimum
     *      set of received items, maximum set of spent items, and context
     *      (supplied as extraData).
     *
     * @custom:param caller      The address of the caller (e.g. Seaport).
     * @custom:param fulfiller    The address of the fulfiller (e.g. the account
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
        return ("GenericAdapter", schemas);
    }
}
