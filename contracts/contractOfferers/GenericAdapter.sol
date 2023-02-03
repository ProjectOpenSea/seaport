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

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

/**
 * @title GenericAdapter
 * @author 0age
 * @notice GenericAdapter is a proof of concept for a contract offerer that can
 *         source liquidity from arbitrary targets, such as other marketplaces,
 *         and make those liquidity sources available from within Seaport. Care
 *         must be taken when interacting with this contract, as it expects any
 *         tokens necessary to procure the requested offer items to be provided
 *         to this contract prior to order generation and can interact with
 *         arbitrary targets; do not directly approve this contract to transfer
 *         tokens and ensure that appropriate minimumReceived / offer item
 *         arrays are supplied. Also note that any time this contract is used as
 *         part of a call to a "fulfillAvailable" method, a failure that causes
 *         the order to be skipped may orphan tokens that were previously sent
 *         to the contract must be retrieved by calling `retrieveTokens` from
 *         the designated router contract.
 */
contract GenericAdapter is ContractOffererInterface, TokenTransferrer {
    address private immutable _SEAPORT;
    address private immutable _ROUTER;

    error InvalidCaller(address caller);
    error InvalidFulfiller(address fulfiller);
    error UnsupportedExtraDataVersion(uint8 version);
    error InvalidExtraDataEncoding(uint8 version);
    error ApprovalFailed(address approvalTarget); // 0xe5a0a42f
    error CallFailed(address target); // 0x201be191
    error NativeTokenTransferGenericFailure(address account, uint256 amount); // 0xbc806b96
    error NotImplemented();

    constructor(address seaport, address router) {
        _SEAPORT = seaport;
        _ROUTER = router;
    }

    /**
     * @dev Enable the router contract to send native tokens to this contract.
     */
    receive() external payable {
        if (msg.sender != _ROUTER) {
            revert InvalidFulfiller(msg.sender);
        }
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items, and optional context (supplied as extraData).
     *
     * @param fulfiller       The address of the fulfiller.
     * @param minimumReceived The minimum items that the caller is willing to
     *                        receive.
     * @custom:param maxSpent The maximum items the caller is willing to spend.
     * @param context         Additional context of the order:
     *                          - target: contract to provide payload (20 bytes)
     *                          - value: native tokens to supply (12 bytes)
     *                          - totalApprovals: approvals to make (1 byte)
     *                              - approvalTarget (20 bytes * totalApprovals)
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

        // Declare an error buffer; first check is that the caller is Seaport.
        uint256 errorBuffer = _cast(msg.sender == _SEAPORT);

        // Next, check that the fulfiller is the router.
        errorBuffer |= errorBuffer ^ (_cast(fulfiller == _ROUTER) << 1);

        // Next, check for sip-6 version byte.
        errorBuffer |= errorBuffer ^ (_cast(context[0] == 0x00) << 2);

        // Retrieve the target and the number of approvals to perform.
        address target;
        uint256 value;
        uint256 approvalDataSize;
        assembly {
            let targetAndValue := calldataload(add(context.offset, 33))
            target := shr(96, targetAndValue)
            value := and(0xffffffffffffffffffffffff, targetAndValue)
            let totalApprovals := and(
                0xff,
                calldataload(add(context.offset, 34))
            )
            approvalDataSize := mul(totalApprovals, 41)
        }

        // Next, check for sufficient context length.
        unchecked {
            errorBuffer |=
                errorBuffer ^
                (_cast(contextLength < 34 + approvalDataSize) << 3);
        }

        // Handle decoding errors.
        if (errorBuffer != 0) {
            uint8 version = uint8(context[0]);

            if (errorBuffer << 255 != 0) {
                revert InvalidCaller(msg.sender);
            } else if (errorBuffer << 254 != 0) {
                revert InvalidFulfiller(fulfiller);
            } else if (errorBuffer << 253 != 0) {
                revert UnsupportedExtraDataVersion(version);
            } else if (errorBuffer << 252 != 0) {
                revert InvalidExtraDataEncoding(version);
            }
        }

        // Perform approvals (if any) followed by generic call to the target.
        assembly {
            // Derive the location where approval data starts and ends.
            let approvalDataStarts := add(context.offset, 66)
            let approvalDataEnds := add(approvalDataStarts, approvalDataSize)

            // Iterate over each approval.
            for {
                let i := approvalDataStarts
            } lt(i, approvalDataEnds) {
                i := add(i, 41)
            } {
                // Attempt to process each approval. This only needs to be done
                // once per target per token. The approval type is even (for
                // ERC20) or odd (for ERC721 / 1155) and is converted to 0 or 1.
                let approvalTarget := shr(96, calldataload(i))
                let approvalType := and(0x01, calldataload(sub(i, 11)))
                let approvalToken := shr(96, calldataload(add(i, 21)))
                let approvalValue := sub(approvalType, iszero(approvalType))
                let selector := shl(
                    224,
                    add(
                        mul(0x095ea7b3, iszero(approvalType)),
                        mul(0xa22cb465, approvalType)
                    )
                )

                // Put calldata in scratch space & some of free memory pointer.
                mstore(0, selector)
                mstore(4, approvalTarget)
                mstore(36, approvalValue)

                // Fire off the call to the token, bubbling up reverts.
                let success := call(gas(), approvalToken, 0, 0, 68, 0, 0)

                if iszero(success) {
                    if and(returndatasize(), lt(returndatasize(), 0xffff)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    mstore(0, 0xe5a0a42f)
                    mstore(0x20, approvalToken)
                    revert(0x1c, 0x24)
                }
            }

            // Clear dirty upper bits from free memory pointer.
            mstore(36, 0)

            // Get the free memory pointer.
            let freeMemoryPointer := mload(0x40)

            // Get the size of the payload.
            let payloadSize := sub(contextLength, add(34, approvalDataSize))

            // Copy the payload into memory at the free memory pointer.
            calldatacopy(freeMemoryPointer, approvalDataEnds, payloadSize)

            // Fire off the call to the target, bubbling up reverts if present.
            let success := call(
                gas(),
                target,
                value,
                freeMemoryPointer,
                payloadSize,
                0,
                0
            )

            if iszero(success) {
                if and(returndatasize(), lt(returndatasize(), 0xffff)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                mstore(0, 0x201be191)
                mstore(0x20, target)
                revert(0x1c, 0x24)
            }
        }

        return (minimumReceived, new ReceivedItem[](0));
    }

    /**
     * @dev Allows the designated router to return tokens it has supplied to the
     *      contract in the event of a failure to generate the associated order.
     *
     * @param tokens    The tokens to send back to the designated recipient.
     *                  Note that native tokens will be automatically returned.
     * @param recipient The account to send back tokens to.
     */
    function returnTokens(
        SpentItem[] calldata tokens,
        address payable recipient
    ) external {
        if (msg.sender != _ROUTER) {
            revert InvalidFulfiller(msg.sender);
        }

        // Return native tokens.
        assembly {
            if selfbalance() {
                let success := call(gas(), recipient, selfbalance(), 0, 0, 0, 0)
                if iszero(success) {
                    if and(returndatasize(), lt(returndatasize(), 0xffff)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    mstore(0, 0xbc806b96)
                    mstore(0x20, recipient)
                    mstore(0x40, selfbalance())
                    revert(0x1c, 0x44)
                }
            }
        }

        // Perform token transfers. Note that this can be optimized quite a bit
        // from here; for instance, this is using transferFrom rather than a
        // vanilla transfer.
        uint256 totalTokens = tokens.length;
        for (uint256 i = 0; i < totalTokens; ) {
            SpentItem calldata item = tokens[i];

            ItemType itemType = item.itemType;
            if (itemType == ItemType.ERC20) {
                _performERC20Transfer(
                    item.token,
                    address(this),
                    recipient,
                    item.amount
                );
            } else if (itemType == ItemType.ERC721) {
                _performERC721Transfer(
                    item.token,
                    address(this),
                    recipient,
                    item.identifier
                );
            } else {
                _performERC1155Transfer(
                    item.token,
                    address(this),
                    recipient,
                    item.identifier,
                    item.amount
                );
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Enable the router contract to send ERC1155 tokens to this contract.
     */
    function onERC1155Received(
        address operator,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external view returns (bytes4) {
        if (operator != _ROUTER) {
            revert InvalidFulfiller(msg.sender);
        }

        return bytes4(0xf23a6e61);
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
    ) external pure override returns (bytes4) {
        // Utilize assembly to efficiently return the ratifyOrder magic value.
        assembly {
            mstore(0, 0xf4dd92ce)
            return(0x1c, 0x04)
        }
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
        return ("GenericAdapter", schemas);
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
