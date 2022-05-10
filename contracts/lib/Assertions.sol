// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { OrderParameters } from "./ConsiderationStructs.sol";

import { GettersAndDerivers } from "./GettersAndDerivers.sol";

import { TokenTransferrerErrors } from "../interfaces/TokenTransferrerErrors.sol";

import "./ConsiderationConstants.sol";

/**
 * @title Assertions
 * @author 0age
 * @notice Assertions contains logic for making various assertions that do not
 *         fit neatly within a dedicated semantic scope.
 */
contract Assertions is GettersAndDerivers, TokenTransferrerErrors {
    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param conduitController A contract that deploys conduits, or proxies
     *                          that may optionally be used to transfer approved
     *                          ERC20/721/1155 tokens.
     */
    constructor(address conduitController)
        GettersAndDerivers(conduitController)
    {}

    /**
     * @dev Internal view function to to ensure that the supplied consideration
     *      array length on a given set of order parameters is not less than the
     *      original consideration array length for that order and to retrieve
     *      the current nonce for a given order's offerer and zone and use it to
     *      derive the order hash.
     *
     * @param orderParameters The parameters of the order to hash.
     *
     * @return The hash.
     */
    function _assertConsiderationLengthAndGetNoncedOrderHash(
        OrderParameters memory orderParameters
    ) internal view returns (bytes32) {
        // Ensure supplied consideration array length is not less than original.
        _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
            orderParameters.consideration.length,
            orderParameters.totalOriginalConsiderationItems
        );

        // Derive and return order hash using current nonce for the offerer.
        return
            _deriveOrderHash(orderParameters, _nonces[orderParameters.offerer]);
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
     * @dev Internal pure function to ensure that a given item amount is not
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
     *      types in BasicOrderParameters. This ensures that functions using the
     *      calldata object normally will be using the same data as the assembly
     *      functions. Note that no parameters are supplied as all basic order
     *      functions use the same calldata encoding.
     */
    function _assertValidBasicOrderParameterOffsets() internal pure {
        // Declare a boolean designating basic order parameter offset validity.
        bool validOffsets;

        // Utilize assembly in order to read offset data directly from calldata.
        assembly {
            /*
             * Checks:
             * 1. Order parameters struct offset == 0x20
             * 2. Additional recipients arr offset == 0x240
             * 3. Signature offset == 0x260 + (recipients.length * 0x40)
             */
            validOffsets := and(
                // Order parameters have offset of 0x20
                eq(
                    calldataload(BasicOrder_parameters_cdPtr),
                    BasicOrder_parameters_ptr
                ),
                // Additional recipients have offset of 0x240
                eq(
                    calldataload(BasicOrder_additionalRecipients_head_cdPtr),
                    BasicOrder_additionalRecipients_head_ptr
                )
            )
            validOffsets := and(
                validOffsets,
                eq(
                    // Load signature offset from calldata
                    calldataload(BasicOrder_signature_cdPtr),
                    // Calculate expected offset: start of recipients + len * 64
                    add(
                        BasicOrder_signature_ptr,
                        mul(
                            calldataload(
                                BasicOrder_additionalRecipients_length_cdPtr
                            ),
                            AdditionalRecipients_size
                        )
                    )
                )
            )
        }

        // Revert with an error if basic order parameter offsets are invalid.
        if (!validOffsets) {
            revert InvalidBasicOrderParameterEncoding();
        }
    }
}
