// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

interface ERC20ApprovalInterface {
    function approve(address, uint256) external returns (bool);
}

interface NFTApprovalInterface {
    function setApprovalForAll(address, bool) external;
}

contract EIP1271WalletCrossChain {
    bytes4 private constant _EIP_1271_MAGIC_VALUE = 0x1626ba7e;

    address public immutable owner;

    bool public showRevertMessage;

    mapping(bytes32 => bytes32) public digestApproved;
    mapping(bytes32 => bytes32) public commandIdApproved;
    mapping(bytes32 => bool) public commandIdRefunded;

    bool public isValid;

    // Hardcoded for illustration of cross chain usecase.

    // Chain ID where the transaction has been started.
    uint256 sourceChainId = 1;

    // Hash that used
    bytes32 gatewayHash = bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));

    // Version of gateway implementation
    uint8 gatewayVersion = 1;

    constructor(address _owner) {
        owner = _owner;
        showRevertMessage = true;
        isValid = true;
    }

    function setValid(bool valid) external {
        isValid = valid;
    }

    function revertWithMessage(bool showMessage) external {
        showRevertMessage = showMessage;
    }

    function _validateWithCrossChainGateway(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes memory payload
    ) internal {
        // From Axelar source code: https://github.com/axelarnetwork/axelar-cgp-solidity/blob/main/contracts/interfaces/IAxelarExecutable.sol
        // bytes32 payloadHash = keccak256(payload);
        // if (!gateway.validateContractCall(commandId, sourceChain, sourceAddress, payloadHash))
        //     revert NotApprovedByGateway();
    }

    // From Axelar source code: https://github.com/axelarnetwork/axelar-cgp-solidity/blob/main/contracts/interfaces/IAxelarExecutable.sol
    function execute(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes memory payload
    ) external {
        _validateWithCrossChainGateway(
            commandId,
            sourceChain,
            sourceAddress,
            payload
        );

        bytes32 digest;
        assembly {
            digest := mload(add(payload, 0x20))
        }

        bytes32 approvedHash = keccak256(
            abi.encodePacked(commandId, sourceChain, sourceAddress, payload)
        );

        digestApproved[digest] = approvedHash;
        commandIdApproved[commandId] = approvedHash;

        // Note: Map commandId -> seller here.
    }

    function approveERC20(
        ERC20ApprovalInterface token,
        address operator,
        uint256 amount
    ) external {
        if (msg.sender != owner) {
            revert("Only owner");
        }

        token.approve(operator, amount);
    }

    function approveNFT(NFTApprovalInterface token, address operator) external {
        if (msg.sender != owner) {
            revert("Only owner");
        }

        token.setApprovalForAll(operator, true);
    }

    function isValidSignature(bytes32 digest, bytes memory signature)
        external
        view
        returns (bytes4)
    {
        if (signature.length != 65) {
            revert();
        }

        bytes32 commandId;
        bytes32 approvedHash;
        uint8 v;

        assembly {
            commandId := mload(add(signature, 0x20))
            approvedHash := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        require(!commandIdRefunded[commandId], "Already refunded");
        require(
            commandIdApproved[commandId] == approvedHash &&
                digestApproved[digest] == approvedHash &&
                v == gatewayVersion,
            "Invalid signature"
        );

        return isValid ? _EIP_1271_MAGIC_VALUE : bytes4(0xffffffff);
    }
}
