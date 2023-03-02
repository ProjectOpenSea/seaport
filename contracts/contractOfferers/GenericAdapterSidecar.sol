// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct Call {
    address target;
    bool allowFailure;
    uint256 value;
    bytes callData;
}

/**
 * @title GenericAdapterSidecar
 * @author 0age
 * @notice GenericAdapterSidecar is a contract that is deployed alongside a
 *         GenericAdapter contract and that performs arbitrary calls in an
 *         isolated context. It is imperative that this contract does not ever
 *         receive approvals, as there are no access controls preventing an
 *         arbitrary party from taking those tokens. Similarly, any tokens left
 *         on this contract can be taken by an arbitrary party on subsequent
 *         calls.
 */
contract GenericAdapterSidecar {
    error InvalidEncodingOrCaller(); // 0x8f183575
    error CallFailed(uint256 index); // 0x3f9a3b48
    error ExcessNativeTokenReturnFailed(uint256 amount); // 0x3d3f0ba4

    address private immutable _DESIGNATED_CALLER;

    constructor() {
        _DESIGNATED_CALLER = msg.sender;
    }

    /**
     * @dev Enable accepting native tokens.
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
        assembly {
            mstore(0, 0x150b7a02)
            return(0x1c, 0x20)
        }
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
        assembly {
            mstore(0, 0xf23a6e61)
            return(0x1c, 0x20)
        }
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external payable returns (bytes4) {
        assembly {
            mstore(0, 0xbc197c81)
            return(0x1c, 0x20)
        }
    }

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

            let freeMemoryPtr := mload(0x40)

            let totalCalls := and(calldataload(0x24), 0xffffffff)

            // Derive the calldata offset for the final call.
            let finalCallOffset := add(0x44, shl(0x05, totalCalls))

            // Iterate over each call.
            for {
                let callOffset := 0x44
            } lt(callOffset, finalCallOffset) {
                callOffset := add(callOffset, 0x20)
            } {
                let callPtr := add(calldataload(callOffset), 0x44)

                // TODO: assert that callPtr is not OOR

                let callDataOffset := and(
                    calldataload(add(callPtr, 0x60)),
                    0xffffffff
                )

                let callDataLength := and(
                    calldataload(add(callPtr, callDataOffset)),
                    0xffffffff
                )

                calldatacopy(
                    freeMemoryPtr,
                    add(add(callPtr, 0x20), callDataOffset),
                    callDataLength
                )

                // Perform the call to the target, supplying value and calldata.
                let success := call(
                    gas(),
                    calldataload(callPtr), // target
                    calldataload(add(callPtr, 0x40)), // value
                    freeMemoryPtr, // callData data
                    callDataLength, // length
                    0,
                    0
                )

                // Revert if the call fails and failure is not allowed.
                if iszero(or(calldataload(add(callPtr, 0x20)), success)) {
                    if and(
                        iszero(iszero(returndatasize())),
                        lt(returndatasize(), 0xffff)
                    ) {
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
