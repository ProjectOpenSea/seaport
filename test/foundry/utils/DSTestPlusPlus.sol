// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { DSTestPlus } from "@rari-capital/solmate/src/test/utils/DSTestPlus.sol";
import { Test } from "forge-std/Test.sol";

contract DSTestPlusPlus is Test, DSTestPlus {
    function assertFalse(bool condition)
        internal
        virtual
        override(Test, DSTestPlus)
    {
        Test.assertFalse(condition);
    }
}
