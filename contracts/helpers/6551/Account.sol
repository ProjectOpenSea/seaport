// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IERC6551Account.sol";
import "./lib/ERC6551AccountLib.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {
    EnumerableMap,
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {
    BaseAccount as BaseERC4337Account,
    IEntryPoint,
    UserOperation
} from "lib/account-abstraction/contracts/core/BaseAccount.sol";

import "./interfaces/IAccountGuardian.sol";

error NotAuthorized();
error InvalidInput();
error AccountLocked();
error ExceedsMaxLockTime();
error UntrustedImplementation();
error UseApprovalSpecificMethods();
error OwnershipCycle();

enum ApprovalType {
    ERC20_APPROVE,
    INCREASE_ALLOWANCE,
    ERC721_APPROVE,
    SET_APPROVAL_FOR_ALL
}

/**
 * @title A smart contract account owned by a single ERC721 token
 */
contract Account is
    IERC165,
    IERC1271,
    IERC6551Account,
    IERC721Receiver,
    IERC1155Receiver,
    UUPSUpgradeable,
    BaseERC4337Account
{
    using ECDSA for bytes32;
    using EnumerableMap for EnumerableMap.Bytes32ToBytes32Map;

    // bytes4(keccak256("approve(address,uint256)"))
    uint256 constant IERC20_721_APPROVE_SELECTOR =
        0x095ea7b300000000000000000000000000000000000000000000000000000000;
    // bytes4(keccak256("increaseAllowance(address,uint256)"))
    uint256 constant IERC20_NONSTANDARD_INCREASE_ALLOWANCE_SELECTOR =
        0x3950935100000000000000000000000000000000000000000000000000000000;
    // bytes4(keccak256("setApprovalForAll(address,bool)"))
    uint256 constant IERC721_1155_SET_APPROVAL_FOR_ALL_SELECTOR =
        0xa22cb46500000000000000000000000000000000000000000000000000000000;

    /// @dev ERC-4337 entry point address
    address public immutable _entryPoint;

    /// @dev AccountGuardian contract address
    address public immutable guardian;

    /// @dev timestamp at which this account will be unlocked
    uint256 public lockedUntil;

    /// @dev mapping from owner => selector => implementation
    mapping(address => mapping(bytes4 => address)) public overrides;

    /// @dev mapping from owner => caller => has permissions
    mapping(address => mapping(address => bool)) public permissions;

    /// @dev enumerable map from token address => operator (if erc20/erc1155) or tokenId (if erc721)
    EnumerableMap.Bytes32ToBytes32Map _approvals;

    // EnumerableSet.AddressSet _approvedErc20s;
    // EnumerableSet.AddressSet _approvedErc721s;
    // EnumerableSet.AddressSet _approvedForAll;
    // mapping(address => EnumerableMap.Bytes32ToBytes32Map) _approvalsForAll;
    // mapping(address => EnumerableMap.AddressToUintMap) _erc20ApprovalsMap;
    // mapping(address => EnumerableMap.UintToAddressMap) _erc721ApprovalsMap;

    event OverrideUpdated(
        address owner,
        bytes4 selector,
        address implementation
    );

    event PermissionUpdated(address owner, address caller, bool hasPermission);

    event LockUpdated(uint256 lockedUntil);

    /// @dev reverts if caller is not the owner of the account
    modifier onlyOwner() {
        if (msg.sender != owner()) revert NotAuthorized();
        _;
    }

    /// @dev reverts if caller is not authorized to execute on this account
    modifier onlyAuthorized() {
        if (!isAuthorized(msg.sender)) revert NotAuthorized();
        _;
    }

    /// @dev reverts if this account is currently locked
    modifier onlyUnlocked() {
        if (isLocked()) revert AccountLocked();
        _;
    }

    constructor(address _guardian, address entryPoint_) {
        if (_guardian == address(0) || entryPoint_ == address(0))
            revert InvalidInput();

        _entryPoint = entryPoint_;
        guardian = _guardian;
    }

    /// @dev allows eth transfers by default, but allows account owner to override
    receive() external payable {
        _handleOverride();
    }

    /// @dev allows account owner to add additional functions to the account via an override
    fallback() external payable {
        _handleOverride();
    }

    /// @dev executes a low-level call against an account if the caller is authorized to make calls
    ///      enumerable map of approvals will be updated in storage if call includes approval
    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable onlyAuthorized onlyUnlocked returns (bytes memory) {
        // Emit an event indicating a transaction has been executed.
        emit TransactionExecuted(to, value, data);

        // Increment the account nonce.
        _incrementNonce();

        // If the call is an approval, get the approved address and approved amount.
        if (_isApproval(data)) {
            ApprovalType memory approvalType = _getApprovalType(data);
            // TODO: get approvedAddress and approvedAmount
            if (approvalType == ApprovalType.ERC20_APPROVE) {
                address approvedAddress = address(bytes20(data[4:24]));
                uint256 approvedAmount = uint256(bytes32(data[24:56]));
            }

            // Update the enumerable map of approvals.
            _trackApprovals(approvalType, to, approvedAddress, approvedAmount);
        }

        return _call(to, value, data);
    }

    /// @dev sets the implementation address for a given function call
    function setOverrides(
        bytes4[] calldata selectors,
        address[] calldata implementations
    ) external onlyUnlocked {
        address _owner = owner();
        if (msg.sender != _owner) revert NotAuthorized();

        uint256 length = selectors.length;

        if (implementations.length != length) revert InvalidInput();

        for (uint256 i = 0; i < length; i++) {
            overrides[_owner][selectors[i]] = implementations[i];
            emit OverrideUpdated(_owner, selectors[i], implementations[i]);
        }

        _incrementNonce();
    }

    /// @dev grants a given caller execution permissions
    function setPermissions(
        address[] calldata callers,
        bool[] calldata _permissions
    ) external onlyUnlocked {
        address _owner = owner();
        if (msg.sender != _owner) revert NotAuthorized();

        uint256 length = callers.length;

        if (_permissions.length != length) revert InvalidInput();

        for (uint256 i = 0; i < length; i++) {
            permissions[_owner][callers[i]] = _permissions[i];
            emit PermissionUpdated(_owner, callers[i], _permissions[i]);
        }

        _incrementNonce();
    }

    /// @dev locks the account until a certain timestamp
    function lock(uint256 _lockedUntil) external onlyOwner onlyUnlocked {
        if (_lockedUntil > block.timestamp + 365 days)
            revert ExceedsMaxLockTime();

        lockedUntil = _lockedUntil;

        emit LockUpdated(_lockedUntil);

        _incrementNonce();
    }

    /// @dev returns the current lock status of the account as a boolean
    function isLocked() public view returns (bool) {
        return lockedUntil > block.timestamp;
    }

    /// @dev EIP-1271 signature validation. By default, only the owner of the account is permissioned to sign.
    /// This function can be overriden.
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) external view returns (bytes4 magicValue) {
        _handleOverrideStatic();

        bool isValid = SignatureChecker.isValidSignatureNow(
            owner(),
            hash,
            signature
        );

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }

    /// @dev Returns the EIP-155 chain ID, token contract address, and token ID for the token that
    /// owns this account.
    function token()
        external
        view
        returns (uint256 chainId, address tokenContract, uint256 tokenId)
    {
        return ERC6551AccountLib.token();
    }

    /// @dev Returns the current account nonce
    function nonce() public view override returns (uint256) {
        return IEntryPoint(_entryPoint).getNonce(address(this), 0);
    }

    /// @dev Increments the account nonce if the caller is not the ERC-4337 entry point
    function _incrementNonce() internal {
        if (msg.sender != _entryPoint)
            IEntryPoint(_entryPoint).incrementNonce(0);
    }

    /// @dev Return the ERC-4337 entry point address
    function entryPoint() public view override returns (IEntryPoint) {
        return IEntryPoint(_entryPoint);
    }

    /// @dev Returns the owner of the ERC-721 token which owns this account. By default, the owner
    /// of the token has full permissions on the account.
    function owner() public view returns (address) {
        (
            uint256 chainId,
            address tokenContract,
            uint256 tokenId
        ) = ERC6551AccountLib.token();

        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    /// @dev Returns the authorization status for a given caller
    function isAuthorized(address caller) public view returns (bool) {
        // authorize entrypoint for 4337 transactions
        if (caller == _entryPoint) return true;

        (
            uint256 chainId,
            address tokenContract,
            uint256 tokenId
        ) = ERC6551AccountLib.token();
        address _owner = IERC721(tokenContract).ownerOf(tokenId);

        // authorize token owner
        if (caller == _owner) return true;

        // authorize caller if owner has granted permissions
        if (permissions[_owner][caller]) return true;

        // authorize trusted cross-chain executors if not on native chain
        if (
            chainId != block.chainid &&
            IAccountGuardian(guardian).isTrustedExecutor(caller)
        ) return true;

        return false;
    }

    /// @dev Returns true if a given interfaceId is supported by this account. This method can be
    /// extended by an override.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        bool defaultSupport = interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId;

        if (defaultSupport) return true;

        // if not supported by default, check override
        _handleOverrideStatic();

        return false;
    }

    /// @dev Allows ERC-721 tokens to be received so long as they do not cause an ownership cycle.
    /// This function can be overriden.
    function onERC721Received(
        address,
        address,
        uint256 receivedTokenId,
        bytes memory
    ) public view override returns (bytes4) {
        _handleOverrideStatic();

        (
            uint256 chainId,
            address tokenContract,
            uint256 tokenId
        ) = ERC6551AccountLib.token();

        if (
            chainId == block.chainid &&
            tokenContract == msg.sender &&
            tokenId == receivedTokenId
        ) revert OwnershipCycle();

        return this.onERC721Received.selector;
    }

    /// @dev Allows ERC-1155 tokens to be received. This function can be overriden.
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public view override returns (bytes4) {
        _handleOverrideStatic();

        return this.onERC1155Received.selector;
    }

    /// @dev Allows ERC-1155 token batches to be received. This function can be overriden.
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public view override returns (bytes4) {
        _handleOverrideStatic();

        return this.onERC1155BatchReceived.selector;
    }

    /// @dev Contract upgrades can only be performed by the owner and the new implementation must
    /// be trusted
    function _authorizeUpgrade(
        address newImplementation
    ) internal view override onlyOwner {
        bool isTrusted = IAccountGuardian(guardian).isTrustedImplementation(
            newImplementation
        );
        if (!isTrusted) revert UntrustedImplementation();
    }

    /// @dev Validates a signature for a given ERC-4337 operation
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view override returns (uint256 validationData) {
        bool isValid = this.isValidSignature(
            userOpHash.toEthSignedMessageHash(),
            userOp.signature
        ) == IERC1271.isValidSignature.selector;

        if (isValid) {
            return 0;
        }

        return 1;
    }

    /// @dev Executes a low-level call
    function _call(
        address to,
        uint256 value,
        bytes calldata data
    ) internal returns (bytes memory result) {
        bool success;
        (success, result) = to.call{ value: value }(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /// @dev Executes a low-level call to the implementation if an override is set
    function _handleOverride() internal {
        address implementation = overrides[owner()][msg.sig];

        if (implementation != address(0)) {
            bytes memory result = _call(implementation, msg.value, msg.data);
            assembly {
                return(add(result, 32), mload(result))
            }
        }
    }

    /// @dev Executes a low-level static call
    function _callStatic(
        address to,
        bytes calldata data
    ) internal view returns (bytes memory result) {
        bool success;
        (success, result) = to.staticcall(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /// @dev Executes a low-level static call to the implementation if an override is set
    function _handleOverrideStatic() internal view {
        address implementation = overrides[owner()][msg.sig];

        if (implementation != address(0)) {
            bytes memory result = _callStatic(implementation, msg.data);
            assembly {
                return(add(result, 32), mload(result))
            }
        }
    }

    function _trackApprovals(
        ApprovalType approvalType,
        address target,
        address approvedAddress,
        uint256 approvedValue
    ) internal {
        if (approvalType == ApprovalType.ERC20_APPROVE) {
            _updateApprovedOperator(
                _approvals,
                target,
                approvedAddress,
                approvedValue
            );
        } else if (approvalType == ApprovalType.SET_APPROVAL_FOR_ALL) {
            _updateApprovedOperator(
                _approvals,
                target,
                approvedAddress,
                approvedValue
            );
        } else if (approvalType == ApprovalType.ERC721_APPROVE) {
            if (approvedAddress == address(0)) {
                bool removed = _erc721ApprovalsMap[target].remove(
                    approvedValue
                );
                if (removed && _erc721ApprovalsMap[target].length() == 0) {
                    _approvedErc721s.remove(target);
                }
            } else {
                _approvedErc721s.add(target);
                _erc721ApprovalsMap[target].set(approvedValue, approvedAddress);
            }
        } else {
            if (approvedValue > 0) {
                // increase allowance
                uint256 currentValue;
                if (_erc20ApprovalsMap[target].contains(approvedAddress)) {
                    currentValue = _erc20ApprovalsMap[target].get(
                        approvedAddress
                    );
                } else {
                    currentValue = 0;
                }
                uint256 newValue = currentValue + approvedValue;
                _updateApprovedOperator(
                    _approvals,
                    target,
                    approvedAddress,
                    newValue
                );
            }
        }
        // TODO: track decreases
    }

    function _updateApprovedOperator(
        EnumerableMap.Bytes32ToBytes32Map storage approvals,
        address target,
        address operator,
        uint256 value
    ) internal {
        if (value == 0) {
            // Remove operator if approvals are being revoked.
            _removeOperator(approvals, target);
        } else {
            // Add the operator to the approvals map.
            approvals.add(target);
        }
    }

    function _removeOperator(
        EnumerableMap.Bytes32ToBytes32Map storage approvals,
        address target
    ) internal {
        bytes32 memory targetBytes32 = bytes32(uint256(target));
        bool removed = approvals.remove(targetBytes32);
    }

    /// @dev checks if a low-level call is an approval
    function _isApproval(bytes calldata callData) internal pure returns (bool) {
        uint256 selector = _getSelector(callData);
        return
            selector == IERC20_721_APPROVE_SELECTOR ||
            selector == IERC20_NONSTANDARD_INCREASE_ALLOWANCE_SELECTOR ||
            selector == IERC721_1155_SET_APPROVAL_FOR_ALL_SELECTOR;
    }

    /// @dev Gets the selector of a low-level call
    function _getSelector(
        bytes calldata callData
    ) internal pure returns (uint256 selector) {
        ///@solidity memory-safe-assembly
        assembly {
            selector := calldataload(callData.offset)
            selector := and(selector, SELECTOR_MASK)
        }
    }

    /// @dev Gets approval type from the function selector
    function _getApprovalType(
        bytes calldata callData
    ) internal pure returns (ApprovalType approvalType) {
        uint256 selector = _getSelector(callData);
        if (selector == IERC20_721_APPROVE_SELECTOR) {
            // check if token is an ERC20, since selector is same as ERC721
            try
                IERC20(tokenAddress).allowance(address(this), approvedAddress)
            returns (uint256) {
                approvalType = ApprovalType.ERC20_APPROVE;
            } catch {
                // if call fails, token is erc721
                approvalType = ApprovalType.ERC721_APPROVE;
            }
            // some erc20 tokens have a non-standard increaseAllowance method
        } else if (selector == IERC20_NONSTANDARD_INCREASE_ALLOWANCE_SELECTOR) {
            approvalType = ApprovalType.INCREASE_ALLOWANCE;
        } else {
            approvalType = ApprovalType.SET_APPROVAL_FOR_ALL;
        }
    }
}
