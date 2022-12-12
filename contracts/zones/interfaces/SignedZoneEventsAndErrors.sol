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
     * @dev Revert with an error when an order is signed with a signer
     *      that is not approved.
     */
    error SignerNotApproved(address signer, bytes32 orderHash);

    /**
     * @dev Revert with an error when the signature has expired.
     */
    error SignatureExpired(uint256 expiration, bytes32 orderHash);

    /**
     * @dev Revert with an error if the fulfiller does not match.
     */
    error InvalidFulfiller(
        address expectedFulfiller,
        address actualFulfiller,
        bytes32 orderHash
    );

    /**
     * @dev Revert with an error if a new signer is the zero addres.
     */
    error SignerCannotBeZeroAddress();
}
