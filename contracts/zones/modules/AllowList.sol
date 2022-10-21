// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { BaseZone } from "../BaseZone.sol";
import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ZoneModuleInterface } from "../interfaces/ZoneModuleInterface.sol";
import { AdvancedOrder } from "../../lib/ConsiderationStructs.sol";

abstract contract AllowList is BaseZone {
    error InvalidProof();

    uint256 private immutable _VARIABLE_EXTRA_DATA_INDEX =
        _VARIABLE_EXTRA_DATA_LENGTH++;
    uint256 private immutable _FIXED_EXTRA_DATA_INDEX =
        _FIXED_EXTRA_DATA_LENGTH++;

    function _validateOrder(bytes32, address) internal view virtual override {
        revert ExtraDataRequired();
    }

    function _validateOrder(
        bytes32,
        address caller,
        bytes[] memory fixedExtraData,
        bytes[] memory variableExtraData
    ) internal view virtual override {
        bytes32 leaf = keccak256(abi.encodePacked(caller));

        bytes32 root = abi.decode(
            fixedExtraData[_FIXED_EXTRA_DATA_INDEX],
            (bytes32)
        );

        bytes32[] memory proof = abi.decode(
            variableExtraData[_VARIABLE_EXTRA_DATA_INDEX],
            (bytes32[])
        );

        if (!MerkleProof.verify(proof, root, leaf)) {
            revert InvalidProof();
        }
    }
}
