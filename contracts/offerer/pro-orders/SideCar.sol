// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC1155 } from "forge-std/interfaces/IERC1155.sol";

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

/**
 * @title Sidecar
 * @author 0age, vasa_develop
 * @notice Sidecar is a contract that is deployed alongside a
 *         GenericAdapter contract and that performs arbitrary calls in an
 *         isolated context. It is imperative that this contract does not ever
 *         receive approvals, as there are no access controls preventing an
 *         arbitrary party from taking those tokens. Similarly, any tokens left
 *         on this contract can be taken by an arbitrary party on subsequent
 *         calls.
 */
contract Sidecar {
    error InvalidEncodingOrCaller(); // 0x8f183575
    error CallFailed(uint256 index); // 0x3f9a3b48
    error ExcessNativeTokenReturnFailed(uint256 amount); // 0x3d3f0ba4

    address private immutable _DESIGNATED_CALLER;

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

    constructor() {
        _DESIGNATED_CALLER = msg.sender;
    }

    function onERC1155Received(
        address,
        address,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) public virtual returns (bytes4) {
        // If the item is not sent by ProOrdersAdapter, send it to ProOrdersAdapter
        IERC1155(msg.sender).safeTransferFrom(
            address(this),
            _DESIGNATED_CALLER,
            _id,
            _value,
            _data
        );
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) public virtual returns (bytes4) {
        // If the item is not sent by ProOrdersAdapter, send it to ProOrdersAdapter
        IERC1155(msg.sender).safeBatchTransferFrom(
            address(this),
            _DESIGNATED_CALLER,
            _ids,
            _values,
            _data
        );
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes calldata _data
    ) external virtual returns (bytes4) {
        // If the item is not sent by ProOrdersAdapter, send it to ProOrdersAdapter
        IERC721(msg.sender).safeTransferFrom(
            address(this),
            _DESIGNATED_CALLER,
            _tokenId,
            _data
        );
        return 0x150b7a02;
    }

    // Used by ERC721BasicToken.sol
    function onERC721Received(
        address,
        uint256 _tokenId,
        bytes calldata _data
    ) external virtual returns (bytes4) {
        // If the item is not sent by ProOrdersAdapter, send it to ProOrdersAdapter
        IERC721(msg.sender).safeTransferFrom(
            address(this),
            _DESIGNATED_CALLER,
            _tokenId,
            _data
        );
        return 0xf0b9e5ba;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external view virtual returns (bool) {
        return interfaceId == this.supportsInterface.selector;
    }

    receive() external payable {}

    /**
     * @dev Execute an arbitrary sequence of calls. Only callable from the
     *      designated caller.
     */
    function execute(Call[] calldata calls) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            calls[i].target.call{ value: calls[i].value }(calls[i].callData);
        }
    }
}
