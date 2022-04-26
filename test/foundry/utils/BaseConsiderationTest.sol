// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { Consideration, ItemType, ConsiderationItem } from "../../../contracts/Consideration.sol";
import { DSTestPlusPlus } from "./DSTestPlusPlus.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

/// @dev Base test case that deploys Consideration and its dependencies
contract BaseConsiderationTest is DSTestPlusPlus {
    using stdStorage for StdStorage;

    Consideration consideration;
    address internal _wyvernProxyRegistry;
    address internal _wyvernTokenTransferProxy;
    address internal _wyvernDelegateProxyImplementation;

    function setUp() public virtual {
        _deployLegacyContracts();

        consideration = new Consideration(
            _wyvernProxyRegistry,
            _wyvernTokenTransferProxy,
            _wyvernDelegateProxyImplementation
        );
    }

    function signOrder(uint256 _pkOfSigner, bytes32 _orderHash)
        internal
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        return
            vm.sign(
                _pkOfSigner,
                keccak256(
                    abi.encodePacked(
                        bytes2(0x1901),
                        consideration.DOMAIN_SEPARATOR(),
                        _orderHash
                    )
                )
            );
    }

    /**
    @dev get and deploy precompiled contracts that depend on legacy versions
        of the solidity compiler
     */
    function _deployLegacyContracts() private {
        /// @dev deploy WyvernProxyRegistry from precompiled source
        bytes memory bytecode = vm.getCode(
            "out/WyvernProxyRegistry.sol/WyvernProxyRegistry.json"
        );
        // TODO: temporary, get this working before dealing with storage .slots
        address registryCopy;
        assembly {
            registryCopy := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        _wyvernProxyRegistry = registryCopy;

        /// @dev deploy WyvernTokenTransferProxy from precompiled source
        bytes memory constructorArgs = abi.encode(registryCopy);
        bytecode = abi.encodePacked(
            vm.getCode(
                "out/WyvernTokenTransferProxy.sol/WyvernTokenTransferProxy.json"
            ),
            constructorArgs
        );
        /// @dev deploy WyvernTokenTransferProxy from precompiled source
        address proxyCopy;
        assembly {
            proxyCopy := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        _wyvernTokenTransferProxy = proxyCopy;

        /// @dev use stdstore to read delegateProxyImplementation from deployed registry
        _wyvernDelegateProxyImplementation = address(
            uint160(
                stdstore
                    .target(_wyvernProxyRegistry)
                    .sig("delegateProxyImplementation()")
                    .find()
            )
        );
    }
}
