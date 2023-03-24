// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Vm } from "forge-std/Vm.sol";
import "forge-std/Test.sol";

import "seaport-sol/../ArrayHelpers.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";

struct EventData {
    address emitter;
    bytes32 topic0;
    bytes32 topic1;
    bytes32 topic2;
    bytes32 topic3;
    bytes32 dataHash;
}

contract TransferRecords {
    using ArrayHelpers for MemoryPointer;

    bytes32[] eventHashes;

    address private constant VM_ADDRESS =
        address(uint160(uint256(keccak256("hevm cheat code"))));

    Vm private constant vm = Vm(VM_ADDRESS);

    function start() external {
        vm.recordLogs();
    }

    function stop() external {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 logIndex;
        bytes32[] memory expectedEvents = eventHashes;
        uint256 lastLogIndex = toMemoryPointer(expectedEvents).reduce(
            checkNextLog,
            0,
            toMemoryPointer(logs)
        );
        int256 nextTransferIndex = toMemoryPointer(logs).findIndex(
            isTransferEvent,
            lastLogIndex
        );
        require(
            nextTransferIndex == -1,
            "TransferRecords: more transfers than expected"
        );
    }

    function checkNextLog(
        uint256 lastLogIndex,
        uint256 expectedEventHash,
        MemoryPointer logsArray
    ) internal returns (uint256 nextLogIndex) {
        int256 nextTransferIndex = logsArray.findIndex(
            isTransferEvent,
            lastLogIndex
        );
        require(
            nextTransferIndex != -1,
            "TransferRecords: transfer event not found"
        );
        uint256 i = uint256(nextTransferIndex);
        MemoryPointer log = logsArray.next().pptr(i * 32);
        require(
            getEventHash(log) == bytes32(expectedEventHash),
            "TransferRecords: log hash does not match"
        );
        return i + 1;
    }

    function toMemoryPointer(
        Vm.Log[] memory arr
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := arr
        }
    }

    function toMemoryPointer(
        bytes32[] memory arr
    ) internal pure returns (MemoryPointer ptr) {
        assembly {
            ptr := arr
        }
    }

    function mulCondition(bool x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := mul(x, y)
        }
    }

    function getEventHash(MemoryPointer log) internal pure returns (bytes32) {
        MemoryPointer topics = log.pptr();
        uint256 topicsCount = topics.readUint256();
        MemoryPointer data = log.pptr(32);
        return
            keccak256(
                abi.encode(
                    EventData(
                        // token = log.emitter
                        log.offset(0x40).readAddress(),
                        // topic0
                        bytes32(
                            mulCondition(
                                topicsCount > 0,
                                topics.offset(0x20).readUint256()
                            )
                        ),
                        // topic1
                        bytes32(
                            mulCondition(
                                topicsCount > 1,
                                topics.offset(0x40).readUint256()
                            )
                        ),
                        // topic2
                        bytes32(
                            mulCondition(
                                topicsCount > 2,
                                topics.offset(0x60).readUint256()
                            )
                        ),
                        // topic3
                        bytes32(
                            mulCondition(
                                topicsCount > 3,
                                topics.offset(0x80).readUint256()
                            )
                        ),
                        // keccak256(data)
                        data.offset(32).hash(data.readUint256())
                    )
                )
            );
    }

    function isTransferEvent(MemoryPointer log) internal pure returns (bool) {
        MemoryPointer topics = log.pptr();
        bytes32 topic0 = bytes32(
            mulCondition(
                topics.readUint256() > 0,
                topics.offset(0x20).readUint256()
            )
        );
        return topic0 == Transfer.selector || topic0 == TransferSingle.selector;
    }

    function toBytes32(address a) internal pure returns (bytes32 b) {
        assembly {
            b := a
        }
    }

    event Transfer(address indexed from, address indexed to, uint256 value);

    function expectERC20Transfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) external {
        // emitter
        bytes32 eventHash = keccak256(
            abi.encode(
                EventData(
                    token,
                    Transfer.selector,
                    toBytes32(from),
                    toBytes32(to),
                    bytes32(0),
                    keccak256(abi.encode(amount))
                )
            )
        );
        eventHashes.push(eventHash);
    }

    function expectERC721Transfer(
        address token,
        address from,
        address to,
        uint256 id
    ) external {
        // emitter
        bytes32 eventHash = keccak256(
            abi.encode(
                EventData(
                    token,
                    Transfer.selector,
                    toBytes32(from),
                    toBytes32(to),
                    bytes32(id),
                    ""
                )
            )
        );
        eventHashes.push(eventHash);
    }

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    function expectERC1155Transfer(
        address token,
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external {
        // emitter
        bytes32 eventHash = keccak256(
            abi.encode(
                EventData(
                    token,
                    TransferSingle.selector,
                    toBytes32(operator),
                    toBytes32(from),
                    toBytes32(to),
                    keccak256(abi.encode(id, amount))
                )
            )
        );
        eventHashes.push(eventHash);
    }
}

