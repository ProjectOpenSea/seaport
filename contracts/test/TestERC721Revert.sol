// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { TestERC721 } from "./TestERC721.sol";

contract TestERC721Revert is TestERC721 {
    function transferFrom(
        address /* from */,
        address /* to */,
        uint256 /* amount */
    ) public pure override {
        revert(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        );
    }
}
