//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Used for minting test ERC20s in our tests
contract TestERC20 is ERC20("Test20", "TST20") {
  function mint(address to, uint256 amount) public returns (bool) {
    _mint(to, amount);
    return true;
  }
}
