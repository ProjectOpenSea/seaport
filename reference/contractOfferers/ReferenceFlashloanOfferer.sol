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
        address _fulfiller = fulfiller;
        
        // Revert if the maximumSpent array is not exactly 1 item long.
        if (maximumSpent.length != 1) {
            revert InvalidTotalMaximumSpentItems();
        }

        // Get the maximumSpent item and amount.
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
            if (
                minimumReceivedItem.amount > maximumSpentAmount ||
                unacceptableItemTypePair ||
                unacceptableAddressPair ||
                minimumReceivedItemTypeAddressMismatch ||
                maximumSpentItemTypeAddressMismatch
            ) {
                revert InvalidItems();
            }

            // Process the deposit or withdrawal.
            _processDepositOrWithdrawal(
                _fulfiller,
                minimumReceivedItem,
                context
            );
        } else {
            // Revert if the minimumReceived array is not 0 or 1 items long.
            revert InvalidTotalMinimumReceivedItems();
        }

        // Convert the maximumSpent item to a ReceivedItem.
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
        // Silence compiler warning.
        ratifyOrderMagicValue = bytes4(0); 

        // If the caller is not Seaport, revert.
        if (msg.sender != _SEAPORT) {
            revert InvalidCaller(msg.sender);
        }

        // If context is present...
        if (context.length > 0) {
            // ...look for flashloans with callback flags.

            // The First byte of the context is the schema ID.
            // Bytes at indexes 1-21 of the context are the cleanup recipient
            //address.
            // Bytes n-n of the context are the flashloan data length.
            // 36-40?  44-52?  24-32?

            // Extract the cleanup recipient address from the context.
            address cleanupRecipient = address(
                // My God the assembly might be clearer than this.
                uint160(bytes20(context[1:21]))
            );
            // TODO: Come back and figure this out.  I thought I had it but now
            // I'm confused as hell.
            uint256 flashloanDataLengthRaw = uint256(
                bytes32(context[36:40])
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

                // TODO: Switch all ranges in comments to use indexes.
                // The first 21 bytes of the context are the cleanup recipient
                // address, which is where the `flashloanDataInitialOffset`
                // comes from.
                // So, the first flashloan starts at byte 22 and goes to byte
                // 53.  The next is 54-85, etc. `startingIndex` and
                // `endingIndex` define the range of bytes for each flashloan.
                startingIndex = flashloanDataInitialOffset + i - 32;
                endingIndex = flashloanDataInitialOffset + i;

                // Each flashloan is 32 bytes long.
                // Bytes at indexes 0-10 are the value, at index 11 is the
                // callback flag, and indexes 12-31 are the recipient address.

                // Extract the shouldCall flag from the flashloan data.
                shouldCall = context[startingIndex + 11] == 0x01;
                // Extract the recipient address from the flashloan data.
                address recipient = address(
                    uint160(bytes20(context[endingIndex - 20:endingIndex]))
                );

                // TODO: Figure out where I should be using `shouldCall`.
                // Call the recipient's cleanup function.
                (bool success, bytes memory returnData) = recipient.call{
                    value: 0
                }(
                    abi.encodeWithSignature(
                        "cleanup(address)",
                        cleanupRecipient
                    )
                );

                // TODO: Fix `this.cleanup.selector`.
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
        return ("FlashloanOfferer", schemas);
    }

    function _processFlashloan(
        bytes calldata context
    ) internal returns (uint256 totalSpent) {
        // Get the length of the context array from calldata.
        uint256 contextLength = uint256(bytes32(context[24:32]));

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
            uint256 flashloanLength = uint256(bytes32(context[36:40]));

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

            // TODO: Switch all ranges in comments to use indexes.
            // The first 21 bytes of the context are the cleanup recipient
            // address, which is where the `flashloanDataInitialOffset`
            // comes from.
            // So, the first flashloan starts at byte 22 and goes to byte
            // 53.  The next is 54-85, etc. `startingIndex` and
            // `endingIndex` define the range of bytes for each flashloan.
            startingIndex = flashloanDataInitialOffset + i - 32;
            endingIndex = flashloanDataInitialOffset + i;

            // Bytes at indexes 0-10 are the value, at index 11 is the flag, and
            // at indexes 12-31 are the recipient address.
            value = uint256(bytes32(context[startingIndex:11]));
            recipient = address(
                uint160(bytes20(context[endingIndex - 20:endingIndex]))
            );

            // Track the total value of all flashloans for a subsequent check in
            // `generateOrder`.
            totalValue += value;

            // Send the flashloan to the recipient.
            (bool success, ) = recipient.call{ value: value }("");

            // If the call fails, revert.
            if (!success) {
                revert CallFailed();
            }
        }

        // Return the total value of all flashloans.
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

        // If the item has this contract as its token, process as a deposit...
        if (spentItem.token == address(this)) {
            balanceOf[fulfiller] += spentItem.amount;
        } else {
            // ...otherwise it is a withdrawal.
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
