// SPDX-Identifier: MIT
pragma solidity ^0.8.13;

import { CustomERC721 } from "../../token/CustomERC721.sol";

contract PreapprovedERC721 is CustomERC721 {
    mapping(address => bool) public preapprovals;

    constructor(address[] memory preapproved) CustomERC721("", "") {
        for (uint256 i = 0; i < preapproved.length; i++) {
            preapprovals[preapproved[i]] = true;
        }
    }

    function mint(address to, uint256 amount) external returns (bool) {
        _mint(to, amount);
        return true;
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) public view override returns (bool) {
        return
            preapprovals[operator] || super.isApprovedForAll(owner, operator);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }
}
