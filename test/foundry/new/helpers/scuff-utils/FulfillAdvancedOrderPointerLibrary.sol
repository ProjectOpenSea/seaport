pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayCriteriaResolverPointerLibrary.sol";
import "./AdvancedOrderPointerLibrary.sol";
import { AdvancedOrder, CriteriaResolver } from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type FulfillAdvancedOrderPointer is uint256;

using Scuff for MemoryPointer;
using FulfillAdvancedOrderPointerLibrary for FulfillAdvancedOrderPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillAdvancedOrder(AdvancedOrder,CriteriaResolver[],bytes32,address)
library FulfillAdvancedOrderPointerLibrary {
  enum ScuffKind { advancedOrder_HeadOverflow, advancedOrder_parameters_HeadOverflow, advancedOrder_parameters_offerer_DirtyBits, advancedOrder_parameters_offerer_MaxValue, advancedOrder_parameters_zone_DirtyBits, advancedOrder_parameters_zone_MaxValue, advancedOrder_parameters_offer_HeadOverflow, advancedOrder_parameters_offer_length_DirtyBits, advancedOrder_parameters_offer_length_MaxValue, advancedOrder_parameters_offer_element_itemType_DirtyBits, advancedOrder_parameters_offer_element_itemType_MaxValue, advancedOrder_parameters_offer_element_token_DirtyBits, advancedOrder_parameters_offer_element_token_MaxValue, advancedOrder_parameters_consideration_HeadOverflow, advancedOrder_parameters_consideration_length_DirtyBits, advancedOrder_parameters_consideration_length_MaxValue, advancedOrder_parameters_consideration_element_itemType_DirtyBits, advancedOrder_parameters_consideration_element_itemType_MaxValue, advancedOrder_parameters_consideration_element_token_DirtyBits, advancedOrder_parameters_consideration_element_token_MaxValue, advancedOrder_parameters_consideration_element_recipient_DirtyBits, advancedOrder_parameters_consideration_element_recipient_MaxValue, advancedOrder_parameters_orderType_DirtyBits, advancedOrder_parameters_orderType_MaxValue, advancedOrder_numerator_DirtyBits, advancedOrder_numerator_MaxValue, advancedOrder_denominator_DirtyBits, advancedOrder_denominator_MaxValue, advancedOrder_signature_HeadOverflow, advancedOrder_extraData_HeadOverflow, criteriaResolvers_HeadOverflow, criteriaResolvers_length_DirtyBits, criteriaResolvers_length_MaxValue, criteriaResolvers_element_HeadOverflow, criteriaResolvers_element_side_DirtyBits, criteriaResolvers_element_side_MaxValue, criteriaResolvers_element_criteriaProof_HeadOverflow, criteriaResolvers_element_criteriaProof_length_DirtyBits, criteriaResolvers_element_criteriaProof_length_MaxValue, recipient_DirtyBits, recipient_MaxValue }

  enum ScuffableField { advancedOrder, criteriaResolvers, recipient }

  bytes4 internal constant FunctionSelector = 0xe7acab24;
  string internal constant FunctionName = "fulfillAdvancedOrder";
  uint256 internal constant criteriaResolversOffset = 0x20;
  uint256 internal constant fulfillerConduitKeyOffset = 0x40;
  uint256 internal constant recipientOffset = 0x60;
  uint256 internal constant HeadSize = 0x80;
  uint256 internal constant MinimumAdvancedOrderScuffKind = uint256(ScuffKind.advancedOrder_parameters_HeadOverflow);
  uint256 internal constant MaximumAdvancedOrderScuffKind = uint256(ScuffKind.advancedOrder_extraData_HeadOverflow);
  uint256 internal constant MinimumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_length_DirtyBits);
  uint256 internal constant MaximumCriteriaResolversScuffKind = uint256(ScuffKind.criteriaResolvers_element_criteriaProof_length_MaxValue);

  /// @dev Convert a `MemoryPointer` to a `FulfillAdvancedOrderPointer`.
  /// This adds `FulfillAdvancedOrderPointerLibrary` functions as members of the pointer
  function wrap(MemoryPointer ptr) internal pure returns (FulfillAdvancedOrderPointer) {
    return FulfillAdvancedOrderPointer.wrap(MemoryPointer.unwrap(ptr.offset(4)));
  }

  /// @dev Convert a `FulfillAdvancedOrderPointer` back into a `MemoryPointer`.
  function unwrap(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return MemoryPointer.wrap(FulfillAdvancedOrderPointer.unwrap(ptr));
  }

  function isFunction(bytes4 selector) internal pure returns (bool) {
    return FunctionSelector == selector;
  }

  /// @dev Convert a `bytes` with encoded calldata for `fulfillAdvancedOrder`to a `FulfillAdvancedOrderPointer`.
  /// This adds `FulfillAdvancedOrderPointerLibrary` functions as members of the pointer
  function fromBytes(bytes memory data) internal pure returns (FulfillAdvancedOrderPointer ptrOut) {
    assembly {
      ptrOut := add(data, 0x24)
    }
  }

  /// @dev Encode function call from arguments
  function fromArgs(AdvancedOrder memory advancedOrder, CriteriaResolver[] memory criteriaResolvers, bytes32 fulfillerConduitKey, address recipient) internal pure returns (FulfillAdvancedOrderPointer ptrOut) {
    bytes memory data = abi.encodeWithSignature("fulfillAdvancedOrder(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes),(uint256,uint8,uint256,uint256,bytes32[])[],bytes32,address)", advancedOrder, criteriaResolvers, fulfillerConduitKey, recipient);
    ptrOut = fromBytes(data);
  }

  /// @dev Resolve the pointer to the head of `advancedOrder` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function advancedOrderHead(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap();
  }

  /// @dev Resolve the `AdvancedOrderPointer` pointing to the data buffer of `advancedOrder`
  function advancedOrderData(FulfillAdvancedOrderPointer ptr) internal pure returns (AdvancedOrderPointer) {
    return AdvancedOrderPointerLibrary.wrap(ptr.unwrap().offset(advancedOrderHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `criteriaResolvers` in memory.
  /// This points to the offset of the item's data relative to `ptr`
  function criteriaResolversHead(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(criteriaResolversOffset);
  }

  /// @dev Resolve the `DynArrayCriteriaResolverPointer` pointing to the data buffer of `criteriaResolvers`
  function criteriaResolversData(FulfillAdvancedOrderPointer ptr) internal pure returns (DynArrayCriteriaResolverPointer) {
    return DynArrayCriteriaResolverPointerLibrary.wrap(ptr.unwrap().offset(criteriaResolversHead(ptr).readUint256()));
  }

  /// @dev Resolve the pointer to the head of `fulfillerConduitKey` in memory.
  /// This points to the beginning of the encoded `bytes32`
  function fulfillerConduitKey(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(fulfillerConduitKeyOffset);
  }

  /// @dev Resolve the pointer to the head of `recipient` in memory.
  /// This points to the beginning of the encoded `address`
  function recipient(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(recipientOffset);
  }

  /// @dev Resolve the pointer to the tail segment of the encoded calldata.
  /// This is the beginning of the dynamically encoded data.
  function tail(FulfillAdvancedOrderPointer ptr) internal pure returns (MemoryPointer) {
    return ptr.unwrap().offset(HeadSize);
  }

  function addScuffDirectives(FulfillAdvancedOrderPointer ptr, ScuffDirectivesArray directives, uint256 kindOffset, ScuffPositions positions) internal pure {
    /// @dev Overflow offset for `advancedOrder`
    directives.push(Scuff.lower(uint256(ScuffKind.advancedOrder_HeadOverflow) + kindOffset, 224, ptr.advancedOrderHead(), positions));
    /// @dev Add all nested directives in advancedOrder
    ptr.advancedOrderData().addScuffDirectives(directives, kindOffset + MinimumAdvancedOrderScuffKind, positions);
    /// @dev Overflow offset for `criteriaResolvers`
    directives.push(Scuff.lower(uint256(ScuffKind.criteriaResolvers_HeadOverflow) + kindOffset, 224, ptr.criteriaResolversHead(), positions));
    /// @dev Add all nested directives in criteriaResolvers
    ptr.criteriaResolversData().addScuffDirectives(directives, kindOffset + MinimumCriteriaResolversScuffKind, positions);
    /// @dev Add dirty upper bits to `recipient`
    directives.push(Scuff.upper(uint256(ScuffKind.recipient_DirtyBits) + kindOffset, 96, ptr.recipient(), positions));
    /// @dev Set every bit in `recipient` to 1
    directives.push(Scuff.lower(uint256(ScuffKind.recipient_MaxValue) + kindOffset, 96, ptr.recipient(), positions));
  }

  function getScuffDirectives(FulfillAdvancedOrderPointer ptr) internal pure returns (ScuffDirective[] memory) {
    ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
    ScuffPositions positions = EmptyPositions;
    addScuffDirectives(ptr, directives, 0, positions);
    return directives.finalize();
  }

  function getScuffDirectivesForCalldata(bytes memory data) internal pure returns (ScuffDirective[] memory) {
    return getScuffDirectives(fromBytes(data));
  }

  function toString(ScuffKind k) internal pure returns (string memory) {
    if (k == ScuffKind.advancedOrder_HeadOverflow) return "advancedOrder_HeadOverflow";
    if (k == ScuffKind.advancedOrder_parameters_HeadOverflow) return "advancedOrder_parameters_HeadOverflow";
    if (k == ScuffKind.advancedOrder_parameters_offerer_DirtyBits) return "advancedOrder_parameters_offerer_DirtyBits";
    if (k == ScuffKind.advancedOrder_parameters_offerer_MaxValue) return "advancedOrder_parameters_offerer_MaxValue";
    if (k == ScuffKind.advancedOrder_parameters_zone_DirtyBits) return "advancedOrder_parameters_zone_DirtyBits";
    if (k == ScuffKind.advancedOrder_parameters_zone_MaxValue) return "advancedOrder_parameters_zone_MaxValue";
    if (k == ScuffKind.advancedOrder_parameters_offer_HeadOverflow) return "advancedOrder_parameters_offer_HeadOverflow";
    if (k == ScuffKind.advancedOrder_parameters_offer_length_DirtyBits) return "advancedOrder_parameters_offer_length_DirtyBits";
    if (k == ScuffKind.advancedOrder_parameters_offer_length_MaxValue) return "advancedOrder_parameters_offer_length_MaxValue";
    if (k == ScuffKind.advancedOrder_parameters_offer_element_itemType_DirtyBits) return "advancedOrder_parameters_offer_element_itemType_DirtyBits";
    if (k == ScuffKind.advancedOrder_parameters_offer_element_itemType_MaxValue) return "advancedOrder_parameters_offer_element_itemType_MaxValue";
    if (k == ScuffKind.advancedOrder_parameters_offer_element_token_DirtyBits) return "advancedOrder_parameters_offer_element_token_DirtyBits";
    if (k == ScuffKind.advancedOrder_parameters_offer_element_token_MaxValue) return "advancedOrder_parameters_offer_element_token_MaxValue";
    if (k == ScuffKind.advancedOrder_parameters_consideration_HeadOverflow) return "advancedOrder_parameters_consideration_HeadOverflow";
    if (k == ScuffKind.advancedOrder_parameters_consideration_length_DirtyBits) return "advancedOrder_parameters_consideration_length_DirtyBits";
    if (k == ScuffKind.advancedOrder_parameters_consideration_length_MaxValue) return "advancedOrder_parameters_consideration_length_MaxValue";
    if (k == ScuffKind.advancedOrder_parameters_consideration_element_itemType_DirtyBits) return "advancedOrder_parameters_consideration_element_itemType_DirtyBits";
    if (k == ScuffKind.advancedOrder_parameters_consideration_element_itemType_MaxValue) return "advancedOrder_parameters_consideration_element_itemType_MaxValue";
    if (k == ScuffKind.advancedOrder_parameters_consideration_element_token_DirtyBits) return "advancedOrder_parameters_consideration_element_token_DirtyBits";
    if (k == ScuffKind.advancedOrder_parameters_consideration_element_token_MaxValue) return "advancedOrder_parameters_consideration_element_token_MaxValue";
    if (k == ScuffKind.advancedOrder_parameters_consideration_element_recipient_DirtyBits) return "advancedOrder_parameters_consideration_element_recipient_DirtyBits";
    if (k == ScuffKind.advancedOrder_parameters_consideration_element_recipient_MaxValue) return "advancedOrder_parameters_consideration_element_recipient_MaxValue";
    if (k == ScuffKind.advancedOrder_parameters_orderType_DirtyBits) return "advancedOrder_parameters_orderType_DirtyBits";
    if (k == ScuffKind.advancedOrder_parameters_orderType_MaxValue) return "advancedOrder_parameters_orderType_MaxValue";
    if (k == ScuffKind.advancedOrder_numerator_DirtyBits) return "advancedOrder_numerator_DirtyBits";
    if (k == ScuffKind.advancedOrder_numerator_MaxValue) return "advancedOrder_numerator_MaxValue";
    if (k == ScuffKind.advancedOrder_denominator_DirtyBits) return "advancedOrder_denominator_DirtyBits";
    if (k == ScuffKind.advancedOrder_denominator_MaxValue) return "advancedOrder_denominator_MaxValue";
    if (k == ScuffKind.advancedOrder_signature_HeadOverflow) return "advancedOrder_signature_HeadOverflow";
    if (k == ScuffKind.advancedOrder_extraData_HeadOverflow) return "advancedOrder_extraData_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_HeadOverflow) return "criteriaResolvers_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_length_DirtyBits) return "criteriaResolvers_length_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_length_MaxValue) return "criteriaResolvers_length_MaxValue";
    if (k == ScuffKind.criteriaResolvers_element_HeadOverflow) return "criteriaResolvers_element_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_element_side_DirtyBits) return "criteriaResolvers_element_side_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_element_side_MaxValue) return "criteriaResolvers_element_side_MaxValue";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_HeadOverflow) return "criteriaResolvers_element_criteriaProof_HeadOverflow";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_length_DirtyBits) return "criteriaResolvers_element_criteriaProof_length_DirtyBits";
    if (k == ScuffKind.criteriaResolvers_element_criteriaProof_length_MaxValue) return "criteriaResolvers_element_criteriaProof_length_MaxValue";
    if (k == ScuffKind.recipient_DirtyBits) return "recipient_DirtyBits";
    return "recipient_MaxValue";
  }

  function toKind(uint256 k) internal pure returns (ScuffKind) {
    return ScuffKind(k);
  }

  function toKindString(uint256 k) internal pure returns (string memory) {
    return toString(toKind(k));
  }
}