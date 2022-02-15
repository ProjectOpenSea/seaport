// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface ERC20Interface {
    function transferFrom(address, address, uint256) external returns (bool);
}

interface ERC721Interface {
    function transferFrom(address, address, uint256) external;
}

interface ERC1155Interface {
    function safeTransferFrom(address, address, uint256, uint256) external;
}