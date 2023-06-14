// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ZoneInterface } from "seaport-types/src/interfaces/ZoneInterface.sol";

import {
    PausableZoneEventsAndErrors
} from "./interfaces/PausableZoneEventsAndErrors.sol";

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {
    SeaportInterface
} from "seaport-types/src/interfaces/SeaportInterface.sol";

import { IERC6551Registry } from "./interfaces/IERC6551Registry.sol";

import { IERC6551Account } from "./interfaces/IERC6551Account.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    Execution,
    Fulfillment,
    Order,
    OrderComponents,
    Schema,
    ZoneParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * TODO: update title
 * @title  TokenBoundZone
 * @author stephankmin
 * @notice TokenBoundZone is a zone implementation that validates Token Bound Accounts (TBAs)
 *         still own the same tokens both pre- and post-fulfillment.
 */

contract TokenBoundZone is ERC165, PausableZoneEventsAndErrors, ZoneInterface {
    // Revert if account nonce has been incremented.
    error InvalidAccountNonce();

    // Revert if account no longer owns the same tokens.
    error InvalidOffer();

    // Set an immutable EIP-6551 registry to check for account nonce.
    IERC6551Registry internal immutable _erc6551Registry;

    // Set an address for the account implementation to pass into the call to the registry.
    address internal _accountImplementation;

    constructor(address erc6551Registry, address accountImplementation) {
        _erc6551Registry = IERC6551Registry(erc6551Registry);
        _accountImplementation = accountImplementation;
    }

    /**
     * @dev Validates an order. Assumes the extraData field in zoneParameters is structured
     *      as follows:
     *      [0:20] - TBA address
     *      [20:52] - TBA nonce prior to order fulfillment
     *      [52:] - Tokens owned by TBA prior to order fulfillment
     *
     *      For each token owned by TBA, calldata should be 92 bytes structured as follows:
     *          [0:8] - enum ItemType
     *          [8:28] - token address
     *          [28:60] - tokenId
     *          [60:92] - amount
     *
     *      For validation purposes, the zoneHash MUST be a hash of extraData.
     *
     * @param zoneParameters The context about the order fulfillment and any
     *                       supplied extraData.
     *
     * @return validOrderMagicValue The magic value that indicates a valid
     *                              order.
     */
    function validateOrder(
        ZoneParameters calldata zoneParameters
    ) public returns (bytes4 validOrderMagicValue) {
        // Get the TBA address from extraData.
        address accountAddress = address(
            bytes20(zoneParameters.extraData[:20])
        );

        // Get the expected account nonce from extraData.
        uint256 expectedAccountNonce = uint256(
            bytes32(zoneParameters.extraData[20:52])
        );

        // Get the actual account nonce by calling the nonce method on the 6551
        // account.
        uint256 actualAccountNonce = IERC6551Account(payable(accountAddress))
            .nonce();

        // Revert if the expected account nonce does not match the actual account nonce.
        if (expectedAccountNonce != actualAccountNonce) {
            revert InvalidAccountNonce();
        }

        // Check that TBA still owns the same tokens from pre-fulfillment.

        // Check that token approvals have been revoked.

        // Return magic value
        validOrderMagicValue = ZoneInterface.validateOrder.selector;
    }

    function getSeaportMetadata()
        external
        pure
        override
        returns (string memory name, Schema[] memory schemas)
    {
        schemas = new Schema[](1);
        schemas[0].id = 3003;
        schemas[0].metadata = new bytes(0);

        return ("TokenBoundZone", schemas);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC165, ZoneInterface) returns (bool) {
        return
            interfaceId == type(ZoneInterface).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
