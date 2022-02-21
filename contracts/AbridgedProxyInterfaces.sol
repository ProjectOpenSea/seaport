// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface ProxyRegistryInterface {
	function proxies(address user) external view returns (address proxy);
}

interface ProxyInterface {
	function implementation() external view returns (address);
	function transferERC721(
		address token, address from, address to, uint256 tokenId
	) external returns (bool);
	function transferERC1155(
		address token, address from, address to, uint256 tokenId, uint256 amount
	) external returns (bool);
	function batchTransferERC1155(
		address token,
		address from,
		address to,
		uint256[] calldata tokenIds,
		uint256[] calldata amounts
	) external returns (bool);
}