// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

/**
 * This deployer is designed to be owned by a gnosis safe, DAO, or trusted
 * party. It can deploy new PausableZone contracts, which can be used as a zone.
 */

import { PausableZone } from "./PausableZone.sol";

// prettier-ignore
import {
    PausableZoneEventsAndErrors
} from "./interfaces/PausableZoneEventsAndErrors.sol";

// prettier-ignore
import {
    Order,
    Fulfillment,
    OrderComponents,
    AdvancedOrder,
    CriteriaResolver,
    Execution
} from "../lib/ConsiderationStructs.sol";

import { SeaportInterface } from "../interfaces/SeaportInterface.sol";

contract PausableZoneController is PausableZoneEventsAndErrors {
    // Owns this deployer and can activate the kill switch for the PausableZone.
    address public deployerOwner;

    // Address of the new potential owner of the zone.
    address private _potentialOwner;

    // Address with the ability to pause the zone.
    address public pauserAddress;

    bytes32 public immutable zoneCreationCode;

    /**
     * @dev Throws if called by any account other than the owner or pauser.
     */
    modifier isPauser() {
        if (msg.sender != pauserAddress && msg.sender != deployerOwner) {
            revert InvalidPauser();
        }
        _;
    }

    constructor(address _deployerOwner) {
        deployerOwner = _deployerOwner;

        zoneCreationCode = keccak256(type(PausableZone).creationCode);
    }

    // Deploy a PausableZone.
    function createZone(bytes32 salt)
        external
        returns (address derivedAddress)
    {
        require(
            msg.sender == deployerOwner,
            "Only owner can create new Zones from here."
        );

        // This expression demonstrates address computation but is not required.
        derivedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            zoneCreationCode
                        )
                    )
                )
            )
        );

        // Revert if a zone is currently deployed to the derived address.
        if (derivedAddress.code.length != 0) {
            revert ZoneAlreadyExists(derivedAddress);
        }

        // Deploy the zone using the supplied salt.
        new PausableZone{ salt: salt }();

        // Emit an event signifying that the zone was created.
        emit ZoneCreated(derivedAddress, salt);
    }

    // Pause Seaport by self destructing GlobalPausable.
    function pause(address zone) external isPauser returns (bool success) {
        PausableZone(zone).pause();

        success = true;
    }

    /**
     * @notice Uses a zone to cancel Seaport orders.
     */
    function cancelOrderZone(
        address globalPausableAddress,
        SeaportInterface seaportAddress,
        OrderComponents[] calldata orders
    ) external {
        require(
            msg.sender == deployerOwner,
            "Only the owner can cancel orders with the zone."
        );

        PausableZone gp = PausableZone(globalPausableAddress);
        gp.cancelOrders(seaportAddress, orders);
    }

    function executeMatchOrdersZone(
        address globalPausableAddress,
        SeaportInterface seaportAddress,
        Order[] calldata orders,
        Fulfillment[] calldata fulfillments
    ) external payable returns (Execution[] memory executions) {
        require(
            msg.sender == deployerOwner,
            "Only the owner can execute orders with the zone."
        );

        PausableZone gp = PausableZone(globalPausableAddress);
        executions = gp.executeMatchOrders{ value: msg.value }(
            seaportAddress,
            orders,
            fulfillments
        );
    }

    function executeMatchAdvancedOrdersZone(
        address globalPausableAddress,
        SeaportInterface seaportAddress,
        AdvancedOrder[] calldata orders,
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments
    ) external payable returns (Execution[] memory executions) {
        require(
            msg.sender == deployerOwner,
            "Only the owner can execute advanced orders with the zone."
        );

        PausableZone gp = PausableZone(globalPausableAddress);
        executions = gp.executeMatchAdvancedOrders{ value: msg.value }(
            seaportAddress,
            orders,
            criteriaResolvers,
            fulfillments
        );
    }

    /**
     * @notice Initiate Zone ownership transfer by assigning a new potential
     *         owner this contract. Once set, the new potential owner
     *         may call `acceptOwnership` to claim ownership.
     *         Only the owner in question may call this function.
     *
     * @param newPotentialOwner The address for which to initiate ownership
     *                          transfer to.
     */
    function transferOwnership(address newPotentialOwner) external {
        require(
            msg.sender == deployerOwner,
            "Only Owner can transfer Ownership."
        );

        // Ensure the new potential owner is not an invalid address.
        require(
            newPotentialOwner != address(0),
            "New Owner can not be 0 address."
        );

        // Emit an event indicating that the potential owner has been updated.
        emit PotentialOwnerUpdated(newPotentialOwner);

        _potentialOwner = newPotentialOwner;
    }

    /**
     * @notice Clear the currently set potential owner, if any.
     *         Only the owner of this contract may call this function.
     */
    function cancelOwnershipTransfer() external {
        // Ensure the caller is the current owner.
        require(msg.sender == deployerOwner, "Only Owner can cancel.");

        // Emit an event indicating that the potential owner has been cleared.
        emit PotentialOwnerUpdated(address(0));

        // Clear the current new potential owner.
        delete _potentialOwner;
    }

    /**
     * @notice Accept ownership of this contract. Only accounts that the
     *         current owner has set as the new potential owner may call this
     *         function.
     */
    function acceptOwnership() external {
        require(
            msg.sender == _potentialOwner,
            "Only Potential Owner can claim."
        );

        // Emit an event indicating that the potential owner has been cleared.
        emit PotentialOwnerUpdated(address(0));

        // Clear the current new potential owner
        delete _potentialOwner;

        // Emit an event indicating ownership has been transferred.
        emit OwnershipTransferred(deployerOwner, msg.sender);

        // Set the caller as the owner of this contract.
        deployerOwner = msg.sender;
    }

    /**
     * @notice Assigns the given address with the ability to pause the zone.
     *
     * @param pauserToAssign Address to assign role.
     */
    function assignPauser(address pauserToAssign) external {
        require(msg.sender == deployerOwner, "Can only be set by the deployer");
        require(
            pauserToAssign != address(0),
            "Pauser can not be set to the null address"
        );
        pauserAddress = pauserToAssign;

        // Emit an event.
        emit PauserUpdated(pauserAddress);
    }

    /**
     * @notice Assigns the given address with the ability to operate the
     *         give zone.
     *
     * @param globalPausableAddress Zone Address to assign operator role.
     * @param operatorToAssign      Address to assign role.
     */
    function assignOperatorOfZone(
        address globalPausableAddress,
        address operatorToAssign
    ) external {
        require(msg.sender == deployerOwner, "Can only be set by the deployer");
        PausableZone gp = PausableZone(globalPausableAddress);
        gp.assignOperator(operatorToAssign);
    }
}
