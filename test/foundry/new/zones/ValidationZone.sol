//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "seaport-sol/SeaportStructs.sol";
import { ItemType } from "seaport-sol/SeaportEnums.sol";

import { ContractOffererInterface } from
    "seaport-core/interfaces/ContractOffererInterface.sol";

import { ZoneInterface } from "seaport-core/interfaces/ZoneInterface.sol";

contract TestTransferValidationZoneOfferer is
    // ContractOffererInterface,
    ZoneInterface
{
    uint256 expectedSpentAmount;

    constructor(uint256 expected) {
        expectedSpentAmount = expected;
    }

    receive() external payable { }

    /**
     * @dev Validates that the parties have received the correct items.
     *
     * @param zoneParameters The zone parameters, including the SpentItem and
     *                       ReceivedItem arrays.
     *
     * @return validOrderMagicValue The magic value to indicate things are OK.
     */
    function validateOrder(ZoneParameters calldata zoneParameters)
        external
        view
        override
        returns (bytes4 validOrderMagicValue)
    {
        if (zoneParameters.offer[0].amount != expectedSpentAmount) {
            revert("Incorrect spent amount");
        }

        // Return the selector of validateOrder as the magic value.
        validOrderMagicValue = this.validateOrder.selector;
    }

    // /**
    //  * @dev Generates an order with the specified minimum and maximum spent
    //  *      items.
    //  */
    // function generateOrder(
    //     address,
    //     SpentItem[] calldata a,
    //     SpentItem[] calldata b,
    //     bytes calldata c
    // )
    //     external
    //     virtual
    //     override
    //     returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    // {
    //     return previewOrder(address(this), address(this), a, b, c);
    // }

    // /**
    //  * @dev View function to preview an order generated in response to a minimum
    //  *      set of received items, maximum set of spent items, and context
    //  *      (supplied as extraData).
    //  */
    // function previewOrder(
    //     address,
    //     address,
    //     SpentItem[] calldata a,
    //     SpentItem[] calldata b,
    //     bytes calldata
    // )
    //     public
    //     view
    //     override
    //     returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    // { }

    // /**
    //  * @dev Ratifies that the parties have received the correct items.
    //  *
    //  * @param minimumReceived The minimum items that the caller was willing to
    //  *                        receive.
    //  * @param maximumSpent    The maximum items that the caller was willing to
    //  *                        spend.
    //  * @param context         The context of the order.
    //  * @ param orderHashes     The order hashes, unused here.
    //  * @ param contractNonce   The contract nonce, unused here.
    //  *
    //  * @return ratifyOrderMagicValue The magic value to indicate things are OK.
    //  */
    // function ratifyOrder(
    //     SpentItem[] calldata minimumReceived, /* offer */
    //     ReceivedItem[] calldata maximumSpent, /* consideration */
    //     bytes calldata context, /* context */
    //     bytes32[] calldata, /* orderHashes */
    //     uint256 /* contractNonce */
    // ) external override returns (bytes4 /* ratifyOrderMagicValue */ ) {
    //     return this.ratifyOrder.selector;
    // }

    function getSeaportMetadata()
        external
        pure
        returns (
            // override(ContractOffererInterface, ZoneInterface)
            string memory name,
            Schema[] memory schemas
        )
    {
        // Return the metadata.
        name = "TestTransferValidationZoneOfferer";
        schemas = new Schema[](1);
        schemas[0].id = 1337;
        schemas[0].metadata = new bytes(0);
    }
}
