// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract TestERC20Panic is ERC20("TestPanic", "PANIC", 18) {
    function mint(address to, uint256 amount) external returns (bool) {
        _mint(to, amount);
        return true;
    }

    function transferFrom(
        address /* from */,
        address /* to */,
        uint256 /* amount */
    ) public pure override returns (bool) {
        uint256 a = uint256(0) / uint256(0);
        a;

        return true;
    }
}
