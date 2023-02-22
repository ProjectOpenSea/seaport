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

/**
 * @title FlashloanOfferer
 * @author 0age
 * @notice FlashloanOfferer is a proof of concept for a flashloan contract
 *         offerer. It will send native tokens to each specified recipient in
 *         the given amount when generating an order, and can optionally trigger
 *         callbacks for those recipients when ratifying the order after it has
 *         executed. It will aggregate all provided native tokens and return a
 *         single maximumSpent item with itself as the recipient for the total
 *         amount of aggregated native tokens.
 */
contract FlashloanOfferer is ContractOffererInterface {
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

        SpentItem calldata maximumSpentItem = maximumSpent[0];

        uint256 maximumSpentAmount;
        assembly {
            maximumSpentAmount := calldataload(add(maximumSpentItem, 0x60))
        }

        if (minimumReceived.length == 0) {
            // No minimumReceived items indicates to perform a flashloan.
            if (_processFlashloan(context) > maximumSpentAmount) {
                revert InsufficientMaximumSpentAmount();
            }
        } else if (minimumReceived.length == 1) {
            // One minimumReceived item indicates a deposit or withdrawal.
            SpentItem calldata minimumReceivedItem = minimumReceived[0];

            assembly {
                // Revert if minimumReceived item amount is greater than
                // maximumSpent, or if any of the following are not true:
                //  - one of the item types is 1 and the other is 0
                //  - one of the tokens is address(this) and the other is null
                //  - item type 1 has address(this) token and 0 is null token
                if or(
                    or(
                        gt(
                            calldataload(add(minimumReceivedItem, 0x60)),
                            maximumSpentAmount
                        ),
                        or(
                            iszero(
                                eq(
                                    add(
                                        and(
                                            calldataload(minimumReceivedItem),
                                            0xff
                                        ),
                                        and(
                                            calldataload(maximumSpentItem),
                                            0xff
                                        )
                                    ),
                                    0x01
                                )
                            ),
                            iszero(
                                eq(
                                    add(
                                        mul(
                                            calldataload(minimumReceivedItem),
                                            calldataload(
                                                add(minimumReceivedItem, 0x20)
                                            )
                                        ),
                                        mul(
                                            calldataload(maximumSpentItem),
                                            calldataload(
                                                add(maximumSpentItem, 0x20)
                                            )
                                        )
                                    ),
                                    address()
                                )
                            )
                        )
                    ),
                    iszero(
                        and(
                            iszero(
                                mul(
                                    calldataload(
                                        add(minimumReceivedItem, 0x20)
                                    ),
                                    calldataload(add(maximumSpentItem, 0x20))
                                )
                            ),
                            iszero(
                                xor(
                                    add(
                                        calldataload(
                                            add(minimumReceivedItem, 0x20)
                                        ),
                                        calldataload(
                                            add(maximumSpentItem, 0x20)
                                        )
                                    ),
                                    address()
                                )
                            )
                        )
                    )
                ) {
                    // revert InvalidItems()
                    mstore(0, 0x913c728a)
                    revert(0x1c, 0x04)
                }
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
    ) external override returns (bytes4) {
        if (msg.sender != _SEAPORT) {
            revert InvalidCaller(msg.sender);
        }

        // If there is any context, trigger designated callbacks & provide data.
        assembly {
            // If context is present, look for flashloans with callback flags.
            if and(calldataload(context.offset), 0xfffffff) {
                let cleanupRecipient := calldataload(add(context.offset, 1))
                let flashloanDataStarts := add(context.offset, 21)
                let flashloanDataEnds := add(
                    flashloanDataStarts,
                    shl(0x05, and(0xff, calldataload(add(context.offset, 20))))
                )

                mstore(0, 0xfbacefce) // cleanup(address) selector
                mstore(0x20, cleanupRecipient)

                // Iterate over each flashloan.
                for {
                    let flashloanDataOffset := flashloanDataStarts
                } lt(flashloanDataOffset, flashloanDataEnds) {
                    flashloanDataOffset := add(flashloanDataOffset, 0x20)
                } {
                    // Note: confirm that this is the correct usage of byte opcode
                    let flashloanData := calldataload(flashloanDataOffset)
                    // let shouldCall := byte(12, flashloanData)
                    let recipient := and(
                        0xffffffffffffffffffffffffffffffffffffffff,
                        flashloanData
                    )
                    let value := shr(168, flashloanData)

                    // Fire off call to recipient. Revert & bubble up revert
                    // data if present & reasonably-sized, else revert with a
                    // custom error. Note that checking for sufficient native
                    // token balance is an option here if more specific custom
                    // reverts are preferred.
                    let success := call(
                        gas(),
                        recipient,
                        value,
                        0x1c,
                        0x24,
                        0,
                        4
                    )

                    if or(
                        iszero(success),
                        xor(
                            mload(0),
                            0xfbacefce000000000000000000000000000000000000000000000000fbacefce
                        )
                    ) {
                        if and(
                            and(
                                iszero(success),
                                iszero(iszero(returndatasize()))
                            ),
                            lt(returndatasize(), 0xffff)
                        ) {
                            returndatacopy(0, 0, returndatasize())
                            revert(0, returndatasize())
                        }

                        // CallFailed()
                        mstore(0, 0x3204506f)
                        revert(0x1c, 0x04)
                    }
                }
            }

            // return RatifyOrderMagicValue
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
        // Get the length of the context array from calldata (masked).
        uint256 contextLength;
        assembly {
            contextLength := and(calldataload(context.offset), 0xfffffff)
        }

        uint256 flashloanDataSize;
        {
            // Declare an error buffer; first check is that caller is Seaport.
            uint256 errorBuffer = _cast(msg.sender == _SEAPORT);

            // Next, check for sip-6 version byte.
            errorBuffer |= errorBuffer ^ (_cast(context[0] == 0x00) << 1);

            // Retrieve the number of flashloans.
            assembly {
                let totalFlashloans := and(
                    0xff,
                    calldataload(add(context.offset, 20))
                )

                // Include one word of flashloan data for each flashloan.
                flashloanDataSize := shl(0x05, totalFlashloans)
            }

            // Next, check for sufficient context length.
            unchecked {
                errorBuffer |=
                    errorBuffer ^
                    (_cast(contextLength < 22 + flashloanDataSize) << 2);
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

        uint256 totalValue;

        assembly {
            let flashloanDataStarts := add(context.offset, 21)
            let flashloanDataEnds := add(flashloanDataStarts, flashloanDataSize)
            // Iterate over each flashloan.
            for {
                let flashloanDataOffset := flashloanDataStarts
            } lt(flashloanDataOffset, flashloanDataEnds) {
                flashloanDataOffset := add(flashloanDataOffset, 0x20)
            } {
                let value := shr(168, calldataload(flashloanDataOffset))
                let recipient := and(
                    0xffffffffffffffffffffffffffffffffffffffff,
                    calldataload(flashloanDataOffset)
                )

                totalValue := add(totalValue, value)

                // Fire off call to recipient. Revert & bubble up revert data if
                // present & reasonably-sized, else revert with a custom error.
                // Note that checking for sufficient native token balance is an
                // option here if more specific custom reverts are preferred.
                if iszero(call(gas(), recipient, value, 0, 0, 0, 0)) {
                    if and(
                        iszero(iszero(returndatasize())),
                        lt(returndatasize(), 0xffff)
                    ) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    // CallFailed()
                    mstore(0, 0x3204506f)
                    revert(0x1c, 0x04)
                }
            }
        }

        return totalValue;
    }

    function _processDepositOrWithdrawal(
        address fulfiller,
        SpentItem calldata spentItem,
        bytes calldata context
    ) internal {
        {
            // Get the length of the context array from calldata (unmasked).
            uint256 contextLength;
            assembly {
                contextLength := calldataload(context.offset)
            }

            // Declare an error buffer; first check is that caller is Seaport.
            uint256 errorBuffer = _cast(msg.sender == _SEAPORT);

            // Next, check that context is empty.
            errorBuffer |= errorBuffer ^ (_cast(contextLength == 0) << 1);

            // Handle decoding errors.
            if (errorBuffer != 0) {
                if (errorBuffer << 255 != 0) {
                    revert InvalidCaller(msg.sender);
                } else if (errorBuffer << 254 != 0) {
                    revert InvalidExtraDataEncoding(0);
                }
            }

            // if the item has this contract as its token, process as a deposit.
            if (spentItem.token == address(this)) {
                balanceOf[fulfiller] += spentItem.amount;
            } else {
                // otherwise it is a withdrawal.
                balanceOf[fulfiller] -= spentItem.amount;
            }
        }
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
        assembly {
            calldatacopy(receivedItem, spentItem, 0x80)
            mstore(add(receivedItem, 0x80), address())
        }
    }
}
