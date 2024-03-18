// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC1155Recipient } from "../../utils/ERC1155Recipient.sol";

contract EIP1271Offerer is ERC1155Recipient {
    error EIP1271OffererInvalidSignature(bytes32 digest, bytes signature);

    bytes4 private constant _EIP_1271_MAGIC_VALUE = 0x1626ba7e;

    mapping(bytes32 => bytes32) public digestToSignatureHash;

    bool private _returnEmpty = false;

    function registerSignature(bytes32 digest, bytes memory signature) public {
        digestToSignatureHash[digest] = keccak256(signature);
    }

    function isValidSignature(
        bytes32 digest,
        bytes memory signature
    ) external view returns (bytes4) {
        if (_returnEmpty) {
            return bytes4(0x00000000);
        }

        bytes32 signatureHash = keccak256(signature);
        if (digestToSignatureHash[digest] == signatureHash) {
            return _EIP_1271_MAGIC_VALUE;
        }

        // TODO: test for bubbled up revert reasons as well
        assembly {
            revert(0, 0)
        }
    }

    function returnEmpty() external {
        _returnEmpty = true;
    }

    function is1271() external pure returns (bool) {
        return true;
    }

    receive() external payable {}
}
