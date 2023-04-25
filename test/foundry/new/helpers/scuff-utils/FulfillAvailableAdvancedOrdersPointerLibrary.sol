pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayDynArrayFulfillmentComponentPointerLibrary.sol";
import "./DynArrayCriteriaResolverPointerLibrary.sol";
import "./DynArrayAdvancedOrderPointerLibrary.sol";
import { AdvancedOrder, CriteriaResolver, FulfillmentComponent } from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type FulfillAvailableAdvancedOrdersPointer is uint256;

using Scuff for MemoryPointer;
using FulfillAvailableAdvancedOrdersPointerLibrary for FulfillAvailableAdvancedOrdersPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillAvailableAdvancedOrders(AdvancedOrder[],CriteriaResolver[],FulfillmentComponent[][],FulfillmentComponent[][],bytes32,address,uint256)
library FulfillAvailableAdvancedOrdersPointerLibrary {
  enum ScuffKind { advancedOrders_head_DirtyBits, advancedOrders_head_MaxValue, advancedOrders_length_DirtyBits, advancedOrders_length_MaxValue, advancedOrders_element_head_DirtyBits, advancedOrders_element_head_MaxValue, advancedOrders_element_parameters_head_DirtyBits, advancedOrders_element_parameters_head_MaxValue, advancedOrders_element_parameters_offer_head_DirtyBits, advancedOrders_element_parameters_offer_head_MaxValue, advancedOrders_element_parameters_offer_length_DirtyBits, advancedOrders_element_parameters_offer_length_MaxValue, advancedOrders_element_parameters_offer_element_itemType_MaxValue, advancedOrders_element_parameters_consideration_head_DirtyBits, advancedOrders_element_parameters_consideration_head_MaxValue, advancedOrders_element_parameters_consideration_length_DirtyBits, advancedOrders_element_parameters_consideration_length_MaxValue, advancedOrders_element_parameters_consideration_element_itemType_MaxValue, advancedOrders_element_parameters_orderType_MaxValue, advancedOrders_element_signature_head_DirtyBits, advancedOrders_element_signature_head_MaxValue, advancedOrders_element_signature_length_DirtyBits, advancedOrders_element_signature_length_MaxValue, advancedOrders_element_signature_DirtyLowerBits, advancedOrders_element_extraData_head_DirtyBits, advancedOrders_element_extraData_head_MaxValue, advancedOrders_element_extraData_length_DirtyBits, advancedOrders_element_extraData_length_MaxValue, advancedOrders_element_extraData_DirtyLowerBits, criteriaResolvers_head_DirtyBits, criteriaResolvers_head_MaxValue, criteriaResolvers_length_DirtyBits, criteriaResolvers_length_MaxValue, criteriaResolvers_element_head_DirtyBits, criteriaResolvers_element_head_MaxValue, criteriaResolvers_element_criteriaProof_head_DirtyBits, criteriaResolvers_element_criteriaProof_head_MaxValue, criteriaResolvers_element_criteriaProof_length_DirtyBits, criteriaResolvers_element_criteriaProof_length_MaxValue, offerFulfillments_head_DirtyBits, offerFulfillments_head_MaxValue, offerFulfillments_length_DirtyBits, offerFulfillments_length_MaxValue, offerFulfillments_element_head_DirtyBits, offerFulfillments_element_head_MaxValue, offerFulfillments_element_length_DirtyBits, offerFulfillments_element_length_MaxValue, considerationFulfillments_head_DirtyBits, considerationFulfillments_head_MaxValue, considerationFulfillments_length_DirtyBits, considerationFulfillments_length_MaxValue, considerationFulfillments_element_head_DirtyBits, considerationFulfillments_element_head_MaxValue, considerationFulfillments_element_length_DirtyBits, considerationFulfillments_element_length_MaxValue }

  enum ScuffableField { advancedOrders_head, advancedOrders, criteriaResolvers_head, criteriaResolvers, offerFulfillments_head, offerFulfillments, considerationFulfillments_head, considerationFulfillments }

  bytes4 internal constant FunctionSelector = 0x87201b41;
  string internal constant FunctionName = "fulfillAvailableAdvancedOrders";
  uint256 internal constant criteriaResolversOffset = 0x20;
  uint256 internal constant offerFulfillmentsOffset = 0x40;
  uint256 internal constant considerationFulfillmentsOffset = 0x60;
  uint256 internal constant fulfillerConduitKeyOffset = 0x80;
  uint256 internal constant recipientOffset = 0xa0;
  uint256 internal constant maximumFulfilledOffset = 0xc0;
  uint256 internal constant HeadSize = 0xe0;
  uint256 internal constant MinimumAdvancedOrdersScuffKind = uint256(ScuffKind.advancedOrders_length_DirtyBits);
  uint256 internal constant MaximumAdvancedOrdersScuffKind = uint256(ScuffKind.advancedOrders_element_extraData_DirtyLowerBits);
  uint256 internal constant MinimumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_length_DirtyBits);
  uint256 internal constant MaximumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_element_criteriaProof_length_MaxValue);
  uint256 internal constant MinimumOfferFulfillmentsScuffKind = uint256(ScuffKind.offerFulfillments_length_DirtyBits);
  uint256 internal constant MaximumOfferFulfillmentsScuffKind = uint256(ScuffKind.offerFulfillments_element_length_MaxValue);
  uint256 internal constant MinimumConsiderationFulfillmentsScuffKind = uint256(ScuffKind.considerationFulfillments_length_DirtyBits);
  uint256 internal constant MaximumConsiderationFulfillmentsScuffKind = uint256(ScuffKind.considerationFulfillments_element_length_MaxValue);

  /// @dev Convert a `MemoryPointer` to a `FulfillAvailableAdvancedOrdersPointer`.
  /// This adds `FulfillAvailableAdvancedOrdersPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (FulfillAvailableAdvancedOrdersPointer) {
    return FulfillAvailableAdvancedOrdersPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `FulfillAvailableAdvancedOrdersPointer` back into a `MemoryPointer`.
  function unwrap(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(FulfillAvailableAdvancedOrdersPointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `fulfillAvailableAdvancedOrders`to a `FulfillAvailableAdvancedOrdersPointer`.
  /// This adds `FulfillAvailableAdvancedOrdersPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (FulfillAvailableAdvancedOrdersPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function calldata
  function encodeFunctionCall(AdvancedOrder[] memory _advancedOrders, CriteriaResolver[] memory _criteriaResolvers, FulfillmentComponent[][] memory _offerFulfillments, FulfillmentComponent[][] memory _considerationFulfillments, bytes32 _fulfillerConduitKey, address _recipient, uint256 _maximumFulfilled) internal pure returns (bytes memory) {
    return abi.encodeWithSignature("fulfillAvailableAdvancedOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes)[],(uint256,uint8,uint256,uint256,bytes32[])[],(uint256,uint256)[][],(uint256,uint256)[][],bytes32,address,uint256)", _advancedOrders, _criteriaResolvers, _offerFulfillments, _considerationFulfillments, _fulfillerConduitKey, _recipient, _maximumFulfilled);
  }

  /// @dev Encode function call from arguments
  function fromArgs(AdvancedOrder[] memory _advancedOrders, CriteriaResolver[] memory _criteriaResolvers, FulfillmentComponent[][] memory _offerFulfillments, FulfillmentComponent[][] memory _considerationFulfillments, bytes32 _fulfillerConduitKey, address _recipient, uint256 _maximumFulfilled) internal pure returns (FulfillAvailableAdvancedOrdersPointer ptrOut) {
    bytes memory data = encodeFunctionCall(_advancedOrders, _criteriaResolvers, _offerFulfillments, _considerationFulfillments, _fulfillerConduitKey, _recipient, _maximumFulfilled);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `advancedOrders` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function advancedOrdersHead(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `DynArrayAdvancedOrderPointer` pointing to the data buffer of `advancedOrders`
  function advancedOrdersData(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (DynArrayAdvancedOrderPointer) {
    return DynArrayAdvancedOrderPointerLibrary.wrap(ptr.unwrap().offset(advancedOrdersHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `criteriaResolvers` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function criteriaResolversHead(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(criteriaResolversOffset);
  }

  /// @dev Resolve the `DynArrayCriteriaResolverPointer` pointing to the data buffer of `criteriaResolvers`
  function criteriaResolversData(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (DynArrayCriteriaResolverPointer) {
    return DynArrayCriteriaResolverPointerLibrary.wrap(ptr.unwrap().offset(criteriaResolversHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `offerFulfillments` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function offerFulfillmentsHead(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(offerFulfillmentsOffset);
  }

  /// @dev Resolve the `DynArrayDynArrayFulfillmentComponentPointer` pointing to the data buffer of `offerFulfillments`
  function offerFulfillmentsData(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (DynArrayDynArrayFulfillmentComponentPointer) {
    return DynArrayDynArrayFulfillmentComponentPointerLibrary.wrap(ptr.unwrap().offset(offerFulfillmentsHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `considerationFulfillments` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function considerationFulfillmentsHead(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(considerationFulfillmentsOffset);
  }

  /// @dev Resolve the `DynArrayDynArrayFulfillmentComponentPointer` pointing to the data buffer of `considerationFulfillments`
  function considerationFulfillmentsData(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (DynArrayDynArrayFulfillmentComponentPointer) {
    return DynArrayDynArrayFulfillmentComponentPointerLibrary.wrap(ptr.unwrap().offset(considerationFulfillmentsHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `fulfillerConduitKey` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function fulfillerConduitKey(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(fulfillerConduitKeyOffset);
  }

  /// @dev Resolve the pointer to the head of `recipient` in memory.
  /// This points to the beginning of the encoded `address`
  function recipient(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(recipientOffset);
  }

  /// @dev Resolve the pointer to the head of `maximumFulfilled` in memory.
  /// This points to the beginning of the encoded `uint256`
  function maximumFulfilled(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(maximumFulfilledOffset);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(FulfillAvailableAdvancedOrdersPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Add dirty upper bits to advancedOrders head
    directives.push(Scuff.upper(uint256(ScuffKind.advancedOrders_head_DirtyBits) + kindOffset, 224, ptr.advancedOrdersHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.advancedOrders_head_MaxValue) + kindOffset, 229, ptr.advancedOrdersHead(), positions));
    /// @dev Add all nested directives in advancedOrders
    ptr.advancedOrdersData().addScuffDirectives(directives, kindOffset + MinimumAdvancedOrdersScuffKind, positions);
    /// @dev Add dirty upper bits to criteriaResolvers head
    directives.push(Scuff.upper(uint256(ScuffKind.criteriaResolvers_head_DirtyBits) + kindOffset, 224, ptr.criteriaResolversHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.criteriaResolvers_head_MaxValue) + kindOffset, 229, ptr.criteriaResolversHead(), positions));
    /// @dev Add all nested directives in criteriaResolvers
    ptr.criteriaResolversData().addScuffDirectives(directives, kindOffset + MinimumCriteriaResolversScuffKind, positions);
    /// @dev Add dirty upper bits to offerFulfillments head
    directives.push(Scuff.upper(uint256(ScuffKind.offerFulfillments_head_DirtyBits) + kindOffset, 224, ptr.offerFulfillmentsHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.offerFulfillments_head_MaxValue) + kindOffset, 229, ptr.offerFulfillmentsHead(), positions));
    /// @dev Add all nested directives in offerFulfillments
    ptr.offerFulfillmentsData().addScuffDirectives(directives, kindOffset + MinimumOfferFulfillmentsScuffKind, positions);
    /// @dev Add dirty upper bits to considerationFulfillments head
    directives.push(Scuff.upper(uint256(ScuffKind.considerationFulfillments_head_DirtyBits) + kindOffset, 224, ptr.considerationFulfillmentsHead(), positions));
    /// @dev Set every bit in length to 1
    directives.push(Scuff.lower(uint256(ScuffKind.considerationFulfillments_head_MaxValue) + kindOffset, 229, ptr.considerationFulfillmentsHead(), positions));
    /// @dev Add all nested directives in considerationFulfillments
    ptr.considerationFulfillmentsData().addScuffDirectives(directives, kindOffset + MinimumConsiderationFulfillmentsScuffKind, positions);
  }

  function getScuffDirectives(FulfillAvailableAdvancedOrdersPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function getScuffDirectivesForCalldata(bytes memory data) internal pure returns (ScuffDirective[] memory) {
    return getScuffDirectives(fromBytes(data));
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.advancedOrders_head_DirtyBits) return "advancedOrders_head_DirtyBits";
    if (k == ScuffKind.advancedOrders_head_MaxValue) return "advancedOrders_head_MaxValue";
    if (k == ScuffKind.advancedOrders_length_DirtyBits) return "advancedOrders_length_DirtyBits";
    if (k == ScuffKind.advancedOrders_length_MaxValue) return "advancedOrders_length_MaxValue";
    if (k == ScuffKind.advancedOrders_element_head_DirtyBits) return "advancedOrders_element_head_DirtyBits";
    if (k == ScuffKind.advancedOrders_element_head_MaxValue) return "advancedOrders_element_head_MaxValue";
    if (k == ScuffKind.advancedOrders_element_parameters_head_DirtyBits) return "advancedOrders_element_parameters_head_DirtyBits";
    if (k == ScuffKind.advancedOrders_element_parameters_head_MaxValue) return "advancedOrders_element_parameters_head_MaxValue";
    if (k == ScuffKind.advancedOrders_element_parameters_offer_head_DirtyBits) return "advancedOrders_element_parameters_offer_head_DirtyBits";
    if (k == ScuffKind.advancedOrders_element_parameters_offer_head_MaxValue) return "advancedOrders_element_parameters_offer_head_MaxValue";
    if (k == ScuffKind.advancedOrders_element_parameters_offer_length_DirtyBits) return "advancedOrders_element_parameters_offer_length_DirtyBits";
    if (k == ScuffKind.advancedOrders_element_parameters_offer_length_MaxValue) return "advancedOrders_element_parameters_offer_length_MaxValue";
    if (k == ScuffKind.advancedOrders_element_parameters_offer_element_itemType_MaxValue) return "advancedOrders_element_parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.advancedOrders_element_parameters_consideration_head_DirtyBits) return "advancedOrders_element_parameters_consideration_head_DirtyBits";
    if (k == ScuffKind.advancedOrders_element_parameters_consideration_head_MaxValue) return "advancedOrders_element_parameters_consideration_head_MaxValue";
    if (k == ScuffKind.advancedOrders_element_parameters_consideration_length_DirtyBits) return "advancedOrders_element_parameters_consideration_length_DirtyBits";
    if (k == ScuffKind.advancedOrders_element_parameters_consideration_length_MaxValue) return "advancedOrders_element_parameters_consideration_length_MaxValue";
    if (k == ScuffKind.advancedOrders_element_parameters_consideration_element_itemType_MaxValue) return "advancedOrders_element_parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.advancedOrders_element_parameters_orderType_MaxValue) return "advancedOrders_element_parameters_orderType_MaxValue";
    if (k == ScuffKind.advancedOrders_element_signature_head_DirtyBits) return "advancedOrders_element_signature_head_DirtyBits";
    if (k == ScuffKind.advancedOrders_element_signature_head_MaxValue) return "advancedOrders_element_signature_head_MaxValue";
    if (k == ScuffKind.advancedOrders_element_signature_length_DirtyBits) return "advancedOrders_element_signature_length_DirtyBits";
    if (k == ScuffKind.advancedOrders_element_signature_length_MaxValue) return "advancedOrders_element_signature_length_MaxValue";
    if (k == ScuffKind.advancedOrders_element_signature_DirtyLowerBits) return "advancedOrders_element_signature_DirtyLowerBits";
    if (k == ScuffKind.advancedOrders_element_extraData_head_DirtyBits) return "advancedOrders_element_extraData_head_DirtyBits";
    if (k == ScuffKind.advancedOrders_element_extraData_head_MaxValue) return "advancedOrders_element_extraData_head_MaxValue";
    if (k == ScuffKind.advancedOrders_element_extraData_length_DirtyBits) return "advancedOrders_element_extraData_length_DirtyBits";
    if (k == ScuffKind.advancedOrders_element_extraData_length_MaxValue) return "advancedOrders_element_extraData_length_MaxValue";
    if (k == ScuffKind.advancedOrders_element_extraData_DirtyLowerBits) return "advancedOrders_element_extraData_DirtyLowerBits";
    if (k == ScuffKind.criteriaResolvers_head_DirtyBits) return "criteriaResolvers_head_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_head_MaxValue) return "criteriaResolvers_head_MaxValue";
    if (k == ScuffKind.criteriaResolvers_length_DirtyBits) return "criteriaResolvers_length_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_length_MaxValue) return "criteriaResolvers_length_MaxValue";
    if (k == ScuffKind.criteriaResolvers_element_head_DirtyBits) return "criteriaResolvers_element_head_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_element_head_MaxValue) return "criteriaResolvers_element_head_MaxValue";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_head_DirtyBits) return "criteriaResolvers_element_criteriaProof_head_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_head_MaxValue) return "criteriaResolvers_element_criteriaProof_head_MaxValue";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_length_DirtyBits) return "criteriaResolvers_element_criteriaProof_length_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_length_MaxValue) return "criteriaResolvers_element_criteriaProof_length_MaxValue";
    if (k == ScuffKind.offerFulfillments_head_DirtyBits) return "offerFulfillments_head_DirtyBits";
    if (k == ScuffKind.offerFulfillments_head_MaxValue) return "offerFulfillments_head_MaxValue";
    if (k == ScuffKind.offerFulfillments_length_DirtyBits) return "offerFulfillments_length_DirtyBits";
    if (k == ScuffKind.offerFulfillments_length_MaxValue) return "offerFulfillments_length_MaxValue";
    if (k == ScuffKind.offerFulfillments_element_head_DirtyBits) return "offerFulfillments_element_head_DirtyBits";
    if (k == ScuffKind.offerFulfillments_element_head_MaxValue) return "offerFulfillments_element_head_MaxValue";
    if (k == ScuffKind.offerFulfillments_element_length_DirtyBits) return "offerFulfillments_element_length_DirtyBits";
    if (k == ScuffKind.offerFulfillments_element_length_MaxValue) return "offerFulfillments_element_length_MaxValue";
    if (k == ScuffKind.considerationFulfillments_head_DirtyBits) return "considerationFulfillments_head_DirtyBits";
    if (k == ScuffKind.considerationFulfillments_head_MaxValue) return "considerationFulfillments_head_MaxValue";
    if (k == ScuffKind.considerationFulfillments_length_DirtyBits) return "considerationFulfillments_length_DirtyBits";
    if (k == ScuffKind.considerationFulfillments_length_MaxValue) return "considerationFulfillments_length_MaxValue";
    if (k == ScuffKind.considerationFulfillments_element_head_DirtyBits) return "considerationFulfillments_element_head_DirtyBits";
    if (k == ScuffKind.considerationFulfillments_element_head_MaxValue) return "considerationFulfillments_element_head_MaxValue";
    if (k == ScuffKind.considerationFulfillments_element_length_DirtyBits) return "considerationFulfillments_element_length_DirtyBits";
    return "considerationFulfillments_element_length_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}