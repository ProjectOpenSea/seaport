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

/**
 * @title ReferenceFlashloanOfferer
 * @author 0age
 * @notice FlashloanOfferer is a proof of concept for a flashloan contract
 *         offerer. It will send native tokens to each specified recipient in
 *         the given amount when generating an order, and can optionally trigger
 *         callbacks for those recipients when ratifying the order after it has
 *         executed. It will aggregate all provided native tokens and return a
 *         single maximumSpent item with itself as the recipient for the total
 *         amount of aggregated native tokens. This is the reference
 *         implementation.
 */
contract ReferenceFlashloanOfferer is ContractOffererInterface {
    address private immutable _SEAPORT;

    mapping(address => uint256) public balanceOf;

    error InvalidCaller(address caller);
    error InvalidTotalMaximumSpentItems();
    error InsufficientMaximumSpentAmount();
    error InvalidItems();
    error InvalidTotalMinimumReceivedItems();
    error UnsupportedExtraDataVersion(uint8 version);
    error InvalidExtraDataEncoding(uint8 version);
    error CallFailed(); // 0x3204506f
    error NotImplemented();

    constructor(address seaport) {
        _SEAPORT = seaport;
    }

    // TODO: Fix.
    function cleanup(address) external payable returns (bytes4) {
        return this.cleanup.selector;
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items, and optional context (supplied as extraData).
     *
     * @param fulfiller       The address of the fulfiller.
     * @param minimumReceived The minimum items that the caller must receive. If
     *                        empty, the caller is requisitioning a flashloan. A
     *                        single ERC20 item with this contract as the token
     *                        indicates a native token deposit and must have an
     *                        accompanying native token item as maximumSpent; a
     *                        single native item indicates a withdrawal and must
     *                        have an accompanying ERC20 item with this contract
     *                        as the token, where in both cases the amounts must
     *                        be equal.
     * @param maximumSpent    The maximum items the caller is willing to spend.
     *                        For flashloans, a single native token item must be
     *                        provided with amount not less than the sum of all
     *                        flashloaned amounts.
     * @param context         Additional context of the order when flashloaning:
     *                          - cleanupRecipient: arg for cleanup (20 bytes)
     *                          - totalRecipients: flashloans to send (1 byte)
     *                              - amount (11 bytes * totalRecipients)
     *                              - shouldCallback (1 byte * totalRecipients)
     *                              - recipient (20 bytes * totalRecipients)
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration An array containing a single consideration item,
     *                       with this contract named as the recipient. The item
     *                       type and amount will depend on the type of order.
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
        if (maximumSpent.length != 1) {
            revert InvalidTotalMaximumSpentItems();
        }

        // struct SpentItem {
        //     ItemType itemType;
        //     address token;
        //     uint256 identifier;
        //     uint256 amount;
        // }

        SpentItem calldata maximumSpentItem = maximumSpent[0];
        uint256 maximumSpentAmount = maximumSpentItem.amount;

        if (minimumReceived.length == 0) {
            // No minimumReceived items indicates to perform a flashloan.
            if (_processFlashloan(context) > maximumSpentAmount) {
                revert InsufficientMaximumSpentAmount();
            }
        } else if (minimumReceived.length == 1) {
            // One minimumReceived item indicates a deposit or withdrawal.
            SpentItem calldata minimumReceivedItem = minimumReceived[0];

            bool unacceptableItemTypePair = (minimumReceivedItem.itemType ==
                ItemType.ERC20 &&
                maximumSpentItem.itemType == ItemType.NATIVE) ||
                (minimumReceivedItem.itemType == ItemType.NATIVE &&
                    maximumSpentItem.itemType == ItemType.ERC20);

            bool unacceptableAddressPair = (minimumReceivedItem.token ==
                address(this) &&
                maximumSpentItem.token == address(0)) ||
                (minimumReceivedItem.token == address(0) &&
                    maximumSpentItem.token == address(this));

            bool minimumReceivedItemTypeAddressMismatch = (minimumReceivedItem
                .itemType ==
                ItemType.ERC20 &&
                minimumReceivedItem.token == address(this)) ||
                (minimumReceivedItem.itemType == ItemType.NATIVE &&
                    minimumReceivedItem.token == address(0));

            bool maximumSpentItemTypeAddressMismatch = (maximumSpentItem
                .itemType ==
                ItemType.ERC20 &&
                maximumSpentItem.token == address(this)) ||
                (maximumSpentItem.itemType == ItemType.NATIVE &&
                    maximumSpentItem.token == address(0));

            // Revert if minimumReceived item amount is greater than
            // maximumSpent, or if any of the following are not true:
            //  - one of the item types is 1 and the other is 0
            //  - one of the tokens is address(this) and the other is null
            //  - item type 1 has address(this) token and 0 is null token
            // TODO: add comments on why lol
            // TODO: Make sure that the reference implementation matches the
            //       assembly and not just the comments.
            if (
                minimumReceivedItem.amount > maximumSpentAmount ||
                unacceptableItemTypePair ||
                unacceptableAddressPair ||
                minimumReceivedItemTypeAddressMismatch ||
                maximumSpentItemTypeAddressMismatch
            ) {
                revert InvalidItems();
            }

            _processDepositOrWithdrawal(
                fulfiller,
                minimumReceivedItem,
                context
            );
        } else {
            revert InvalidTotalMinimumReceivedItems();
        }

        consideration = new ReceivedItem[](1);
        consideration[0] = _copySpentAsReceivedToSelf(maximumSpentItem);

        return (minimumReceived, consideration);
    }

    /**
     * @dev Enable accepting native tokens.
     */
    receive() external payable {}

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
        bytes calldata context, // encoded based on the schemaID
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external override returns (bytes4 ratifyOrderMagicValue) {
        ratifyOrderMagicValue = bytes4(0);

        // If caller is not Seaport, revert.
        if (msg.sender != _SEAPORT) {
            revert InvalidCaller(msg.sender);
        }

        // TODO: check all of this stuff for off by one errors, etc.
        // If context is present...
        if (context.length > 0) {
            // ...look for flashloans with callback flags.
            bytes memory cleanupRecipientBytes = context[1:21];
            // Extract the cleanup recipient address from the context.
            address cleanupRecipient = address(
                // My God the assembly might be clearer than this.
                uint160(bytes20(cleanupRecipientBytes))
            );

            bytes memory flashloanDataLengthRawBytes = context[36:40];
            uint256 flashloanDataLengthRaw = uint256(
                bytes32(flashloanDataLengthRawBytes)
            );
            uint256 flashloanDataLength = 5 * (2 ^ flashloanDataLengthRaw);

            uint256 flashloanDataInitialOffset = 21;
            uint256 startingIndex;
            uint256 endingIndex;
            bool shouldCall;

            // Iterate over each flashloan, one word of memory at a time.
            for (uint256 i = 0; i < flashloanDataLength; ) {
                // Increment i by 32 bytes (1 word) to get the next word.
                i += 32;

                // The first 21 bytes are the cleanup recipient address, which
                // is where the `flashloanDataInitialOffset` comes from.
                // So, the first flashloan starts at byte 21 and goes to byte
                // 53.  The next is 54-86, etc.
                startingIndex = flashloanDataInitialOffset + i - 32;
                endingIndex = flashloanDataInitialOffset + i;

                // Bytes at indexes 0-10 are the value, at index 11 is the flag,
                // and at indexes 12-31 are the recipient address.

                // Extract the shouldCall flag from the flashloan data.
                shouldCall = context[startingIndex + 11] == 0x01;

                // Extract the recipient address from the flashloan data.
                address recipient = address(
                    uint160(bytes20(context[endingIndex - 20:endingIndex]))
                );

                (bool success, bytes memory returnData) = recipient.call{
                    value: 0
                }(
                    abi.encodeWithSignature(
                        "cleanup(address)",
                        cleanupRecipient
                    )
                );

                // TODO: Fix.
                if (
                    success == false ||
                    bytes4(returnData) != this.cleanup.selector
                ) {
                    revert CallFailed();
                }
            }

            // If everything's OK, return the magic value.
            return bytes4(this.ratifyOrder.selector);
        }

        // // If there is any context, trigger designated callbacks & provide data.
        // assembly {
        //     // If context is present, look for flashloans with callback flags.
        //     if and(calldataload(context.offset), 0xfffffff) {
        //         // let cleanupRecipient := calldataload(add(context.offset, 1))
        //         // let flashloanDataStarts := add(context.offset, 21)

        //         // calldataload(add(context.offset, 20))
        //         // ==
        //         // A word of memory starting 20 bytes (1 address worth?) into
        //         // the context arg.  bytes 20-40?

        //         // and(0xff, calldataload(add(context.offset, 20)))
        //         // [masks off all but the last 4 bytes of the result]
        //         // ==
        //         // maskedValue would be something like 0x0000...0000111111111.

        //         // shl(0x05, and(0xff, calldataload(add(context.offset, 20))))
        //         // [shl is equivalent to multiplying by 2^n]
        //         // so this is like 5 * 2^(maskedValue)?

        //         // add(
        //         //     flashloanDataStarts,
        //         //     shl(0x05, and(0xff, calldataload(add(context.offset, 20))))
        //         // )

        //         // I think the net of this is to add the start value to the
        //         // length of the flashloan data, which is encoded at
        //         // context[36:40].

        //         // I don't need to worry about the add, since I can do `context`

        //         // let flashloanDataEnds := add(
        //         //     flashloanDataStarts,
        //         //     shl(0x05, and(0xff, calldataload(add(context.offset, 20))))
        //         // )

        //         // // This stores the selector for the cleanup function at 0.
        //         // mstore(0, 0xfbacefce) // cleanup(address) selector
        //         // // This stores the cleanup recipient address at 0x20 (so it's)
        //         // // the first [and only] argument.
        //         // mstore(0x20, cleanupRecipient)

        //         // // I can skip that stuff.

        //         // Iterate over each flashloan.
        //         // Set up the iterator already.
        //         // for {
        //         //     let flashloanDataOffset := flashloanDataStarts
        //         // } lt(flashloanDataOffset, flashloanDataEnds) {
        //         //     flashloanDataOffset := add(flashloanDataOffset, 0x20)
        //         // } {
        //         //     // // Note: confirm that this is the correct usage of byte opcode
        //         //     // let shouldCall := byte(
        //         //     //     12,
        //         //     //     calldataload(flashloanDataOffset)
        //         //     // )

        //         //     // let recipient := and(
        //         //     //     0xffffffffffffffffffffffffffffffffffffffff,
        //         //     //     calldataload(flashloanDataOffset)
        //         //     // )

        //         //     // FROM JAMES: since each word is 32-bytes, storing a 4-byte
        //         //     // value means the first 28 bytes (0x1C in hex) are empty

        //         //     // Fire off call to recipient. Revert & bubble up revert data if
        //         //     // present & reasonably-sized, else revert with a custom error.
        //         //     // Note that checking for sufficient native token balance is an
        //         //     // option here if more specific custom reverts are preferred.
        //         //     let success := call(
        //         //         gas(), // gas
        //         //         recipient, // address
        //         //         0, // value
        //         //         0x1c, // argsOffset, 28
        //         //         0x24, // argsSize, 36
        //         //         0, // retOffset, 0
        //         //         4 // retSize, 4
        //         //     )

        //         //     if or(
        //         //         // If it fails or doesn't return the magic value, revert.
        //         //         iszero(success),
        //         //         xor(
        //         //             mload(0),
        //         //             0xfbacefce000000000000000000000000000000000000000000000000fbacefce
        //         //         )
        //         //     ) {
        //         //         if and(
        //         //             and(
        //         //                 iszero(success),
        //         //                 iszero(iszero(returndatasize()))
        //         //             ),
        //         //             lt(returndatasize(), 0xffff)
        //         //         ) {
        //         //             returndatacopy(0, 0, returndatasize())
        //         //             revert(0, returndatasize())
        //         //         }

        //         //         // CallFailed()
        //         //         mstore(0, 0x3204506f)
        //         //         revert(0x1c, 0x04)
        //         //     }
        //         // }
        //     }

        //     mstore(0, 0xf4dd92ce)
        //     return(0x1c, 0x04)
        // }
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
        return ("FlashloanOfferer", schemas);
    }

    function _processFlashloan(
        bytes calldata context
    ) internal returns (uint256 totalSpent) {
        // Get the length of the context array from calldata (masked).
        // uint256 contextLength;
        // assembly {
        //     contextLength := and(calldataload(context.offset), 0xfffffff)
        // }

        bytes memory contextLengthRawBytes = context[24:32];
        uint256 contextLength = uint256(bytes32(contextLengthRawBytes));

        uint256 flashloanDataLength;
        {
            // Check is that caller is Seaport.
            if (msg.sender != _SEAPORT) {
                revert InvalidCaller(msg.sender);
            }

            // Check for sip-6 version byte.
            if (context[0] != 0x00) {
                revert UnsupportedExtraDataVersion(uint8(context[0]));
            }

            // Retrieve the number of flashloans.
            bytes memory LengthRawBytes = context[36:40];
            uint256 flashloanLength = uint256(bytes32(LengthRawBytes));

            // Include one word of flashloan data for each flashloan.
            flashloanDataLength = 5 * (2 ^ flashloanLength);

            if (contextLength < 22 + flashloanDataLength) {
                revert InvalidExtraDataEncoding(uint8(context[0]));
            }
        }

        uint256 flashloanDataInitialOffset = 21;
        uint256 startingIndex;
        uint256 endingIndex;
        uint256 value;
        address recipient;
        uint256 totalValue;

        // Iterate over each flashloan, one word of memory at a time.
        for (uint256 i = 0; i < flashloanDataLength; ) {
            // Increment i by 32 bytes (1 word) to get the next word.
            i += 32;

            // The first 21 bytes are the cleanup recipient address, which
            // is where the `flashloanDataInitialOffset` comes from.
            // So, the first flashloan starts at byte 21 and goes to byte
            // 53.  The next is 54-86, etc.
            startingIndex = flashloanDataInitialOffset + i - 32;
            endingIndex = flashloanDataInitialOffset + i;

            // Bytes at indexes 0-10 are the value, at index 11 is the flag, and
            // at indexes 12-31 are the recipient address.
            value = uint256(bytes32(context[startingIndex:11]));
            recipient = address(
                uint160(bytes20(context[endingIndex - 20:endingIndex]))
            );

            totalValue += value;

            (bool success, ) = recipient.call{ value: value }("");

            if (!success) {
                revert CallFailed();
            }
        }

        return totalValue;
    }

    function _processDepositOrWithdrawal(
        address fulfiller,
        SpentItem calldata spentItem,
        bytes calldata context
    ) internal {
        // Get the length of the context array from calldata (unmasked).
        uint256 contextLength = uint256(bytes32(context));

        // Check is that caller is Seaport.
        if (msg.sender != _SEAPORT) {
            revert InvalidCaller(msg.sender);
        }

        // Next, check that context is empty.
        if (contextLength != 0) {
            revert InvalidExtraDataEncoding(0);
        }

        // if the item has this contract as its token, process as a deposit.
        if (spentItem.token == address(this)) {
            balanceOf[fulfiller] += spentItem.amount;
        } else {
            // otherwise it is a withdrawal.
            balanceOf[fulfiller] -= spentItem.amount;
        }
    }

    /**
     * @dev Copies a spent item from calldata and converts into a received item,
     *      applying address(this) as the recipient. Note that this currently
     *      clobbers the word directly after the spent item in memory.
     *
     * @param spentItem The spent item.
     *
     * @return receivedItem The received item.
     */
    function _copySpentAsReceivedToSelf(
        SpentItem calldata spentItem
    ) internal view returns (ReceivedItem memory receivedItem) {
        return
            ReceivedItem({
                itemType: spentItem.itemType,
                token: spentItem.token,
                identifier: spentItem.identifier,
                amount: spentItem.amount,
                recipient: payable(address(this))
            });
    }
}
