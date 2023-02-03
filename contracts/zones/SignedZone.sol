// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ZoneParameters, Schema } from "../lib/ConsiderationStructs.sol";

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import {
    SignedZoneEventsAndErrors
} from "./interfaces/SignedZoneEventsAndErrors.sol";

import { SIP5Interface } from "./interfaces/SIP5Interface.sol";

import {
    SignedZoneControllerInterface
} from "./interfaces/SignedZoneControllerInterface.sol";

import "./lib/SignedZoneConstants.sol";

/**
 * @title  SignedZone
 * @author ryanio, BCLeFevre
 * @notice SignedZone is an implementation of SIP-7 that requires orders
 *         to be signed by an approved signer.
 *         https://github.com/ProjectOpenSea/SIPs/blob/main/SIPS/sip-7.md
 */
contract SignedZone is SignedZoneEventsAndErrors, ZoneInterface, SIP5Interface {
    /// @dev The zone's controller that is set during deployment.
    address private immutable _controller;

    /// @dev The authorized signers, and if they are active
    mapping(address => bool) private _signers;

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

    /**
     * @notice Constructor to deploy the contract.
     */
    constructor() {
        // Set the deployer as the controller.
        _controller = msg.sender;

        // Derive and set the domain separator.
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();

        // Emit an event to signal a SIP-5 contract has been deployed.
        emit SeaportCompatibleContractDeployed();
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

            // Revert if the order does not have any consideration items.
            // (Substandard #1 requirement)
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

        // extraData bytes 93-end: context (optional, variable length)
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
        if (!_signers[recoveredSigner]) {
            revert SignerNotActive(recoveredSigner, orderHash);
        }
        // Return the selector of validateOrder as the magic value.
        validOrderMagicValue = ZoneInterface.validateOrder.selector;
    }

    /**
     * @dev Returns Seaport metadata for this contract, returning the
     *      contract name and supported schemas.
     *
     * @return name The contract name
     * @return schemas  The supported SIPs
     */
    function getSeaportMetadata()
        external
        view
        override(SIP5Interface, ZoneInterface)
        returns (string memory name, Schema[] memory schemas)
    {
        // Return the supported SIPs.
        schemas = new Schema[](1);
        schemas[0].id = 7;

        // Get the SIP-7 information.
        (
            bytes32 domainSeparator,
            string memory zoneName,
            string memory apiEndpoint,
            uint256[] memory substandards,
            string memory documentationURI
        ) = _sip7Information();

        // Return the zone name.
        name = zoneName;

        // Encode the SIP-7 information.
        schemas[0].metadata = abi.encode(
            domainSeparator,
            apiEndpoint,
            substandards,
            documentationURI
        );
    }

    /**
     * @notice The fallback function is used as a dispatcher for the
     *         `updateSigner`, `getActiveSigners` and `supportsInterface`
     *         functions.
     */
    // prettier-ignore
    fallback(bytes calldata) external payable returns (bytes memory output) {
        // Get the function selector.
        bytes4 selector = msg.sig;

        if (selector == 0xf460590b) {
            // updateSigner(address,bool)

            // Get the signer, and active status.
            address signer = abi.decode(msg.data[4:], (address));
            bool active = abi.decode(msg.data[36:], (bool));

            // Call to update the signer.
            _updateSigner(signer, active);
        } else if (selector == 0xa784b80c) {
            // getActiveSigners()

            // Call the internal function to get the active signers.
            return abi.encode(_getActiveSigners());
        } else if (selector == 0x01ffc9a7) {
            // supportsInterface(bytes4)

            // Get the interface ID.
            bytes4 interfaceId = abi.decode(msg.data[4:], (bytes4));

            // Call the internal function to determine if the interface is
            // supported.
            return abi.encode(_supportsInterface(interfaceId));
        }
    }

    /**
     * @notice Add or remove a signer to the zone.
     *         Only the controller can call this function.
     *
     * @param signer The signer address to add or remove.
     */
    function _updateSigner(address signer, bool active) internal {
        // Only the controller can call this function.
        _assertCallerIsController();
        // Add or remove the signer.
        active ? _addSigner(signer) : _removeSigner(signer);
    }

    /**
     * @notice Add a new signer to the zone.
     *         Only the controller or an active signer can call this function.
     *
     * @param signer The new signer address to add.
     */
    function _addSigner(address signer) internal {
        // Set the signer info.
        _signers[signer] = true;
        // Emit an event that the signer was added.
        emit SignerAdded(signer);
    }

    /**
     * @notice Remove an active signer from the zone.
     *         Only the controller or an active signer can call this function.
     *
     * @param signer The signer address to remove.
     */
    function _removeSigner(address signer) internal {
        // Set the signer's active status to false.
        _signers[signer] = false;

        // Emit an event that the signer was removed.
        emit SignerRemoved(signer);
    }

    /**
     * @notice Returns the active signers for the zone.
     *
     * @return signers The active signers.
     */
    function _getActiveSigners()
        internal
        view
        returns (address[] memory signers)
    {
        // Return the active signers for the zone by calling the controller.
        signers = SignedZoneControllerInterface(_controller).getActiveSigners(
            address(this)
        );
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function _supportsInterface(bytes4 interfaceId)
        internal
        pure
        returns (bool supportsInterface)
    {
        // Determine if the interface is supported.
        supportsInterface =
            interfaceId == type(SIP5Interface).interfaceId || // SIP-5
            interfaceId == type(ZoneInterface).interfaceId || // ZoneInterface
            interfaceId == 0x01ffc9a7; // ERC-165
    }

    /**
     * @notice Internal call to return the signing information, substandards,
     *         and documentation about the zone.
     *
     * @return domainSeparator  The domain separator used for signing.
     * @return zoneName         The zone name.
     * @return apiEndpoint      The API endpoint for the zone.
     * @return substandards     The substandards supported by the zone.
     * @return documentationURI The documentation URI for the zone.
     */
    function _sip7Information()
        internal
        view
        returns (
            bytes32 domainSeparator,
            string memory zoneName,
            string memory apiEndpoint,
            uint256[] memory substandards,
            string memory documentationURI
        )
    {
        // Return the SIP-7 information.
        domainSeparator = _domainSeparator();

        // Get the SIP-7 information from the controller.
        (
            ,
            zoneName,
            apiEndpoint,
            substandards,
            documentationURI
        ) = SignedZoneControllerInterface(_controller)
            .getAdditionalZoneInformation(address(this));
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
     * @dev Private view function to revert if the caller is not the
     *      controller.
     */
    function _assertCallerIsController() internal view {
        // Get the controller address to use in the assembly block.
        address controller = _controller;

        assembly {
            // Revert if the caller is not the controller.
            if iszero(eq(caller(), controller)) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, InvalidController_error_selector)
                // revert(abi.encodeWithSignature(
                //   "InvalidController()")
                // )
                revert(0x1c, InvalidController_error_length)
            }
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
