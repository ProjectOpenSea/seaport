// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {
    ErrorsAndWarnings,
    ErrorsAndWarningsLib
} from "../order-validator/lib/ErrorsAndWarnings.sol";

contract TestEW {
    using ErrorsAndWarningsLib for ErrorsAndWarnings;

    ErrorsAndWarnings errorsAndWarnings;

    constructor() {
        errorsAndWarnings = ErrorsAndWarnings(new uint16[](0), new uint16[](0));
    }

    function addError(uint16 err) public {
        ErrorsAndWarnings memory memEw = errorsAndWarnings;
        memEw.addError(err);
        errorsAndWarnings = memEw;
    }

    function addWarning(uint16 warn) public {
        ErrorsAndWarnings memory memEw = errorsAndWarnings;
        memEw.addWarning(warn);
        errorsAndWarnings = memEw;
    }

    function hasErrors() public view returns (bool) {
        return errorsAndWarnings.hasErrors();
    }

    function hasWarnings() public view returns (bool) {
        return errorsAndWarnings.hasWarnings();
    }
}
