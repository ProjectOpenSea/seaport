// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

// prettier-ignore
import {
    ProxyRegistryInterface,
    TokenTransferProxyInterface
} from "contracts/interfaces/AbridgedProxyInterfaces.sol";

// prettier-ignore
import {
    ConduitControllerInterface
} from "contracts/interfaces/ConduitControllerInterface.sol";

// prettier-ignore
import {
    ConsiderationEventsAndErrors
} from "contracts/interfaces/ConsiderationEventsAndErrors.sol";

import { OrderStatus } from "contracts/lib/ConsiderationStructs.sol";

/**
 * @title ConsiderationBase
 * @author 0age
 * @notice ConsiderationBase contains all storage, constants, and constructor
 *         logic.
 */
contract ReferenceConsiderationBase is ConsiderationEventsAndErrors {
    // Declare constants for name, version, and reentrancy sentinel values.
    string internal constant _NAME = "Consideration";
    string internal constant _VERSION = "rc.1";
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;

    // Precompute hashes, original chainId, and domain separator on deployment.
    bytes32 internal immutable _NAME_HASH;
    bytes32 internal immutable _VERSION_HASH;
    bytes32 internal immutable _EIP_712_DOMAIN_TYPEHASH;
    bytes32 internal immutable _OFFER_ITEM_TYPEHASH;
    bytes32 internal immutable _CONSIDERATION_ITEM_TYPEHASH;
    bytes32 internal immutable _ORDER_TYPEHASH;
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    // Allow for interaction with the conduit controller.
    ConduitControllerInterface internal immutable _CONDUIT_CONTROLLER;

    // Cache the conduit creation code hash used by the conduit controller.
    bytes32 internal immutable _CONDUIT_CREATION_CODE_HASH;

    // Prevent reentrant calls on protected functions.
    uint256 internal _reentrancyGuard;

    // Track status of each order (validated, cancelled, and fraction filled).
    mapping(bytes32 => OrderStatus) internal _orderStatus;

    // Cancel all of a given offerer's orders signed with their current nonce.
    mapping(address => uint256) internal _nonces;

    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param conduitController           A contract that deploys conduits, or
     *                                    proxies that may optionally be used to
     *                                    transfer approved ERC20+721+1155
     *                                    tokens.
     */
    constructor(address conduitController) {
        // Derive hashes, reference chainId, and associated domain separator.
        bytes32 tempNameHash = keccak256(bytes(_NAME));
        bytes32 tempVersionHash = keccak256(bytes(_VERSION));

        // prettier-ignore
        bytes memory offerItemTypeString = abi.encodePacked(
            "OfferItem(",
                "uint8 itemType,",
                "address token,",
                "uint256 identifierOrCriteria,",
                "uint256 startAmount,",
                "uint256 endAmount",
            ")"
        );
        // prettier-ignore
        bytes memory considerationItemTypeString = abi.encodePacked(
            "ConsiderationItem(",
                "uint8 itemType,",
                "address token,",
                "uint256 identifierOrCriteria,",
                "uint256 startAmount,",
                "uint256 endAmount,",
                "address recipient",
            ")"
        );
        // prettier-ignore
        bytes memory orderComponentsPartialTypeString = abi.encodePacked(
            "OrderComponents(",
                "address offerer,",
                "address zone,",
                "OfferItem[] offer,",
                "ConsiderationItem[] consideration,",
                "uint8 orderType,",
                "uint256 startTime,",
                "uint256 endTime,",
                "bytes32 zoneHash,",
                "uint256 salt,",
                "bytes32 conduitKey,",
                "uint256 nonce",
            ")"
        );

        // prettier-ignore
        bytes32 tempEIP712Domain = keccak256(
            abi.encodePacked(
                "EIP712Domain(",
                    "string name,",
                    "string version,",
                    "uint256 chainId,",
                    "address verifyingContract",
                ")"
            )
        );
        _OFFER_ITEM_TYPEHASH = keccak256(offerItemTypeString);
        _CONSIDERATION_ITEM_TYPEHASH = keccak256(considerationItemTypeString);
        _ORDER_TYPEHASH = keccak256(
            abi.encodePacked(
                orderComponentsPartialTypeString,
                considerationItemTypeString,
                offerItemTypeString
            )
        );
        _CHAIN_ID = block.chainid;

        _EIP_712_DOMAIN_TYPEHASH = tempEIP712Domain;
        _NAME_HASH = tempNameHash;
        _VERSION_HASH = tempVersionHash;

        _DOMAIN_SEPARATOR = _deriveInitialDomainSeparator(
            tempEIP712Domain,
            tempNameHash,
            tempVersionHash
        );

        ConduitControllerInterface tempConduitController = ConduitControllerInterface(
                conduitController
            );
        _CONDUIT_CONTROLLER = tempConduitController;

        (_CONDUIT_CREATION_CODE_HASH, ) = (
            tempConduitController.getConduitCodeHashes()
        );

        // Initialize the reentrancy guard in a cleared state.
        _reentrancyGuard = _NOT_ENTERED;
    }

    /**
     * @dev Internal view function to derive the initial EIP-712 domain
     *      separator.
     *
     * @return The derived domain separator.
     */
    function _deriveInitialDomainSeparator(
        bytes32 _EIP_712_DOMAIN_TYPEHASH,
        bytes32 _NAME_HASH,
        bytes32 _VERSION_HASH
    ) internal view virtual returns (bytes32) {
        return
            _deriveDomainSeparator(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH
            );
    }

    /**
     * @dev Internal view function to derive the EIP-712 domain separator.
     *
     * @return The derived domain separator.
     */
    function _deriveDomainSeparator(
        bytes32 _EIP_712_DOMAIN_TYPEHASH,
        bytes32 _NAME_HASH,
        bytes32 _VERSION_HASH
    ) internal view virtual returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }
}
