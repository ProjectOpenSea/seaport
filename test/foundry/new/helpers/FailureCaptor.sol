// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Vm, vm, checkGlobalFailed, unsetGlobalFailed } from "./VmUtils.sol";
import { LibString } from "solady/src/utils/LibString.sol";
import { getSelector } from "./scuff-utils/Index.sol";

using LibString for uint256;
using { toHexString } for bytes32;

function toHexString(bytes32 x) pure returns (string memory) {
    return uint256(x).toHexString();
}

library FailureCaptor {
    using LibString for *;

    event log(string);
    event logs(bytes);
    event log_address(address);
    event log_bytes32(bytes32);
    event log_int(int);
    event log_uint(uint);
    event log_bytes(bytes);
    event log_string(string);
    event log_named_address(string key, address val);
    event log_named_bytes32(string key, bytes32 val);
    event log_named_decimal_int(string key, int val, uint decimals);
    event log_named_decimal_uint(string key, uint val, uint decimals);
    event log_named_int(string key, int val);
    event log_named_uint(string key, uint val);
    event log_named_bytes(string key, bytes val);
    event log_named_string(string key, string val);

    function decode_log(
        bytes memory eventData
    ) internal pure returns (string memory) {
        return abi.decode(eventData, (string));
    }

    function decode_logs(
        bytes memory eventData
    ) internal pure returns (string memory) {
        bytes memory data = abi.decode(eventData, (bytes));
        return data.toHexString();
    }

    function decode_log_address(
        bytes memory eventData
    ) internal pure returns (string memory) {
        address addr = abi.decode(eventData, (address));
        return addr.toHexString();
    }

    function decode_log_bytes32(
        bytes memory eventData
    ) internal pure returns (string memory) {
        bytes32 data = abi.decode(eventData, (bytes32));
        return data.toHexString();
    }

    function decode_log_int(
        bytes memory eventData
    ) internal pure returns (string memory) {
        int256 value = abi.decode(eventData, (int256));
        return value.toString();
    }

    function decode_log_uint(
        bytes memory eventData
    ) internal pure returns (string memory) {
        uint256 value = abi.decode(eventData, (uint256));
        return value.toString();
    }

    function decode_log_bytes(
        bytes memory eventData
    ) internal pure returns (string memory) {
        bytes memory data = abi.decode(eventData, (bytes));
        return data.toHexString();
    }

    function decode_log_string(
        bytes memory eventData
    ) internal pure returns (string memory) {
        return abi.decode(eventData, (string));
    }

    function decode_log_named_address(
        bytes memory eventData
    ) internal pure returns (string memory) {
        (string memory key, address val) = abi.decode(
            eventData,
            (string, address)
        );
        return string.concat(key, ":", val.toHexString());
    }

    function decode_log_named_bytes32(
        bytes memory eventData
    ) internal pure returns (string memory) {
        (string memory key, bytes32 val) = abi.decode(
            eventData,
            (string, bytes32)
        );
        return string.concat(key, ":", val.toHexString());
    }

    function decode_log_named_int(
        bytes memory eventData
    ) internal pure returns (string memory) {
        (string memory key, int256 val) = abi.decode(
            eventData,
            (string, int256)
        );
        return string.concat(key, ": ", val.toString());
    }

    function decode_log_named_uint(
        bytes memory eventData
    ) internal pure returns (string memory) {
        (string memory key, uint256 val) = abi.decode(
            eventData,
            (string, uint256)
        );
        return string.concat(key, ": ", val.toString());
    }

    function decode_log_named_bytes(
        bytes memory eventData
    ) internal pure returns (string memory) {
        (string memory key, bytes memory val) = abi.decode(
            eventData,
            (string, bytes)
        );
        return string.concat(key, ": ", val.toHexString());
    }

    function decode_log_named_string(
        bytes memory eventData
    ) internal pure returns (string memory) {
        (string memory key, string memory val) = abi.decode(
            eventData,
            (string, string)
        );
        return string.concat(key, ": ", val);
    }

    function tryDecodeLog(
        bytes32 topic0,
        bytes memory eventData
    ) internal pure returns (string memory) {
        if (topic0 == log.selector) {
            return decode_log(eventData);
        }
        if (topic0 == logs.selector) {
            return decode_logs(eventData);
        }
        if (topic0 == log_address.selector) {
            return decode_log_address(eventData);
        }
        if (topic0 == log_bytes32.selector) {
            return decode_log_bytes32(eventData);
        }
        if (topic0 == log_int.selector) {
            return decode_log_int(eventData);
        }
        if (topic0 == log_uint.selector) {
            return decode_log_uint(eventData);
        }
        if (topic0 == log_bytes.selector) {
            return decode_log_bytes(eventData);
        }
        if (topic0 == log_string.selector) {
            return decode_log_string(eventData);
        }
        if (topic0 == log_named_address.selector) {
            return decode_log_named_address(eventData);
        }
        if (topic0 == log_named_bytes32.selector) {
            return decode_log_named_bytes32(eventData);
        }
        if (topic0 == log_named_int.selector) {
            return decode_log_named_int(eventData);
        }
        if (topic0 == log_named_uint.selector) {
            return decode_log_named_uint(eventData);
        }
        if (topic0 == log_named_bytes.selector) {
            return decode_log_named_bytes(eventData);
        }
        if (topic0 == log_named_string.selector) {
            return decode_log_named_string(eventData);
        }
    }

    function captureFailure()
        internal
        returns (bool failed, string memory reason)
    {
        failed = checkGlobalFailed();
        if (failed) {
            Vm.Log[] memory logsArray = vm.getRecordedLogs();
            reason = decodeFailureLogs(logsArray);
            unsetGlobalFailed();
        }
    }

    function decodeSolidityError(
        bytes memory data
    ) internal pure returns (string memory reason) {
      assembly {
        let length := mload(data)
        reason := add(data, 4)
        mstore(reason, sub(length, 4))
      }
    }

    bytes4 internal constant SolidityErrorSelector = 0x08c379a0;
    bytes4 internal constant SolidityPanicSelector = 0x4e487b71;

    function decodePanicReason(
        bytes memory data
    ) internal pure returns (string memory) {
        uint256 code;
        assembly {
            code := mload(add(data, 0x24))
        }
        if (code == 0x01) return "Panic: assertionError";
        if (code == 0x11) return "Panic: arithmeticError";
        if (code == 0x12) return "Panic: divisionError";
        if (code == 0x21) return "Panic: enumConversionError";
        if (code == 0x22) return "Panic: encodeStorageError";
        if (code == 0x31) return "Panic: popError";
        if (code == 0x32) return "Panic: indexOOBError";
        if (code == 0x41) return "Panic: memOverflowError";
        if (code == 0x51) return "Panic: zeroVarError";
        return "unknown panic";
    }

    function tryDecodeError(
        bytes memory data
    ) internal pure returns (string memory) {
        if (data.length == 0) return "";
        bytes4 selector = getSelector(data);
        if (selector == SolidityErrorSelector) {
            return decodeSolidityError(data);
        }
        if (selector == SolidityPanicSelector) {
            return decodePanicReason(data);
        }
        return string.concat("unknown error: ", data.toHexString());
    }

    function decodeFailureLogs(
        Vm.Log[] memory logsArray
    ) internal pure returns (string memory) {
        string memory result = "";
        for (uint i = 0; i < logsArray.length; i++) {
            if (logsArray[i].topics.length == 0) {
                continue;
            }
            string memory logData = tryDecodeLog(
                logsArray[i].topics[0],
                logsArray[i].data
            );
            if (bytes(logData).length > 0) {
                result = string.concat(result, logData);
                if (i < logsArray.length - 1) {
                    result = string.concat(result, "\n");
                }
            }
        }
        return result;
    }
}
