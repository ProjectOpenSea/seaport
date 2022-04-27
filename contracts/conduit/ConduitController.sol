// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { Conduit } from "./Conduit.sol";

// prettier-ignore
import {
	ConduitControllerInterface
} from "../interfaces/ConduitControllerInterface.sol";

import { ConduitInterface } from "../interfaces/ConduitInterface.sol";

contract ConduitController is ConduitControllerInterface {
    struct ConduitProperties {
        bytes32 key;
        address owner;
        address potentialOwner;
        address[] channels;
        mapping(address => uint256) channelIndexesPlusOne;
    }

    mapping(address => ConduitProperties) internal _conduits;

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

        _conduits[conduit].owner = initialOwner;
        _conduits[conduit].key = conduitKey;

        emit NewConduit(conduit, conduitKey);
        emit OwnershipTransferred(conduit, address(0), initialOwner);
    }

    function updateChannel(
        address conduit,
        address channel,
        bool isOpen
    ) external override {
        _assertCallerIsConduitOwner(conduit);

        ConduitInterface(conduit).updateChannel(channel, isOpen);

        ConduitProperties storage conduitProperties = _conduits[conduit];

        uint256 channelIndexPlusOne = (
            conduitProperties.channelIndexesPlusOne[channel]
        );

        bool channelCurrentlyOpen = channelIndexPlusOne != 0;

        if (isOpen && !channelCurrentlyOpen) {
            conduitProperties.channels.push(channel);
            conduitProperties.channelIndexesPlusOne[channel] = (
                conduitProperties.channels.length
            );
        } else if (!isOpen && channelCurrentlyOpen) {
            // Use "swap and pop" method
            uint256 removedChannelIndex = channelIndexPlusOne - 1;
            uint256 finalChannelIndex = conduitProperties.channels.length - 1;

            if (finalChannelIndex != removedChannelIndex) {
                address finalChannel = (
                    conduitProperties.channels[finalChannelIndex]
                );
                conduitProperties.channels[removedChannelIndex] = finalChannel;
                conduitProperties.channelIndexesPlusOne[finalChannel] = (
                    channelIndexPlusOne
                );
            }

            conduitProperties.channels.pop();
            delete conduitProperties.channelIndexesPlusOne[channel];
        }
    }

    function transferOwnership(address conduit, address newPotentialOwner)
        external
        override
    {
        _assertCallerIsConduitOwner(conduit);

        if (newPotentialOwner == address(0)) {
            revert NewPotentialOwnerIsZeroAddress(conduit);
        }

        emit PotentialOwnerUpdated(
            conduit,
            _conduits[conduit].potentialOwner,
            newPotentialOwner
        );

        _conduits[conduit].potentialOwner = newPotentialOwner;
    }

    function cancelOwnershipTransfer(address conduit) external override {
        _assertCallerIsConduitOwner(conduit);

        emit PotentialOwnerUpdated(
            conduit,
            _conduits[conduit].potentialOwner,
            address(0)
        );

        delete _conduits[conduit].potentialOwner;
    }

    function acceptOwnership(address conduit) external override {
        if (msg.sender != _conduits[conduit].potentialOwner) {
            revert CallerIsNotNewPotentialOwner(conduit);
        }

        emit PotentialOwnerUpdated(
            conduit,
            _conduits[conduit].potentialOwner,
            address(0)
        );

        delete _conduits[conduit].potentialOwner;

        emit OwnershipTransferred(
            conduit,
            _conduits[conduit].owner,
            msg.sender
        );

        _conduits[conduit].owner = msg.sender;
    }

    function ownerOf(address conduit)
        external
        view
        override
        returns (address owner)
    {
        _assertConduitExists(conduit);

        owner = _conduits[conduit].owner;
    }

    function getKey(address conduit)
        external
        view
        override
        returns (bytes32 conduitKey)
    {
        conduitKey = _conduits[conduit].key;

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
        _assertConduitExists(conduit);

        potentialOwner = _conduits[conduit].potentialOwner;
    }

    function getChannelStatus(address conduit, address channel)
        external
        view
        override
        returns (bool isOpen)
    {
        _assertConduitExists(conduit);

        isOpen = _conduits[conduit].channelIndexesPlusOne[channel] != 0;
    }

    function getTotalChannels(address conduit)
        external
        view
        override
        returns (uint256 totalChannels)
    {
        _assertConduitExists(conduit);

        totalChannels = _conduits[conduit].channels.length;
    }

    function getChannel(address conduit, uint256 channelIndex)
        external
        view
        override
        returns (address channel)
    {
        _assertConduitExists(conduit);

        if (_conduits[conduit].channels.length >= channelIndex) {
            revert ChannelOutOfRange(conduit);
        }

        channel = _conduits[conduit].channels[channelIndex];
    }

    function getChannels(address conduit)
        external
        view
        override
        returns (address[] memory channels)
    {
        _assertConduitExists(conduit);

        channels = _conduits[conduit].channels;
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

    function _assertCallerIsConduitOwner(address conduit) internal view {
        if (msg.sender != _conduits[conduit].owner) {
            revert CallerIsNotOwner(conduit);
        }
    }

    function _assertConduitExists(address conduit) internal view {
        if (_conduits[conduit].key == bytes32(0)) {
            revert NoConduit();
        }
    }
}
