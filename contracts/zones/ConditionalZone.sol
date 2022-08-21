// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";
import { SeaportInterface } from "../interfaces/SeaportInterface.sol";

import {
    AdvancedOrder,
    CriteriaResolver
} from "../lib/ConsiderationStructs.sol";

error PermanentlyInvalid();
error TemporarilyInvalid();

/**
 * @title  ConditionalZone
 * @author Slokh
 * @notice ConditionalZone allows for IFTTT types of orders.
 */
contract ConditionalZone is ZoneInterface {
    SeaportInterface seaport;

    constructor(address seaportAddress) {
        seaport = SeaportInterface(seaportAddress);
    }

    /**
     * @notice Check if a given order is currently valid.
     *
     * @dev This function is called by Seaport whenever extraData is not
     *      provided by the caller.
     *
     * @param orderHash The hash of the order.
     * @param caller    The caller in question.
     * @param offerer   The offerer in question.
     * @param zoneHash  The hash to provide upon calling the zone.
     *
     * @return validOrderMagicValue A magic value indicating if the order is
     *                              currently valid.
     */
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external view override returns (bytes4 validOrderMagicValue) {
        orderHash;
        caller;
        offerer;

        // Only validate if there is a zoneHash
        if (zoneHash != "") {
            (
                ,
                bool isCancelled,
                uint256 totalFilled,
                uint256 totalSize
            ) = seaport.getOrderStatus(zoneHash);

            // If the dependant order was cancelled, this order can never be valid.
            if (isCancelled) {
                return 0x0;
            }

            // If the dependant order has not been filled, this order is not valid yet.
            if (totalFilled == 0 || totalFilled != totalSize) {
                return 0x0;
            }
        }

        // Return the selector of isValidOrder as the magic value.
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    /**
     * @notice Check if a given order including extraData is currently valid.
     *
     * @dev This function is called by Seaport whenever any extraData is
     *      provided by the caller.
     *
     * @param orderHash         The hash of the order.
     * @param caller            The caller in question.
     * @param order             The order in question.
     * @param priorOrderHashes  The order hashes of each order supplied prior to
     *                          the current order as part of a "match" variety
     *                          of order fulfillment.
     * @param criteriaResolvers The criteria resolvers corresponding to
     *                          the order.
     *
     * @return validOrderMagicValue A magic value indicating if the order is
     *                              currently valid.
     */
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata priorOrderHashes,
        CriteriaResolver[] calldata criteriaResolvers
    ) external pure override returns (bytes4 validOrderMagicValue) {
        orderHash;
        caller;
        order;
        priorOrderHashes;
        criteriaResolvers;

        // Return the selector of isValidOrder as the magic value.
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }
}
