// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract TestERC721Revert {
    function transferFrom(
        address /* from */,
        address /* to */,
        uint256 /* amount */
    ) public pure {
        revert("Some ERC721 revert message");
    }
}
