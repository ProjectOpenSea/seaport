// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ConduitControllerInterface
} from "../../contracts/interfaces/ConduitControllerInterface.sol";

import {
    ConsiderationEventsAndErrors
} from "../../contracts/interfaces/ConsiderationEventsAndErrors.sol";

import {
    ReentrancyErrors
} from "../../contracts/interfaces/ReentrancyErrors.sol";

/**
 * @title ConsiderationBase
 * @author 0age
 * @notice ConsiderationBase contains all storage, constants, and constructor
 *         logic.
 */
contract ReferenceConsiderationBase is
    ConsiderationEventsAndErrors,
    ReentrancyErrors
{
    // Declare constants for name, version, and reentrancy sentinel values.
    string internal constant _NAME = "Consideration";
    string internal constant _VERSION = "1.2-reference";
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;

    // Precompute hashes, original chainId, and domain separator on deployment.
    bytes32 internal immutable _NAME_HASH;
    bytes32 internal immutable _VERSION_HASH;
    bytes32 internal immutable _EIP_712_DOMAIN_TYPEHASH;
    bytes32 internal immutable _OFFER_ITEM_TYPEHASH;
    bytes32 internal immutable _CONSIDERATION_ITEM_TYPEHASH;
    bytes32 internal immutable _ORDER_TYPEHASH;
    bytes32 internal immutable _BULK_ORDER_TYPEHASH;
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    // Allow for interaction with the conduit controller.
    ConduitControllerInterface internal immutable _CONDUIT_CONTROLLER;

    // Cache the conduit creation code hash used by the conduit controller.
    bytes32 internal immutable _CONDUIT_CREATION_CODE_HASH;

    // Map bulk order tree height to its respective EIP-712 typehash.
    mapping(uint256 => bytes32) internal _bulkOrderTypehashes;

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
        // Derive name and version hashes alongside required EIP-712 typehashes.
        (
            _NAME_HASH,
            _VERSION_HASH,
            _EIP_712_DOMAIN_TYPEHASH,
            _OFFER_ITEM_TYPEHASH,
            _CONSIDERATION_ITEM_TYPEHASH,
            _ORDER_TYPEHASH,
            _BULK_ORDER_TYPEHASH,
            _DOMAIN_SEPARATOR
        ) = _deriveTypehashes();

        // Store the current chainId and derive the current domain separator.
        _CHAIN_ID = block.chainid;

        // Set the supplied conduit controller to temp.
        ConduitControllerInterface tempConduitController = ConduitControllerInterface(
                conduitController
            );

        _CONDUIT_CONTROLLER = tempConduitController;

        // Retrieve the conduit creation code hash from the supplied controller.
        (_CONDUIT_CREATION_CODE_HASH, ) = (
            tempConduitController.getConduitCodeHashes()
        );

        _bulkOrderTypehashes[1] = bytes32(
            0x3ca2711d29384747a8f61d60aad3c450405f7aaff5613541dee28df2d6986d32
        );
        _bulkOrderTypehashes[2] = bytes32(
            0xbf8e29b89f29ed9b529c154a63038ffca562f8d7cd1e2545dda53a1b582dde30
        );
        _bulkOrderTypehashes[3] = bytes32(
            0x53c6f6856e13104584dd0797ca2b2779202dc2597c6066a42e0d8fe990b0024d
        );
        _bulkOrderTypehashes[4] = bytes32(
            0xa02eb7ff164c884e5e2c336dc85f81c6a93329d8e9adf214b32729b894de2af1
        );
        _bulkOrderTypehashes[5] = bytes32(
            0x39c9d33c18e050dda0aeb9a8086fb16fc12d5d64536780e1da7405a800b0b9f6
        );
        _bulkOrderTypehashes[6] = bytes32(
            0x1c19f71958cdd8f081b4c31f7caf5c010b29d12950be2fa1c95070dc47e30b55
        );
        _bulkOrderTypehashes[7] = bytes32(
            0xca74fab2fece9a1d58234a274220ad05ca096a92ef6a1ca1750b9d90c948955c
        );
        _bulkOrderTypehashes[8] = bytes32(
            0x7ff98d9d4e55d876c5cfac10b43c04039522f3ddfb0ea9bfe70c68cfb5c7cc14
        );
        _bulkOrderTypehashes[9] = bytes32(
            0xbed7be92d41c56f9e59ac7a6272185299b815ddfabc3f25deb51fe55fe2f9e8a
        );
        _bulkOrderTypehashes[10] = bytes32(
            0xd1d97d1ef5eaa37a4ee5fbf234e6f6d64eb511eb562221cd7edfbdde0848da05
        );
        _bulkOrderTypehashes[11] = bytes32(
            0x896c3f349c4da741c19b37fec49ed2e44d738e775a21d9c9860a69d67a3dae53
        );
        _bulkOrderTypehashes[12] = bytes32(
            0xbb98d87cc12922b83759626c5f07d72266da9702d19ffad6a514c73a89002f5f
        );
        _bulkOrderTypehashes[13] = bytes32(
            0xe6ae19322608dd1f8a8d56aab48ed9c28be489b689f4b6c91268563efc85f20e
        );
        _bulkOrderTypehashes[14] = bytes32(
            0x6b5b04cbae4fcb1a9d78e7b2dfc51a36933d023cf6e347e03d517b472a852590
        );
        _bulkOrderTypehashes[15] = bytes32(
            0xd1eb68309202b7106b891e109739dbbd334a1817fe5d6202c939e75cf5e35ca9
        );
        _bulkOrderTypehashes[16] = bytes32(
            0x1da3eed3ecef6ebaa6e5023c057ec2c75150693fd0dac5c90f4a142f9879fde8
        );
        _bulkOrderTypehashes[17] = bytes32(
            0xeee9a1392aa395c7002308119a58f2582777a75e54e0c1d5d5437bd2e8bf6222
        );
        _bulkOrderTypehashes[18] = bytes32(
            0xc3939feff011e53ab8c35ca3370aad54c5df1fc2938cd62543174fa6e7d85877
        );
        _bulkOrderTypehashes[19] = bytes32(
            0x0efca7572ac20f5ae84db0e2940674f7eca0a4726fa1060ffc2d18cef54b203d
        );
        _bulkOrderTypehashes[20] = bytes32(
            0x5a4f867d3d458dabecad65f6201ceeaba0096df2d0c491cc32e6ea4e64350017
        );
        _bulkOrderTypehashes[21] = bytes32(
            0x80987079d291feebf21c2230e69add0f283cee0b8be492ca8050b4185a2ff719
        );
        _bulkOrderTypehashes[22] = bytes32(
            0x3bd8cff538aba49a9c374c806d277181e9651624b3e31111bc0624574f8bca1d
        );
        _bulkOrderTypehashes[23] = bytes32(
            0x5d6a3f098a0bc373f808c619b1bb4028208721b3c4f8d6bc8a874d659814eb76
        );
        _bulkOrderTypehashes[24] = bytes32(
            0x1d51df90cba8de7637ca3e8fe1e3511d1dc2f23487d05dbdecb781860c21ac1c
        );
    }

    /**
     * @dev Internal view function to derive the initial EIP-712 domain
     *      separator.
     *
     * @param _eip712DomainTypeHash      The primary EIP-712 domain typehash.
     * @param _nameHash                  The hash of the name of the contract.
     * @param _versionHash               The hash of the version string of the
     *                                   contract.
     *
     * @return domainSeparator           The derived domain separator.
     */
    function _deriveInitialDomainSeparator(
        bytes32 _eip712DomainTypeHash,
        bytes32 _nameHash,
        bytes32 _versionHash
    ) internal view virtual returns (bytes32 domainSeparator) {
        return
            _deriveDomainSeparator(
                _eip712DomainTypeHash,
                _nameHash,
                _versionHash
            );
    }

    /**
     * @dev Internal view function to derive the EIP-712 domain separator.
     *
     * @return The derived domain separator.
     */
    function _deriveDomainSeparator(
        bytes32 _eip712DomainTypeHash,
        bytes32 _nameHash,
        bytes32 _versionHash
    ) internal view virtual returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _eip712DomainTypeHash,
                _nameHash,
                _versionHash,
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev Internal pure function to derive required EIP-712 typehashes and
     *      other hashes during contract creation.
     *
     * @return nameHash                  The hash of the name of the contract.
     * @return versionHash               The hash of the version string of the
     *                                   contract.
     * @return eip712DomainTypehash      The primary EIP-712 domain typehash.
     * @return offerItemTypehash         The EIP-712 typehash for OfferItem
     *                                   types.
     * @return considerationItemTypehash The EIP-712 typehash for
     *                                   ConsiderationItem types.
     * @return orderTypehash             The EIP-712 typehash for Order types.
     * @return bulkOrderTypeHash
     * @return domainSeparator           The domain separator.
     */
    function _deriveTypehashes()
        internal
        view
        returns (
            bytes32 nameHash,
            bytes32 versionHash,
            bytes32 eip712DomainTypehash,
            bytes32 offerItemTypehash,
            bytes32 considerationItemTypehash,
            bytes32 orderTypehash,
            bytes32 bulkOrderTypeHash,
            bytes32 domainSeparator
        )
    {
        // Derive hash of the name of the contract.
        nameHash = keccak256(bytes(_NAME));

        // Derive hash of the version string of the contract.
        versionHash = keccak256(bytes(_VERSION));

        // Construct the OfferItem type string.
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

        // Construct the ConsiderationItem type string.
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

        // Construct the OrderComponents type string, not including the above.
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
                "uint256 counter",
            ")"
        );

        // Construct the primary EIP-712 domain type string.
        // prettier-ignore
        eip712DomainTypehash = keccak256(
            abi.encodePacked(
                "EIP712Domain(",
                    "string name,",
                    "string version,",
                    "uint256 chainId,",
                    "address verifyingContract",
                ")"
            )
        );

        // Derive the OfferItem type hash using the corresponding type string.
        offerItemTypehash = keccak256(offerItemTypeString);

        // Derive ConsiderationItem type hash using corresponding type string.
        considerationItemTypehash = keccak256(considerationItemTypeString);

        // Derive OrderItem type hash via combination of relevant type strings.
        orderTypehash = keccak256(
            abi.encodePacked(
                orderComponentsPartialTypeString,
                considerationItemTypeString,
                offerItemTypeString
            )
        );

        // Encode the type string for the BulkOrder struct.
        bytes memory bulkOrderPartialTypeString = abi.encodePacked(
            "BulkOrder(OrderComponents[2][2][2][2][2][2][2] tree)"
        );

        // Generate the keccak256 hash of the concatenated type strings for the
        // BulkOrder, considerationItem, offerItem, and orderComponents.
        bulkOrderTypeHash = keccak256(
            abi.encodePacked(
                bulkOrderPartialTypeString,
                considerationItemTypeString,
                offerItemTypeString,
                orderComponentsPartialTypeString
            )
        );

        // Derive the initial domain separator using the domain typehash, the
        // name hash, and the version hash.
        domainSeparator = _deriveInitialDomainSeparator(
            eip712DomainTypehash,
            nameHash,
            versionHash
        );
    }
}
