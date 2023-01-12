// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@rari-capital/solmate/src/tokens/ERC20.sol";

contract TestERC20Revert is ERC20("TestRevert", "REVERT", 18) {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transferFrom(
        address, /* from */
        address, /* to */
        uint256 /* amount */
    ) public pure override returns (bool) {
        revert("Some ERC20 revert message");
    }
}
