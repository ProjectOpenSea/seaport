// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    SpentItem,
    ReceivedItem,
    Schema
} from "../lib/ConsiderationStructs.sol";

interface ContractOffererInterface {
    function generateOrder(
        address fulfiller,
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
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        view
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration);

    function getSeaportMetadata()
        external
        view
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        );

    // Additional functions and/or events based on implemented schemaIDs
}
