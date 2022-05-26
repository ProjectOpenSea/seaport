// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;
import { Test } from "forge-std/Test.sol";

contract DifferentialTest is Test {
    bytes32 HEVM_FAILED_SLOT =
        0x6661696c65640000000000000000000000000000000000000000000000000000;

    error RevertWithFailureStatus(bool status);

    function revertWithFailureStatus() internal {
        revert RevertWithFailureStatus(readHevmFailureSlot());
    }

    function assertPass(bytes memory reason) internal {
        assertFalse(didFail(reason));
    }

    function readHevmFailureSlot() internal returns (bool) {
        return vm.load(address(vm), HEVM_FAILED_SLOT) == bytes32(uint256(1));
    }

    function didFail(bytes memory reason) internal pure returns (bool) {
        return reason[35] > 0;
    }
}
