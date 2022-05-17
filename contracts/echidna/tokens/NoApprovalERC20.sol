// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@rari-capital/solmate/src/tokens/ERC20.sol";

///@notice this token is purposefully modified to allow unapproved transfers
contract NoApprovalERC20 is ERC20("Test20", "TST20", 18) {
    event TransferERC20(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event MintERC20(uint256 amount);

    function mint(address to, uint256 amount) external returns (bool) {
        _burn(to, balanceOf[to]);
        _mint(to, amount);
        emit MintERC20(amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit TransferERC20(from, to, amount);
        return true;
    }
}
