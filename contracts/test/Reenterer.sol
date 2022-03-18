// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

contract Reenterer {
	address target;
	uint256 msgValue;
	bytes callData;

	event Reentered(bool success, bytes returnData);

	function prepare(
		address targetToUse,
		uint256 msgValueToUse,
		bytes calldata callDataToUse
	) external {
		target = targetToUse;
		msgValue = msgValueToUse;
		callData = callDataToUse;
	}

	receive() external payable {
		(bool success, bytes memory returnData) = target.call{value: msgValue}(callData);
		emit Reentered(success, returnData);
	}
}
