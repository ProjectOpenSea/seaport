// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ConsiderationDelegated } from "../lib/ConsiderationDelegated.sol";

contract DelegatedDomainSeparatorTester is ConsiderationDelegated {
    address _DEPLOYER;

    constructor(
        address legacyProxyRegistry,
        address requiredProxyImplementation
    ) ConsiderationDelegated(legacyProxyRegistry, requiredProxyImplementation) {
        _DEPLOYER = msg.sender;
    }

    function deriveDomainSeparatorAndCompare() external view {
        bytes32 derived = _deriveDomainSeparator();
        bytes32 expected = keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                _DEPLOYER
            )
        );

        if (derived != expected) {
            revert("Incorrectly derived domain separator.");
        }
    }
}
