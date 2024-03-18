//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    Schema,
    ZoneParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ZoneInterface } from "seaport-types/src/interfaces/ZoneInterface.sol";

contract HashCalldataTestZone is ZoneInterface {
    bytes32 public expectedZoneAuthorizeCalldataHash;
    bytes32 public expectedZoneValidateCalldataHash;

    function authorizeOrder(
        ZoneParameters calldata zoneParameters
    ) public view returns (bytes4) {
        // Hash the zone parameters.
        bytes32 _expectedZoneHash = bytes32(
            keccak256(abi.encode(zoneParameters))
        );

        if (_expectedZoneHash != expectedZoneAuthorizeCalldataHash) {
            revert(
                "Zone calldata hash does not match expected zone hash in authorizeOrder"
            );
        }

        // Return the authorizeOrder magic value.
        return this.authorizeOrder.selector;
    }

    /**
     * @dev Validates the order with the given `zoneParameters`.  Called by
     *      Consideration whenever any extraData is provided by the caller.
     *
     * @param zoneParameters The parameters for the order.
     *
     * @return validOrderMagicValue The validOrder magic value.
     */
    function validateOrder(
        ZoneParameters calldata zoneParameters
    ) external view returns (bytes4 validOrderMagicValue) {
        // Hash the zone parameters.
        bytes32 _expectedZoneHash = bytes32(
            keccak256(abi.encode(zoneParameters))
        );

        if (_expectedZoneHash != expectedZoneValidateCalldataHash) {
            revert(
                "Zone calldata hash does not match expected zone hash in validateOrder"
            );
        }

        // Return the validOrderMagicValue.
        return ZoneInterface.validateOrder.selector;
    }

    function setExpectedAuthorizeCalldataHash(
        bytes32 _expectedZoneAuthorizeCalldataHash
    ) public {
        expectedZoneAuthorizeCalldataHash = _expectedZoneAuthorizeCalldataHash;
    }

    function setExpectedValidateCalldataHash(
        bytes32 _expectedZoneValidateCalldataHash
    ) public {
        expectedZoneValidateCalldataHash = _expectedZoneValidateCalldataHash;
    }

    receive() external payable {}

    function getSeaportMetadata()
        external
        pure
        override(ZoneInterface)
        returns (string memory name, Schema[] memory schemas)
    {
        // Return the metadata.
        name = "TestCalldataHashContractOfferer";
        schemas = new Schema[](1);
        schemas[0].id = 1337;
        schemas[0].metadata = new bytes(0);
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
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ZoneInterface) returns (bool) {
        return interfaceId == type(ZoneInterface).interfaceId;
    }
}
