// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ProxyRegistryInterface {
    function proxies(address user) external view returns (address proxy);
}

interface ProxyInterface {
    function proxyAssert(
        address dest,
        uint8 howToCall,
        bytes calldata callData
    ) external;

    function implementation() external view returns (address);
}

interface TokenTransferProxyInterface {
    function transferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
