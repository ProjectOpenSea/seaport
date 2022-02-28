pragma solidity 0.8.12;

interface ConsiderationHelperInterface {
	function deriveDomainSeparator() external view returns (bytes32);
}