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
        bytes calldata context
    )
        external
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration);

    function previewOrder(
        address caller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context
    )
        external
        view
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration);

    function getInventory()
        external
        view
        returns (SpentItem[] memory offerable, SpentItem[] memory receivable);

    event InventoryUpdated(InventoryUpdate[] inventoryUpdates);
}
