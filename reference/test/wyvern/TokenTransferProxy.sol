pragma solidity ^0.4.13;

import "./ERC20.sol";
import "./ProxyRegistry.sol";

contract TokenTransferProxy {
    /* Authentication registry. */
    ProxyRegistry public registry;

    /**
     * Call ERC20 `transferFrom`
     *
     * @dev Authenticated contract only
     * @param token ERC20 token address
     * @param from From address
     * @param to To address
     * @param amount Transfer amount
     */
    function transferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        require(registry.contracts(msg.sender));
        return ERC20(token).transferFrom(from, to, amount);
    }
}
