// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface ERC20Interface {
    function transferFrom(address, address, uint256) external returns (bool);
}

interface ERC721Interface {
    function transferFrom(address, address, uint256) external;
}

interface ERC1155Interface {
    function safeTransferFrom(address, address, uint256, uint256, bytes calldata) external;
    function safeBatchTransferFrom(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external;
}