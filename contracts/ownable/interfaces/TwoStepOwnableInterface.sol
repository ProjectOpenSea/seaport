// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title   TwoStepOwnableInterface
 * @author  OpenSea Protocol
 * @notice  TwoStepOwnableInterface contains all external function interfaces,
 *          events and errors for the TwoStepOwnable contract.
 */
interface TwoStepOwnableInterface {
    /**
     * @dev Emit an event whenever the contract owner registers a new potential
     *      owner.
     *
     * @param newPotentialOwner The new potential owner of the contract.
     */
    event PotentialOwnerUpdated(address newPotentialOwner);

    /**
     * @dev Emit an event whenever contract ownership is transferred.
     *
     * @param previousOwner The previous owner of the contract.
     * @param newOwner      The new owner of the contract.
     */
    event OwnershipTransferred(address previousOwner, address newOwner);

    /**
     * @dev Revert with an error when attempting to call a function that
     *      requires ownership with a caller that is not the owner.
     */
    error CallerIsNotOwner();

    /**
     * @dev Revert with an error when attempting to register an initial owner
     *      and supplying the null address.
     */
    error InitialOwnerIsNullAddress();

    /**
     * @dev Revert with an error when attempting to register a new potential
     *      owner and supplying the null address.
     */
    error NewPotentialOwnerIsNullAddress();

    /**
     * @dev Revert with an error when attempting to set a new potential owner
     *      that is already set.
     */
    error NewPotentialOwnerAlreadySet(address newPotentialOwner);

    /**
     * @dev Revert with an error when attempting to claim ownership of the
     *      contract with a caller that is not the current potential owner.
     */
    error CallerIsNotNewPotentialOwner();

    /**
     * @dev Revert with an error when attempting to cancel ownership transfer
     *      when no new potential owner is currently set.
     */
    error NoPotentialOwnerCurrentlySet();

    /**
     * @notice Initiate ownership transfer by assigning a new potential owner
     *         to this contract. Once set, the new potential owner may call
     *         `acceptOwnership` to claim ownership. Only the owner may call
     *         this function.
     *
     * @param newPotentialOwner The address for which to initiate ownership
     *                          transfer to.
     */
    function transferOwnership(address newPotentialOwner) external;

    /**
     * @notice Clear the currently set potential owner, if any. Only the owner
     *         of this contract may call this function.
     */
    function cancelOwnershipTransfer() external;

    /**
     * @notice Accept ownership of this contract. Only the account that the
     *         current owner has set as the new potential owner may call this
     *         function.
     */
    function acceptOwnership() external;

    /**
     * @notice An external view function that returns the potential owner.
     *
     * @return The address of the potential owner.
     */
    function potentialOwner() external view returns (address);

    /**
     * @notice An external view function that returns the owner.
     *
     * @return The address of the owner.
     */
    function owner() external view returns (address);
}
