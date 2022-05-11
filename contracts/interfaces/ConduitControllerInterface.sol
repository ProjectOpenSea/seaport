// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

interface ConduitControllerInterface {
    struct ConduitProperties {
        bytes32 key;
        address owner;
        address potentialOwner;
        address[] channels;
        mapping(address => uint256) channelIndexesPlusOne;
    }

    event NewConduit(address conduit, bytes32 conduitKey);

    event OwnershipTransferred(
        address indexed conduit,
        address indexed previousOwner,
        address indexed newOwner
    );

    event PotentialOwnerUpdated(
        address indexed conduit,
        address indexed previousOwner,
        address indexed newOwner
    );

    error InvalidCreator();

    error NoConduit();

    error ConduitAlreadyExists(address conduit);

    error CallerIsNotOwner(address conduit);

    error NewPotentialOwnerIsZeroAddress(address conduit);

    error CallerIsNotNewPotentialOwner(address conduit);

    error ChannelOutOfRange(address conduit);

    function createConduit(bytes32 conduitKey, address initialOwner)
        external
        returns (address conduit);

    function updateChannel(
        address conduit,
        address channel,
        bool isOpen
    ) external;

    function transferOwnership(address conduit, address newPotentialOwner)
        external;

    function cancelOwnershipTransfer(address conduit) external;

    function acceptOwnership(address conduit) external;

    function ownerOf(address conduit) external view returns (address owner);

    function getKey(address conduit) external view returns (bytes32 conduitKey);

    function getConduit(bytes32 conduitKey)
        external
        view
        returns (address conduit, bool exists);

    function getPotentialOwner(address conduit)
        external
        view
        returns (address potentialOwner);

    function getChannelStatus(address conduit, address channel)
        external
        view
        returns (bool isOpen);

    function getTotalChannels(address conduit)
        external
        view
        returns (uint256 totalChannels);

    function getChannel(address conduit, uint256 channelIndex)
        external
        view
        returns (address channel);

    function getChannels(address conduit)
        external
        view
        returns (address[] memory channels);

    function getConduitCodeHashes()
        external
        view
        returns (bytes32 creationCodeHash, bytes32 runtimeCodeHash);
}
