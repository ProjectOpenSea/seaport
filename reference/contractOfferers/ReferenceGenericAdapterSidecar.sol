// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct Call {
    address target;
    bool allowFailure;
    uint256 value;
    bytes callData;
}

/**
 * @title ReferenceGenericAdapterSidecar
 * @author 0age
 * @notice GenericAdapterSidecar is a contract that is deployed alongside a
 *         GenericAdapter contract and that performs arbitrary calls in an
 *         isolated context. It is imperative that this contract does not ever
 *         receive approvals, as there are no access controls preventing an
 *         arbitrary party from taking those tokens. Similarly, any tokens left
 *         on this contract can be taken by an arbitrary party on subsequent
 *         calls.  This is the high level reference implementation.
 */
contract ReferenceGenericAdapterSidecar {
    error InvalidEncodingOrCaller(); // 0x8f183575
    error CallFailed(uint256 index); // 0x3f9a3b48
    error NativeTokenTransferGenericFailure(); // 0xbc806b96

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
     * @dev Execute an arbitrary sequence of calls. Only callable from the
     *      designated caller.  The selector is 0xb252b6e5.
     */
    function execute(Call[] calldata calls) external payable {
        // Retrieve designated caller from runtime code & place value on stack.
        address designatedCaller = _DESIGNATED_CALLER;

        // // Revert if standard encoding is not utilized or caller is invalid.
        // if or(
        //     // msg.sender != designatedCaller
        //     xor(caller(), designatedCaller),
        //     // calldataload(0x04) != 0x20
        //     xor(calldataload(0x04), 0x20)
        //     // The first 4 bytes of the calldata are the function selector,
        //     // I think.
        //     // So I think `calldataload(0x04)` is getting 32 bytes starting
        //     // from the fifth byte (the first arg? array length?).
        //     // And then we're checking that the value doesn't equal 0x20.
            
        //     // How does checking that the value of the first 32 bytes
        //     // doesn't equal 0x20 ensure that the standard encoding is
        //     // used lol?

        // Revert if the caller is not the designated caller or if the callData
        // is improperly encoded.
        if (
            msg.sender != designatedCaller ||
            // TODO: Ask 0 or James about this.
            calls.length != 32
            ) {
            revert InvalidEncodingOrCaller();
        }

        // Iterate over each call.
        for (uint i=0; i < calls.length; ++i) {
            // // Perform the call to the target, supplying value and calldata.
            // let success := call(
            //     gas(),
            //     calldataload(callOffset), // target
            //     calldataload(add(callOffset, 0x40)), // value
            //     add(callDataOffset, 0x20), // callData data
            //     and(calldataload(callDataOffset), 0xffffffff), // length
            //     0,
            //     0
            // )

            // Do a low-level call to get success status.
            // TODO: Do I need to do anything with the return data?
            (bool success, ) = calls[i]
                .target
                .call{value: calls[i].value}(
                    abi.encodeWithSelector(
                        // Is there a diagram of the contents of calls.callData?
                        // This is a wild guess.
                        bytes4(calls[i].callData[0:4]),
                        calls[i].callData[4:]
                    )
                );

            if (calls[i].allowFailure == false && success == false) {
                revert CallFailed(i);
            }
        }

        // Return excess native tokens, if any remain, to the caller.
        if (address(this).balance > 0) {
            // Declare a variable indicating whether the call was successful or not.
            (bool success, ) = msg.sender.call{ value: address(this).balance }("");

            // If the call fails...
            if (!success) {
                // Note that this reference implementation deviates from the
                // optimized contract, which "bubbles up" revert data
                revert NativeTokenTransferGenericFailure();
            }
        }
    }
}
