// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title ArtAuthenticity
 * @dev Handles art authenticity verification and duplicate prevention
 */
contract ArtAuthenticity is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    // Structs
    struct Artwork {
        string contentHash;        // Hash of the artwork content
        string metadataHash;       // Hash of the artwork metadata
        address creator;           // Original creator
        uint256 creationTimestamp; // When the artwork was first registered
        bool isVerified;          // Whether the artwork has been verified
        string[] supportedChains;  // Chains where this artwork is registered
        mapping(string => bool) isRegisteredOnChain; // Track registration per chain
    }

    struct VerificationRequest {
        address submitter;
        string contentHash;
        string metadataHash;
        string chainId;
        uint256 timestamp;
        bool isProcessed;
        string reason;
    }

    // State variables
    mapping(string => Artwork) public artworks; // contentHash => Artwork
    mapping(address => string[]) public creatorArtworks; // creator => contentHashes
    mapping(string => bool) public supportedChains; // chainId => isSupported
    Counters.Counter private _verificationRequestIds;
    mapping(uint256 => VerificationRequest) public verificationRequests;
    
    // Curator roles
    mapping(address => bool) public curators;
    mapping(address => uint256) public curatorStakes;
    uint256 public minimumCuratorStake;
    
    // Events
    event ArtworkRegistered(
        string indexed contentHash,
        address indexed creator,
        string chainId,
        string metadataHash
    );
    event ArtworkVerified(
        string indexed contentHash,
        address indexed curator,
        string reason
    );
    event VerificationRequested(
        uint256 indexed requestId,
        string contentHash,
        address submitter,
        string chainId
    );
    event CuratorAdded(address indexed curator, uint256 stake);
    event CuratorRemoved(address indexed curator);
    event ChainSupported(string chainId, bool isSupported);

    // Modifiers
    modifier onlyCurator() {
        require(curators[msg.sender], "Not a curator");
        require(curatorStakes[msg.sender] >= minimumCuratorStake, "Insufficient stake");
        _;
    }

    modifier onlySupportedChain(string memory chainId) {
        require(supportedChains[chainId], "Chain not supported");
        _;
    }

    constructor(uint256 _minimumCuratorStake) {
        minimumCuratorStake = _minimumCuratorStake;
    }

    /**
     * @dev Register a new artwork
     */
    function registerArtwork(
        string memory contentHash,
        string memory metadataHash,
        string memory chainId
    ) external nonReentrant onlySupportedChain(chainId) {
        require(bytes(contentHash).length > 0, "Invalid content hash");
        require(bytes(metadataHash).length > 0, "Invalid metadata hash");
        require(!artworks[contentHash].isVerified, "Artwork already registered");

        Artwork storage artwork = artworks[contentHash];
        artwork.contentHash = contentHash;
        artwork.metadataHash = metadataHash;
        artwork.creator = msg.sender;
        artwork.creationTimestamp = block.timestamp;
        artwork.isVerified = false;
        artwork.supportedChains.push(chainId);
        artwork.isRegisteredOnChain[chainId] = true;

        creatorArtworks[msg.sender].push(contentHash);

        emit ArtworkRegistered(contentHash, msg.sender, chainId, metadataHash);
    }

    /**
     * @dev Request artwork verification
     */
    function requestVerification(
        string memory contentHash,
        string memory metadataHash,
        string memory chainId
    ) external payable nonReentrant onlySupportedChain(chainId) {
        require(msg.value >= minimumCuratorStake, "Insufficient stake");
        require(!artworks[contentHash].isVerified, "Artwork already verified");

        _verificationRequestIds.increment();
        uint256 requestId = _verificationRequestIds.current();

        verificationRequests[requestId] = VerificationRequest({
            submitter: msg.sender,
            contentHash: contentHash,
            metadataHash: metadataHash,
            chainId: chainId,
            timestamp: block.timestamp,
            isProcessed: false,
            reason: ""
        });

        emit VerificationRequested(requestId, contentHash, msg.sender, chainId);
    }

    /**
     * @dev Verify an artwork
     */
    function verifyArtwork(
        uint256 requestId,
        bool approved,
        string memory reason
    ) external onlyCurator {
        VerificationRequest storage request = verificationRequests[requestId];
        require(!request.isProcessed, "Request already processed");

        request.isProcessed = true;
        request.reason = reason;

        if (approved) {
            Artwork storage artwork = artworks[request.contentHash];
            artwork.isVerified = true;
            emit ArtworkVerified(request.contentHash, msg.sender, reason);
        }
    }

    /**
     * @dev Check if artwork is original
     */
    function isOriginal(
        string memory contentHash,
        string memory chainId
    ) external view returns (bool) {
        Artwork storage artwork = artworks[contentHash];
        return artwork.isVerified && artwork.isRegisteredOnChain[chainId];
    }

    /**
     * @dev Add a new curator
     */
    function addCurator(address curator, uint256 stake) external onlyOwner {
        require(stake >= minimumCuratorStake, "Insufficient stake");
        curators[curator] = true;
        curatorStakes[curator] = stake;
        emit CuratorAdded(curator, stake);
    }

    /**
     * @dev Remove a curator
     */
    function removeCurator(address curator) external onlyOwner {
        require(curators[curator], "Not a curator");
        curators[curator] = false;
        curatorStakes[curator] = 0;
        emit CuratorRemoved(curator);
    }

    /**
     * @dev Add or remove supported chain
     */
    function setChainSupport(string memory chainId, bool isSupported) external onlyOwner {
        supportedChains[chainId] = isSupported;
        emit ChainSupported(chainId, isSupported);
    }

    /**
     * @dev Get artwork details
     */
    function getArtworkDetails(
        string memory contentHash
    ) external view returns (
        string memory metadataHash,
        address creator,
        uint256 creationTimestamp,
        bool isVerified,
        string[] memory chains
    ) {
        Artwork storage artwork = artworks[contentHash];
        return (
            artwork.metadataHash,
            artwork.creator,
            artwork.creationTimestamp,
            artwork.isVerified,
            artwork.supportedChains
        );
    }

    /**
     * @dev Get creator's artworks
     */
    function getCreatorArtworks(
        address creator
    ) external view returns (string[] memory) {
        return creatorArtworks[creator];
    }

    // Function to receive ETH
    receive() external payable {}
} 