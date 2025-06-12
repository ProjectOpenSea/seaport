// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title SecureMultiSig
 * @dev A secure multi-signature contract with Web3-specific security features
 */
contract SecureMultiSig is ReentrancyGuard, Pausable {
    using Counters for Counters.Counter;

    // Constants for gas optimization
    uint256 private constant MAX_UINT256 = type(uint256).max;
    uint256 private constant MAX_SIGNATURES = 10;
    
    // Value thresholds in wei
    uint256 public constant STANDARD_THRESHOLD = 10 ether;
    uint256 public constant LARGE_THRESHOLD = 50 ether;
    uint256 public constant EXTREME_THRESHOLD = 100 ether;

    // Required signatures for each threshold
    uint256 public constant STANDARD_SIGNATURES = 2;
    uint256 public constant LARGE_SIGNATURES = 3;
    uint256 public constant EXTREME_SIGNATURES = 4;

    // Transaction struct with gas optimization
    struct Transaction {
        address to;              // 20 bytes
        uint96 value;           // 12 bytes
        uint32 requiredSignatures; // 4 bytes
        uint32 signatureCount;    // 4 bytes
        uint32 createdAt;        // 4 bytes
        uint32 executedAt;       // 4 bytes
        bool executed;           // 1 byte
        bytes data;              // dynamic
    }

    // Signer struct for gas optimization
    struct Signer {
        uint96 weight;           // 12 bytes
        uint32 lastActive;       // 4 bytes
        bool isActive;           // 1 byte
    }

    // State variables
    mapping(bytes32 => Transaction) public transactions;
    mapping(bytes32 => mapping(address => bool)) public hasSigned;
    mapping(address => Signer) public signers;
    mapping(address => uint256) public nonces;
    mapping(bytes32 => bool) public executedHashes;
    
    // Events with indexed parameters for efficient filtering
    event TransactionCreated(
        bytes32 indexed transactionId,
        address indexed creator,
        address indexed to,
        uint96 value
    );
    event TransactionSigned(
        bytes32 indexed transactionId,
        address indexed signer,
        uint256 weight
    );
    event TransactionExecuted(
        bytes32 indexed transactionId,
        address indexed executor,
        uint96 value
    );
    event SignerWeightUpdated(
        address indexed signer,
        uint96 oldWeight,
        uint96 newWeight
    );

    // Modifiers
    modifier onlySigner() {
        require(signers[msg.sender].isActive, "Not an active signer");
        _;
    }

    modifier validThreshold(uint256 value) {
        require(value <= EXTREME_THRESHOLD, "Value exceeds maximum threshold");
        _;
    }

    modifier validSignatures(uint256 count) {
        require(count <= MAX_SIGNATURES, "Too many required signatures");
        _;
    }

    constructor() {
        // Initialize with deployer as first signer
        signers[msg.sender] = Signer({
            weight: uint96(1),
            lastActive: uint32(block.timestamp),
            isActive: true
        });
    }

    /**
     * @dev Create a new transaction with optimized gas usage
     */
    function createTransaction(
        address to,
        uint96 value,
        bytes calldata data
    ) 
        external 
        onlySigner 
        nonReentrant 
        whenNotPaused 
        validThreshold(value)
        returns (bytes32) 
    {
        require(to != address(0), "Invalid recipient");
        require(value > 0, "Value must be > 0");

        // Gas optimization: Use uint96 for value
        uint32 requiredSignatures;
        if (value <= STANDARD_THRESHOLD) {
            requiredSignatures = uint32(STANDARD_SIGNATURES);
        } else if (value <= LARGE_THRESHOLD) {
            requiredSignatures = uint32(LARGE_SIGNATURES);
        } else {
            requiredSignatures = uint32(EXTREME_SIGNATURES);
        }

        // Gas optimization: Use keccak256 of packed data
        bytes32 transactionId = keccak256(
            abi.encodePacked(
                to,
                value,
                data,
                block.timestamp,
                nonces[msg.sender]++
            )
        );

        // Gas optimization: Use struct packing
        transactions[transactionId] = Transaction({
            to: to,
            value: value,
            data: data,
            requiredSignatures: requiredSignatures,
            signatureCount: 0,
            createdAt: uint32(block.timestamp),
            executedAt: 0,
            executed: false
        });

        emit TransactionCreated(transactionId, msg.sender, to, value);
        return transactionId;
    }

    /**
     * @dev Sign a transaction with weight-based validation
     */
    function signTransaction(
        bytes32 transactionId,
        bytes calldata signature
    ) 
        external 
        onlySigner 
        nonReentrant 
        whenNotPaused 
    {
        Transaction storage transaction = transactions[transactionId];
        require(transaction.to != address(0), "Transaction does not exist");
        require(!transaction.executed, "Already executed");
        require(!hasSigned[transactionId][msg.sender], "Already signed");

        // Verify signature
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                transactionId,
                transaction.to,
                transaction.value,
                transaction.data
            )
        );
        require(
            _verifySignature(messageHash, signature),
            "Invalid signature"
        );

        // Update signer's last active timestamp
        signers[msg.sender].lastActive = uint32(block.timestamp);
        
        hasSigned[transactionId][msg.sender] = true;
        transaction.signatureCount++;

        emit TransactionSigned(
            transactionId,
            msg.sender,
            signers[msg.sender].weight
        );
    }

    /**
     * @dev Execute a transaction with optimized gas usage
     */
    function executeTransaction(bytes32 transactionId)
        external
        onlySigner
        nonReentrant
        whenNotPaused
    {
        Transaction storage transaction = transactions[transactionId];
        require(transaction.to != address(0), "Transaction does not exist");
        require(!transaction.executed, "Already executed");
        require(
            transaction.signatureCount >= transaction.requiredSignatures,
            "Not enough signatures"
        );

        // Check for transaction replay
        bytes32 executionHash = keccak256(
            abi.encodePacked(
                transactionId,
                transaction.to,
                transaction.value,
                transaction.data
            )
        );
        require(!executedHashes[executionHash], "Transaction already executed");
        executedHashes[executionHash] = true;

        transaction.executed = true;
        transaction.executedAt = uint32(block.timestamp);

        // Execute transaction with gas optimization
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transaction failed");

        emit TransactionExecuted(
            transactionId,
            msg.sender,
            transaction.value
        );
    }

    /**
     * @dev Update signer weight with validation
     */
    function updateSignerWeight(
        address signer,
        uint96 newWeight
    ) 
        external 
        onlySigner 
        nonReentrant 
        whenNotPaused 
    {
        require(signer != address(0), "Invalid signer");
        require(newWeight > 0, "Weight must be > 0");
        
        Signer storage signerData = signers[signer];
        uint96 oldWeight = signerData.weight;
        
        signerData.weight = newWeight;
        signerData.lastActive = uint32(block.timestamp);
        signerData.isActive = true;

        emit SignerWeightUpdated(signer, oldWeight, newWeight);
    }

    /**
     * @dev Verify signature using EIP-712
     */
    function _verifySignature(
        bytes32 messageHash,
        bytes calldata signature
    ) internal view returns (bool) {
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
        address recoveredSigner = ecrecover(ethSignedMessageHash, v, r, s);
        
        return recoveredSigner == msg.sender;
    }

    /**
     * @dev Split signature into r, s, v components
     */
    function _splitSignature(bytes calldata signature)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(signature.length == 65, "Invalid signature length");

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
    }

    /**
     * @dev Emergency pause
     */
    function pause() external onlySigner {
        _pause();
    }

    /**
     * @dev Emergency unpause
     */
    function unpause() external onlySigner {
        _unpause();
    }

    // Allow contract to receive ETH
    receive() external payable {}
} 