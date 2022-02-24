// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { ProxyRegistryInterface } from "../interfaces/AbridgedProxyInterfaces.sol";

import { ConsiderationEventsAndErrors } from "../interfaces/ConsiderationEventsAndErrors.sol";

import { OrderStatus } from "./Structs.sol";

/// @title ConsiderationBase contains all storage, constants, and constructor logic.
/// @author 0age
contract ConsiderationBase is ConsiderationEventsAndErrors {
    // Declare constants for name, version, and reentrancy sentinel values.
    string internal constant _NAME = "Consideration";
    string internal constant _VERSION = "1";
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;

    // Precompute hashes, original chainId, and domain separator on deployment.
    bytes32 internal immutable _NAME_HASH;
    bytes32 internal immutable _VERSION_HASH;
    bytes32 internal immutable _EIP_712_DOMAIN_TYPEHASH;
    bytes32 internal immutable _OFFERED_ITEM_TYPEHASH;
    bytes32 internal immutable _RECEIVED_ITEM_TYPEHASH;
    bytes32 internal immutable _ORDER_HASH;
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    // Allow for interaction with user proxies on the legacy proxy registry.
    ProxyRegistryInterface internal immutable _LEGACY_PROXY_REGISTRY;

    // Ensure that user proxies adhere to the required proxy implementation.
    address internal immutable _REQUIRED_PROXY_IMPLEMENTATION;

    // Prevent reentrant calls on protected functions.
    uint256 internal _reentrancyGuard;

    // Track status of each order (validated, cancelled, and fraction filled).
    mapping (bytes32 => OrderStatus) internal _orderStatus;

    // Cancel offerer's orders with given zone (offerer => zone => nonce).
    mapping (address => mapping (address => uint256)) internal _nonces;

    /// @dev Derive and set hashes, reference chainId, and associated domain separator during deployment.
    /// @param legacyProxyRegistry A proxy registry that stores per-user proxies that may optionally be used to transfer tokens.
    /// @param requiredProxyImplementation The implementation that this contract will require be set on each per-user proxy.
    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) {
        // Derive hashes, reference chainId, and associated domain separator.
        _NAME_HASH = keccak256(bytes(_NAME));
        _VERSION_HASH = keccak256(bytes(_VERSION));
        _EIP_712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        _OFFERED_ITEM_TYPEHASH = keccak256("OfferedItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)");
        _RECEIVED_ITEM_TYPEHASH = keccak256("ReceivedItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address account)");
        _ORDER_HASH = keccak256("OrderComponents(address offerer,address zone,OfferedItem[] offer,ReceivedItem[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,uint256 salt,uint256 nonce)OfferedItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)ReceivedItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address account)");
        _CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();

        // TODO: validate each of these based on expected codehash
        _LEGACY_PROXY_REGISTRY = ProxyRegistryInterface(legacyProxyRegistry);
        _REQUIRED_PROXY_IMPLEMENTATION = requiredProxyImplementation;

        // Initialize the reentrancy guard in a cleared state.
        _reentrancyGuard = _NOT_ENTERED;
    }

    /// @dev Internal view function to derive the EIP-712 domain separator.
    function _deriveDomainSeparator() internal view returns (bytes32) {
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