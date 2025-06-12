// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SecureMarketplace
 * @dev A gas-optimized NFT marketplace with Web3 security features
 */
contract SecureMarketplace is ReentrancyGuard, Pausable {
    // Gas optimization: Packed structs
    struct Listing {
        address seller;         // 20 bytes
        address nftContract;    // 20 bytes
        uint96 price;          // 12 bytes
        uint32 tokenId;        // 4 bytes
        uint32 createdAt;      // 4 bytes
        bool isActive;         // 1 byte
    }

    struct Offer {
        address buyer;         // 20 bytes
        uint96 amount;         // 12 bytes
        uint32 expiresAt;      // 4 bytes
        bool isActive;         // 1 byte
    }

    // State variables
    mapping(bytes32 => Listing) public listings;
    mapping(bytes32 => mapping(address => Offer)) public offers;
    mapping(address => uint256) public nonces;
    mapping(bytes32 => bool) public executedOrders;
    mapping(address => bool) public ipEnforcers;
    mapping(bytes32 => bool) public burnedTokens;
    
    // Constants for gas optimization
    uint256 private constant MAX_PRICE = 1000 ether;
    uint256 private constant OFFER_DURATION = 7 days;
    
    // Events with indexed parameters
    event ListingCreated(
        bytes32 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint32 tokenId,
        uint96 price
    );
    event ListingCancelled(
        bytes32 indexed listingId,
        address indexed seller
    );
    event OfferCreated(
        bytes32 indexed listingId,
        address indexed buyer,
        uint96 amount
    );
    event OfferCancelled(
        bytes32 indexed listingId,
        address indexed buyer
    );
    event NFTBought(
        bytes32 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint96 price
    );
    event IPViolationReported(
        bytes32 indexed listingId,
        address indexed reporter,
        string reason
    );
    event TokenBurned(
        address indexed nftContract,
        uint32 indexed tokenId,
        address indexed enforcer,
        string reason
    );
    event SimilarityCheckRequested(bytes32 indexed contentHash, address indexed creator);
    event SimilarityCheckCompleted(bytes32 indexed contentHash, bool isOriginal);

    // AI Similarity Detection integration
    AISimilarityDetection public aiSimilarity;
    
    // Mapping to track artworks pending similarity check
    mapping(bytes32 => bool) public pendingSimilarityChecks;
    
    // Modifiers
    modifier onlyIPEnforcer() {
        require(ipEnforcers[msg.sender], "Not authorized IP enforcer");
        _;
    }
    modifier onlyAfterSimilarityCheck(bytes32 contentHash) {
        require(!pendingSimilarityChecks[contentHash], "Similarity check pending");
        _;
    }

    /**
     * @dev Create a new listing with gas optimization
     */
    function createListing(
        address nftContract,
        uint32 tokenId,
        uint96 price,
        bytes32 contentHash
    ) external nonReentrant whenNotPaused onlyAfterSimilarityCheck(contentHash) returns (bytes32) {
        require(price <= MAX_PRICE, "Price too high");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
        require(IERC721(nftContract).getApproved(tokenId) == address(this), "Not approved");

        // Gas optimization: Use keccak256 of packed data
        bytes32 listingId = keccak256(
            abi.encodePacked(
                nftContract,
                tokenId,
                price,
                block.timestamp,
                nonces[msg.sender]++
            )
        );

        // Gas optimization: Use struct packing
        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            price: price,
            tokenId: tokenId,
            createdAt: uint32(block.timestamp),
            isActive: true
        });

        emit ListingCreated(listingId, msg.sender, nftContract, tokenId, price);
        return listingId;
    }

    /**
     * @dev Create an offer with gas optimization
     */
    function createOffer(
        bytes32 listingId,
        uint96 amount
    ) external payable nonReentrant whenNotPaused {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "Listing not active");
        require(msg.value >= amount, "Insufficient payment");
        require(msg.sender != listing.seller, "Cannot offer on own listing");

        // Gas optimization: Use struct packing
        offers[listingId][msg.sender] = Offer({
            buyer: msg.sender,
            amount: amount,
            expiresAt: uint32(block.timestamp + OFFER_DURATION),
            isActive: true
        });

        emit OfferCreated(listingId, msg.sender, amount);
    }

    /**
     * @dev Buy NFT with gas optimization
     */
    function buyNFT(
        bytes32 listingId
    ) external payable nonReentrant whenNotPaused {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "Listing not active");
        require(msg.value >= listing.price, "Insufficient payment");

        // Check for transaction replay
        bytes32 orderHash = keccak256(
            abi.encodePacked(
                listingId,
                listing.nftContract,
                listing.tokenId,
                listing.price
            )
        );
        require(!executedOrders[orderHash], "Order already executed");
        executedOrders[orderHash] = true;

        // Transfer NFT
        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        // Transfer payment
        (bool success, ) = listing.seller.call{value: listing.price}("");
        require(success, "Payment failed");

        // Refund excess payment
        if (msg.value > listing.price) {
            (success, ) = msg.sender.call{value: msg.value - listing.price}("");
            require(success, "Refund failed");
        }

        listing.isActive = false;
        emit NFTBought(listingId, msg.sender, listing.seller, listing.price);
    }

    /**
     * @dev Accept offer with gas optimization
     */
    function acceptOffer(
        bytes32 listingId,
        address buyer
    ) external nonReentrant whenNotPaused {
        Listing storage listing = listings[listingId];
        Offer storage offer = offers[listingId][buyer];
        
        require(listing.isActive, "Listing not active");
        require(offer.isActive, "Offer not active");
        require(block.timestamp <= offer.expiresAt, "Offer expired");
        require(msg.sender == listing.seller, "Not seller");

        // Transfer NFT
        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            buyer,
            listing.tokenId
        );

        // Transfer payment
        (bool success, ) = listing.seller.call{value: offer.amount}("");
        require(success, "Payment failed");

        listing.isActive = false;
        offer.isActive = false;
        emit NFTBought(listingId, buyer, listing.seller, offer.amount);
    }

    /**
     * @dev Cancel listing with gas optimization
     */
    function cancelListing(bytes32 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(msg.sender == listing.seller, "Not seller");
        require(listing.isActive, "Listing not active");

        listing.isActive = false;
        emit ListingCancelled(listingId, msg.sender);
    }

    /**
     * @dev Cancel offer with gas optimization
     */
    function cancelOffer(bytes32 listingId) external nonReentrant {
        Offer storage offer = offers[listingId][msg.sender];
        require(offer.isActive, "Offer not active");

        offer.isActive = false;
        (bool success, ) = msg.sender.call{value: offer.amount}("");
        require(success, "Refund failed");

        emit OfferCancelled(listingId, msg.sender);
    }

    /**
     * @dev Emergency pause
     */
    function pause() external {
        _pause();
    }

    /**
     * @dev Emergency unpause
     */
    function unpause() external {
        _unpause();
    }

    /**
     * @dev Add or remove IP enforcers
     */
    function setIPEnforcer(address enforcer, bool status) external onlyOwner {
        ipEnforcers[enforcer] = status;
    }

    /**
     * @dev Report IP violation
     */
    function reportIPViolation(
        bytes32 listingId,
        string calldata reason
    ) external {
        require(listings[listingId].isActive, "Listing not active");
        emit IPViolationReported(listingId, msg.sender, reason);
    }

    /**
     * @dev Burn token due to IP violation
     */
    function burnTokenForIPViolation(
        address nftContract,
        uint32 tokenId,
        string calldata reason
    ) external onlyIPEnforcer nonReentrant {
        bytes32 burnId = keccak256(
            abi.encodePacked(nftContract, tokenId)
        );
        require(!burnedTokens[burnId], "Token already burned");
        
        // Transfer token to this contract first
        IERC721(nftContract).transferFrom(
            IERC721(nftContract).ownerOf(tokenId),
            address(this),
            tokenId
        );

        // Mark as burned
        burnedTokens[burnId] = true;

        // Cancel any active listings
        bytes32 listingId = keccak256(
            abi.encodePacked(
                nftContract,
                tokenId,
                block.timestamp
            )
        );
        if (listings[listingId].isActive) {
            listings[listingId].isActive = false;
        }

        emit TokenBurned(nftContract, tokenId, msg.sender, reason);
    }

    /**
     * @dev Check if token is burned
     */
    function isTokenBurned(
        address nftContract,
        uint32 tokenId
    ) external view returns (bool) {
        bytes32 burnId = keccak256(
            abi.encodePacked(nftContract, tokenId)
        );
        return burnedTokens[burnId];
    }

    // Allow contract to receive ETH
    receive() external payable {}

    /**
     * @dev Set AI Similarity Detection contract
     */
    function setAISimilarityContract(address _aiSimilarity) external onlyOwner {
        require(_aiSimilarity != address(0), "Invalid address");
        aiSimilarity = AISimilarityDetection(_aiSimilarity);
    }
    
    function requestSimilarityCheck(bytes32 contentHash) external {
        require(!pendingSimilarityChecks[contentHash], "Check already requested");
        pendingSimilarityChecks[contentHash] = true;
        emit SimilarityCheckRequested(contentHash, msg.sender);
    }
    
    function completeSimilarityCheck(bytes32 contentHash, bool isOriginal) external {
        require(msg.sender == address(aiSimilarity), "Only AI contract");
        require(pendingSimilarityChecks[contentHash], "No pending check");
        
        pendingSimilarityChecks[contentHash] = false;
        emit SimilarityCheckCompleted(contentHash, isOriginal);
        
        if (!isOriginal) {
            // Cancel any active listings for this content
            cancelActiveListings(contentHash);
        }
    }

    // Modify existing functions to include similarity check
    function updateListing(
        uint256 listingId,
        uint256 newPrice,
        bytes32 contentHash
    ) external nonReentrant whenNotPaused onlyAfterSimilarityCheck(contentHash) {
        // ... existing listing update code ...
    }
} 