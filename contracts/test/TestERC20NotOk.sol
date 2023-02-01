// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";

// Used for minting test ERC20s in our tests.
contract TestERC20NotOk is ERC20("Test20NotOk", "TST20NO", 18) {
    bool public notOk;

    function mint(address to, uint256 amount) external returns (bool) {
        _mint(to, amount);
        return true;
    }

    function transferFrom(
        address /* from */,
        address /* to */,
        uint256 /* amount */
    ) public pure override returns (bool) {
        return false;
    }
}
