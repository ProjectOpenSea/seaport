// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

/**
 * @notice Checks that the `optimized` profile still builds the exact init code
 *         of the canonical Seaport 1.6 deployment, so toolchain and dependency
 *         changes in this repository cannot silently change the contract.
 *
 *         Run `FOUNDRY_PROFILE=optimized forge build` before this test.
 */
contract DeployedBytecodeTest is Test {
    // Canonical Seaport 1.6, deployed at the same address on every chain.
    address constant SEAPORT_1_6 = 0x0000000000000068F116a894984e2DB1123eB395;

    // Constructor argument of the canonical deployment.
    address constant CONDUIT_CONTROLLER =
        0x00000000F9490004C11Cef243f5400493c00Ad63;

    // ImmutableCreate2Factory and the salt passed to it in Ethereum mainnet
    // tx 0x926e958d5919f0089f47a353b0a8a211bd858abb20348261d41672d77fa7c6a0.
    address constant IMMUTABLE_CREATE2_FACTORY =
        0x0000000000FFe8B47B3e2130213B802212439497;
    bytes32 constant SEAPORT_1_6_SALT =
        0x0000000000000000000000000000000000000000d738b7f0bb99901b1c83f249;

    // keccak256 of the init code (creation code plus constructor argument)
    // deployed in the transaction above.
    bytes32 constant SEAPORT_1_6_INIT_CODE_HASH =
        0xde057106c8377de87f4547af6ef65fa2c96fddbc136be5748060ed7c32902d94;

    function test_initCodeHashDerivesCanonicalAddress() public pure {
        assertEq(
            vm.computeCreate2Address(
                SEAPORT_1_6_SALT,
                SEAPORT_1_6_INIT_CODE_HASH,
                IMMUTABLE_CREATE2_FACTORY
            ),
            SEAPORT_1_6
        );
    }

    function test_optimizedBuildMatchesDeployedInitCode() public view {
        bytes memory initCode = abi.encodePacked(
            vm.getCode("optimized-out/Seaport.sol/Seaport.json"),
            abi.encode(CONDUIT_CONTROLLER)
        );

        assertEq(
            keccak256(initCode),
            SEAPORT_1_6_INIT_CODE_HASH,
            "Seaport build no longer matches the deployed 1.6 init code"
        );
    }
}
