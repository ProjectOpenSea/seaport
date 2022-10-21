// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { TwoStepOwnable } from "./lib/TwoStepOwnable.sol";
import { ZoneModuleInterface } from "./interfaces/ZoneModuleInterface.sol";
import { AdvancedOrder } from "../lib/ConsiderationStructs.sol";
import {
    ConsiderationInterface
} from "../interfaces/ConsiderationInterface.sol";

abstract contract BaseZone is TwoStepOwnable, ZoneModuleInterface {
    error InvalidExtraData();
    error InvalidExtraDataVersion();

    ConsiderationInterface internal immutable SEAPORT;
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );
    bytes32 internal constant _NAME_HASH = keccak256("Zone");
    uint256 internal immutable _CHAIN_ID = block.chainid;
    bytes32 internal immutable _DOMAIN_SEPARATOR = _deriveDomainSeparator();
    uint256 internal _FIXED_EXTRA_DATA_LENGTH = 0;
    uint256 internal _VARIABLE_EXTRA_DATA_LENGTH = 0;

    constructor(address seaport) {
        SEAPORT = ConsiderationInterface(seaport);
        _setInitialOwner(msg.sender);
    }

    /**
     * @notice Internal function to efficiently access the current domain separator.
     */
    function _domainSeparator() internal view returns (bytes32) {
        return
            _CHAIN_ID == block.chainid
                ? _DOMAIN_SEPARATOR
                : _deriveDomainSeparator();
    }

    /**
     * @notice Internal view function to derive the EIP-712 domain separator.
     *
     * @return The derived domain separator.
     */
    function _deriveDomainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    function _parseExtraData(AdvancedOrder calldata advancedOrder)
        internal
        view
        returns (bytes[] memory fixedData, bytes[] memory variableData)
    {
        if (advancedOrder.parameters.zoneHash == 0) {
            return (
                new bytes[](0),
                abi.decode(advancedOrder.extraData, (bytes[]))
            );
        }

        // Need to assure that fixed data is as required
        uint8 version;
        bytes calldata extraData = advancedOrder.extraData;
        bytes memory usedExtraData;

        assembly {
            // Set version value
            version := calldataload(extraData.offset)
            // Shift correctly to just use 1 byte
            version := shr(248, version)
            let extraDataLength := extraData.length
            // Set to point to free memory
            usedExtraData := mload(0x40)
            // Increment free memory pointer. Need an additional word for size (minus byte for version)
            mstore(0x40, add(usedExtraData, add(extraDataLength, 0x1F)))
            // Copy calldata to memory
            calldatacopy(
                // Set data starting at 1 slot offset (first will be size)
                add(usedExtraData, 0x20),
                // Use data after the version
                add(extraData.offset, 0x1),
                // Copy length minus version
                sub(extraDataLength, 0x1)
            )
            // Set the length
            mstore(usedExtraData, sub(extraDataLength, 1))
        }

        if (version == 1) {
            bytes32 expectedHash;
            assembly {
                expectedHash := keccak256(
                    add(usedExtraData, 0x20),
                    mload(usedExtraData)
                )
            }

            if (expectedHash != advancedOrder.parameters.zoneHash) {
                revert InvalidExtraData();
            }

            return (abi.decode(usedExtraData, (bytes[])), new bytes[](0));
        } else if (version == 2) {
            (
                bytes[] memory fixedExtraData,
                bytes[] memory variableExtraData
            ) = abi.decode(usedExtraData, (bytes[], bytes[]));
            if (
                advancedOrder.parameters.zoneHash !=
                keccak256(abi.encode(fixedExtraData))
            ) {
                revert InvalidExtraData();
            }

            return (fixedExtraData, variableExtraData);
        } else if (version == 3) {
            bytes[] memory extraDataArray = abi.decode(
                usedExtraData,
                (bytes[])
            );

            if (
                advancedOrder.parameters.zoneHash !=
                keccak256(extraDataArray[extraDataArray.length - 1])
            ) {
                revert InvalidExtraData();
            }

            bytes32[] memory extraDataHashes = abi.decode(
                extraDataArray[extraDataArray.length - 1],
                (bytes32[])
            );

            bytes[] memory fixedExtraData = new bytes[](
                _FIXED_EXTRA_DATA_LENGTH
            );
            bytes[] memory variableExtraData = new bytes[](
                _VARIABLE_EXTRA_DATA_LENGTH
            );
            uint256 fixedExtraDataIndex = 0;

            for (uint256 i = 0; i < extraDataArray.length - 1; i++) {
                if (extraDataHashes[i] == bytes32(0)) {
                    variableExtraData[i - fixedExtraDataIndex] = extraDataArray[
                        i
                    ];
                } else if (extraDataHashes[i] == keccak256(extraDataArray[i])) {
                    fixedExtraData[fixedExtraDataIndex++] = extraDataArray[i];
                } else {
                    revert InvalidExtraData();
                }
            }

            return (fixedExtraData, variableExtraData);
        }

        revert InvalidExtraDataVersion();
    }
}
