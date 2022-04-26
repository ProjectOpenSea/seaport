// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { DSTestPlusPlus } from "./DSTestPlusPlus.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { Consideration } from "../../../contracts/Consideration.sol";

/// @dev Base test case that deploys Consideration and its dependencies
contract ConsiderationBaseTest is DSTestPlusPlus {
    using stdStorage for StdStorage;

    Consideration consideration;
    address registry;
    address proxy;
    address delegateProxyImplementation;

    function setUp() public virtual {
        _deployLegacyContracts();

        consideration = new Consideration(
            proxy,
            delegateProxyImplementation,
            registry
        );
    }

    /**
    @dev get and deploy precompiled contracts that depend on legacy versions
        of the solidity compiler
     */
    function _deployLegacyContracts() internal {
        /// @dev deploy WyvernProxyRegistry from precompiled source
        bytes memory bytecode = vm.getCode(
            "wyvern-0.4.13/WyvernProxyRegistry.sol/WyvernProxyRegistry.json"
        );
        // TODO: temporary, get this working before dealing with storage .slots
        address registryCopy;
        assembly {
            registryCopy := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        registry = registryCopy;
        /// @dev deploy WyvernTokenTransferProxy from precompiled source
        bytes memory constructorArgs = abi.encode(registryCopy);
        bytecode = abi.encodePacked(
            vm.getCode(
                "wyvern-0.4.13/WyvernTokenTransferProxy.sol/WyvernTokenTransferProxy.json"
            ),
            constructorArgs
        );
        address proxyCopy;
        assembly {
            proxyCopy := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        proxy = proxyCopy;
        /// @dev use stdstore to read delegateProxyImplementation from deployed registry
        delegateProxyImplementation = address(
            uint160(
                stdstore
                    .target(registry)
                    .sig("delegateProxyImplementation()")
                    .find()
            )
        );
    }
}
