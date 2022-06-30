// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// prettier-ignore
import {
	ConduitControllerInterface
} from "../interfaces/ConduitControllerInterface.sol";

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

import { ConduitController } from "../conduit/ConduitController.sol";

import { ConduitMock } from "../test/ConduitMock.sol";

contract ConduitControllerMock is ConduitController {
    // Set conduit creation code and runtime code hashes as immutable arguments.
    bytes32 internal immutable _MOCK_CONDUIT_CREATION_CODE_HASH;
    bytes32 internal immutable _MOCK_CONDUIT_RUNTIME_CODE_HASH;

    constructor() {
        // Derive the conduit creation code hash and set it as an immutable.
        _MOCK_CONDUIT_CREATION_CODE_HASH = keccak256(
            type(ConduitMock).creationCode
        );

        // Deploy a conduit with the zero hash as the salt.
        ConduitMock zeroConduit = new ConduitMock{ salt: bytes32(0) }();

        // Retrieve the conduit runtime code hash and set it as an immutable.
        _MOCK_CONDUIT_RUNTIME_CODE_HASH = address(zeroConduit).codehash;
    }

    function createMockConduit(bytes32 conduitKey, address initialOwner)
        external
        returns (address conduit)
    {
        // Ensure that an initial owner has been supplied.
        if (initialOwner == address(0)) {
            revert InvalidInitialOwner();
        }

        // If the first 20 bytes of the conduit key do not match the caller...
        if (address(uint160(bytes20(conduitKey))) != msg.sender) {
            // Revert with an error indicating that the creator is invalid.
            revert InvalidCreator();
        }

        // Derive address from deployer, conduit key and creation code hash.
        conduit = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            conduitKey,
                            _MOCK_CONDUIT_CREATION_CODE_HASH
                        )
                    )
                )
            )
        );

        // If derived conduit exists, as evidenced by comparing runtime code...
        if (conduit.codehash == _MOCK_CONDUIT_RUNTIME_CODE_HASH) {
            // Revert with an error indicating that the conduit already exists.
            revert ConduitAlreadyExists(conduit);
        }

        // Deploy the conduit via CREATE2 using the conduit key as the salt.
        new ConduitMock{ salt: conduitKey }();

        // Initialize storage variable referencing conduit properties.
        ConduitProperties storage conduitProperties = _conduits[conduit];

        // Set the supplied initial owner as the owner of the conduit.
        conduitProperties.owner = initialOwner;

        // Set conduit key used to deploy the conduit to enable reverse lookup.
        conduitProperties.key = conduitKey;

        // Emit an event indicating that the conduit has been deployed.
        emit NewConduit(conduit, conduitKey);

        // Emit an event indicating that conduit ownership has been assigned.
        emit OwnershipTransferred(conduit, address(0), initialOwner);
    }
}
