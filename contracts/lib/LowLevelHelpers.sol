// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ConsiderationConstants.sol";

/**
 * @title LowLevelHelpers
 * @author 0age
 * @notice LowLevelHelpers contains logic for performing various low-level
 *         operations.
 */
contract LowLevelHelpers {
    /**
     * @dev Internal function to call an arbitrary target with given calldata.
     *      Note that no data is written to memory and no contract size check is
     *      performed.
     *
     * @param target                The account to call.
     * @param callDataMemoryPointer The location in memory of the calldata to
     *                              supply when calling the target.
     * @param callDataLength        The length of the calldata.
     *
     * @return success The status of the staticcall to the target.
     */
    function _call(
        address target,
        uint256 callDataMemoryPointer,
        uint256 callDataLength
    ) internal returns (bool success) {
        assembly {
            // Clear the start of scratch space.
            mstore(0, 0)

            // Perform call, placing result in the first word of scratch space.
            success := call(
                gas(),
                target,
                0,
                callDataMemoryPointer,
                callDataLength,
                0,
                OneWord
            )
        }
    }

    /**
     * @dev Internal view function to revert and pass along the revert reason if
     *      data was returned by the last call and that the size of that data
     *      does not exceed the currently allocated memory size.
     */
    function _revertWithReasonIfOneIsReturned() internal view {
        assembly {
            // If it returned a message, bubble it up as long as sufficient gas
            // remains to do so:
            if returndatasize() {
                // Ensure that sufficient gas is available to copy returndata
                // while expanding memory where necessary. Start by computing
                // the word size of returndata and allocated memory.
                let returnDataWords := div(
                    add(returndatasize(), AlmostOneWord),
                    OneWord
                )

                // Note: use the free memory pointer in place of msize() to work
                // around a Yul warning that prevents accessing msize directly
                // when the IR pipeline is activated.
                let msizeWords := div(mload(FreeMemoryPointerSlot), OneWord)

                // Next, compute the cost of the returndatacopy.
                let cost := mul(CostPerWord, returnDataWords)

                // Then, compute cost of new memory allocation.
                if gt(returnDataWords, msizeWords) {
                    cost := add(
                        cost,
                        add(
                            mul(sub(returnDataWords, msizeWords), CostPerWord),
                            div(
                                sub(
                                    mul(returnDataWords, returnDataWords),
                                    mul(msizeWords, msizeWords)
                                ),
                                MemoryExpansionCoefficient
                            )
                        )
                    )
                }

                // Finally, add a small constant and compare to gas remaining;
                // bubble up the revert data if enough gas is still available.
                if lt(add(cost, ExtraGasBuffer), gas()) {
                    // Copy returndata to memory; overwrite existing memory.
                    returndatacopy(0, 0, returndatasize())

                    // Revert, specifying memory region with copied returndata.
                    revert(0, returndatasize())
                }
            }
        }
    }

    /**
     * @dev Internal pure function to determine if the first word of scratch
     *      space matches an expected magic value.
     *
     * @param expected The expected magic value.
     *
     * @return A boolean indicating whether the expected value matches the one
     *         located in the first word of scratch space.
     */
    function _doesNotMatchMagic(bytes4 expected) internal pure returns (bool) {
        // Declare a variable for the value held in scratch space.
        bytes4 result;

        // Utilize assembly in order to read directly from scratch space.
        assembly {
            // Take value from scratch space and place it on the stack.
            result := mload(0)
        }

        // Return a boolean indicating whether expected and located value match.
        return result != expected;
    }

    /**
     * @dev Internal view function to branchlessly select either the caller (if
     *      a supplied recipient is equal to zero) or the supplied recipient (if
     *      that recipient is a nonzero value).
     *
     * @param recipient The supplied recipient.
     *
     * @return updatedRecipient The updated recipient.
     */
    function _substituteCallerForEmptyRecipient(
        address recipient
    ) internal view returns (address updatedRecipient) {
        // Utilize assembly to perform a branchless operation on the recipient.
        assembly {
            // Add caller to recipient if recipient equals 0; otherwise add 0.
            updatedRecipient := add(recipient, mul(iszero(recipient), caller()))
        }
    }

    /**
     * @dev Internal pure function to compare two addresses without first
     *      masking them. Note that dirty upper bits will cause otherwise equal
     *      addresses to be recognized as unequal.
     *
     * @param a The first address.
     * @param b The second address
     *
     * @return areEqual A boolean representing whether the addresses are equal.
     */
    function _unmaskedAddressComparison(
        address a,
        address b
    ) internal pure returns (bool areEqual) {
        // Utilize assembly to perform the comparison without masking.
        assembly {
            areEqual := eq(a, b)
        }
    }
}