contract LogsEmitter {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event DifferentEvent(address account);
    event NoTopic() anonymous;

    function emitLogs(address from, address to, uint256 amount) external {
        emit Transfer(from, to, amount);
        emit NoTopic();
        emit DifferentEvent(address(1));
    }

    function emitTransferLog(
        address from,
        address to,
        uint256 amount
    ) external {
        emit Transfer(from, to, amount);
    }

    function emit4(
        bytes32 topic0,
        bytes32 topic1,
        bytes32 topic2,
        bytes32 topic3,
        bytes memory data
    ) external {
        assembly {
            log4(add(data, 32), mload(data), topic0, topic1, topic2, topic3)
        }
    }

    function emit3(
        bytes32 topic0,
        bytes32 topic1,
        bytes32 topic2,
        bytes memory data
    ) external {
        assembly {
            log3(add(data, 32), mload(data), topic0, topic1, topic2)
        }
    }

    function emit2(bytes32 topic0, bytes32 topic1, bytes memory data) external {
        assembly {
            log2(add(data, 32), mload(data), topic0, topic1)
        }
    }

    function emit1(bytes32 topic0, bytes memory data) external {
        assembly {
            log1(add(data, 32), mload(data), topic0)
        }
    }
}

contract TestRecords is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);
    TransferRecords internal records;
    LogsEmitter internal logsEmitter;

    function setUp() external {
        records = new TransferRecords();
        logsEmitter = new LogsEmitter();
    }

    function test() external {
        records.expectERC20Transfer(
            address(logsEmitter),
            address(0xb0b),
            address(0xa11ce),
            1000
        );

        records.start();
        logsEmitter.emitLogs(address(0xb0b), address(0xa11ce), 1000);
        records.stop();
    }

    function test2() external {
        vm.expectEmit(true, true, true, true, address(logsEmitter));
        emit Transfer(address(0xb0b), address(0xa11ce), 1000);
        logsEmitter.emitLogs(address(0xb0b), address(0xa11ce), 1000);
    }

    function testManyTransfers() external {
        records.expectERC20Transfer(
            address(logsEmitter),
            address(0xb0b),
            address(0xa11ce),
            1000
        );
        records.expectERC20Transfer(
            address(logsEmitter),
            address(0xa11ce),
            address(0xb0b),
            10001
        );
        records.expectERC20Transfer(
            address(logsEmitter),
            address(0xa11ce),
            address(0xb0b),
            100220
        );

        records.start();
        logsEmitter.emitLogs(address(0xb0b), address(0xa11ce), 1000);
        logsEmitter.emitLogs(address(0xa11ce), address(0xb0b), 10001);
        logsEmitter.emitTransferLog(address(0xa11ce), address(0xb0b), 100220);
        records.stop();
    }

    function testDifferentTopic1() external {
        records.expectERC20Transfer(
            address(logsEmitter),
            address(0xb0b),
            address(0xa11ce),
            1000
        );

        records.start();
        logsEmitter.emitLogs(address(0xf00), address(0xa11ce), 1000);
        vm.expectRevert("TransferRecords: log hash does not match");
        records.stop();
    }

    function testDifferentTopic2() external {
        records.expectERC20Transfer(
            address(logsEmitter),
            address(0xb0b),
            address(0xa11ce),
            1000
        );

        records.start();
        logsEmitter.emitLogs(address(0xb0b), address(0xba4), 1000);
        vm.expectRevert("TransferRecords: log hash does not match");
        records.stop();
    }

    function testDifferentTopic3() external {
        records.expectERC20Transfer(
            address(logsEmitter),
            address(0xb0b),
            address(0xa11ce),
            1000
        );

        records.start();
        logsEmitter.emit4(
            Transfer.selector,
            bytes32(uint(0xb0b)),
            bytes32(uint(0xa11ce)),
            bytes32(uint(1000)),
            abi.encode(1000)
        );
        vm.expectRevert("TransferRecords: log hash does not match");
        records.stop();
    }

    function testUnexpectedTransfer() external {
        records.expectERC20Transfer(
            address(logsEmitter),
            address(0xb0b),
            address(0xa11ce),
            1000
        );

        records.start();
        logsEmitter.emitLogs(address(0xb0b), address(0xa11ce), 1000);
        logsEmitter.emitLogs(address(0xb0b), address(0xa11ce), 1000);
        vm.expectRevert("TransferRecords: more transfers than expected");
        records.stop();
    }

    function testMissingTransfer() external {
        records.expectERC20Transfer(
            address(logsEmitter),
            address(0xb0b),
            address(0xa11ce),
            1000
        );

        records.start();
        vm.expectRevert("TransferRecords: transfer event not found");
        records.stop();
    }
}

