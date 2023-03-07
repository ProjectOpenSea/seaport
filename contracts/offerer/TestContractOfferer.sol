// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem
} from "../lib/ConsiderationStructs.sol";

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

// import { GenericAdapterSidecar } from "./GenericAdapterSidecar.sol";

interface ILooksRareExchange {
    struct MakerOrder {
        bool isOrderAsk; // true --> ask / false --> bid
        address signer; // signer of the maker order
        address collection; // collection address
        uint256 price; // price (used as )
        uint256 tokenId; // id of the token
        uint256 amount; // amount of tokens to sell/purchase (must be 1 for ERC721, 1+ for ERC1155)
        address strategy; // strategy for trade execution (e.g., DutchAuction, StandardSaleForFixedPrice)
        address currency; // currency (e.g., WETH)
        uint256 nonce; // order nonce (must be unique unless new maker order is meant to override existing one e.g., lower ask price)
        uint256 startTime; // startTime in timestamp
        uint256 endTime; // endTime in timestamp
        uint256 minPercentageToAsk; // slippage protection (9000 --> 90% of the final price must return to ask)
        bytes params; // additional parameters
        uint8 v; // v: parameter (27 or 28)
        bytes32 r; // r: parameter
        bytes32 s; // s: parameter
    }

    struct TakerOrder {
        bool isOrderAsk; // true --> ask / false --> bid
        address taker; // msg.sender
        uint256 price; // final price for the purchase
        uint256 tokenId;
        uint256 minPercentageToAsk; // // slippage protection (9000 --> 90% of the final price must return to ask)
        bytes params; // other params (e.g., tokenId)
    }

    function matchAskWithTakerBidUsingETHAndWETH(
        TakerOrder calldata takerBid,
        MakerOrder calldata makerAsk
    ) external payable;

    function matchAskWithTakerBid(
        TakerOrder calldata takerBid,
        MakerOrder calldata makerAsk
    ) external;

    function matchBidWithTakerAsk(
        TakerOrder calldata takerAsk,
        MakerOrder calldata makerBid
    ) external;
}

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

/**
 * @title GenericAdapter
 * @author 0age
 * @notice GenericAdapter is a proof of concept for a contract offerer that can
 *         source liquidity from arbitrary targets, such as other marketplaces,
 *         and make those liquidity sources available from within Seaport. It
 *         encapsulates arbitrary execution within a companion contract, called
 *         the "sidecar."
 */
