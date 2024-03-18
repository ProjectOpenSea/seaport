// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    Schema,
    ZoneParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { ZoneInterface } from "seaport-types/src/interfaces/ZoneInterface.sol";

contract VerboseAuthZone is ERC165, ZoneInterface {
    // Create a mapping of orderHashes to authorized status.
    mapping(bytes32 => bool) public orderIsAuthorized;

    bool shouldReturnInvalidMagicValue;
    bool shouldRevert;

    event Authorized(bytes32 orderHash);

    event AuthorizeOrderReverted(bytes32 orderHash);

    event AuthorizeOrderNonMagicValue(bytes32 orderHash);

    error OrderNotAuthorized();

    constructor(bool _shouldReturnInvalidMagicValue, bool _shouldRevert) {
        shouldReturnInvalidMagicValue = _shouldReturnInvalidMagicValue;
        shouldRevert = _shouldRevert;
    }

    function setAuthorizationStatus(bytes32 orderHash, bool status) public {
        orderIsAuthorized[orderHash] = status;
    }

    function authorizeOrder(
        ZoneParameters calldata zoneParameters
    ) public returns (bytes4) {
        if (!orderIsAuthorized[zoneParameters.orderHash]) {
            if (shouldReturnInvalidMagicValue) {
                emit AuthorizeOrderNonMagicValue(zoneParameters.orderHash);

                // Return the a value that is not the authorizeOrder magic
                // value.
                return bytes4(0x12345678);
            }

            if (shouldRevert) {
                emit AuthorizeOrderReverted(zoneParameters.orderHash);
                revert OrderNotAuthorized();
            }
        }

        emit Authorized(zoneParameters.orderHash);

        // Return the authorizeOrder magic value.
        return this.authorizeOrder.selector;
    }

    function validateOrder(
        ZoneParameters calldata /* zoneParameters */
    ) external pure returns (bytes4 validOrderMagicValue) {
        // Return the validOrderMagicValue.
        return ZoneInterface.validateOrder.selector;
    }

    function getSeaportMetadata()
        external
        pure
        override
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        )
    {
        schemas = new Schema[](1);
        schemas[0].id = 3003;
        schemas[0].metadata = new bytes(0);

        return ("VerboseAuthZone", schemas);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC165, ZoneInterface) returns (bool) {
        return
            interfaceId == type(ZoneInterface).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
