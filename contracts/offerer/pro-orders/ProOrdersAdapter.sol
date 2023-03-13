// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import {
    ContractOffererInterface
} from "../../interfaces/ContractOffererInterface.sol";

import { ItemType } from "../../lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem
} from "../../lib/ConsiderationStructs.sol";

import { TokenTransferrer } from "../../lib/TokenTransferrer.sol";

import { Sidecar } from "./SideCar.sol";

struct Call {
    address target;
    bool allowFailure;
    uint256 value;
    bytes callData;
}

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

interface ISideCar {
    function execute(Call[] calldata /* calls */) external payable;
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
contract ProOrdersAdapter is ContractOffererInterface, TokenTransferrer {
    address private immutable _SEAPORT;
    address public immutable _SIDECAR;
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
        _SIDECAR = address(new Sidecar());
        // _FLASHLOAN_OFFERER = flashloanOfferer;

        emit SeaportCompatibleContractDeployed();
    }

    event TestContractOffererEvent(
        address fulfiller,
        SpentItem[] minimumReceived,
        SpentItem[] maximumSpent,
        bytes context, // encoded based on the schemaID
        uint256 balance
    );

    event LooksRareEthBuyEvent(
        uint256 tokenId,
        uint256 price,
        uint256 nonce,
        uint256 startTime,
        uint256 endTime,
        uint256 minPercentageToAsk,
        uint256 amount,
        uint256 v,
        bytes32 r,
        bytes32 s,
        address collectionAddress,
        address signer,
        address strategy,
        bool isERC721
    );

    struct LooksRareEthBuy {
        uint256 tokenId;
        uint256 price;
        uint256 nonce;
        uint256 startTime;
        uint256 endTime;
        uint256 minPercentageToAsk;
        uint256 amount;
        uint256 v;
        bytes32 r;
        bytes32 s;
        address collectionAddress;
        address signer;
        address strategy;
        bool isERC721;
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
        emit TestContractOffererEvent(
            fulfiller,
            minimumReceived,
            maximumSpent,
            context,
            address(this).balance
        );

        Call[] memory calls = abi.decode(context, (Call[]));

        IERC721(minimumReceived[0].token).setApprovalForAll(_SEAPORT, true);

        ISideCar(_SIDECAR).execute(calls);

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
        return ("ProOrdersAdapter", schemas);
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
