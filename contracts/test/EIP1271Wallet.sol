// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

contract EIP1271Wallet {
    bytes4 private constant _EIP_1271_MAGIC_VALUE = 0x1626ba7e;

    address public immutable owner;

    bool showRevertMessage = true;

    constructor(address _owner) {
        owner = _owner;
    }

    function revertWithMessage(bool showMessage) external {
        showRevertMessage = showMessage;
    }

    function isValidSignature(
        bytes32 digest,
        bytes memory signature
    ) external view returns (bytes4) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert();
        }

        if (v != 27 && v != 28) {
            revert();
        }

        address signer = ecrecover(digest, v, r, s);

        if (signer == address(0)) {
            revert();
        }

        if (signer != owner) {
            if (showRevertMessage) {
                revert("NOT SIGNER!");
            }

            revert();
        }

        return _EIP_1271_MAGIC_VALUE;
    }
}