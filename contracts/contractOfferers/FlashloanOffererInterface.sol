// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem
} from "../lib/ConsiderationStructs.sol";

interface FlashloanOffererInterface is ContractOffererInterface {
    function generateOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration);

    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata context, // encoded based on the schemaID
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external returns (bytes4);

    function previewOrder(
        address,
        address,
        SpentItem[] calldata,
        SpentItem[] calldata,
        bytes calldata
    ) external pure returns (SpentItem[] memory, ReceivedItem[] memory);

    function getSeaportMetadata()
        external
        pure
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        );
}
