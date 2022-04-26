// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { Conduit } from "./Conduit.sol";

// prettier-ignore
import {
	ConduitControllerInterface
} from "../interfaces/ConduitControllerInterface.sol";

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

contract ConduitController is ConduitControllerInterface {
    mapping(address => mapping(bytes32 => uint256)) internal _commitments;

    mapping(address => bytes32) internal _conduitKeys;

    mapping(address => address) internal _conduitOwners;

    mapping(address => address) internal _conduitPotentialOwners;

    uint256 internal immutable _DELAY_PERIOD;
    uint256 internal immutable _VALIDITY_WINDOW;
    bytes32 internal immutable _CONDUIT_CREATION_CODE_HASH;
    bytes32 internal immutable _CONDUIT_RUNTIME_CODE_HASH;

    constructor(uint256 delayPeriod, uint256 validityWindow) {
        if (delayPeriod == 0) {
            revert InvalidConfigurationParameter();
        }

        _DELAY_PERIOD = delayPeriod;

        if (validityWindow == 0) {
            revert InvalidConfigurationParameter();
        }

        _VALIDITY_WINDOW = validityWindow;

        _CONDUIT_CREATION_CODE_HASH = keccak256(type(Conduit).creationCode);

        Conduit zeroConduit = new Conduit{ salt: bytes32(0) }();

        _CONDUIT_RUNTIME_CODE_HASH = address(zeroConduit).codehash;
    }

    function registerKey(bytes32 commitment) external override {
        _commitments[msg.sender][commitment] = block.timestamp;
    }

    function createConduit(
        bytes32 conduitKey,
        bytes32 commitmentSalt,
        address initialOwner
    ) external override returns (address conduit) {
        bytes32 commitment = keccak256(
            abi.encodePacked(conduitKey, commitmentSalt, initialOwner)
        );
        uint256 committedAt = _commitments[msg.sender][commitment];

        if (committedAt == 0) {
            revert MissingCommitment(msg.sender, conduitKey);
        }

        uint256 validAt = committedAt + _DELAY_PERIOD;
        uint256 validUntil = validAt + _VALIDITY_WINDOW;
        if (block.timestamp < validAt || block.timestamp >= validUntil) {
            revert InvalidCommitmentTime(msg.sender, conduitKey);
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

        _conduitPotentialOwners[conduit] = newPotentialOwner;
    }

    function cancelOwnershipTransfer(address conduit) external override {
        address conduitOwner = _conduitOwners[conduit];

        if (msg.sender != conduitOwner) {
            revert CallerIsNotOwner(conduit);
        }

        delete _conduitPotentialOwners[conduit];
    }

    function acceptOwnership(address conduit) external override {
        if (msg.sender != _conduitPotentialOwners[conduit]) {
            revert CallerIsNotNewPotentialOwner(conduit);
        }

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

    function getCommitment(address committer, bytes32 commitment)
        external
        view
        override
        returns (
            bool committed,
            bool valid,
            uint256 validAt,
            uint256 validUntil
        )
    {
        uint256 committedAt = _commitments[committer][commitment];

        committed = (committedAt == 0);

        if (committed) {
            validAt = committedAt + _DELAY_PERIOD;
            validUntil = validAt + _VALIDITY_WINDOW;
            valid = block.timestamp >= validAt && block.timestamp < validUntil;
        } else {
            validAt = 0;
            validUntil = 0;
            valid = false;
        }
    }

    function getCommitmentParameters()
        external
        view
        override
        returns (uint256 delayPeriod, uint256 validityWindow)
    {
        delayPeriod = _DELAY_PERIOD;
        validityWindow = _VALIDITY_WINDOW;
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

    function deriveCommitment(
        bytes32 conduitKey,
        bytes32 commitmentSalt,
        address initialOwner
    ) external pure override returns (bytes32 commitment) {
        commitment = keccak256(
            abi.encodePacked(conduitKey, commitmentSalt, initialOwner)
        );
    }
}
