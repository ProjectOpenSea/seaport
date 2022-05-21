// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import { Test } from "forge-std/Test.sol";

contract DifferentialTest is Test {
    // slot where HEVM stores bool of whether or not an assertion has failed
    bytes32 HEVM_FAILED_SLOT =
        0x6661696c65640000000000000000000000000000000000000000000000000000;

    // hash of the bytes surfaced by `revert RevertWithFailureStatus(false)`
    bytes32 PASSING_HASH =
        0xf951c460268b64a0aabc103be9b020b90c4d14012c2d21f9c441a69438400a57;

    error RevertWithFailureStatus(bool status);

    ///@dev reverts after function body with the failure status, clearing all state changes made
    modifier stateless() {
        _;
        revertWithFailureStatus();
    }

    function assertPass(bytes memory reason) internal {
        assertEq(keccak256(reason), PASSING_HASH);
    }

    function revertWithFailureStatus() internal {
        revert RevertWithFailureStatus(readHevmFailureSlot());
    }

    function readHevmFailureSlot() internal returns (bool) {
        return vm.load(address(vm), HEVM_FAILED_SLOT) == bytes32(uint256(1));
    }
}
