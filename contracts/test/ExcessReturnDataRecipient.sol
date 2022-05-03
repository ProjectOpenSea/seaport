//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

contract ExcessReturnDataRecipient {
    uint256 revertDataSize;

    function setRevertDataSize(uint256 size) external {
        revertDataSize = size;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external view returns (bytes4 magic) {
        magic = this.onERC1155Received.selector;
        uint256 size = revertDataSize;
        if (size > 0) {
            assembly {
                mstore(size, 1)
            }
            bytes32 noOp;
            while (gasleft() > 100) {
                noOp = keccak256("");
            }
            assembly {
                revert(0, size)
            }
        }
    }

    receive() external payable {
        uint256 size = revertDataSize;
        if (size > 0) {
            assembly {
                mstore(size, 1)
            }
            bytes32 noOp;
            while (gasleft() > 100) {
                noOp = keccak256("");
            }
            assembly {
                revert(0, size)
            }
        }
    }
}
