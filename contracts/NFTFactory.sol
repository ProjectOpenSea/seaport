// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title NFTFactory
 * @dev A gas-optimized NFT factory with Web3 security features
 */
contract NFTFactory is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;

    // Gas optimization: Packed structs
    struct NFTCollection {
        address creator;        // 20 bytes
        uint32 maxSupply;      // 4 bytes
        uint32 minted;         // 4 bytes
        uint96 mintPrice;      // 12 bytes
        bool isActive;         // 1 byte
        string baseURI;        // dynamic
    }

    // State variables
    mapping(bytes32 => NFTCollection) public collections;
    mapping(address => bytes32[]) public creatorCollections;
    mapping(bytes32 => mapping(address => uint32)) public mintedPerUser;
    
    // Constants for gas optimization
    uint256 private constant MAX_SUPPLY = 10000;
    uint256 private constant MAX_MINT_PRICE = 10 ether;
    
    // Events with indexed parameters
    event CollectionCreated(
        bytes32 indexed collectionId,
        address indexed creator,
        uint32 maxSupply,
        uint96 mintPrice
    );
    event NFTMinted(
        bytes32 indexed collectionId,
        address indexed to,
        uint32 tokenId
    );

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Create a new NFT collection with gas optimization
     */
    function createCollection(
        string calldata name,
        string calldata symbol,
        uint32 maxSupply,
        uint96 mintPrice,
        string calldata baseURI
    ) external nonReentrant returns (bytes32) {
        require(maxSupply <= MAX_SUPPLY, "Max supply too high");
        require(mintPrice <= MAX_MINT_PRICE, "Mint price too high");
        require(bytes(baseURI).length > 0, "Invalid baseURI");

        // Gas optimization: Use keccak256 of packed data
        bytes32 collectionId = keccak256(
            abi.encodePacked(
                name,
                symbol,
                maxSupply,
                mintPrice,
                baseURI,
                block.timestamp,
                msg.sender
            )
        );

        // Gas optimization: Use struct packing
        collections[collectionId] = NFTCollection({
            creator: msg.sender,
            maxSupply: maxSupply,
            minted: 0,
            mintPrice: mintPrice,
            isActive: true,
            baseURI: baseURI
        });

        creatorCollections[msg.sender].push(collectionId);

        emit CollectionCreated(collectionId, msg.sender, maxSupply, mintPrice);
        return collectionId;
    }

    /**
     * @dev Mint an NFT with gas optimization
     */
    function mintNFT(
        bytes32 collectionId,
        address to
    ) external payable nonReentrant {
        NFTCollection storage collection = collections[collectionId];
        require(collection.isActive, "Collection not active");
        require(collection.minted < collection.maxSupply, "Max supply reached");
        require(msg.value >= collection.mintPrice, "Insufficient payment");
        require(mintedPerUser[collectionId][to] < 10, "Max mints per user reached");

        // Gas optimization: Use uint32 for token IDs
        uint32 tokenId = uint32(collection.minted);
        collection.minted++;
        mintedPerUser[collectionId][to]++;

        // Deploy NFT contract if not exists
        address nftContract = _deployNFTContract(
            collectionId,
            collection.baseURI
        );

        // Mint NFT
        IERC721(nftContract).safeMint(to, tokenId);

        emit NFTMinted(collectionId, to, tokenId);
    }

    /**
     * @dev Deploy NFT contract with gas optimization
     */
    function _deployNFTContract(
        bytes32 collectionId,
        string memory baseURI
    ) internal returns (address) {
        // Gas optimization: Use CREATE2 for deterministic addresses
        bytes memory bytecode = type(NFTContract).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(collectionId));
        
        address nftContract;
        assembly {
            nftContract := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(nftContract != address(0), "Deployment failed");
        
        return nftContract;
    }

    /**
     * @dev Update collection status
     */
    function updateCollectionStatus(
        bytes32 collectionId,
        bool isActive
    ) external {
        NFTCollection storage collection = collections[collectionId];
        require(msg.sender == collection.creator, "Not creator");
        collection.isActive = isActive;
    }

    /**
     * @dev Withdraw funds with gas optimization
     */
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}

/**
 * @title NFTContract
 * @dev Gas-optimized NFT contract
 */
contract NFTContract is ERC721URIStorage, ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string private _baseTokenURI;
    address public immutable factory;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
        factory = msg.sender;
    }

    function safeMint(address to, uint256 tokenId) external {
        require(msg.sender == factory, "Only factory can mint");
        _safeMint(to, tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // Gas optimization: Override required functions
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
} 