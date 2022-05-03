// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { OwnableDelegateProxy } from "./OwnableDelegateProxy.sol";

interface ProxyRegistry {
    function delegateProxyImplementation() external returns (address);

    function registerProxy() external returns (OwnableDelegateProxy);

    function proxies(address _addr)
        external
        view
        returns (OwnableDelegateProxy);
}
