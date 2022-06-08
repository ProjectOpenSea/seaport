// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

interface ERC20ApprovalInterface {
    function approve(address, uint256) external returns (bool);
}

interface NFTApprovalInterface {
    function setApprovalForAll(address, bool) external;
}

contract EIP1271WalletSpecial {
    bytes4 private constant _EIP_1271_MAGIC_VALUE = 0x1626ba7e;

    address public immutable owner;

    bool public showRevertMessage;

    mapping(bytes32 => bool) public digestApproved;

    bool public isValid;

    // Hardcoded for illustration of cross chain usecase
    uint256 targetChainId = 1;
    bytes32 gatewayHash = bytes32(uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
    uint256 gatewayVersion = 7;

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

    function registerDigest(bytes32 digest, bool approved) external {
        digestApproved[digest] = approved;
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
        if (digestApproved[digest]) {
            return _EIP_1271_MAGIC_VALUE;
        }

        if (signature.length != 65) {
            revert();
        }

        uint256 a;
        bytes32 b;
        uint8 c;

        assembly {
            a := mload(add(signature, 0x20))
            b := mload(add(signature, 0x40))
            c := byte(0, mload(add(signature, 0x60)))
        }

        require(a == targetChainId && b == gatewayHash && c == gatewayVersion, "Invalid signature");

        return isValid ? _EIP_1271_MAGIC_VALUE : bytes4(0xffffffff);
    }
}
