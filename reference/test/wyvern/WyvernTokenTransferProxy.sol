pragma solidity ^0.4.13;

import "./ProxyRegistry.sol";
import "./TokenTransferProxy.sol";

contract WyvernTokenTransferProxy is TokenTransferProxy {
    constructor(ProxyRegistry registryAddr) public {
        registry = registryAddr;
    }
}
