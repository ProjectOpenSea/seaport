// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { OrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";

import { ReferenceGettersAndDerivers } from "./ReferenceGettersAndDerivers.sol";

import {
    TokenTransferrerErrors
} from "../../contracts/interfaces/TokenTransferrerErrors.sol";

import { ReferenceCounterManager } from "./ReferenceCounterManager.sol";

/**
 * @title Assertions
 * @author 0age
 * @notice Assertions contains logic for making various assertions that do not
 *         fit neatly within a dedicated semantic scope.
 */
contract ReferenceAssertions is
    ReferenceGettersAndDerivers,
    ReferenceCounterManager,
    TokenTransferrerErrors
{
    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param conduitController A contract that deploys conduits, or proxies
     *                          that may optionally be used to transfer approved
     *                          ERC20/721/1155 tokens.
     */
    constructor(
        address conduitController
    ) ReferenceGettersAndDerivers(conduitController) {}

    /**
     * @dev Internal view function to to ensure that the supplied consideration
     *      array length on a given set of order parameters is not less than the
     *      original consideration array length for that order and to retrieve
     *      the current counter for a given order's offerer and zone and use it
     *      to  derive the order hash.
     *
     * @param orderParameters The parameters of the order to hash.
     *
     * @return orderHash The order hash.
     */
    function _assertConsiderationLengthAndGetOrderHash(
        OrderParameters memory orderParameters
    ) internal view returns (bytes32 orderHash) {
        // Ensure supplied consideration array length is not less than original.
        _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
            orderParameters.consideration.length,
            orderParameters.totalOriginalConsiderationItems
        );

        // Derive and return order hash using current counter for the offerer.
        orderHash = _deriveOrderHash(
            orderParameters,
            _getCounter(orderParameters.offerer)
        );
    }

    /**
     * @dev Internal pure function to ensure that the supplied consideration
     *      array length for an order to be fulfilled is not less than the
     *      original consideration array length for that order.
     *
     * @param suppliedConsiderationItemTotal The number of consideration items
     *                                       supplied when fulfilling the order.
     * @param originalConsiderationItemTotal The number of consideration items
     *                                       supplied on initial order creation.
     */
    function _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
        uint256 suppliedConsiderationItemTotal,
        uint256 originalConsiderationItemTotal
    ) internal pure {
        // Ensure supplied consideration array length is not less than original.
        if (suppliedConsiderationItemTotal < originalConsiderationItemTotal) {
            revert MissingOriginalConsiderationItems();
        }
    }

    /**
     * @dev Internal pure function to ensure that a given item amount in not
     *      zero.
     *
     * @param amount The amount to check.
     */
    function _assertNonZeroAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert MissingItemAmount();
        }
    }

    /**
     * @dev Internal pure function to validate calldata offsets for dynamic
     *      types in BasicOrderParameters and other parameters. This ensures
     *      that functions using the calldata object normally will be using the
     *      same data as the assembly functions and that values that are bound
     *      to a given range are within that range. Note that no parameters are
     *      supplied as all basic order functions use the same calldata
     *      encoding.
     */
    function _assertValidBasicOrderParameters() internal pure {
        /*
         * Checks:
         * 1. Order parameters struct offset == 0x20
         * 2. Additional recipients arr offset == 0x200
         * 3. Signature offset == 0x240 + (recipients.length * 0x40)
         * 4. BasicOrderType between 0 and 23 (i.e. < 24)
         */
        // Declare a boolean designating basic order parameter offset validity.
        bool validOffsets = (abi.decode(msg.data[4:36], (uint256)) == 32 &&
            abi.decode(msg.data[548:580], (uint256)) == 576 &&
            abi.decode(msg.data[580:612], (uint256)) ==
            608 + 64 * abi.decode(msg.data[612:644], (uint256))) &&
            abi.decode(msg.data[292:324], (uint256)) < 24;

        // Revert with an error if basic order parameter offsets are invalid.
        if (!validOffsets) {
            revert InvalidBasicOrderParameterEncoding();
        }
    }
}
