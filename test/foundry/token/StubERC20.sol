// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StubERC20 {
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        emit Transfer(from, to, amount);
        return true;
    }
}
