// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IAccountGuardian {
    function setTrustedImplementation(
        address implementation,
        bool trusted
    ) external;

    function setTrustedExecutor(address executor, bool trusted) external;

    function defaultImplementation() external view returns (address);

    function isTrustedImplementation(
        address implementation
    ) external view returns (bool);

    function isTrustedExecutor(
        address implementation
    ) external view returns (bool);
}
