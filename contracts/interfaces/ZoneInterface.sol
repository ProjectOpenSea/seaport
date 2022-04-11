// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { AdvancedOrder } from "../lib/ConsiderationStructs.sol";

interface ZoneInterface {
	// Called by Consideration whenever extraData is not provided by the caller.
	function isValidOrder(
		bytes32 orderHash, address caller, address offerer
	) external view returns (bytes4 validOrderMagicValue);

	// Called by Consideration whenever any extraData is provided by the caller.
	function isValidOrderIncludingExtraData(
		bytes32 orderHash, address caller, AdvancedOrder calldata order
	) external view returns (bytes4 validOrderMagicValue);
}
