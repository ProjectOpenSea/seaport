//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Used for minting test ERC20s in our tests
contract TestERC20 is ERC20("Test20", "TST20") {
    bool public blocked;

    constructor() {
        blocked = false;
    }

    function blockTransfer(bool blocking) external {
        blocked = blocking;
    }

    function mint(address to, uint256 amount) external returns (bool) {
        _mint(to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool ok) {
        if (blocked) {
            return false;
        }

        super.transferFrom(from, to, amount);

        ok = true;
    }
}
