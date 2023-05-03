// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

struct ErrorsAndWarnings {
    uint16[] errors;
    uint16[] warnings;
}

library ErrorsAndWarningsLib {
    function concat(ErrorsAndWarnings memory ew1, ErrorsAndWarnings memory ew2)
        internal
        pure
    {
        ew1.errors = concatMemory(ew1.errors, ew2.errors);
        ew1.warnings = concatMemory(ew1.warnings, ew2.warnings);
    }

    function addError(ErrorsAndWarnings memory ew, uint16 err) internal pure {
        ew.errors = pushMemory(ew.errors, err);
    }

    function addWarning(ErrorsAndWarnings memory ew, uint16 warn)
        internal
        pure
    {
        ew.warnings = pushMemory(ew.warnings, warn);
    }

    function hasErrors(ErrorsAndWarnings memory ew)
        internal
        pure
        returns (bool)
    {
        return ew.errors.length != 0;
    }

    function hasWarnings(ErrorsAndWarnings memory ew)
        internal
        pure
        returns (bool)
    {
        return ew.warnings.length != 0;
    }

    // Helper Functions
    function concatMemory(uint16[] memory array1, uint16[] memory array2)
        private
        pure
        returns (uint16[] memory)
    {
        if (array1.length == 0) {
            return array2;
        } else if (array2.length == 0) {
            return array1;
        }

        uint16[] memory returnValue = new uint16[](
            array1.length + array2.length
        );

        for (uint256 i = 0; i < array1.length; i++) {
            returnValue[i] = array1[i];
        }
        for (uint256 i = 0; i < array2.length; i++) {
            returnValue[i + array1.length] = array2[i];
        }

        return returnValue;
    }

    function pushMemory(uint16[] memory uint16Array, uint16 newValue)
        internal
        pure
        returns (uint16[] memory)
    {
        uint16[] memory returnValue = new uint16[](uint16Array.length + 1);

        for (uint256 i = 0; i < uint16Array.length; i++) {
            returnValue[i] = uint16Array[i];
        }
        returnValue[uint16Array.length] = newValue;

        return returnValue;
    }
}
