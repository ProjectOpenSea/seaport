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

import { TokenTransferrer } from "../lib/TokenTransferrer.sol";

import { GenericAdapterSidecar } from "./GenericAdapterSidecar.sol";

interface GenericAdapterInterface is ContractOffererInterface {
    function generateOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration);

    function cleanup(address recipient) external payable returns (bytes4);

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external payable returns (bytes4);

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external payable returns (bytes4);

    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */, // encoded based on the schemaID
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external pure override returns (bytes4);

    function previewOrder(
        address,
        address,
        SpentItem[] calldata,
        SpentItem[] calldata,
        bytes calldata
    )
        external
        pure
        override
        returns (SpentItem[] memory, ReceivedItem[] memory);

    function getSeaportMetadata()
        external
        pure
        override
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        );
}
