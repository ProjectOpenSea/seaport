// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ArtAuthenticity.sol";

/**
 * @title AISimilarityDetection
 * @dev Handles AI-based similarity detection for artworks
 */
contract AISimilarityDetection is Ownable, ReentrancyGuard {
    // Structs
    struct SimilarityCheck {
        string contentHash;
        string[] featureVector;    // AI-extracted features
        uint256 timestamp;
        address submitter;
        bool isProcessed;
        uint256 similarityScore;   // 0-100, where 100 is identical
        string[] similarArtworks;  // Hashes of similar artworks
    }

    struct AIConfig {
        uint256 minSimilarityThreshold;  // Minimum similarity to flag (0-100)
        uint256 maxFeatureVectorSize;    // Maximum size of feature vector
        bool isEnabled;
        address[] authorizedAIProviders;
    }

    // State variables
    mapping(string => SimilarityCheck) public similarityChecks;
    mapping(address => bool) public authorizedAIProviders;
    mapping(string => string[]) public artworkFeatureVectors;
    AIConfig public aiConfig;
    ArtAuthenticity public artAuthenticity;

    // Events
    event SimilarityCheckRequested(
        string indexed contentHash,
        address indexed submitter,
        uint256 timestamp
    );
    event SimilarityCheckProcessed(
        string indexed contentHash,
        uint256 similarityScore,
        string[] similarArtworks
    );
    event AIProviderAuthorized(address indexed provider);
    event AIProviderRemoved(address indexed provider);
    event AIConfigUpdated(
        uint256 minSimilarityThreshold,
        uint256 maxFeatureVectorSize,
        bool isEnabled
    );

    // Modifiers
    modifier onlyAuthorizedAIProvider() {
        require(authorizedAIProviders[msg.sender], "Not authorized AI provider");
        _;
    }

    modifier onlyWhenEnabled() {
        require(aiConfig.isEnabled, "AI detection is disabled");
        _;
    }

    constructor(
        address _artAuthenticity,
        uint256 _minSimilarityThreshold,
        uint256 _maxFeatureVectorSize
    ) {
        artAuthenticity = ArtAuthenticity(_artAuthenticity);
        aiConfig = AIConfig({
            minSimilarityThreshold: _minSimilarityThreshold,
            maxFeatureVectorSize: _maxFeatureVectorSize,
            isEnabled: true,
            authorizedAIProviders: new address[](0)
        });
    }

    /**
     * @dev Request similarity check for an artwork
     */
    function requestSimilarityCheck(
        string memory contentHash,
        string[] memory featureVector
    ) external nonReentrant onlyWhenEnabled {
        require(featureVector.length <= aiConfig.maxFeatureVectorSize, "Feature vector too large");
        require(!similarityChecks[contentHash].isProcessed, "Check already processed");

        similarityChecks[contentHash] = SimilarityCheck({
            contentHash: contentHash,
            featureVector: featureVector,
            timestamp: block.timestamp,
            submitter: msg.sender,
            isProcessed: false,
            similarityScore: 0,
            similarArtworks: new string[](0)
        });

        emit SimilarityCheckRequested(contentHash, msg.sender, block.timestamp);
    }

    /**
     * @dev Process similarity check results
     */
    function processSimilarityCheck(
        string memory contentHash,
        uint256 similarityScore,
        string[] memory similarArtworks
    ) external onlyAuthorizedAIProvider nonReentrant {
        require(similarityChecks[contentHash].timestamp > 0, "Check not found");
        require(!similarityChecks[contentHash].isProcessed, "Already processed");
        require(similarityScore <= 100, "Invalid similarity score");

        SimilarityCheck storage check = similarityChecks[contentHash];
        check.isProcessed = true;
        check.similarityScore = similarityScore;
        check.similarArtworks = similarArtworks;

        // If similarity is above threshold, flag for review
        if (similarityScore >= aiConfig.minSimilarityThreshold) {
            // Store feature vector for future comparisons
            artworkFeatureVectors[contentHash] = check.featureVector;
        }

        emit SimilarityCheckProcessed(contentHash, similarityScore, similarArtworks);
    }

    /**
     * @dev Get similarity check results
     */
    function getSimilarityCheck(
        string memory contentHash
    ) external view returns (
        bool isProcessed,
        uint256 similarityScore,
        string[] memory similarArtworks,
        uint256 timestamp
    ) {
        SimilarityCheck storage check = similarityChecks[contentHash];
        return (
            check.isProcessed,
            check.similarityScore,
            check.similarArtworks,
            check.timestamp
        );
    }

    /**
     * @dev Add authorized AI provider
     */
    function addAIProvider(address provider) external onlyOwner {
        require(!authorizedAIProviders[provider], "Provider already authorized");
        authorizedAIProviders[provider] = true;
        aiConfig.authorizedAIProviders.push(provider);
        emit AIProviderAuthorized(provider);
    }

    /**
     * @dev Remove authorized AI provider
     */
    function removeAIProvider(address provider) external onlyOwner {
        require(authorizedAIProviders[provider], "Provider not authorized");
        authorizedAIProviders[provider] = false;
        
        // Remove from array
        for (uint256 i = 0; i < aiConfig.authorizedAIProviders.length; i++) {
            if (aiConfig.authorizedAIProviders[i] == provider) {
                aiConfig.authorizedAIProviders[i] = aiConfig.authorizedAIProviders[aiConfig.authorizedAIProviders.length - 1];
                aiConfig.authorizedAIProviders.pop();
                break;
            }
        }
        
        emit AIProviderRemoved(provider);
    }

    /**
     * @dev Update AI configuration
     */
    function updateAIConfig(
        uint256 _minSimilarityThreshold,
        uint256 _maxFeatureVectorSize,
        bool _isEnabled
    ) external onlyOwner {
        require(_minSimilarityThreshold <= 100, "Invalid threshold");
        require(_maxFeatureVectorSize > 0, "Invalid vector size");

        aiConfig.minSimilarityThreshold = _minSimilarityThreshold;
        aiConfig.maxFeatureVectorSize = _maxFeatureVectorSize;
        aiConfig.isEnabled = _isEnabled;

        emit AIConfigUpdated(_minSimilarityThreshold, _maxFeatureVectorSize, _isEnabled);
    }

    /**
     * @dev Check if artwork is similar to any existing artworks
     */
    function isSimilarToExisting(
        string memory contentHash
    ) external view returns (bool) {
        SimilarityCheck storage check = similarityChecks[contentHash];
        return check.isProcessed && check.similarityScore >= aiConfig.minSimilarityThreshold;
    }

    /**
     * @dev Get feature vector for an artwork
     */
    function getFeatureVector(
        string memory contentHash
    ) external view returns (string[] memory) {
        return artworkFeatureVectors[contentHash];
    }
} 