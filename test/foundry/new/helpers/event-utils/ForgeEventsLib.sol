// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "seaport-sol/../PointerLibraries.sol";

import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";

import { getEventHash, getTopicsHash } from "./EventHashes.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

bytes32 constant Topic0_ERC20_ERC721_Transfer = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
bytes32 constant Topic0_ERC1155_TransferSingle = 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62;

library ForgeEventsLib {
    using { ifTrue } for bytes32;

    function getForgeEventHash(
        Vm.Log memory log
    ) internal pure returns (bytes32) {
        bytes32 topicsHash = getForgeTopicsHash(log);
        bytes32 dataHash = getDataHash(log);
        return getEventHash(log.emitter, topicsHash, dataHash);
    }

    function toMemoryPointer(
        Vm.Log memory log
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := log
        }
    }

    function getDataHash(Vm.Log memory log) internal pure returns (bytes32) {
        MemoryPointer data = toMemoryPointer(log).pptr(32);
        return data.offset(32).hash(data.readUint256());
    }

    function getTopic0(Vm.Log memory log) internal pure returns (bytes32) {
        MemoryPointer topics = toMemoryPointer(log).pptr();
        uint256 topicsCount = topics.readUint256();
        return topics.offset(0x20).readBytes32().ifTrue(topicsCount > 0);
    }

    function reEmit(Vm.Log memory log) internal {
        MemoryPointer topics = toMemoryPointer(log).pptr();
        uint256 topicsCount = topics.readUint256();
        (
            bytes32 topic0,
            bytes32 topic1,
            bytes32 topic2,
            bytes32 topic3
        ) = getTopics(log);
        MemoryPointer data = toMemoryPointer(log).pptr(32);
        assembly {
            switch topicsCount
            case 4 {
                log4(data, mload(data), topic0, topic1, topic2, topic3)
            }
            case 3 {
                log3(data, mload(data), topic0, topic1, topic2)
            }
            case 2 {
                log2(data, mload(data), topic0, topic1)
            }
            case 1 {
                log1(data, mload(data), topic0)
            }
            default {
                log0(data, mload(data))
         
              }
        }
        console2.log("Emitter: ", log.emitter);
    }

    function describeLog(Vm.Log memory log) internal returns (string memory) {
        (
            bytes32 topic0,
            bytes32 topic1,
            bytes32 topic2,
            bytes32 topic3
        ) = getTopics(log);

        address from;
        address to;
        string memory prefix;
        string memory suffix;

        if (topic0 == Topic0_ERC20_ERC721_Transfer) {
            from = address(uint160(uint256(topic1)));
            to = address(uint160(uint256(topic2)));
            if (topic3 != bytes32(0)) {
                uint256 id = uint256(topic3);
                prefix = "ERC721";
                suffix = string.concat(" | id: ", Strings.toString(id));
            } else {
                prefix = "ERC20";
                uint256 amount = log.data.length >= 32
                    ? abi.decode(log.data, (uint256))
                    : 0;
                suffix = string.concat(" | amount: ", Strings.toString(amount));
            }
        } else if (topic0 == Topic0_ERC1155_TransferSingle) {
            address operator = address(uint160(uint256(topic1)));
            from = address(uint160(uint256(topic2)));
            to = address(uint160(uint256(topic3)));
            prefix = string.concat(
                "ERC1155 | operator: ",
                Strings.toHexString(operator)
            );
            (uint256 id, uint256 amount) = abi.decode(
                log.data,
                (uint256, uint256)
            );
            suffix = string.concat(
                " | id: ",
                Strings.toString(id),
                "amount: ",
                Strings.toString(amount)
            );
        }
        return
            string.concat(
                prefix,
                " | token: ",
                Strings.toHexString(log.emitter),
                " | from: ",
                Strings.toHexString(from),
                " | to: ",
                Strings.toHexString(to),
                suffix
            );
    }

    function getTopics(
        Vm.Log memory log
    )
        internal
        pure
        returns (bytes32 topic0, bytes32 topic1, bytes32 topic2, bytes32 topic3)
    {
        MemoryPointer topics = toMemoryPointer(log).pptr();
        uint256 topicsCount = topics.readUint256();
        topic0 = topics.offset(0x20).readBytes32().ifTrue(topicsCount > 0);
        topic1 = topics.offset(0x40).readBytes32().ifTrue(topicsCount > 1);
        topic2 = topics.offset(0x60).readBytes32().ifTrue(topicsCount > 2);
        topic3 = topics.offset(0x80).readBytes32().ifTrue(topicsCount > 3);
    }

    function getForgeTopicsHash(
        Vm.Log memory log
    ) internal pure returns (bytes32 topicHash) {
        MemoryPointer topics = toMemoryPointer(log).pptr();
        uint256 topicsCount = topics.readUint256();
        bytes32 topic0 = topics.offset(0x20).readBytes32().ifTrue(
            topicsCount > 0
        );
        bytes32 topic1 = topics.offset(0x40).readBytes32().ifTrue(
            topicsCount > 1
        );
        bytes32 topic2 = topics.offset(0x60).readBytes32().ifTrue(
            topicsCount > 2
        );
        bytes32 topic3 = topics.offset(0x80).readBytes32().ifTrue(
            topicsCount > 3
        );
        return getTopicsHash(topic0, topic1, topic2, topic3);
    }
}

function ifTrue(bytes32 a, bool b) pure returns (bytes32 c) {
    assembly {
        c := mul(a, b)
    }
}
