// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @notice SignedZoneEventsAndErrors contains errors and events
 *         related to zone interaction.
 */
interface SignedZoneEventsAndErrors {
    /**
     * @dev Emit an event when a new signer is added.
     */
    event SignerAdded(address signer);

    /**
     * @dev Emit an event when a signer is removed.
     */
    event SignerRemoved(address signer);

    /**
     * @dev Revert with an error if msg.sender is not the owner
     *      or an active signer.
     */
    error OnlyOwnerOrActiveSigner();

    /**
     * @dev Revert with an error if trying to add a signer that is
     *      already active.
     */
    error SignerAlreadyAdded(address signer);

    /**
     * @dev Revert with an error if trying to remove a signer that is
     *      not present.
     */
    error SignerNotPresent(address signer);

    /**
     * @dev Revert with an error if a new signer is the zero address.
     */
    error SignerCannotBeZeroAddress();

    /**
     * @dev Revert with an error if a removed signer is trying to be
     *      reauthorized.
     */
    error SignerCannotBeReauthorized(address signer);

    /**
     * @dev Revert with an error when an order is signed with a signer
     *      that is not active.
     */
    error SignerNotActive(address signer, bytes32 orderHash);

    /**
     * @dev Revert with an error when the signature has expired.
     */
    error SignatureExpired(uint256 expiration, bytes32 orderHash);

    /**
     * @dev Revert with an error if supplied order extraData is an invalid
     *      length.
     */
    error InvalidExtraDataLength(bytes32 orderHash);

    /**
     * @dev Revert with an error if the supplied order extraData does not
     *      support the zone's SIP6 version.
     */
    error InvalidSIP6Version(bytes32 orderHash);

    /**
     * @dev Revert with an error if the supplied order extraData does not
     *      support the zone's substandard requirements.
     */
    error InvalidSubstandardSupport(
        string reason,
        uint256 substandardVersion,
        bytes32 orderHash
    );

    /**
     * @dev Revert with an error if the supplied order extraData does not
     *      support the zone's substandard version.
     */
    error InvalidSubstandardVersion(bytes32 orderHash);

    /**
     * @dev Revert with an error if the fulfiller does not match.
     */
    error InvalidFulfiller(
        address expectedFulfiller,
        address actualFulfiller,
        bytes32 orderHash
    );

    /**
     * @dev Revert with an error if the received item does not match.
     */
    error InvalidReceivedItem(
        uint256 expectedReceivedIdentifier,
        uint256 actualReceievedIdentifier,
        bytes32 orderHash
    );

    /**
     * @dev Revert with an error if the zone parameter encoding is invalid.
     */
    error InvalidZoneParameterEncoding();
}
