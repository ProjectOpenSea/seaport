//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.7;

import "@rari-capital/solmate/src/tokens/ERC20.sol";

contract TestERC20Panic is ERC20("TestPanic", "PANIC", 18) {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 a = uint256(0) / uint256(0);
        a;

        return true;
    }
}
