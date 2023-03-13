// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC721 } from "forge-std/interfaces/IERC721.sol";

struct Call {
    address target;
    bool allowFailure;
    uint256 value;
    bytes callData;
}

/**
 * @title ProOrdersAdapterSidecar
 * @author 0age, vasa_develop
 * @notice ProOrdersAdapterSidecar is a contract that is deployed alongside a
 *         GenericAdapter contract and that performs arbitrary calls in an
 *         isolated context. It is imperative that this contract does not ever
 *         receive approvals, as there are no access controls preventing an
 *         arbitrary party from taking those tokens. Similarly, any tokens left
 *         on this contract can be taken by an arbitrary party on subsequent
 *         calls.
 */
contract ProOrdersAdapterSidecar {
    error InvalidEncodingOrCaller(); // 0x8f183575
    error CallFailed(uint256 index); // 0x3f9a3b48
    error ExcessNativeTokenReturnFailed(uint256 amount); // 0x3d3f0ba4

    address private immutable _DESIGNATED_CALLER;

    constructor() {
        _DESIGNATED_CALLER = msg.sender;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public virtual returns (bytes4) {
        // If the item is not sent by ProOrdersAdapter, send it to ProOrdersAdapter
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public virtual returns (bytes4) {
        // If the item is not sent by ProOrdersAdapter, send it to ProOrdersAdapter
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        // If the item is not sent by ProOrdersAdapter, send it to ProOrdersAdapter
        return 0x150b7a02;
    }

    // Used by ERC721BasicToken.sol
    function onERC721Received(
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        // If the item is not sent by ProOrdersAdapter, send it to ProOrdersAdapter
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
    function execute(Call[] calldata /* calls */) external payable {
        // Retrieve designated caller from runtime code & place value on stack.
        address designatedCaller = _DESIGNATED_CALLER;

        assembly {
            // Revert if standard encoding is not utilized or caller is invalid.
            if or(
                xor(caller(), designatedCaller),
                xor(calldataload(0x04), 0x20)
            ) {
                mstore(0, 0x8f183575)
                revert(0x1c, 0x04)
            }

            // Derive the calldata offset for the final call.
            let finalCallOffset := add(
                0x44,
                shl(0x05, and(calldataload(0x24), 0xffffffff))
            )

            // Iterate over each call.
            for {
                let callOffset := 0x44
            } lt(callOffset, finalCallOffset) {
                callOffset := add(callOffset, 0x20)
            } {
                let callPtr := calldataload(callOffset)

                // TODO: assert that callPtr is not OOR

                let callDataOffset := and(
                    calldataload(add(callPtr, 0x60)),
                    0xffffffff
                )

                // Perform the call to the target, supplying value and calldata.
                let success := call(
                    gas(),
                    calldataload(callPtr), // target
                    calldataload(add(callPtr, 0x40)), // value
                    add(callDataOffset, 0x20), // callData data
                    and(calldataload(callDataOffset), 0xffffffff), // length
                    0,
                    0
                )

                // Revert if the call fails and failure is not allowed.
                if iszero(or(calldataload(add(callPtr, 0x20)), success)) {
                    if and(returndatasize(), lt(returndatasize(), 0xffff)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    mstore(0, 0x3f9a3b48)
                    mstore(0x20, shr(0x05, sub(callOffset, 0x44)))
                    revert(0x1c, 0x24)
                }
            }

            // Return excess native tokens to the caller.
            if selfbalance() {
                let success := call(gas(), caller(), selfbalance(), 0, 0, 0, 0)
                if iszero(success) {
                    if and(returndatasize(), lt(returndatasize(), 0xffff)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    mstore(0, 0x3d3f0ba4)
                    mstore(0x20, selfbalance())
                    revert(0x1c, 0x24)
                }
            }
        }
    }
}
