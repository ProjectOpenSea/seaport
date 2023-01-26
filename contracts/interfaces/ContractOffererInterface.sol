// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    SpentItem,
    ReceivedItem,
    Schema
} from "../lib/ConsiderationStructs.sol";

/**
 * @title ContractOffererInterface
 * @notice Contains the minimum interfaces needed to interact with a contract
 *         offerer.
 */
interface ContractOffererInterface {
    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items, and optional context (supplied as extraData).
     *
     * @param fulfiller       The address of the fulfiller.
     * @param minimumReceived The minimum items that the caller is willing to
     *                        receive.
     * @param maximumSpent    The maximum items the caller is willing to spend.
     * @param context         Additional context of the order.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration A tuple containing the consideration items.
     */
    function generateOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration);

    /**
     * @dev Ratifies an order with the specified offer, consideration, and
     *      optional extra data.
     *
     * @param offer         The offer items.
     * @param consideration The consideration items.
     * @param context       Additional context of the order.
     * @param orderHashes   The hashes to ratify.
     * @param contractNonce The nonce of the contract.
     *
     * @return ratifyOrderMagicValue The magic value returned by the contract
     *                               offerer.
     */
    function ratifyOrder(
        SpentItem[] calldata offer,
        ReceivedItem[] calldata consideration,
        bytes calldata context, // encoded based on the schemaID
        bytes32[] calldata orderHashes,
        uint256 contractNonce
    ) external returns (bytes4 ratifyOrderMagicValue);

    /**
     * @dev Generates an order in response to a minimum received set of items.
     *
     * @param caller          The address of the caller.
     * @param fulfiller       The address of the fulfiller.
     * @param minimumReceived The minimum items that the caller is willing to
     *                        receive.
     * @param maximumSpent    The maximum items the caller is willing to spend.
     * @param context         Additional context of the order.
     *
     * @return offer         A tuple containing the offer items.
     * @return consideration A tuple containing the consideration items.
     */
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

    /**
     * @dev Gets the metadata for this contract offerer.
     *
     * @return name    The name of the contract offerer.
     * @return schemas The schemas supported by the contract offerer.
     */
    function getSeaportMetadata()
        external
        view
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        );

    // Additional functions and/or events based on implemented schemaIDs
}
