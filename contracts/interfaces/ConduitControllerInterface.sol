// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ConduitControllerInterface {
    error MissingCommitment(address committer, bytes32 conduitKey);

    error InvalidCommitmentTime(address committer, bytes32 conduitKey);

    error NoConduit();

    error InvalidConfigurationParameter();

    error ConduitAlreadyExists(address conduit);

    error CallerIsNotOwner(address conduit);

    error NewPotentialOwnerIsZeroAddress(address conduit);

    event NewConduit(address conduit, bytes32 conduitKey, address initialOwner);

    event OwnershipTransferred(
        address indexed conduit,
        address indexed previousOwner,
        address indexed newOwner
    );

    error CallerIsNotNewPotentialOwner(address conduit);

    function registerKey(bytes32 commitment) external;

    function createConduit(
        bytes32 conduitKey,
        bytes32 commitmentSalt,
        address initialOwner
    ) external returns (address conduit);

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

    function deriveCommitment(
        bytes32 conduitKey,
        bytes32 commitmentSalt,
        address initialOwner
    ) external view returns (bytes32 commitment);

    function getCommitment(address committer, bytes32 commitment)
        external
        view
        returns (
            bool committed,
            bool valid,
            uint256 validAt,
            uint256 validUntil
        );

    function getCommitmentParameters()
        external
        view
        returns (uint256 delayPeriod, uint256 validityWindow);

    function getConduitCodeHashes()
        external
        view
        returns (bytes32 creationCodeHash, bytes32 runtimeCodeHash);
}
