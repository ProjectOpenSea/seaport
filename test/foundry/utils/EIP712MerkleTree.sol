// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { MurkyBase } from "murky/common/MurkyBase.sol";
import {
    TypehashDirectory
} from "../../../contracts/lib/TypehashDirectory.sol";
import { Test } from "forge-std/Test.sol";
import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";
import {
    OrderComponents
} from "../../../contracts/lib/ConsiderationStructs.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract MerkleUnsorted is MurkyBase {
    function hashLeafPairs(
        bytes32 left,
        bytes32 right
    ) public pure override returns (bytes32 _hash) {
        assembly {
            mstore(0x0, left)
            mstore(0x20, right)
            _hash := keccak256(0x0, 0x40)
        }
    }
}

contract EIP712MerkleTree is Test {
    TypehashDirectory internal immutable _typehashDirectory;
    OrderComponents private emptyOrderComponents;
    MerkleUnsorted private merkle;

    constructor() {
        _typehashDirectory = new TypehashDirectory();
        merkle = new MerkleUnsorted();
    }

    function _lookupBulkOrderTypehash(
        uint256 treeHeight
    ) internal view returns (bytes32 typeHash) {
        TypehashDirectory directory = _typehashDirectory;
        assembly {
            let typeHashOffset := add(1, shl(0x5, sub(treeHeight, 1)))
            extcodecopy(directory, 0, typeHashOffset, 0x20)
            typeHash := mload(0)
        }
    }

    function signBulkOrder(
        ConsiderationInterface consideration,
        uint256 privateKey,
        OrderComponents[] memory orderComponents,
        uint24 orderIndex
    ) public returns (bytes memory) {
        bytes32 emptyComponentsHash = consideration.getOrderHash(
            emptyOrderComponents
        );
        bytes32[] memory leaves;
        bytes32 bulkOrderTypehash;
        {
            uint256 height = Math.log2(orderComponents.length);
            if (2 ** height != orderComponents.length) {
                height += 1;
            }
            bulkOrderTypehash = _lookupBulkOrderTypehash(height);
            leaves = new bytes32[](2 ** height);
            for (uint256 i = 0; i < orderComponents.length; i++) {
                leaves[i] = consideration.getOrderHash(orderComponents[i]);
            }

            for (uint256 i = orderComponents.length; i < 2 ** height; i++) {
                leaves[i] = emptyComponentsHash;
            }
        }

        emit log_named_bytes32("bulkOrderTypehash", bulkOrderTypehash);
        bytes32 rootHash = merkle.getRoot(leaves);
        bytes32 bulkOrderHash = keccak256(
            abi.encode(bulkOrderTypehash, rootHash)
        );

        (, bytes32 domainSeparator, ) = consideration.information();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, bulkOrderHash)
            )
        );

        bytes32[] memory proof = merkle.getProof(leaves, orderIndex);
        // orderIndex should only take up 3 bytes but proof needs to be abi-encoded to include its length
        return
            abi.encodePacked(
                abi.encode(v, r, s),
                orderIndex,
                abi.encode(proof)
            );
    }
}
