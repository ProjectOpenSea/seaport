// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    SpentItem,
    ReceivedItem,
    InventoryUpdate
} from "../lib/ConsiderationStructs.sol";

interface ContractOffererInterface {
    function generateOrder(
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration);

    function ratifyOrder(
        SpentItem[] calldata offer,
        ReceivedItem[] calldata consideration,
        bytes calldata context, // encoded based on the schemaID
        bytes32[] calldata orderHashes,
        uint256 contractNonce
    ) external returns (bytes4 ratifyOrderMagicValue);

    function previewOrder(
        address caller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        view
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration);

    function getMetadata()
        external
        view
        returns (
            uint256 schemaID, // maps to a Seaport standard's ID
            string memory name,
            bytes memory metadata // decoded based on the schemaID
        );

    // Additional functions and/or events based on schemaID
}
