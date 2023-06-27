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

import {
    IERC6551Registry
} from "../helpers/6551/interfaces/IERC6551Registry.sol";

import {
    IERC6551Account
} from "../helpers/6551/interfaces/IERC6551Account.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    Execution,
    Fulfillment,
    Order,
    OrderComponents,
    Schema,
    SpentItem,
    ZoneParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @title  TBAZone
 * @author stephankmin
 * @notice TokenBoundZone is a zone implementation that validates Token Bound Accounts (TBAs)
 *         still own the same tokens both pre- and post-fulfillment.
 */

contract TBAZone is ERC165, ZoneInterface {
    // Revert if account nonce has been incremented.
    error InvalidAccountNonce();

    // Revert if hash of extraData does not match zoneHash.
    error InvalidExtraData();

    // Revert if msg.sender is not the owner of the TBA.
    error InvalidAccountOwner(address tba, address msgSender);

    // Set an immutable EIP-6551 registry to check for account nonce.
    IERC6551Registry internal immutable _erc6551Registry;

    // Set an address for the account implementation to pass into the call to the registry.
    address internal _accountImplementation;

    modifier onlyAccountOwner(address tba) {
        if (msg.sender != IERC6551Account(tba).owner()) {
            revert InvalidAccountOwner(tba, msg.sender);
        }
        _;
    }

    constructor(address erc6551Registry, address accountImplementation) {
        _erc6551Registry = IERC6551Registry(erc6551Registry);
        _accountImplementation = accountImplementation;
    }

    uint256 constant TBA_EXTRADATA_RSHIFT = 96;
    uint256 constant NONCE_RSHIFT = 64;
    uint256 constant UINT32_MASK = 0xffffffff;

    struct EncodedExtraData {
        address tba;
        uint256 nonce;
        SpentItem[] tokenBalances;
    }

    /**
     * @dev Validates an order. Assumes the extraData field in zoneParameters is structured
     *      as follows:
     *      [0:20] - TBA address
     *      [20:52] - TBA nonce prior to order fulfillment
     *      [52:] - SpentItem structs defining tokens owned by TBA prior to order fulfillment
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
        bytes calldata extraData = zoneParameters.extraData;
        address tba;
        uint32 expectedAccountNonce;

        assembly {
            tba := shr(TBA_EXTRADATA_RSHIFT, calldataload(extraData.offset))
            expectedAccountNonce := shr(
                NONCE_RSHIFT,
                calldataload(extraData.offset)
            )
        }

        // Check that hash of extraData matches zoneHash.
        // Implicitly checks that TBA still owns the tokens specified in extraData.
        bytes32 expectedExtraDataHash = zoneParameters.zoneHash;

        bytes32 actualExtraDataHash = keccak256(extraData);

        if (expectedExtraDataHash != actualExtraDataHash) {
            revert InvalidExtraData();
        }

        // Get the actual account nonce by calling the nonce method on the 6551
        // account.
        uint256 actualAccountNonce = IERC6551Account(payable(tba)).nonce();

        // Revert if the expected account nonce does not match the actual account nonce.
        if (expectedAccountNonce != actualAccountNonce) {
            revert InvalidAccountNonce();
        }

        // TODO: Check that token approvals have been revoked.

        // Return magic value
        validOrderMagicValue = ZoneInterface.validateOrder.selector;
    }

    function revokeAllTokenApprovals(
        address tba
    ) external onlyAccountOwner(tba) {
        // Revoke approvals for all tokens owned by the TBA.
        IERC20(tokenAddress).approve(msg.sender, 0);
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
