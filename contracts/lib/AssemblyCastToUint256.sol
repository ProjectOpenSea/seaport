// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

/**
 * @title AssemblyCastToUint256
 * @author Rotcivegaf
 * @notice AssemblyCastToUint256 contains a pure function related to casting an
 *         address to an uint256 in inline assembly
 *         With the objective to save gas
 */
contract AssemblyCastToUint256 {
    function toUint256(address value) internal pure returns (uint256 result) {
        assembly {
            result := value
        }
    }
}