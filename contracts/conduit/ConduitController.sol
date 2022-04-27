// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { Conduit } from "./Conduit.sol";

// prettier-ignore
import {
	ConduitControllerInterface
} from "../interfaces/ConduitControllerInterface.sol";

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

contract ConduitController is ConduitControllerInterface {
    mapping(address => bytes32) internal _conduitKeys;

    mapping(address => address) internal _conduitOwners;

    mapping(address => address) internal _conduitPotentialOwners;

    bytes32 internal immutable _CONDUIT_CREATION_CODE_HASH;
    bytes32 internal immutable _CONDUIT_RUNTIME_CODE_HASH;

    constructor() {
        _CONDUIT_CREATION_CODE_HASH = keccak256(type(Conduit).creationCode);

        Conduit zeroConduit = new Conduit{ salt: bytes32(0) }();

        _CONDUIT_RUNTIME_CODE_HASH = address(zeroConduit).codehash;
    }

    function createConduit(bytes32 conduitKey, address initialOwner)
        external
        override
        returns (address conduit)
    {
        if (address(uint160(uint256(conduitKey))) != msg.sender) {
            revert InvalidCreator();
        }

        conduit = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            conduitKey,
                            _CONDUIT_CREATION_CODE_HASH
                        )
                    )
                )
            )
        );

        if (conduit.codehash == _CONDUIT_RUNTIME_CODE_HASH) {
            revert ConduitAlreadyExists(conduit);
        }

        new Conduit{ salt: conduitKey }();

        _conduitOwners[conduit] = initialOwner;
        _conduitKeys[conduit] = conduitKey;

        emit NewConduit(conduit, conduitKey);
        emit OwnershipTransferred(conduit, address(0), initialOwner);
    }

    function updateChannel(
        address conduit,
        address channel,
        bool isOpen
    ) external override {
        address conduitOwner = _conduitOwners[conduit];

        if (msg.sender != conduitOwner) {
            revert CallerIsNotOwner(conduit);
        }

        ConduitInterface(conduit).updateChannel(channel, isOpen);
    }

    function transferOwnership(address conduit, address newPotentialOwner)
        external
        override
    {
        if (newPotentialOwner == address(0)) {
            revert NewPotentialOwnerIsZeroAddress(conduit);
        }

        address conduitOwner = _conduitOwners[conduit];

        if (msg.sender != conduitOwner) {
            revert CallerIsNotOwner(conduit);
        }

        emit PotentialOwnerUpdated(
            conduit,
            _conduitPotentialOwners[conduit],
            newPotentialOwner
        );

        _conduitPotentialOwners[conduit] = newPotentialOwner;
    }

    function cancelOwnershipTransfer(address conduit) external override {
        address conduitOwner = _conduitOwners[conduit];

        if (msg.sender != conduitOwner) {
            revert CallerIsNotOwner(conduit);
        }

        emit PotentialOwnerUpdated(
            conduit,
            _conduitPotentialOwners[conduit],
            address(0)
        );

        delete _conduitPotentialOwners[conduit];
    }

    function acceptOwnership(address conduit) external override {
        if (msg.sender != _conduitPotentialOwners[conduit]) {
            revert CallerIsNotNewPotentialOwner(conduit);
        }

        emit PotentialOwnerUpdated(
            conduit,
            _conduitPotentialOwners[conduit],
            address(0)
        );

        delete _conduitPotentialOwners[conduit];

        emit OwnershipTransferred(conduit, _conduitOwners[conduit], msg.sender);

        _conduitOwners[conduit] = msg.sender;
    }

    function ownerOf(address conduit)
        external
        view
        override
        returns (address owner)
    {
        if (_conduitKeys[conduit] == bytes32(0)) {
            revert NoConduit();
        }

        owner = _conduitOwners[conduit];
    }

    function getKey(address conduit)
        external
        view
        override
        returns (bytes32 conduitKey)
    {
        conduitKey = _conduitKeys[conduit];

        if (conduitKey == bytes32(0)) {
            revert NoConduit();
        }
    }

    function getConduit(bytes32 conduitKey)
        external
        view
        override
        returns (address conduit, bool exists)
    {
        conduit = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            conduitKey,
                            _CONDUIT_CREATION_CODE_HASH
                        )
                    )
                )
            )
        );

        exists = (conduit.codehash == _CONDUIT_RUNTIME_CODE_HASH);
    }

    function getPotentialOwner(address conduit)
        external
        view
        override
        returns (address potentialOwner)
    {
        bytes32 conduitKey = _conduitKeys[conduit];

        if (conduitKey == bytes32(0)) {
            revert NoConduit();
        }

        potentialOwner = _conduitPotentialOwners[conduit];
    }

    function getConduitCodeHashes()
        external
        view
        override
        returns (bytes32 creationCodeHash, bytes32 runtimeCodeHash)
    {
        creationCodeHash = _CONDUIT_CREATION_CODE_HASH;
        runtimeCodeHash = _CONDUIT_RUNTIME_CODE_HASH;
    }
}