struct ERC20TokenRecords {
    mapping(address => int256) expectedChange;
    mapping(address => uint256) initialBalance;
    mapping(address => bool) hasAccount;
    address[] accounts;
}

struct ERC20Records {
    mapping(address => ERC20TokenRecords) tokenRecords;
    mapping(address => bool) hasToken;
    address[] tokens;
}

struct ETHRecords {
    mapping(address => int256) expectedChange;
    mapping(address => uint256) initialBalance;
    mapping(address => bool) hasAccount;
    address[] accounts;
}

library ERC20RecordsLib {
    function expectBalanceChange(
        ERC20TokenRecords storage tokenRecords,
        address token,
        address account,
        int256 amount
    ) internal {
        if (!tokenRecords.hasAccount[account]) {
            tokenRecords.hasAccount[account] = true;
            tokenRecords.initialBalance[account] = IERC20(token).balanceOf(
                account
            );
            tokenRecords.accounts.push(account);
            tokenRecords.expectedChange[account] = amount;
        } else {
            tokenRecords.expectedChange[account] += amount;
        }
    }

    function expectBalanceChange(
        ERC20Records storage allRecords,
        address token,
        address account,
        int256 amount
    ) internal {
        if (!allRecords.hasToken[token]) {
            allRecords.hasToken[token] = true;
            allRecords.tokens.push(token);
        }
        expectBalanceChange(
            allRecords.tokenRecords[token],
            token,
            account,
            amount
        );
    }
}

library ETHRecordsLib {
    function expectBalanceChange(
        ETHRecords storage ethRecords,
        address token,
        address account,
        int256 amount
    ) internal {
        if (!ethRecords.hasAccount[account]) {
            ethRecords.hasAccount[account] = true;
            ethRecords.initialBalance[account] = account.balance;
            ethRecords.accounts.push(account);
            ethRecords.expectedChange[account] = amount;
        } else {
            ethRecords.expectedChange[account] += amount;
        }
    }
}
