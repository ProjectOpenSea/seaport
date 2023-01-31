// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ZoneParameters, Schema } from "../lib/ConsiderationStructs.sol";

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import { SignedZoneInterface } from "./interfaces/SignedZoneInterface.sol";

import {
    SignedZoneEventsAndErrors
} from "./interfaces/SignedZoneEventsAndErrors.sol";

import { SIP5Interface } from "./interfaces/SIP5Interface.sol";

import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @title  SignedZone
 * @author ryanio, BCLeFevre
 * @notice SignedZone is an implementation of SIP-7 that requires orders
 *         to be signed by an approved signer.
 *         https://github.com/ProjectOpenSea/SIPs/blob/main/SIPS/sip-7.md
 */
contract SignedZone is
    SignedZoneEventsAndErrors,
    ZoneInterface,
    SignedZoneInterface,
    SIP5Interface,
    ERC165,
    Ownable2Step
{
    /// @dev The authorized signers.
    mapping(address => SignerInfo) private _signers;

    /// @dev The currently active signers.
    address[] private _activeSigners;

    /// @dev The API endpoint where orders for this zone can be signed.
    ///      Request and response payloads are defined in SIP-7.
    string private _sip7APIEndpoint;

    /// @dev The substandards supported by this zone.
    ///      Substandards are defined in SIP-7.
    uint256[] private _sip7Substandards = [1];

    /// @dev The URI to the documentation describing the behavior of the
    ///      contract.
    string private _sip7DocumentationURI;

    /// @dev The name for this zone returned in getSeaportMetadata().
    string private _ZONE_NAME;

    /// @dev The EIP-712 digest parameters.
    bytes32 internal immutable _NAME_HASH = keccak256(bytes("SignedZone"));
    bytes32 internal immutable _VERSION_HASH = keccak256(bytes("1.0"));
    // prettier-ignore
    bytes32 internal immutable _EIP_712_DOMAIN_TYPEHASH = keccak256(
          abi.encodePacked(
            "EIP712Domain(",
                "string name,",
                "string version,",
                "uint256 chainId,",
                "address verifyingContract",
            ")"
          )
        );
    // prettier-ignore
    bytes32 internal immutable _SIGNED_ORDER_TYPEHASH = keccak256(
          abi.encodePacked(
            "SignedOrder(",
                "address fulfiller,",
                "uint64 expiration,",
                "bytes32 orderHash,",
                "bytes context",
            ")"
          )
        );
    uint256 internal immutable _CHAIN_ID = block.chainid;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    /* solhint-disable private-vars-leading-underscore */
    /* solhint-disable const-name-snakecase */

    /// @dev ECDSA signature offsets.
    uint256 internal constant ECDSA_MaxLength = 65;
    uint256 internal constant ECDSA_signature_s_offset = 0x40;
    uint256 internal constant ECDSA_signature_v_offset = 0x60;

    /// @dev Helpers for memory offsets.
    uint256 internal constant OneWord = 0x20;
    uint256 internal constant TwoWords = 0x40;
    uint256 internal constant ThreeWords = 0x60;
    uint256 internal constant FourWords = 0x80;
    uint256 internal constant FiveWords = 0xa0;
    uint256 internal constant Signature_lower_v = 27;
    uint256 internal constant MaxUint8 = 0xff;
    bytes32 internal constant EIP2098_allButHighestBitMask = (
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );
    uint256 internal constant Ecrecover_precompile = 1;
    uint256 internal constant Ecrecover_args_size = 0x80;
    uint256 internal constant FreeMemoryPointerSlot = 0x40;
    uint256 internal constant ZeroSlot = 0x60;
    uint256 internal constant Slot0x80 = 0x80;

    /// @dev The EIP-712 digest offsets.
    uint256 internal constant EIP712_DomainSeparator_offset = 0x02;
    uint256 internal constant EIP712_SignedOrderHash_offset = 0x22;
    uint256 internal constant EIP712_DigestPayload_size = 0x42;
    uint256 internal constant EIP_712_PREFIX = (
        0x1901000000000000000000000000000000000000000000000000000000000000
    );

    /*
     *  error InvalidFulfiller(address expectedFulfiller, address actualFulfiller, bytes32 orderHash)
     *    - Defined in SignedZoneEventsAndErrors.sol
     *  Memory layout:
     *    - 0x00: Left-padded selector (data begins at 0x1c)
     *    - 0x20: expectedFulfiller
     *    - 0x40: actualFullfiller
     *    - 0x60: orderHash
     * Revert buffer is memory[0x1c:0x80]
     */
    uint256 constant InvalidFulfiller_error_selector = 0x1bcf9bb7;
    uint256 constant InvalidFulfiller_error_expectedFulfiller_ptr = 0x20;
    uint256 constant InvalidFulfiller_error_actualFulfiller_ptr = 0x40;
    uint256 constant InvalidFulfiller_error_orderHash_ptr = 0x60;
    uint256 constant InvalidFulfiller_error_length = 0x64;

    /*
     *  error InvalidReceivedItem(uint256 expectedReceivedIdentifier, uint256 actualReceievedIdentifier, bytes32 orderHash)
     *    - Defined in SignedZoneEventsAndErrors.sol
     *  Memory layout:
     *    - 0x00: Left-padded selector (data begins at 0x1c)
     *    - 0x20: expectedReceivedIdentifier
     *    - 0x40: actualReceievedIdentifier
     *    - 0x60: orderHash
     * Revert buffer is memory[0x1c:0x80]
     */
    uint256 constant InvalidReceivedItem_error_selector = 0xb36c03e8;
    uint256 constant InvalidReceivedItem_error_expectedReceivedItem_ptr = 0x20;
    uint256 constant InvalidReceivedItem_error_actualReceivedItem_ptr = 0x40;
    uint256 constant InvalidReceivedItem_error_orderHash_ptr = 0x60;
    uint256 constant InvalidReceivedItem_error_length = 0x64;

    /*
     *  error InvalidZoneParameterEncoding()
     *    - Defined in SignedZoneEventsAndErrors.sol
     *  Memory layout:
     *    - 0x00: Left-padded selector (data begins at 0x1c)
     * Revert buffer is memory[0x1c:0x20]
     */
    uint256 constant InvalidZoneParameterEncoding_error_selector = 0x46d5d895;
    uint256 constant InvalidZoneParameterEncoding_error_length = 0x04;

    /*
     * error InvalidExtraDataLength()
     *   - Defined in SignedZoneEventsAndErrors.sol
     * Memory layout:
     *   - 0x00: Left-padded selector (data begins at 0x1c)
     *   - 0x20: orderHash
     * Revert buffer is memory[0x1c:0x40]
     */
    uint256 constant InvalidExtraDataLength_error_selector = 0xd232fd2c;
    uint256 constant InvalidExtraDataLength_error_orderHash_ptr = 0x20;
    uint256 constant InvalidExtraDataLength_error_length = 0x24;
    uint256 constant InvalidExtraDataLength_epected_length = 0x7e;

    uint256 constant ExtraData_expiration_offset = 0x35;
    uint256 constant ExtraData_substandard_version_byte_offset = 0x7d;
    /*
     *  error InvalidSIP6Version()
     *    - Defined in SignedZoneEventsAndErrors.sol
     *  Memory layout:
     *    - 0x00: Left-padded selector (data begins at 0x1c)
     *    - 0x20: orderHash
     * Revert buffer is memory[0x1c:0x40]
     */
    uint256 constant InvalidSIP6Version_error_selector = 0x64115774;
    uint256 constant InvalidSIP6Version_error_orderHash_ptr = 0x20;
    uint256 constant InvalidSIP6Version_error_length = 0x24;

    /*
     *  error InvalidSubstandardVersion()
     *    - Defined in SignedZoneEventsAndErrors.sol
     *  Memory layout:
     *    - 0x00: Left-padded selector (data begins at 0x1c)
     *    - 0x20: orderHash
     * Revert buffer is memory[0x1c:0x40]
     */
    uint256 constant InvalidSubstandardVersion_error_selector = 0x26787999;
    uint256 constant InvalidSubstandardVersion_error_orderHash_ptr = 0x20;
    uint256 constant InvalidSubstandardVersion_error_length = 0x24;

    /*
     *  error InvalidSubstandardSupport()
     *    - Defined in SignedZoneEventsAndErrors.sol
     *  Memory layout:
     *    - 0x00: Left-padded selector (data begins at 0x1c)
     *    - 0x20: reason
     *    - 0x40: substandardVersion
     *    - 0x60: orderHash
     * Revert buffer is memory[0x1c:0xe0]
     */
    uint256 constant InvalidSubstandardSupport_error_selector = 0x2be76224;
    uint256 constant InvalidSubstandardSupport_error_reason_offset_ptr = 0x20;
    uint256 constant InvalidSubstandardSupport_error_substandard_version_ptr =
        0x40;
    uint256 constant InvalidSubstandardSupport_error_orderHash_ptr = 0x60;
    uint256 constant InvalidSubstandardSupport_error_reason_length_ptr = 0x80;
    uint256 constant InvalidSubstandardSupport_error_reason_ptr = 0xa0;
    uint256 constant InvalidSubstandardSupport_error_reason_2_ptr = 0xc0;
    uint256 constant InvalidSubstandardSupport_error_length = 0xc4;

    /*
     * error SignatureExpired()
     *   - Defined in SignedZoneEventsAndErrors.sol
     * Memory layout:
     *   - 0x00: Left-padded selector (data begins at 0x1c)
     *   - 0x20: expiration
     *   - 0x40: orderHash
     * Revert buffer is memory[0x1c:0x60]
     */
    uint256 constant SignatureExpired_error_selector = 0x16546071;
    uint256 constant SignatureExpired_error_expiration_ptr = 0x20;
    uint256 constant SignatureExpired_error_orderHash_ptr = 0x40;
    uint256 constant SignatureExpired_error_length = 0x44;

    // Zone parameter calldata pointers
    uint256 constant Zone_parameters_cdPtr = 0x04;
    uint256 constant Zone_parameters_fulfiller_cdPtr = 0x44;
    uint256 constant Zone_consideration_head_cdPtr = 0xa4;
    uint256 constant Zone_extraData_cdPtr = 0xc4;

    // Zone parameter memory pointers
    uint256 constant Zone_parameters_ptr = 0x20;

    // Zone parameter offsets
    uint256 constant Zone_parameters_offset = 0x24;
    uint256 constant expectedFulfiller_offset = 0x45;
    uint256 constant actualReceivedIdentifier_offset = 0x84;
    uint256 constant expectedReceivedIdentifier_offset = 0xa2;

    /* solhint-enable private-vars-leading-underscore */
    /* solhint-enable const-name-snakecase */

    /**
     * @dev Modifier to restrict access to the owner or an active signer.
     */
    modifier onlyOwnerOrActiveSigner() {
        if (msg.sender != owner() && !_signers[msg.sender].active) {
            revert OnlyOwnerOrActiveSigner();
        }

        _;
    }

    /**
     * @notice Constructor to deploy the contract.
     *
     * @param zoneName         The name for the zone returned in
     *                         getSeaportMetadata().
     * @param apiEndpoint      The API endpoint where orders for this zone can
     *                         be signed.
     *                         Request and response payloads are defined in
     *                         SIP-7.
     * @param documentationURI The URI to the documentation describing the
     *                         behavior of the contract.
     */
    constructor(
        string memory zoneName,
        string memory apiEndpoint,
        string memory documentationURI
    ) {
        // Set the zone name.
        _ZONE_NAME = zoneName;

        // Set the API endpoint.
        _sip7APIEndpoint = apiEndpoint;

        // Set the documentation URI.
        _sip7DocumentationURI = documentationURI;

        // Derive and set the domain separator.
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();

        // Emit an event to signal a SIP-5 contract has been deployed.
        emit SeaportCompatibleContractDeployed();
    }

    /**
     * @notice Add a new signer to the zone.
     *         Only the owner or an active signer can call this function.
     *
     * @param signer The new signer address to add.
     */
    function addSigner(address signer)
        external
        override
        onlyOwnerOrActiveSigner
    {
        // Do not allow the zero address to be added as a signer.
        if (signer == address(0)) {
            revert SignerCannotBeZeroAddress();
        }

        // Revert if the signer is already added.
        if (_signers[signer].active) {
            revert SignerAlreadyAdded(signer);
        }

        // Revert if the signer was previously authorized.
        if (_signers[signer].previouslyActive) {
            revert SignerCannotBeReauthorized(signer);
        }

        // Set the signer info.
        _signers[signer] = SignerInfo(true, true);

        // Add the signer to _activeSigners.
        _activeSigners.push(signer);

        // Emit an event that the signer was added.
        emit SignerAdded(signer);
    }

    /**
     * @notice Remove an active signer from the zone.
     *         Only the owner or an active signer can call this function.
     *
     * @param signer The signer address to remove.
     */
    function removeSigner(address signer)
        external
        override
        onlyOwnerOrActiveSigner
    {
        // Revert if the signer is not active.
        if (!_signers[signer].active) {
            revert SignerNotPresent(signer);
        }

        // Set the signer's active status to false.
        _signers[signer].active = false;

        // Remove the signer from _activeSigners.
        for (uint256 i = 0; i < _activeSigners.length; ) {
            if (_activeSigners[i] == signer) {
                _activeSigners[i] = _activeSigners[_activeSigners.length - 1];
                _activeSigners.pop();
                break;
            }

            unchecked {
                ++i;
            }
        }

        // Emit an event that the signer was removed.
        emit SignerRemoved(signer);
    }

    /**
     * @notice Update the API endpoint returned by this zone.
     *         Only the owner or an active signer can call this function.
     *
     * @param newApiEndpoint The new API endpoint.
     */
    function updateAPIEndpoint(string calldata newApiEndpoint)
        external
        override
        onlyOwnerOrActiveSigner
    {
        // Update to the new API endpoint.
        _sip7APIEndpoint = newApiEndpoint;
    }

    /**
     * @notice Check if a given order including extraData is currently valid.
     *
     * @dev This function is called by Seaport whenever any extraData is
     *      provided by the caller.
     *
     * @return validOrderMagicValue A magic value indicating if the order is
     *                              currently valid.
     */
    function validateOrder(ZoneParameters calldata zoneParameters)
        external
        view
        override
        returns (bytes4 validOrderMagicValue)
    {
        // Check Zone parameters validity.
        _assertValidZoneParameters();

        // Put the extraData and orderHash on the stack for cheaper access.
        bytes calldata extraData = zoneParameters.extraData;
        bytes32 orderHash = zoneParameters.orderHash;

        // Declare a variable to hold the expiration.
        uint64 expiration;

        // Validate the extraData.
        assembly {
            // Get the length of the extraData.
            let extraDataPtr := add(0x24, calldataload(Zone_extraData_cdPtr))
            let extraDataLength := calldataload(extraDataPtr)

            if iszero(
                eq(extraDataLength, InvalidExtraDataLength_epected_length)
            ) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, InvalidExtraDataLength_error_selector)
                mstore(InvalidExtraDataLength_error_orderHash_ptr, orderHash)
                // revert(abi.encodeWithSignature(
                //   "InvalidExtraDataLength(bytes32)", orderHash)
                // )
                revert(0x1c, InvalidExtraDataLength_error_length)
            }

            // extraData bytes 0-1: SIP-6 version byte (MUST be 0x00)
            let versionByte := shr(248, calldataload(add(extraDataPtr, 0x20)))

            if iszero(eq(versionByte, 0x00)) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, InvalidSIP6Version_error_selector)
                mstore(InvalidSIP6Version_error_orderHash_ptr, orderHash)
                // revert(abi.encodeWithSignature(
                //   "InvalidSIP6Version(bytes32)", orderHash)
                // )
                revert(0x1c, InvalidSIP6Version_error_length)
            }

            // extraData bytes 93-94: Substandard #1 (MUST be 0x00)
            let subStandardVersionByte := shr(
                248,
                calldataload(
                    add(extraDataPtr, ExtraData_substandard_version_byte_offset)
                )
            )

            if iszero(eq(subStandardVersionByte, 0x00)) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, InvalidSubstandardVersion_error_selector)
                mstore(InvalidSubstandardVersion_error_orderHash_ptr, orderHash)
                // revert(abi.encodeWithSignature(
                //   "InvalidSubstandardVersion(bytes32)", orderHash)
                // )
                revert(0x1c, InvalidSubstandardVersion_error_length)
            }

            // extraData bytes 21-29: expiration timestamp (uint64)
            expiration := shr(
                192,
                calldataload(add(extraDataPtr, ExtraData_expiration_offset))
            )
            // Revert if expired.
            if lt(expiration, timestamp()) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, SignatureExpired_error_selector)
                mstore(SignatureExpired_error_expiration_ptr, expiration)
                mstore(SignatureExpired_error_orderHash_ptr, orderHash)
                // revert(abi.encodeWithSignature(
                //   "SignatureExpired(uint256, bytes32)", expiration orderHash)
                // )
                revert(0x1c, SignatureExpired_error_length)
            }

            // Get the length of the consideration array.
            let considerationLength := calldataload(
                add(0x24, calldataload(Zone_consideration_head_cdPtr))
            )

            // // Revert if the order does not have any consideration items.
            // // (Substandard #1 requirement)
            if iszero(considerationLength) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, InvalidSubstandardSupport_error_selector)
                mstore(InvalidSubstandardSupport_error_reason_offset_ptr, 0x60)
                mstore(
                    InvalidSubstandardSupport_error_substandard_version_ptr,
                    1
                )
                mstore(InvalidSubstandardSupport_error_orderHash_ptr, orderHash)
                mstore(InvalidSubstandardSupport_error_reason_length_ptr, 0x2a) // 42 length
                mstore(
                    InvalidSubstandardSupport_error_reason_ptr,
                    "Consideration must have at least"
                )
                mstore(
                    InvalidSubstandardSupport_error_reason_2_ptr,
                    " one item."
                )
                revert(0x1c, InvalidSubstandardSupport_error_length)
            }
        }

        // extraData bytes 29-93: signature
        // (strictly requires 64 byte compact sig, EIP-2098)
        bytes calldata signature = extraData[29:93];

        // // extraData bytes 93-end: context (optional, variable length)
        bytes calldata context = extraData[93:];

        // Check the validity of the Substandard #1 extraData and get the
        // expected fulfiller address.
        address expectedFulfiller = _assertValidSubstandardAndGetExpectedFulfiller(
                orderHash
            );

        // Derive the signedOrder hash.
        bytes32 signedOrderHash = _deriveSignedOrderHash(
            expectedFulfiller,
            expiration,
            orderHash,
            context
        );

        // Derive the EIP-712 digest using the domain separator and signedOrder
        // hash.
        bytes32 digest = _deriveEIP712Digest(
            _domainSeparator(),
            signedOrderHash
        );

        // Recover the signer address from the digest and signature.
        address recoveredSigner = _recoverSigner(digest, signature);

        // Revert if the signer is not active.
        if (!_signers[recoveredSigner].active) {
            revert SignerNotActive(recoveredSigner, orderHash);
        }

        // Return the selector of validateOrder as the magic value.
        validOrderMagicValue = ZoneInterface.validateOrder.selector;
    }

    /**
     * @notice Returns the active signers for the zone.
     *
     * @return signers The active signers.
     */
    function getActiveSigners()
        external
        view
        override
        returns (address[] memory signers)
    {
        // Return the active signers for the zone.
        signers = _activeSigners;
    }

    /**
     * @notice External call to return the signing information, substandards,
     *         and documentation about the zone.
     *
     * @return domainSeparator  The domain separator used for signing.
     * @return apiEndpoint      The API endpoint for the zone.
     * @return substandards     The substandards supported by the zone.
     * @return documentationURI The documentation URI for the zone.
     */
    function sip7Information()
        external
        view
        override
        returns (
            bytes32 domainSeparator,
            string memory apiEndpoint,
            uint256[] memory substandards,
            string memory documentationURI
        )
    {
        // Return the SIP-7 information.
        return _sip7Information();
    }

    /**
     * @dev Returns Seaport metadata for this contract, returning the
     *      contract name and supported schemas.
     *
     * @return name    The contract name
     * @return schemas The supported SIPs
     */
    function getSeaportMetadata()
        external
        view
        override(SIP5Interface, ZoneInterface)
        returns (string memory name, Schema[] memory schemas)
    {
        // Return the zone name.
        name = _ZONE_NAME;

        // Return the supported SIPs.
        schemas = new Schema[](1);
        schemas[0].id = 7;

        // Encode the SIP-7 information.

        (
            bytes32 domainSeparator,
            string memory apiEndpoint,
            uint256[] memory substandards,
            string memory documentationURI
        ) = _sip7Information();

        schemas[0].metadata = abi.encode(
            domainSeparator,
            apiEndpoint,
            substandards,
            documentationURI
        );
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165)
        returns (bool)
    {
        return
            interfaceId == type(SIP5Interface).interfaceId || // SIP-5
            interfaceId == type(ZoneInterface).interfaceId || // ZoneInterface
            super.supportsInterface(interfaceId); // ERC-165
    }

    /**
     * @notice Internal call to return the signing information, substandards,
     *         and documentation about the zone.
     *
     * @return domainSeparator  The domain separator used for signing.
     * @return apiEndpoint      The API endpoint for the zone.
     * @return substandards     The substandards supported by the zone.
     * @return documentationURI The documentation URI for the zone.
     */
    function _sip7Information()
        internal
        view
        returns (
            bytes32 domainSeparator,
            string memory apiEndpoint,
            uint256[] memory substandards,
            string memory documentationURI
        )
    {
        // Return the SIP-7 information.
        domainSeparator = _domainSeparator();
        apiEndpoint = _sip7APIEndpoint;
        substandards = _sip7Substandards;
        documentationURI = _sip7DocumentationURI;
    }

    /**
     * @dev Derive the signedOrder hash from the orderHash and expiration.
     *
     * @param fulfiller  The expected fulfiller address.
     * @param expiration The signature expiration timestamp.
     * @param orderHash  The order hash.
     * @param context    The optional variable-length context.
     *
     * @return signedOrderHash The signedOrder hash.
     *
     */
    function _deriveSignedOrderHash(
        address fulfiller,
        uint64 expiration,
        bytes32 orderHash,
        bytes calldata context
    ) internal view returns (bytes32 signedOrderHash) {
        // Derive the signed order hash.
        signedOrderHash = keccak256(
            abi.encode(
                _SIGNED_ORDER_TYPEHASH,
                fulfiller,
                expiration,
                orderHash,
                keccak256(context)
            )
        );
    }

    /**
     * @dev Internal view function to return the signer of a signature.
     *
     * @param digest    The digest to verify the signature against.
     * @param signature A signature from the signer indicating that the order
     *                  has been approved.
     *
     * @return recoveredSigner The recovered signer.
     */
    function _recoverSigner(bytes32 digest, bytes memory signature)
        internal
        view
        returns (address recoveredSigner)
    {
        // Utilize assembly to perform optimized signature verification check.
        assembly {
            // Ensure that first word of scratch space is empty.
            mstore(0, 0)

            // Declare value for v signature parameter.
            let v

            // Get the length of the signature.
            let signatureLength := mload(signature)

            // Get the pointer to the value preceding the signature length.
            // This will be used for temporary memory overrides - either the
            // signature head for isValidSignature or the digest for ecrecover.
            let wordBeforeSignaturePtr := sub(signature, OneWord)

            // Cache the current value behind the signature to restore it later.
            let cachedWordBeforeSignature := mload(wordBeforeSignaturePtr)

            // Declare lenDiff + recoveredSigner scope to manage stack pressure.
            {
                // Take the difference between the max ECDSA signature length
                // and the actual signature length. Overflow desired for any
                // values > 65. If the diff is not 0 or 1, it is not a valid
                // ECDSA signature - move on to EIP1271 check.
                let lenDiff := sub(ECDSA_MaxLength, signatureLength)

                // If diff is 0 or 1, it may be an ECDSA signature.
                // Try to recover signer.
                if iszero(gt(lenDiff, 1)) {
                    // Read the signature `s` value.
                    let originalSignatureS := mload(
                        add(signature, ECDSA_signature_s_offset)
                    )

                    // Read the first byte of the word after `s`. If the
                    // signature is 65 bytes, this will be the real `v` value.
                    // If not, it will need to be modified - doing it this way
                    // saves an extra condition.
                    v := byte(
                        0,
                        mload(add(signature, ECDSA_signature_v_offset))
                    )

                    // If lenDiff is 1, parse 64-byte signature as ECDSA.
                    if lenDiff {
                        // Extract yParity from highest bit of vs and add 27 to
                        // get v.
                        v := add(
                            shr(MaxUint8, originalSignatureS),
                            Signature_lower_v
                        )

                        // Extract canonical s from vs, all but the highest bit.
                        // Temporarily overwrite the original `s` value in the
                        // signature.
                        mstore(
                            add(signature, ECDSA_signature_s_offset),
                            and(
                                originalSignatureS,
                                EIP2098_allButHighestBitMask
                            )
                        )
                    }
                    // Temporarily overwrite the signature length with `v` to
                    // conform to the expected input for ecrecover.
                    mstore(signature, v)

                    // Temporarily overwrite the word before the length with
                    // `digest` to conform to the expected input for ecrecover.
                    mstore(wordBeforeSignaturePtr, digest)

                    // Attempt to recover the signer for the given signature. Do
                    // not check the call status as ecrecover will return a null
                    // address if the signature is invalid.
                    pop(
                        staticcall(
                            gas(),
                            Ecrecover_precompile, // Call ecrecover precompile.
                            wordBeforeSignaturePtr, // Use data memory location.
                            Ecrecover_args_size, // Size of digest, v, r, and s.
                            0, // Write result to scratch space.
                            OneWord // Provide size of returned result.
                        )
                    )

                    // Restore cached word before signature.
                    mstore(wordBeforeSignaturePtr, cachedWordBeforeSignature)

                    // Restore cached signature length.
                    mstore(signature, signatureLength)

                    // Restore cached signature `s` value.
                    mstore(
                        add(signature, ECDSA_signature_s_offset),
                        originalSignatureS
                    )

                    // Read the recovered signer from the buffer given as return
                    // space for ecrecover.
                    recoveredSigner := mload(0)
                }
            }

            // Restore the cached values overwritten by selector, digest and
            // signature head.
            mstore(wordBeforeSignaturePtr, cachedWordBeforeSignature)
        }
    }

    /**
     * @dev Internal view function to get the EIP-712 domain separator. If the
     *      chainId matches the chainId set on deployment, the cached domain
     *      separator will be returned; otherwise, it will be derived from
     *      scratch.
     *
     * @return The domain separator.
     */
    function _domainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return block.chainid == _CHAIN_ID
            ? _DOMAIN_SEPARATOR
            : _deriveDomainSeparator();
    }

    /**
     * @dev Internal view function to derive the EIP-712 domain separator.
     *
     * @return domainSeparator The derived domain separator.
     */
    function _deriveDomainSeparator()
        internal
        view
        returns (bytes32 domainSeparator)
    {
        bytes32 typehash = _EIP_712_DOMAIN_TYPEHASH;
        bytes32 nameHash = _NAME_HASH;
        bytes32 versionHash = _VERSION_HASH;

        // Leverage scratch space and other memory to perform an efficient hash.
        assembly {
            // Retrieve the free memory pointer; it will be replaced afterwards.
            let freeMemoryPointer := mload(FreeMemoryPointerSlot)

            // Retrieve value at 0x80; it will also be replaced afterwards.
            let slot0x80 := mload(Slot0x80)

            // Place typehash, name hash, and version hash at start of memory.
            mstore(0, typehash)
            mstore(OneWord, nameHash)
            mstore(TwoWords, versionHash)

            // Place chainId in the next memory location.
            mstore(ThreeWords, chainid())

            // Place the address of this contract in the next memory location.
            mstore(FourWords, address())

            // Hash relevant region of memory to derive the domain separator.
            domainSeparator := keccak256(0, FiveWords)

            // Restore the free memory pointer.
            mstore(FreeMemoryPointerSlot, freeMemoryPointer)

            // Restore the zero slot to zero.
            mstore(ZeroSlot, 0)

            // Restore the value at 0x80.
            mstore(Slot0x80, slot0x80)
        }
    }

    /**
     * @dev Internal pure function to efficiently derive an digest to sign for
     *      an order in accordance with EIP-712.
     *
     * @param domainSeparator The domain separator.
     * @param signedOrderHash The signedOrder hash.
     *
     * @return digest The digest hash.
     */
    function _deriveEIP712Digest(
        bytes32 domainSeparator,
        bytes32 signedOrderHash
    ) internal pure returns (bytes32 digest) {
        // Leverage scratch space to perform an efficient hash.
        assembly {
            // Place the EIP-712 prefix at the start of scratch space.
            mstore(0, EIP_712_PREFIX)

            // Place the domain separator in the next region of scratch space.
            mstore(EIP712_DomainSeparator_offset, domainSeparator)

            // Place the signed order hash in scratch space, spilling into the
            // first two bytes of the free memory pointer — this should never be
            // set as memory cannot be expanded to that size, and will be
            // zeroed out after the hash is performed.
            mstore(EIP712_SignedOrderHash_offset, signedOrderHash)

            // Hash the relevant region
            digest := keccak256(0, EIP712_DigestPayload_size)

            // Clear out the dirtied bits in the memory pointer.
            mstore(EIP712_SignedOrderHash_offset, 0)
        }
    }

    /**
     * @dev Internal pure function to validate calldata offsets for the
     *      dyanamic type in ZoneParameters. This ensures that functions using
     *      the calldata object normally will be using the same data as the
     *      assembly functions and that values that are bound to a given range
     *      are within that range.
     */
    function _assertValidZoneParameters() internal pure {
        // Utilize assembly in order to read offset data directly from calldata.
        assembly {
            /*
             * Checks:
             * 1. Zone parameters struct offset == 0x20
             */

            // Zone parameters at calldata 0x04 must have offset of 0x20.
            if iszero(
                eq(calldataload(Zone_parameters_cdPtr), Zone_parameters_ptr)
            ) {
                // Store left-padded selector with push4 (reduces bytecode), mem[28:32] = selector
                mstore(0, InvalidZoneParameterEncoding_error_selector)
                // revert(abi.encodeWithSignature("InvalidZoneParameterEncoding()"))
                revert(0x1c, InvalidZoneParameterEncoding_error_length)
            }
        }
    }

    /**
     * @dev Internal pure function to ensure that the context argument for the
     *      supplied extra data follows the substandard #1 format. Returns the
     *      expected fulfiller of the order for deriving the signed order hash.
     *
     * @param orderHash The order hash.
     *
     * @return expectedFulfiller The expected fulfiller of the order.
     */
    function _assertValidSubstandardAndGetExpectedFulfiller(bytes32 orderHash)
        internal
        pure
        returns (address expectedFulfiller)
    {
        // Revert if the expected fulfiller is not the zero address and does
        // not match the actual fulfiller or if the expected received
        // identifier does not match the actual received identifier.
        assembly {
            // Get the actual fulfiller.
            let actualFulfiller := calldataload(Zone_parameters_fulfiller_cdPtr)
            let extraDataPtr := calldataload(Zone_extraData_cdPtr)
            let considerationPtr := calldataload(Zone_consideration_head_cdPtr)

            // Get the expected fulfiller.
            expectedFulfiller := shr(
                96,
                calldataload(add(expectedFulfiller_offset, extraDataPtr))
            )

            // Get the actual received identifier.
            let actualReceivedIdentifier := calldataload(
                add(actualReceivedIdentifier_offset, considerationPtr)
            )

            // Get the expected received identifier.
            let expectedReceivedIdentifier := calldataload(
                add(expectedReceivedIdentifier_offset, extraDataPtr)
            )

            // Revert if expected fulfiller is not the zero address and does
            // not match the actual fulfiller.
            if and(
                iszero(iszero(expectedFulfiller)),
                iszero(eq(expectedFulfiller, actualFulfiller))
            ) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, InvalidFulfiller_error_selector)
                mstore(
                    InvalidFulfiller_error_expectedFulfiller_ptr,
                    expectedFulfiller
                )
                mstore(
                    InvalidFulfiller_error_actualFulfiller_ptr,
                    actualFulfiller
                )
                mstore(InvalidFulfiller_error_orderHash_ptr, orderHash)
                // revert(abi.encodeWithSignature(
                //   "InvalidFulfiller(address,address,bytes32)", expectedFulfiller, actualFulfiller, orderHash)
                // )
                revert(0x1c, InvalidFulfiller_error_length)
            }

            // Revert if expected received item does not match the actual
            // received item.
            if iszero(
                eq(expectedReceivedIdentifier, actualReceivedIdentifier)
            ) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, InvalidReceivedItem_error_selector)
                mstore(
                    InvalidReceivedItem_error_expectedReceivedItem_ptr,
                    expectedReceivedIdentifier
                )
                mstore(
                    InvalidReceivedItem_error_actualReceivedItem_ptr,
                    actualReceivedIdentifier
                )
                mstore(InvalidReceivedItem_error_orderHash_ptr, orderHash)
                // revert(abi.encodeWithSignature(
                //   "InvalidReceivedItem(uint256,uint256,bytes32)", expectedReceivedIdentifier, actualReceievedIdentifier, orderHash)
                // )
                revert(0x1c, InvalidReceivedItem_error_length)
            }
        }
    }
}