contract TestContractOfferer is ContractOffererInterface, TokenTransferrer {
    address private immutable _SEAPORT;
    // address private immutable _SIDECAR;
    // address private immutable _FLASHLOAN_OFFERER;

    error InvalidCaller(address caller);
    error InvalidFulfiller(address fulfiller);
    error UnsupportedExtraDataVersion(uint8 version);
    error InvalidExtraDataEncoding(uint8 version);
    error ApprovalFailed(address approvalToken); // 0xe5a0a42f
    error CallFailed(); // 0x3204506f
    error NativeTokenTransferGenericFailure(address recipient, uint256 amount); // 0xbc806b96
    error NotImplemented();

    event SeaportCompatibleContractDeployed();

    constructor(address seaport /* , address flashloanOfferer */) {
        _SEAPORT = seaport;
        // _SIDECAR = address(new GenericAdapterSidecar());
        // _FLASHLOAN_OFFERER = flashloanOfferer;

        emit SeaportCompatibleContractDeployed();
    }

    event TestContractOffererEvent(
        address fulfiller,
        SpentItem[] minimumReceived,
        SpentItem[] maximumSpent,
        bytes context // encoded based on the schemaID
    );

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
        emit TestContractOffererEvent(
            fulfiller,
            minimumReceived,
            maximumSpent,
            context
        );

        require(
            IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).transferFrom(
                0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF, // from: bob
                address(this),
                maximumSpent[0].amount
            ),
            "generateOrder: transferFrom failed"
        );

        if (
            maximumSpent[0].token == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        ) {
            IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).withdraw(
                maximumSpent[0].amount
            );
        }

        IERC721(minimumReceived[0].token).setApprovalForAll(_SEAPORT, true);

        ILooksRareExchange.TakerOrder memory takerBid = ILooksRareExchange
            .TakerOrder(
                false, // bool isOrderAsk; // true --> ask / false --> bid
                address(this), // address taker; // msg.sender
                maximumSpent[0].amount, // uint256 price; // final price for the purchase
                minimumReceived[0].identifier, //  uint256 tokenId;
                9800, // uint256 minPercentageToAsk; // // slippage protection (9000 --> 90% of the final price must return to ask)
                hex"" // bytes params; // other params (e.g., tokenId)
            );
        ILooksRareExchange.MakerOrder memory makerAsk = ILooksRareExchange
            .MakerOrder(
                true, // bool isOrderAsk; // true --> ask / false --> bid
                0x073Ab1C0CAd3677cDe9BDb0cDEEDC2085c029579, // address signer; // signer of the maker order
                minimumReceived[0].token, // address collection; // collection address
                maximumSpent[0].amount, // uint256 price; // price (used as )
                minimumReceived[0].identifier, // id of the token
                minimumReceived[0].amount, // amount of tokens to sell/purchase (must be 1 for ERC721, 1+ for ERC1155)
                0x579af6FD30BF83a5Ac0D636bc619f98DBdeb930c, // address strategy; // strategy for trade execution (e.g., DutchAuction, StandardSaleForFixedPrice)
                0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // address currency; // currency (e.g., WETH)
                262, // uint256 nonce; // order nonce (must be unique unless new maker order is meant to override existing one e.g., lower ask price)
                1678202520, // uint256 startTime; // startTime in timestamp
                1680794498, // uint256 endTime; // endTime in timestamp
                9800, // uint256 minPercentageToAsk; // slippage protection (9000 --> 90% of the final price must return to ask)
                hex"", // bytes params; // additional parameters
                27, // uint8 v; // v: parameter (27 or 28)
                bytes32(
                    0x2f781d90b279ea589f6fd867ca34f68687aa79ead3b5f5ed30bf8b141134ee26
                ), // bytes32 r; // r: parameter
                bytes32(
                    0x45052e9e620e6fd5d3c8cffddabf9021e2306883d54bfb058e9a12849129b196
                ) // bytes32 s; // s: parameter
            );

        ILooksRareExchange(0x59728544B08AB483533076417FbBB2fD0B17CE3a)
            .matchAskWithTakerBidUsingETHAndWETH{
            value: maximumSpent[0].amount
        }(takerBid, makerAsk);

        // Get the length of the context array from calldata (masked).
        /* uint256 contextLength;
        assembly {
            contextLength := and(calldataload(context.offset), 0xfffffff)
        }

        uint256 approvalDataSize;

        {
            // Declare an error buffer; first check is that caller is Seaport.
            uint256 errorBuffer = _cast(msg.sender == _SEAPORT);

            // Next, check for sip-6 version byte.
            errorBuffer |= errorBuffer ^ (_cast(context[0] == 0x00) << 1);

            // Retrieve the target and the number of approvals to perform.
            assembly {
                let totalApprovals := and(
                    0xff,
                    calldataload(add(context.offset, 2))
                )
                approvalDataSize := mul(totalApprovals, 21)
            }

            // Next, check for sufficient context length.
            unchecked {
                errorBuffer |=
                    errorBuffer ^
                    (_cast(contextLength < 2 + approvalDataSize) << 2);
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

        // Perform approvals (if any) followed by generic call to the target.
        // NOTE: this could optionally use minimumReceived along with a flag for
        // determining whether or not to iterate over the items and any missing
        // approvals.
        uint256 approvalDataEnds;
        {
            // Read the approval target from runtime code and place on stack.
            address approvalTarget = _SEAPORT;
            assembly {
                // Get the free memory pointer.
                let freeMemoryPointer := mload(0x40)

                // Write Seaport to memory as the approval target. Reuse this
                // memory region for all subsequent approvals.
                mstore(0x20, approvalTarget)

                // Derive the location where approval data starts and ends.
                let approvalDataStarts := add(context.offset, 33)
                approvalDataEnds := add(approvalDataStarts, approvalDataSize)

                // Iterate over each approval.
                for {
                    let approvalDataOffset := approvalDataStarts
                } lt(approvalDataOffset, approvalDataEnds) {
                    approvalDataOffset := add(approvalDataOffset, 21)
                } {
                    // Attempt to process each approval. This only needs to be
                    // done once per token. The approval type is even for ERC20
                    // or odd for ERC721 / 1155 and is converted to 0 or 1.
                    let approvalType := and(
                        0x01,
                        calldataload(sub(approvalDataOffset, 32))
                    )
                    let approvalToken := shr(
                        96,
                        calldataload(approvalDataOffset)
                    )
                    let approvalValue := sub(approvalType, iszero(approvalType))
                    let selector := add(
                        mul(0x095ea7b3, iszero(approvalType)),
                        mul(0xa22cb465, approvalType)
                    )

                    // Write selector & approval value to memory.
                    mstore(0, selector)
                    mstore(0x40, approvalValue)

                    // Fire off call to token. Revert & bubble up revert data if
                    // present & reasonably-sized or revert with a custom error.
                    if iszero(call(gas(), approvalToken, 0, 0x1c, 0x44, 0, 0)) {
                        if and(
                            iszero(iszero(returndatasize())),
                            lt(returndatasize(), 0xffff)
                        ) {
                            returndatacopy(0, 0, returndatasize())
                            revert(0, returndatasize())
                        }

                        // ApprovalFailed(address approvalToken)
                        mstore(0, 0xe5a0a42f)
                        mstore(0x20, approvalToken)
                        revert(0x1c, 0x24)
                    }
                }

                // Restore the free memory pointer.
                mstore(0x40, freeMemoryPointer)
            }
        }

        // Read the sidecar address from runtime code and place on the stack.
        address target = _SIDECAR;

        // Track cumulative native tokens to be spent.
        uint256 value;
        // duplicate fulfiller on stack before it's pushed too far down to be accessed
        address _fulfiller = fulfiller;

        // Transfer each maximumSpent item to the sidecar.
        {
            uint256 totalTokensSpent = maximumSpent.length;
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
            assembly {
                // Get the free memory pointer.
                let freeMemoryPointer := mload(0x40)

                // Get the size of the payload.
                let payloadSize := sub(contextLength, add(2, approvalDataSize))

                // Write the execute(Calls[]) selector. Note this as well as the
                // single offset can be removed on both ends as an optimization.
                mstore(freeMemoryPointer, 0xb252b6e5)

                // Copy payload into memory after selector.
                calldatacopy(
                    add(freeMemoryPointer, 0x20),
                    approvalDataEnds,
                    payloadSize
                )

                // Fire off call to target. Revert and bubble up revert data if
                // present & reasonably-sized, else revert with a custom error.
                // Note that checking for sufficient native token balance is an
                // option here if more specific custom reverts are preferred.
                if iszero(
                    call(
                        gas(),
                        target,
                        value,
                        add(freeMemoryPointer, 0x1c),
                        add(payloadSize, 0x04),
                        0,
                        0
                    )
                ) {
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
        } */

        // Note: balances of minumumReceived items could be asserted here should
        // the sidecar execution output be unreliable. Alternatively, this check
        // can be performed from the sidecar itself as the final multicall step.

        ReceivedItem[] memory receivedItem = new ReceivedItem[](1);
        receivedItem[0] = ReceivedItem(
            maximumSpent[0].itemType,
            maximumSpent[0].token,
            maximumSpent[0].identifier,
            maximumSpent[0].amount,
            payable(address(this))
        );

        return (minimumReceived, receivedItem);
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
        // if (msg.sender != _FLASHLOAN_OFFERER) {
        //     revert InvalidCaller(msg.sender);
        // }
        //
        // // Send any available native token balance to the supplied recipient.
        // assembly {
        //     if selfbalance() {
        //         // Call recipient, supplying balance, and revert on failure.
        //         if iszero(call(gas(), recipient, selfbalance(), 0, 0, 0, 0)) {
        //             if and(
        //                 iszero(iszero(returndatasize())),
        //                 lt(returndatasize(), 0xffff)
        //             ) {
        //                 returndatacopy(0, 0, returndatasize())
        //                 revert(0, returndatasize())
        //             }
        //
        //             // NativeTokenTransferGenericFailure(recipient, selfbalance)
        //             mstore(0, 0xbc806b96)
        //             mstore(0x20, recipient)
        //             mstore(0x40, selfbalance())
        //             revert(0x1c, 0x44)
        //         }
        //     }
        //
        //     mstore(0, 0xfbacefce) // cleanup(address) selector
        //     return(0x1c, 0x04)
        // }

        assembly {
            return(0x1c, 0x04)
        }
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return 0x150b7a02;
    }

    // Used by ERC721BasicToken.sol
    function onERC721Received(
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return 0xf0b9e5ba;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external view virtual returns (bool) {
        return interfaceId == this.supportsInterface.selector;
    }

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
