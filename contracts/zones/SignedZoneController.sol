// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { SignedZone } from "./SignedZone.sol";

import { SignedZoneInterface } from "./interfaces/SignedZoneInterface.sol";

import {
    SignedZoneControllerInterface
} from "./interfaces/SignedZoneControllerInterface.sol";

import {
    SignedZoneControllerEventsAndErrors
} from "./interfaces/SignedZoneControllerEventsAndErrors.sol";

import "./lib/SignedZoneConstants.sol";

/**
 * @title  SignedZoneController
 * @author BCLeFevre
 * @notice SignedZoneController enables the deploying of SignedZones and
 *         managing new SignedZone.
 *         SignedZones are an implementation of SIP-7 that requires orders to
 *         be signed by an approved signer.
 *         https://github.com/ProjectOpenSea/SIPs/blob/main/SIPS/sip-7.md
 */
contract SignedZoneController is
    SignedZoneControllerInterface,
    SignedZoneControllerEventsAndErrors
{
    /**
     * @dev The struct for storing signer info.
     */
    struct SignerInfo {
        /// @dev If the signer is currently active.
        bool active;
        /// @dev If the signer has been active before.
        bool previouslyActive;
    }

    // Properties used by the signed zone, stored on the controller.
    struct SignedZoneProperties {
        /// @dev Owner of the signed zone (used for permissioned functions)
        address owner;
        /// @dev Potential owner of the signed zone
        address potentialOwner;
        /// @dev The name for this zone returned in getSeaportMetadata().
        string zoneName;
        /// @dev The API endpoint where orders for this zone can be signed.
        ///      Request and response payloads are defined in SIP-7.
        string apiEndpoint;
        /// @dev The URI to the documentation describing the behavior of the
        ///      contract.
        string documentationURI;
        /// @dev The substandards supported by this zone.
        ///      Substandards are defined in SIP-7.
        uint256[] substandards;
        /// @dev Mapping of signer information keyed by signer Address
        mapping(address => SignerInfo) signers;
        /// @dev List of active signers
        address[] activeSignerList;
    }

    /// @dev Mapping of signed zone properties keyed by the Signed Zone
    ///      address.
    mapping(address => SignedZoneProperties) internal _signedZones;

    /// @dev The EIP-712 digest parameters for the SignedZone.
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
    uint256 internal immutable _CHAIN_ID = block.chainid;

    /**
     * @dev Initialize contract
     */
    constructor() {}

    /**
     * @notice Deploy a SignedZone to a precomputed address.
     *
     * @param zoneName          The name for the zone returned in
     *                          getSeaportMetadata().
     * @param apiEndpoint       The API endpoint where orders for this zone can
     *                          be signed.
     * @param documentationURI  The URI to the documentation describing the
     *                          behavior of the contract. Request and response
     *                          payloads are defined in SIP-7.
     * @param salt              The salt to be used to derive the zone address
     * @param initialOwner      The initial owner to set for the new zone.
     *
     * @return signedZone The derived address for the zone.
     */
    function createZone(
        string memory zoneName,
        string memory apiEndpoint,
        string memory documentationURI,
        address initialOwner,
        bytes32 salt
    ) external override returns (address signedZone) {
        // Ensure that an initial owner has been supplied.
        if (initialOwner == address(0)) {
            revert InvalidInitialOwner();
        }

        // Ensure the first 20 bytes of the salt are the same as the msg.sender.
        if ((address(uint160(bytes20(salt))) != msg.sender)) {
            // Revert with an error indicating that the creator is invalid.
            revert InvalidCreator();
        }

        // Get the creation code for the signed zone.
        bytes memory _SIGNED_ZONE_CREATION_CODE = abi.encodePacked(
            type(SignedZone).creationCode,
            abi.encode(zoneName)
        );

        // Using assembly try to deploy the zone.
        assembly {
            signedZone := create2(
                0,
                add(0x20, _SIGNED_ZONE_CREATION_CODE),
                mload(_SIGNED_ZONE_CREATION_CODE),
                salt
            )

            if iszero(extcodesize(signedZone)) {
                revert(0, 0)
            }
        }

        // Initialize storage variable referencing signed zone properties.
        SignedZoneProperties storage signedZoneProperties = _signedZones[
            signedZone
        ];

        // Set the supplied intial owner as the owner of the zone.
        signedZoneProperties.owner = initialOwner;
        // Set the zone name.
        signedZoneProperties.zoneName = zoneName;
        // Set the API endpoint.
        signedZoneProperties.apiEndpoint = apiEndpoint;
        // Set the documentation URI.
        signedZoneProperties.documentationURI = documentationURI;
        // Set the substandard.
        signedZoneProperties.substandards = [1];

        // Emit an event signifying that the zone was created.
        emit ZoneCreated(
            signedZone,
            zoneName,
            apiEndpoint,
            documentationURI,
            salt
        );

        // Emit an event indicating that zone ownership has been assigned.
        emit OwnershipTransferred(signedZone, address(0), initialOwner);
    }

    /**
     * @notice Initiate zone ownership transfer by assigning a new potential
     *         owner for the given zone. Once set, the new potential owner
     *         may call `acceptOwnership` to claim ownership of the zone.
     *         Only the owner of the zone in question may call this function.
     *
     * @param zone              The zone for which to initiate ownership
     *                          transfer.
     * @param newPotentialOwner The new potential owner of the zone.
     */
    function transferOwnership(address zone, address newPotentialOwner)
        external
        override
    {
        // Ensure the caller is the current owner of the zone in question.
        _assertCallerIsZoneOwner(zone);

        // Ensure the new potential owner is not an invalid address.
        if (newPotentialOwner == address(0)) {
            revert NewPotentialOwnerIsNullAddress(zone);
        }

        // Ensure the new potential owner is not already set.
        if (newPotentialOwner == _signedZones[zone].potentialOwner) {
            revert NewPotentialOwnerAlreadySet(zone, newPotentialOwner);
        }

        // Emit an event indicating that the potential owner has been updated.
        emit PotentialOwnerUpdated(newPotentialOwner);

        // Set the new potential owner as the potential owner of the zone.
        _signedZones[zone].potentialOwner = newPotentialOwner;
    }

    /**
     * @notice Clear the currently set potential owner, if any, from a zone.
     *         Only the owner of the zone in question may call this function.
     *
     * @param zone The zone for which to cancel ownership transfer.
     */
    function cancelOwnershipTransfer(address zone) external override {
        // Ensure the caller is the current owner of the zone in question.
        _assertCallerIsZoneOwner(zone);

        // Ensure that ownership transfer is currently possible.
        if (_signedZones[zone].potentialOwner == address(0)) {
            revert NoPotentialOwnerCurrentlySet(zone);
        }

        // Emit an event indicating that the potential owner has been cleared.
        emit PotentialOwnerUpdated(address(0));

        // Clear the current new potential owner from the zone.
        _signedZones[zone].potentialOwner = address(0);
    }

    /**
     * @notice Accept ownership of a supplied zone. Only accounts that the
     *         current owner has set as the new potential owner may call this
     *         function.
     *
     * @param zone The zone for which to accept ownership.
     */
    function acceptOwnership(address zone) external override {
        // Ensure that the zone in question exists.
        _assertZoneExists(zone);

        // If caller does not match current potential owner of the zone...
        if (msg.sender != _signedZones[zone].potentialOwner) {
            // Revert, indicating that caller is not current potential owner.
            revert CallerIsNotNewPotentialOwner(zone);
        }

        // Emit an event indicating that the potential owner has been cleared.
        emit PotentialOwnerUpdated(address(0));

        // Clear the current new potential owner from the zone.
        _signedZones[zone].potentialOwner = address(0);

        // Emit an event indicating zone ownership has been transferred.
        emit OwnershipTransferred(zone, _signedZones[zone].owner, msg.sender);

        // Set the caller as the owner of the zone.
        _signedZones[zone].owner = msg.sender;
    }

    /**
     * @notice Update the API endpoint returned by a zone.
     *         Only the owner or an active signer of the supplied zone can call
     *         this function.
     *
     * @param zone           The signed zone to update the API endpoint for.
     * @param newApiEndpoint The new API endpoint.
     */
    function updateAPIEndpoint(address zone, string calldata newApiEndpoint)
        external
        override
    {
        // Ensure the caller is the owner of the signed zone.
        _assertCallerIsZoneOwner(zone);

        // Retrieve storage region where the singers for the signedZone are
        // stored.
        SignedZoneProperties storage signedZoneProperties = _signedZones[zone];

        // Update the API endpoint on the signed zone.
        signedZoneProperties.apiEndpoint = newApiEndpoint;
    }

    /**
     * @notice Update the documentationURI returned by a zone.
     *         Only the owner or an active signer of the supplied zone can call
     *         this function.
     *
     * @param zone             The signed zone to update the documentationURI
     *                         for.
     * @param documentationURI The new documentation URI.
     */
    function updateDocumentationURI(
        address zone,
        string calldata documentationURI
    ) external override {
        // Ensure the caller is the owner of the signed zone.
        _assertCallerIsZoneOwner(zone);

        // Retrieve storage region where the singers for the signedZone are
        // stored.
        SignedZoneProperties storage signedZoneProperties = _signedZones[zone];

        // Update the documentationURI on the signed zone.
        signedZoneProperties.documentationURI = documentationURI;
    }

    /**
     * @notice Add or remove a signer from the supplied zone.
     *         Only the owner or an active signer of the supplied zone can call
     *         this function.
     *
     * @param zone     The signed zone to update the signer permissions for.
     * @param signer   The signer to update the permissions for.
     * @param active   Whether the signer should be active or not.
     */
    function updateSigner(
        address zone,
        address signer,
        bool active
    ) external override {
        // Ensure the caller is the owner of the signed zone.
        _assertCallerIsZoneOwner(zone);

        // Retrieve storage region where the singers for the signedZone are
        // stored.
        SignedZoneProperties storage signedZoneProperties = _signedZones[zone];

        // Validate signer permissions.
        _assertSignerPermissions(signedZoneProperties, signer, active);

        // Update the signer on the signed zone.
        SignedZoneInterface(zone).updateSigner(signer, active);

        // Update the signer information.
        signedZoneProperties.signers[signer].active = active;
        signedZoneProperties.signers[signer].previouslyActive = true;
        // Add the signer to the list of signers if they are active.
        if (active) {
            signedZoneProperties.activeSignerList.push(signer);
        } else {
            // Remove the signer from the list of signers.
            for (
                uint256 i = 0;
                i < signedZoneProperties.activeSignerList.length;

            ) {
                if (signedZoneProperties.activeSignerList[i] == signer) {
                    signedZoneProperties.activeSignerList[
                            i
                        ] = signedZoneProperties.activeSignerList[
                        signedZoneProperties.activeSignerList.length - 1
                    ];
                    signedZoneProperties.activeSignerList.pop();
                    break;
                }

                unchecked {
                    ++i;
                }
            }
        }

        // Emit an event signifying that the signer was updated.
        emit SignerUpdated(zone, signer, active);
    }

    /**
     * @notice Retrieve the current owner of a deployed zone.
     *
     * @param zone The zone for which to retrieve the associated owner.
     *
     * @return owner The owner of the supplied zone.
     */
    function ownerOf(address zone)
        external
        view
        override
        returns (address owner)
    {
        // Ensure that the zone in question exists.
        _assertZoneExists(zone);

        // Retrieve the current owner of the zone in question.
        owner = _signedZones[zone].owner;
    }

    /**
     * @notice Retrieve the potential owner, if any, for a given zone. The
     *         current owner may set a new potential owner via
     *         `transferOwnership` and that owner may then accept ownership of
     *         the zone in question via `acceptOwnership`.
     *
     * @param zone The zone for which to retrieve the potential owner.
     *
     * @return potentialOwner The potential owner, if any, for the zone.
     */
    function getPotentialOwner(address zone)
        external
        view
        override
        returns (address potentialOwner)
    {
        // Ensure that the zone in question exists.
        _assertZoneExists(zone);

        // Retrieve the current potential owner of the zone in question.
        potentialOwner = _signedZones[zone].potentialOwner;
    }

    /**
     * @notice Returns the active signers for the zone. Note that the array of
     *         active signers could grow to a size that this function could not
     *         return, the array of active signers is expected to be small,
     *         and is managed by the controller.
     *
     * @param zone The zone to return the active signers for.
     *
     * @return signers The active signers.
     */
    function getActiveSigners(address zone)
        external
        view
        override
        returns (address[] memory signers)
    {
        // Ensure that the zone in question exists.
        _assertZoneExists(zone);

        // Retrieve storage region where the singers for the signedZone are
        // stored.
        SignedZoneProperties storage signedZoneProperties = _signedZones[zone];

        // Return the active signers for the zone.
        signers = signedZoneProperties.activeSignerList;
    }

    /**
     * @notice Returns if the given address is an active signer for the zone.
     *
     * @param zone   The zone to return the active signers for.
     * @param signer The address to check if it is an active signer.
     *
     * @return The address is an active signer, false otherwise.
     */
    function isActiveSigner(address zone, address signer)
        external
        view
        override
        returns (bool)
    {
        // Ensure that the zone in question exists.
        _assertZoneExists(zone);

        // Retrieve storage region where the singers for the signedZone are
        // stored.
        SignedZoneProperties storage signedZoneProperties = _signedZones[zone];

        // Return whether the signer is an active signer for the zone.
        return signedZoneProperties.signers[signer].active;
    }

    /**
     * @notice Derive the zone address associated with a salt.
     *
     * @param salt  The salt to be used to derive the zone address.
     *
     * @return derivedAddress The derived address of the signed zone.
     */
    function getZone(string memory zoneName, bytes32 salt)
        external
        view
        override
        returns (address derivedAddress)
    {
        // Get the zone creation code hash.
        bytes32 _SIGNED_ZONE_CREATION_CODE_HASH = keccak256(
            abi.encodePacked(
                type(SignedZone).creationCode,
                abi.encode(zoneName)
            )
        );
        // Derive the SignedZone address from deployer, salt and creation code
        // hash.
        derivedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            _SIGNED_ZONE_CREATION_CODE_HASH
                        )
                    )
                )
            )
        );
    }

    /**
     * @notice External call to return the signing information, substandards,
     *         and documentation about the zone.
     *
     * @return domainSeparator  The domain separator used for signing.
     * @return zoneName         The name of the zone.
     * @return apiEndpoint      The API endpoint for the zone.
     * @return substandards     The substandards supported by the zone.
     * @return documentationURI The documentation URI for the zone.
     */
    function getAdditionalZoneInformation(address zone)
        external
        view
        override
        returns (
            bytes32 domainSeparator,
            string memory zoneName,
            string memory apiEndpoint,
            uint256[] memory substandards,
            string memory documentationURI
        )
    {
        // Ensure the zone exists.
        _assertZoneExists(zone);

        // Return the zone's additional information.
        return _additionalZoneInformation(zone);
    }

    /**
     * @notice Internal call to return the signing information, substandards,
     *         and documentation about the zone.
     *
     * @return domainSeparator  The domain separator used for signing.
     * @return zoneName         The name of the zone.
     * @return apiEndpoint      The API endpoint for the zone.
     * @return substandards     The substandards supported by the zone.
     * @return documentationURI The documentation URI for the zone.
     */
    function _additionalZoneInformation(address zone)
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
        // Get the zone properties.
        SignedZoneProperties storage signedZoneProperties = _signedZones[zone];

        // Return the SIP-7 information.
        domainSeparator = _domainSeparator(zone);
        zoneName = signedZoneProperties.zoneName;
        apiEndpoint = signedZoneProperties.apiEndpoint;
        substandards = signedZoneProperties.substandards;
        documentationURI = signedZoneProperties.documentationURI;
    }

    /**
     * @dev Internal view function to get the EIP-712 domain separator. If the
     *      chainId matches the chainId set on deployment, the cached domain
     *      separator will be returned; otherwise, it will be derived from
     *      scratch.
     *
     * @return The domain separator.
     */
    function _domainSeparator(address zone) internal view returns (bytes32) {
        // prettier-ignore
        return _deriveDomainSeparator(zone);
    }

    /**
     * @dev Internal view function to derive the EIP-712 domain separator.
     *
     * @return domainSeparator The derived domain separator.
     */
    function _deriveDomainSeparator(address zone)
        internal
        view
        returns (bytes32 domainSeparator)
    {
        bytes32 typehash = _EIP_712_DOMAIN_TYPEHASH;
        // Get the name hash from the zone properties.
        SignedZoneProperties storage signedZoneProperties = _signedZones[zone];
        bytes32 nameHash = keccak256(bytes(signedZoneProperties.zoneName));
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

            // Place the address of the signed zone contract in the next memory location.
            mstore(FourWords, zone)

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
     * @dev Private view function to revert if the caller is not the owner of a
     *      given zone.
     *
     * @param zone The zone for which to assert ownership.
     */
    function _assertCallerIsZoneOwner(address zone) private view {
        // Ensure that the zone in question exists.
        _assertZoneExists(zone);

        // If the caller does not match the current owner of the zone...
        if (msg.sender != _signedZones[zone].owner) {
            // Revert, indicating that the caller is not the owner.
            revert CallerIsNotOwner(zone);
        }
    }

    /**
     * @dev Private view function to revert if a given zone does not exist.
     *
     * @param zone The zone for which to assert existence.
     */
    function _assertZoneExists(address zone) private view {
        // Attempt to retrieve a the owner for the zone in question.
        if (_signedZones[zone].owner == address(0)) {
            // Revert if no ownerwas located.
            revert NoZone();
        }
    }

    /**
     * @dev Private view function to revert if a signer being added to a zone
     *      is the null address or the signer already exists, or the signer was
     *      previously authorized.  If the signer is being removed, the
     *      function will revert if the signer is not active.
     *
     * @param signedZoneProperties The signed zone properties for the zone.
     * @param signer               The signer to add or remove.
     * @param active               Whether the signer is being added or
     *                             removed.
     */
    function _assertSignerPermissions(
        SignedZoneProperties storage signedZoneProperties,
        address signer,
        bool active
    ) private view {
        // Do not allow the null address to be added as a signer.
        if (signer == address(0)) {
            revert SignerCannotBeNullAddress();
        }

        // If the signer is being added...
        if (active) {
            // Revert if the signer is already added.
            if (signedZoneProperties.signers[signer].active) {
                revert SignerAlreadyAdded(signer);
            }

            // Revert if the signer was previously authorized.
            if (signedZoneProperties.signers[signer].previouslyActive) {
                revert SignerCannotBeReauthorized(signer);
            }
        } else {
            // Revert if the signer is not active.
            if (!signedZoneProperties.signers[signer].active) {
                revert SignerNotPresent(signer);
            }
        }
    }
}
