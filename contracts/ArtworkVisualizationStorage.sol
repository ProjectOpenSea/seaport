// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ArtworkVisualizationStorage is Ownable, ReentrancyGuard {
    struct OnChainVisualizationData {
        uint256 timestamp;
        uint256 qualityScore;
        uint256 originalityScore;
        MarketMetrics marketMetrics;
        VerificationStatus verificationStatus;
        bytes32 offChainDataHash;
    }

    struct MarketMetrics {
        uint256 currentPrice;
        uint256 tradingVolume;
        uint256 holderCount;
    }

    struct VerificationStatus {
        bool isVerified;
        uint256 verificationTimestamp;
    }

    // Mapping from artwork ID to visualization data
    mapping(bytes32 => OnChainVisualizationData) public artworkVisualizations;
    
    // Mapping from artwork ID to update history
    mapping(bytes32 => OnChainVisualizationData[]) public visualizationHistory;
    
    // Mapping from artwork ID to curator approvals
    mapping(bytes32 => mapping(address => bool)) public curatorApprovals;
    
    // Events
    event VisualizationDataUpdated(
        bytes32 indexed artworkId,
        uint256 timestamp,
        bytes32 offChainDataHash
    );
    
    event CuratorApprovalAdded(
        bytes32 indexed artworkId,
        address indexed curator
    );
    
    event CuratorApprovalRemoved(
        bytes32 indexed artworkId,
        address indexed curator
    );

    // Modifiers
    modifier onlyCurator() {
        require(isCurator(msg.sender), "Not a curator");
        _;
    }

    // State variables
    mapping(address => bool) public curators;
    uint256 public requiredCuratorApprovals;
    uint256 public updateCooldown;

    constructor(uint256 _requiredCuratorApprovals, uint256 _updateCooldown) {
        requiredCuratorApprovals = _requiredCuratorApprovals;
        updateCooldown = _updateCooldown;
    }

    /**
     * Update visualization data for an artwork
     */
    function updateVisualizationData(
        bytes32 artworkId,
        uint256 qualityScore,
        uint256 originalityScore,
        MarketMetrics calldata marketMetrics,
        bytes32 offChainDataHash
    ) external nonReentrant {
        require(
            block.timestamp >= artworkVisualizations[artworkId].timestamp + updateCooldown,
            "Update too soon"
        );
        require(
            curatorApprovals[artworkId][msg.sender],
            "Not approved by curator"
        );

        OnChainVisualizationData memory newData = OnChainVisualizationData({
            timestamp: block.timestamp,
            qualityScore: qualityScore,
            originalityScore: originalityScore,
            marketMetrics: marketMetrics,
            verificationStatus: VerificationStatus({
                isVerified: true,
                verificationTimestamp: block.timestamp
            }),
            offChainDataHash: offChainDataHash
        });

        // Store in history
        visualizationHistory[artworkId].push(newData);
        
        // Update current data
        artworkVisualizations[artworkId] = newData;

        emit VisualizationDataUpdated(
            artworkId,
            block.timestamp,
            offChainDataHash
        );
    }

    /**
     * Add curator approval for an artwork
     */
    function addCuratorApproval(bytes32 artworkId) external onlyCurator {
        require(!curatorApprovals[artworkId][msg.sender], "Already approved");
        
        curatorApprovals[artworkId][msg.sender] = true;
        
        emit CuratorApprovalAdded(artworkId, msg.sender);
    }

    /**
     * Remove curator approval for an artwork
     */
    function removeCuratorApproval(bytes32 artworkId) external onlyCurator {
        require(curatorApprovals[artworkId][msg.sender], "Not approved");
        
        curatorApprovals[artworkId][msg.sender] = false;
        
        emit CuratorApprovalRemoved(artworkId, msg.sender);
    }

    /**
     * Get visualization data for an artwork
     */
    function getVisualizationData(bytes32 artworkId)
        external
        view
        returns (OnChainVisualizationData memory)
    {
        return artworkVisualizations[artworkId];
    }

    /**
     * Get visualization history for an artwork
     */
    function getVisualizationHistory(bytes32 artworkId)
        external
        view
        returns (OnChainVisualizationData[] memory)
    {
        return visualizationHistory[artworkId];
    }

    /**
     * Check if an address is a curator
     */
    function isCurator(address account) public view returns (bool) {
        return curators[account];
    }

    /**
     * Add a curator
     */
    function addCurator(address curator) external onlyOwner {
        require(!curators[curator], "Already a curator");
        curators[curator] = true;
    }

    /**
     * Remove a curator
     */
    function removeCurator(address curator) external onlyOwner {
        require(curators[curator], "Not a curator");
        curators[curator] = false;
    }

    /**
     * Update required curator approvals
     */
    function updateRequiredCuratorApprovals(uint256 _requiredCuratorApprovals)
        external
        onlyOwner
    {
        requiredCuratorApprovals = _requiredCuratorApprovals;
    }

    /**
     * Update cooldown period
     */
    function updateCooldownPeriod(uint256 _updateCooldown) external onlyOwner {
        updateCooldown = _updateCooldown;
    }
} 