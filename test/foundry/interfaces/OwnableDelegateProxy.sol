// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

interface OwnableDelegateProxy {
    function name() external returns (string memory);

    function proxyOwner() external returns (address);
}
