pragma solidity ^0.8.17;

import "./GetContractOffererNoncePointerLibrary.sol";
import "./GetCounterPointerLibrary.sol";
import "./GetOrderStatusPointerLibrary.sol";
import "./GetOrderHashPointerLibrary.sol";
import "./FulfillBasicOrderEfficient6GL6ycPointerLibrary.sol";
import "./ValidatePointerLibrary.sol";
import "./CancelPointerLibrary.sol";
import "./MatchAdvancedOrdersPointerLibrary.sol";
import "./MatchOrdersPointerLibrary.sol";
import "./FulfillAvailableAdvancedOrdersPointerLibrary.sol";
import "./FulfillAvailableOrdersPointerLibrary.sol";
import "./FulfillAdvancedOrderPointerLibrary.sol";
import "./FulfillOrderPointerLibrary.sol";
import "./FulfillBasicOrderPointerLibrary.sol";

/// @dev Get the selector from the first 4 bytes of the data
function getSelector(bytes memory data) pure returns (bytes4 selector) {
  assembly {
    selector := shl(224, mload(add(data, 0x04)))
  }
}

/// @dev Get the directives for the given calldata
function getScuffDirectivesForCalldata(bytes memory data) pure returns (ScuffDirective[] memory) {
  bytes4 selector = getSelector(data);
  if (FulfillBasicOrderPointerLibrary.isFunction(selector)) {
    return FulfillBasicOrderPointerLibrary.getScuffDirectivesForCalldata(data);
  }
  if (FulfillOrderPointerLibrary.isFunction(selector)) {
    return FulfillOrderPointerLibrary.getScuffDirectivesForCalldata(data);
  }
  if (FulfillAdvancedOrderPointerLibrary.isFunction(selector)) {
    return FulfillAdvancedOrderPointerLibrary.getScuffDirectivesForCalldata(data);
  }
  if (FulfillAvailableOrdersPointerLibrary.isFunction(selector)) {
    return FulfillAvailableOrdersPointerLibrary.getScuffDirectivesForCalldata(data);
  }
  if (FulfillAvailableAdvancedOrdersPointerLibrary.isFunction(selector)) {
    return FulfillAvailableAdvancedOrdersPointerLibrary.getScuffDirectivesForCalldata(data);
  }
  if (MatchOrdersPointerLibrary.isFunction(selector)) {
    return MatchOrdersPointerLibrary.getScuffDirectivesForCalldata(data);
  }
  if (MatchAdvancedOrdersPointerLibrary.isFunction(selector)) {
    return MatchAdvancedOrdersPointerLibrary.getScuffDirectivesForCalldata(data);
  }
  if (CancelPointerLibrary.isFunction(selector)) {
    return CancelPointerLibrary.getScuffDirectivesForCalldata(data);
  }
  if (ValidatePointerLibrary.isFunction(selector)) {
    return ValidatePointerLibrary.getScuffDirectivesForCalldata(data);
  }
  if (FulfillBasicOrderEfficient6GL6ycPointerLibrary.isFunction(selector)) {
    return FulfillBasicOrderEfficient6GL6ycPointerLibrary.getScuffDirectivesForCalldata(data);
  }
  if (GetOrderHashPointerLibrary.isFunction(selector)) {
    return GetOrderHashPointerLibrary.getScuffDirectivesForCalldata(data);
  }
  revert("No matching function found");
}

function toKindString(bytes4 selector, uint256 k) pure returns (string memory) {
  if (FulfillBasicOrderPointerLibrary.isFunction(selector)) {
    return FulfillBasicOrderPointerLibrary.toKindString(k);
  }
  if (FulfillOrderPointerLibrary.isFunction(selector)) {
    return FulfillOrderPointerLibrary.toKindString(k);
  }
  if (FulfillAdvancedOrderPointerLibrary.isFunction(selector)) {
    return FulfillAdvancedOrderPointerLibrary.toKindString(k);
  }
  if (FulfillAvailableOrdersPointerLibrary.isFunction(selector)) {
    return FulfillAvailableOrdersPointerLibrary.toKindString(k);
  }
  if (FulfillAvailableAdvancedOrdersPointerLibrary.isFunction(selector)) {
    return FulfillAvailableAdvancedOrdersPointerLibrary.toKindString(k);
  }
  if (MatchOrdersPointerLibrary.isFunction(selector)) {
    return MatchOrdersPointerLibrary.toKindString(k);
  }
  if (MatchAdvancedOrdersPointerLibrary.isFunction(selector)) {
    return MatchAdvancedOrdersPointerLibrary.toKindString(k);
  }
  if (CancelPointerLibrary.isFunction(selector)) {
    return CancelPointerLibrary.toKindString(k);
  }
  if (ValidatePointerLibrary.isFunction(selector)) {
    return ValidatePointerLibrary.toKindString(k);
  }
  if (FulfillBasicOrderEfficient6GL6ycPointerLibrary.isFunction(selector)) {
    return FulfillBasicOrderEfficient6GL6ycPointerLibrary.toKindString(k);
  }
  if (GetOrderHashPointerLibrary.isFunction(selector)) {
    return GetOrderHashPointerLibrary.toKindString(k);
  }
  revert("No matching function found");
}

function getFunctionName(bytes4 selector) pure returns (string memory) {
  if (FulfillBasicOrderPointerLibrary.isFunction(selector)) {
    return FulfillBasicOrderPointerLibrary.FunctionName;
  }
  if (FulfillOrderPointerLibrary.isFunction(selector)) {
    return FulfillOrderPointerLibrary.FunctionName;
  }
  if (FulfillAdvancedOrderPointerLibrary.isFunction(selector)) {
    return FulfillAdvancedOrderPointerLibrary.FunctionName;
  }
  if (FulfillAvailableOrdersPointerLibrary.isFunction(selector)) {
    return FulfillAvailableOrdersPointerLibrary.FunctionName;
  }
  if (FulfillAvailableAdvancedOrdersPointerLibrary.isFunction(selector)) {
    return FulfillAvailableAdvancedOrdersPointerLibrary.FunctionName;
  }
  if (MatchOrdersPointerLibrary.isFunction(selector)) {
    return MatchOrdersPointerLibrary.FunctionName;
  }
  if (MatchAdvancedOrdersPointerLibrary.isFunction(selector)) {
    return MatchAdvancedOrdersPointerLibrary.FunctionName;
  }
  if (CancelPointerLibrary.isFunction(selector)) {
    return CancelPointerLibrary.FunctionName;
  }
  if (ValidatePointerLibrary.isFunction(selector)) {
    return ValidatePointerLibrary.FunctionName;
  }
  if (FulfillBasicOrderEfficient6GL6ycPointerLibrary.isFunction(selector)) {
    return FulfillBasicOrderEfficient6GL6ycPointerLibrary.FunctionName;
  }
  if (GetOrderHashPointerLibrary.isFunction(selector)) {
    return GetOrderHashPointerLibrary.FunctionName;
  }
  revert("No matching function found");
}

function getScuffDescription(bytes4 selector, ScuffDirective directive) view returns (ScuffDescription memory description) {
  (uint256 kind, ScuffSide side, uint256 bitOffset, ScuffPositions positions, MemoryPointer pointer) = directive.decode();
  description.pointer = MemoryPointer.unwrap(pointer);
  description.originalValue = pointer.readBytes32();
  description.positions = positions.toArray();
  description.side = toSideString(side);
  description.bitOffset = bitOffset;
  description.kind = toKindString(selector, kind);
  description.functionName = getFunctionName(selector);
}