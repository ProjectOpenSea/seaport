//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;


contract ExcessReturnDataRecipient {
    uint256 revertDataSize;

    function setRevertDataSize(uint256 size) external {
        revertDataSize = size;
    }

    fallback() external payable {
      uint256 size = revertDataSize;
      if (size > 0) {
        assembly { mstore(size, 1) }
        while (gasleft() > 100) { keccak256(""); }
        assembly {
          revert(0, size)
        }
      }
    }
}
