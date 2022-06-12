// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

/**
 * This deployer is designed to be owned by a gnosis safe, DAO, or trusted party.
 * It can deploy new GlobalPausable contracts, which can be used as a zone.
 *
 */

import { GlobalPausable } from "./GlobalPausable.sol";

// prettier-ignore
import {
    GlobalPausableEventsAndErrors
} from "./interfaces/GlobalPausableEventsAndErrors.sol";

import { Order, Fulfillment, OrderComponents, AdvancedOrder, CriteriaResolver, Execution } from "../lib/ConsiderationStructs.sol";

contract DeployerGlobalPausable is GlobalPausableEventsAndErrors {
    //owns this deployer and can activate the kill switch for the GlobalPausable
    address public deployerOwner;

    // Address of the new potential owner of the zone.
    address private _potentialOwner;

    // Address with the ability to pause the zone.
    address public pauserAddress;

    /**
     * @dev Throws if called by any account other than the owner or pauser.
     */
    modifier isPauser() {
        if (msg.sender != pauserAddress && msg.sender != deployerOwner) {
            revert InvalidPauser();
        }
        _;
    }

    constructor(address _deployerOwner, bytes32 _salt) {
        deployerOwner = _deployerOwner;
    }

    //Deploy a GlobalPausable at. Should be an efficient address
    function createZone(bytes32 salt)
        external
        returns (address derivedAddress)
    {
        require(
            msg.sender == deployerOwner,
            "Only owner can create new Zones from here."
        );

        // This complicated expression just tells you how the address
        // can be pre-computed. It is just there for illustration.
        // You actually only need ``new D{salt: salt}(arg)``.
        derivedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    type(GlobalPausable).creationCode,
                                    abi.encode(address(this)) //GlobalPausable takes an address as a constructor param.
                                )
                            )
                        )
                    )
                )
            )
        );

        GlobalPausable zone = new GlobalPausable{ salt: salt }(address(this));
        require(address(zone) == derivedAddress, "Unexpected Derived address");
        emit ZoneCreated(derivedAddress);
    }

    //pause Seaport by self destructing GlobalPausable
    function killSwitch(address _zone) external isPauser returns (bool) {
        GlobalPausable zone = GlobalPausable(_zone);
        zone.kill();
    }

    /**
     * @notice Uses a zone to cancel a restricted Seaport offer
     */
    function cancelOrderZone(
        address _globalPausableAddress,
        address _seaportAddress,
        OrderComponents[] calldata orders
    ) external {
        require(
            msg.sender == deployerOwner,
            "Only the owner can cancel orders with the zone."
        );

        GlobalPausable gp = GlobalPausable(_globalPausableAddress);
        gp.cancelOrder(_seaportAddress, orders);
    }

    function executeRestrictedMatchOrderZone(
        address _globalPausableAddress,
        address _seaportAddress,
        Order[] calldata orders,
        Fulfillment[] calldata fulfillments
    ) external payable returns (Execution[] memory executions) {
        require(
            msg.sender == deployerOwner,
            "Only the owner can execute orders with the zone. "
        );

        GlobalPausable gp = GlobalPausable(_globalPausableAddress);
        executions = gp.executeRestrictedOffer{ value: msg.value }(
            _seaportAddress,
            orders,
            fulfillments
        );
    }

    function executeRestrictedMatchAdvancedOrderZone(
        address _globalPausableAddress,
        address _seaportAddress,
        AdvancedOrder[] calldata orders,
        CriteriaResolver[] calldata criteriaResolvers,
        Fulfillment[] calldata fulfillments
    ) external payable returns (Execution[] memory executions) {
        require(
            msg.sender == deployerOwner,
            "Only the owner can execute advanced orders with the zone."
        );

        GlobalPausable gp = GlobalPausable(_globalPausableAddress);
        executions = gp.executeRestrictedAdvancedOffer{ value: msg.value }(
            _seaportAddress,
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
     * @param newPotentialOwner The address for which to initiate ownership transfer to.
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
    function assignPauser(address pauserToAssign) public {
        require(msg.sender == deployerOwner, "Can only be set by the deployer");
        require(
            pauserToAssign != address(0),
            "Pauser can not be set to the null address"
        );
        pauserAddress = pauserToAssign;

        // Emit the event
        emit PauserUpdated(pauserAddress);
    }
}
