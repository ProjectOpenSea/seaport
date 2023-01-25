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
 * @author ryanio
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
    uint256[] private _sip7Substandards;

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
     * @param substandards     The substandards supported by this zone.
     * @param documentationURI The URI to the documentation describing the
     *                         behavior of the contract.
     */
    constructor(
        string memory zoneName,
        string memory apiEndpoint,
        uint256[] memory substandards,
        string memory documentationURI
    ) {
        // Set the zone name.
        _ZONE_NAME = zoneName;

        // Set the API endpoint.
        _sip7APIEndpoint = apiEndpoint;

        // Set the substandards.
        _sip7Substandards = substandards;

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
        // Put the extraData and orderHash on the stack for cheaper access.
        bytes calldata extraData = zoneParameters.extraData;
        bytes32 orderHash = zoneParameters.orderHash;

        // Revert with an error if the extraData does not have valid length.
        if (extraData.length < 92) {
            revert InvalidExtraData(
                "extraData length must be at least 92 bytes",
                orderHash
            );
        }

        // extraData bytes 0-1: SIP-6 version byte (MUST be 0x00)
        if (extraData[0] != 0x00) {
            revert InvalidExtraData(
                "SIP-6 version byte must be 0x00",
                orderHash
            );
        }

        // extraData bytes 1-21: expected fulfiller
        // (zero address means not restricted)
        address expectedFulfiller = address(bytes20(extraData[1:21]));

        // extraData bytes 21-29: expiration timestamp (uint64)
        uint64 expiration = uint64(bytes8(extraData[21:29]));

        // extraData bytes 29-93: signature
        // (strictly requires 64 byte compact sig, EIP-2098)
        bytes calldata signature = extraData[29:93];

        // extraData bytes 93-end: context (optional, variable length)
        bytes calldata context = extraData[93:];

        // Revert if expired.
        if (block.timestamp > expiration) {
            revert SignatureExpired(expiration, orderHash);
        }

        // Put fulfiller on the stack for more efficient access.
        address actualFulfiller = zoneParameters.fulfiller;

        // Revert if expected fulfiller is not the zero address and does
        // not match the actual fulfiller.
        bool validFulfiller;
        assembly {
            validFulfiller := or(
                iszero(expectedFulfiller),
                eq(expectedFulfiller, actualFulfiller)
            )
        }
        if (!validFulfiller) {
            revert InvalidFulfiller(
                expectedFulfiller,
                actualFulfiller,
                orderHash
            );
        }

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
        SIP7InfoStruct memory sip7Info = _sip7Information();
        domainSeparator = sip7Info.domainSeparator;
        apiEndpoint = sip7Info.apiEndpoint;
        substandards = sip7Info.substandards;
        documentationURI = sip7Info.documentationURI;
    }

    /**
     * @notice Internal call to return the signing information, substandards,
     *         and documentation about the zone.
     *
     * @return sip7Info The SIP-7 information struct for the zone.
     */
    function _sip7Information()
        internal
        view
        returns (SIP7InfoStruct memory sip7Info)
    {
        // Build the SIP-7 information struct.
        sip7Info = SIP7InfoStruct({
            domainSeparator: _domainSeparator(),
            apiEndpoint: _sip7APIEndpoint,
            substandards: _sip7Substandards,
            documentationURI: _sip7DocumentationURI
        });
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
        schemas[0].metadata = abi.encode(_sip7Information());
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
     * @param digest           The digest to verify the signature against.
     * @param signature        A signature from the signer indicating that the
     *                         order has been approved.
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
}
