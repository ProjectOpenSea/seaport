// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

struct ERC20TransferEvent {
    string kind;
    address token;
    address from;
    address to;
    uint256 amount;
}

struct ERC721TransferEvent {
    string kind;
    address token;
    address from;
    address to;
    uint256 identifier;
    // bytes32 topicHash;
    // bytes32 dataHash;
    // bytes32 eventHash;
}

struct ERC1155TransferEvent {
    string kind;
    address token;
    address operator;
    address from;
    address to;
    uint256 identifier;
    uint256 amount;
    // bytes32 topicHash;
    // bytes32 dataHash;
    // bytes32 eventHash;
}

library EventSerializer {
    function serializeString(
        string memory objectKey,
        string memory valueKey,
        string memory value
    ) internal returns (string memory) {
        return vm.serializeString(objectKey, valueKey, value);
    }

    function serializeAddress(
        string memory objectKey,
        string memory valueKey,
        address value
    ) internal returns (string memory) {
        return vm.serializeAddress(objectKey, valueKey, value);
    }

    function serializeBytes32(
        string memory objectKey,
        string memory valueKey,
        bytes32 value
    ) internal returns (string memory) {
        return vm.serializeBytes32(objectKey, valueKey, value);
    }

    function serializeUint256(
        string memory objectKey,
        string memory valueKey,
        uint256 value
    ) internal returns (string memory) {
        return vm.serializeUint(objectKey, valueKey, value);
    }

    function serializeERC20TransferEvent(
        ERC20TransferEvent memory value,
        string memory objectKey,
        string memory valueKey
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        serializeString(obj, "kind", value.kind);
        serializeAddress(obj, "token", value.token);
        serializeAddress(obj, "from", value.from);
        serializeAddress(obj, "to", value.to);
        string memory finalJson = serializeUint256(obj, "amount", value.amount);
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function serializeERC721TransferEvent(
        ERC721TransferEvent memory value,
        string memory objectKey,
        string memory valueKey
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        serializeString(obj, "kind", value.kind);
        serializeAddress(obj, "token", value.token);
        serializeAddress(obj, "from", value.from);
        serializeAddress(obj, "to", value.to);
        string memory finalJson = serializeUint256(
            obj,
            "identifier",
            value.identifier
        );
        // serializeUint256(obj, "identifier", value.identifier);
        // serializeBytes32(obj, "topicHash", value.topicHash);
        // serializeBytes32(obj, "dataHash", value.dataHash);
        // string memory finalJson = serializeBytes32(
        //     obj,
        //     "eventHash",
        //     value.eventHash
        // );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function serializeERC1155TransferEvent(
        ERC1155TransferEvent memory value,
        string memory objectKey,
        string memory valueKey
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        serializeString(obj, "kind", value.kind);
        serializeAddress(obj, "operator", value.operator);
        serializeAddress(obj, "token", value.token);
        serializeAddress(obj, "from", value.from);
        serializeAddress(obj, "to", value.to);
        serializeUint256(obj, "identifier", value.identifier);
        string memory finalJson = serializeUint256(obj, "amount", value.amount);
        // serializeUint256(obj, "amount", value.amount);
        // serializeBytes32(obj, "topicHash", value.topicHash);
        // serializeBytes32(obj, "dataHash", value.dataHash);
        // string memory finalJson = serializeBytes32(
        //     obj,
        //     "eventHash",
        //     value.eventHash
        // );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }
}
