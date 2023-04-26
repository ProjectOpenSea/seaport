pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayCriteriaResolverPointerLibrary.sol";
import "./AdvancedOrderPointerLibrary.sol";
import {
    AdvancedOrder,
    CriteriaResolver
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type FulfillAdvancedOrderPointer is uint256;

using Scuff for MemoryPointer;
using FulfillAdvancedOrderPointerLibrary for FulfillAdvancedOrderPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillAdvancedOrder(AdvancedOrder,CriteriaResolver[],bytes32,address)
library FulfillAdvancedOrderPointerLibrary {
    enum ScuffKind {
        advancedOrder_head_DirtyBits,
        advancedOrder_head_MaxValue,
        advancedOrder_parameters_head_DirtyBits,
        advancedOrder_parameters_head_MaxValue,
        advancedOrder_parameters_offer_head_DirtyBits,
        advancedOrder_parameters_offer_head_MaxValue,
        advancedOrder_parameters_offer_length_DirtyBits,
        advancedOrder_parameters_offer_length_MaxValue,
        advancedOrder_parameters_offer_element_itemType_MaxValue,
        advancedOrder_parameters_consideration_head_DirtyBits,
        advancedOrder_parameters_consideration_head_MaxValue,
        advancedOrder_parameters_consideration_length_DirtyBits,
        advancedOrder_parameters_consideration_length_MaxValue,
        advancedOrder_parameters_consideration_element_itemType_MaxValue,
        advancedOrder_parameters_consideration_element_recipient_DirtyBits,
        advancedOrder_parameters_orderType_MaxValue,
        advancedOrder_signature_head_DirtyBits,
        advancedOrder_signature_head_MaxValue,
        advancedOrder_signature_length_DirtyBits,
        advancedOrder_signature_length_MaxValue,
        advancedOrder_signature_DirtyLowerBits,
        advancedOrder_extraData_head_DirtyBits,
        advancedOrder_extraData_head_MaxValue,
        advancedOrder_extraData_length_DirtyBits,
        advancedOrder_extraData_length_MaxValue,
        advancedOrder_extraData_DirtyLowerBits,
        criteriaResolvers_head_DirtyBits,
        criteriaResolvers_head_MaxValue,
        criteriaResolvers_length_DirtyBits,
        criteriaResolvers_length_MaxValue,
        criteriaResolvers_element_head_DirtyBits,
        criteriaResolvers_element_head_MaxValue,
        criteriaResolvers_element_side_MaxValue,
        criteriaResolvers_element_criteriaProof_head_DirtyBits,
        criteriaResolvers_element_criteriaProof_head_MaxValue,
        criteriaResolvers_element_criteriaProof_length_DirtyBits,
        criteriaResolvers_element_criteriaProof_length_MaxValue,
        recipient_DirtyBits
    }

    enum ScuffableField {
        advancedOrder_head,
        advancedOrder,
        criteriaResolvers_head,
        criteriaResolvers,
        recipient
    }

    bytes4 internal constant FunctionSelector = 0xe7acab24;
    string internal constant FunctionName = "fulfillAdvancedOrder";
    uint256 internal constant criteriaResolversOffset = 0x20;
    uint256 internal constant fulfillerConduitKeyOffset = 0x40;
    uint256 internal constant recipientOffset = 0x60;
    uint256 internal constant HeadSize = 0x80;
    uint256 internal constant MinimumAdvancedOrderScuffKind =
        uint256(ScuffKind.advancedOrder_parameters_head_DirtyBits);
    uint256 internal constant MaximumAdvancedOrderScuffKind =
        uint256(ScuffKind.advancedOrder_extraData_DirtyLowerBits);
    uint256 internal constant MinimumCriteriaResolversScuffKind =
        uint256(ScuffKind.criteriaResolvers_length_DirtyBits);
    uint256 internal constant MaximumCriteriaResolversScuffKind =
        uint256(
            ScuffKind.criteriaResolvers_element_criteriaProof_length_MaxValue
        );

    /// @dev Convert a `MemoryPointer` to a `FulfillAdvancedOrderPointer`.
    /// This adds `FulfillAdvancedOrderPointerLibrary` functions as members of the pointer
    function wrap(
        MemoryPointer ptr
    ) internal pure returns (FulfillAdvancedOrderPointer) {
        return
            FulfillAdvancedOrderPointer.wrap(
                MemoryPointer.unwrap(ptr.offset(4))
            );
    }

    /// @dev Convert a `FulfillAdvancedOrderPointer` back into a `MemoryPointer`.
    function unwrap(
        FulfillAdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return MemoryPointer.wrap(FulfillAdvancedOrderPointer.unwrap(ptr));
    }

    function isFunction(bytes4 selector) internal pure returns (bool) {
        return FunctionSelector == selector;
    }

    /// @dev Convert a `bytes` with encoded calldata for `fulfillAdvancedOrder`to a `FulfillAdvancedOrderPointer`.
    /// This adds `FulfillAdvancedOrderPointerLibrary` functions as members of the pointer
    function fromBytes(
        bytes memory data
    ) internal pure returns (FulfillAdvancedOrderPointer ptrOut) {
        assembly {
            ptrOut := add(data, 0x24)
        }
    }

    /// @dev Encode function calldata
    function encodeFunctionCall(
        AdvancedOrder memory _advancedOrder,
        CriteriaResolver[] memory _criteriaResolvers,
        bytes32 _fulfillerConduitKey,
        address _recipient
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "fulfillAdvancedOrder(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes),(uint256,uint8,uint256,uint256,bytes32[])[],bytes32,address)",
                _advancedOrder,
                _criteriaResolvers,
                _fulfillerConduitKey,
                _recipient
            );
    }

    /// @dev Encode function call from arguments
    function fromArgs(
        AdvancedOrder memory _advancedOrder,
        CriteriaResolver[] memory _criteriaResolvers,
        bytes32 _fulfillerConduitKey,
        address _recipient
    ) internal pure returns (FulfillAdvancedOrderPointer ptrOut) {
        bytes memory data = encodeFunctionCall(
            _advancedOrder,
            _criteriaResolvers,
            _fulfillerConduitKey,
            _recipient
        );
        ptrOut = fromBytes(data);
    }

    /// @dev Resolve the pointer to the head of `advancedOrder` in memory.
    /// This points to the offset of the item's data relative to `ptr`
    function advancedOrderHead(
        FulfillAdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap();
    }

    /// @dev Resolve the `AdvancedOrderPointer` pointing to the data buffer of `advancedOrder`
    function advancedOrderData(
        FulfillAdvancedOrderPointer ptr
    ) internal pure returns (AdvancedOrderPointer) {
        return
            AdvancedOrderPointerLibrary.wrap(
                ptr.unwrap().offset(advancedOrderHead(ptr).readUint256())
            );
    }

    /// @dev Resolve the pointer to the head of `criteriaResolvers` in memory.
    /// This points to the offset of the item's data relative to `ptr`
    function criteriaResolversHead(
        FulfillAdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(criteriaResolversOffset);
    }

    /// @dev Resolve the `DynArrayCriteriaResolverPointer` pointing to the data buffer of `criteriaResolvers`
    function criteriaResolversData(
        FulfillAdvancedOrderPointer ptr
    ) internal pure returns (DynArrayCriteriaResolverPointer) {
        return
            DynArrayCriteriaResolverPointerLibrary.wrap(
                ptr.unwrap().offset(criteriaResolversHead(ptr).readUint256())
            );
    }

    /// @dev Resolve the pointer to the head of `fulfillerConduitKey` in memory.
    /// This points to the beginning of the encoded `bytes32`
    function fulfillerConduitKey(
        FulfillAdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(fulfillerConduitKeyOffset);
    }

    /// @dev Resolve the pointer to the head of `recipient` in memory.
    /// This points to the beginning of the encoded `address`
    function recipient(
        FulfillAdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(recipientOffset);
    }

    /// @dev Resolve the pointer to the tail segment of the encoded calldata.
    /// This is the beginning of the dynamically encoded data.
    function tail(
        FulfillAdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(HeadSize);
    }

    function addScuffDirectives(
        FulfillAdvancedOrderPointer ptr,
        ScuffDirectivesArray directives,
        uint256 kindOffset,
        ScuffPositions positions
    ) internal pure {
        /// @dev Add dirty upper bits to advancedOrder head
        directives.push(
            Scuff.upper(
                uint256(ScuffKind.advancedOrder_head_DirtyBits) + kindOffset,
                224,
                ptr.advancedOrderHead(),
                positions
            )
        );
        /// @dev Set every bit in length to 1
        directives.push(
            Scuff.lower(
                uint256(ScuffKind.advancedOrder_head_MaxValue) + kindOffset,
                229,
                ptr.advancedOrderHead(),
                positions
            )
        );
        /// @dev Add all nested directives in advancedOrder
        ptr.advancedOrderData().addScuffDirectives(
            directives,
            kindOffset + MinimumAdvancedOrderScuffKind,
            positions
        );
        /// @dev Add dirty upper bits to criteriaResolvers head
        directives.push(
            Scuff.upper(
                uint256(ScuffKind.criteriaResolvers_head_DirtyBits) +
                    kindOffset,
                224,
                ptr.criteriaResolversHead(),
                positions
            )
        );
        /// @dev Set every bit in length to 1
        directives.push(
            Scuff.lower(
                uint256(ScuffKind.criteriaResolvers_head_MaxValue) + kindOffset,
                229,
                ptr.criteriaResolversHead(),
                positions
            )
        );
        /// @dev Add all nested directives in criteriaResolvers
        ptr.criteriaResolversData().addScuffDirectives(
            directives,
            kindOffset + MinimumCriteriaResolversScuffKind,
            positions
        );
        /// @dev Add dirty upper bits to `recipient`
        directives.push(
            Scuff.upper(
                uint256(ScuffKind.recipient_DirtyBits) + kindOffset,
                96,
                ptr.recipient(),
                positions
            )
        );
    }

    function getScuffDirectives(
        FulfillAdvancedOrderPointer ptr
    ) internal pure returns (ScuffDirective[] memory) {
        ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
        ScuffPositions positions = EmptyPositions;
        addScuffDirectives(ptr, directives, 0, positions);
        return directives.finalize();
    }

    function getScuffDirectivesForCalldata(
        bytes memory data
    ) internal pure returns (ScuffDirective[] memory) {
        return getScuffDirectives(fromBytes(data));
    }

    function toString(ScuffKind k) internal pure returns (string memory) {
        if (k == ScuffKind.advancedOrder_head_DirtyBits)
            return "advancedOrder_head_DirtyBits";
        if (k == ScuffKind.advancedOrder_head_MaxValue)
            return "advancedOrder_head_MaxValue";
        if (k == ScuffKind.advancedOrder_parameters_head_DirtyBits)
            return "advancedOrder_parameters_head_DirtyBits";
        if (k == ScuffKind.advancedOrder_parameters_head_MaxValue)
            return "advancedOrder_parameters_head_MaxValue";
        if (k == ScuffKind.advancedOrder_parameters_offer_head_DirtyBits)
            return "advancedOrder_parameters_offer_head_DirtyBits";
        if (k == ScuffKind.advancedOrder_parameters_offer_head_MaxValue)
            return "advancedOrder_parameters_offer_head_MaxValue";
        if (k == ScuffKind.advancedOrder_parameters_offer_length_DirtyBits)
            return "advancedOrder_parameters_offer_length_DirtyBits";
        if (k == ScuffKind.advancedOrder_parameters_offer_length_MaxValue)
            return "advancedOrder_parameters_offer_length_MaxValue";
        if (
            k ==
            ScuffKind.advancedOrder_parameters_offer_element_itemType_MaxValue
        ) return "advancedOrder_parameters_offer_element_itemType_MaxValue";
        if (
            k == ScuffKind.advancedOrder_parameters_consideration_head_DirtyBits
        ) return "advancedOrder_parameters_consideration_head_DirtyBits";
        if (k == ScuffKind.advancedOrder_parameters_consideration_head_MaxValue)
            return "advancedOrder_parameters_consideration_head_MaxValue";
        if (
            k ==
            ScuffKind.advancedOrder_parameters_consideration_length_DirtyBits
        ) return "advancedOrder_parameters_consideration_length_DirtyBits";
        if (
            k ==
            ScuffKind.advancedOrder_parameters_consideration_length_MaxValue
        ) return "advancedOrder_parameters_consideration_length_MaxValue";
        if (
            k ==
            ScuffKind
                .advancedOrder_parameters_consideration_element_itemType_MaxValue
        )
            return
                "advancedOrder_parameters_consideration_element_itemType_MaxValue";
        if (
            k ==
            ScuffKind
                .advancedOrder_parameters_consideration_element_recipient_DirtyBits
        )
            return
                "advancedOrder_parameters_consideration_element_recipient_DirtyBits";
        if (k == ScuffKind.advancedOrder_parameters_orderType_MaxValue)
            return "advancedOrder_parameters_orderType_MaxValue";
        if (k == ScuffKind.advancedOrder_signature_head_DirtyBits)
            return "advancedOrder_signature_head_DirtyBits";
        if (k == ScuffKind.advancedOrder_signature_head_MaxValue)
            return "advancedOrder_signature_head_MaxValue";
        if (k == ScuffKind.advancedOrder_signature_length_DirtyBits)
            return "advancedOrder_signature_length_DirtyBits";
        if (k == ScuffKind.advancedOrder_signature_length_MaxValue)
            return "advancedOrder_signature_length_MaxValue";
        if (k == ScuffKind.advancedOrder_signature_DirtyLowerBits)
            return "advancedOrder_signature_DirtyLowerBits";
        if (k == ScuffKind.advancedOrder_extraData_head_DirtyBits)
            return "advancedOrder_extraData_head_DirtyBits";
        if (k == ScuffKind.advancedOrder_extraData_head_MaxValue)
            return "advancedOrder_extraData_head_MaxValue";
        if (k == ScuffKind.advancedOrder_extraData_length_DirtyBits)
            return "advancedOrder_extraData_length_DirtyBits";
        if (k == ScuffKind.advancedOrder_extraData_length_MaxValue)
            return "advancedOrder_extraData_length_MaxValue";
        if (k == ScuffKind.advancedOrder_extraData_DirtyLowerBits)
            return "advancedOrder_extraData_DirtyLowerBits";
        if (k == ScuffKind.criteriaResolvers_head_DirtyBits)
            return "criteriaResolvers_head_DirtyBits";
        if (k == ScuffKind.criteriaResolvers_head_MaxValue)
            return "criteriaResolvers_head_MaxValue";
        if (k == ScuffKind.criteriaResolvers_length_DirtyBits)
            return "criteriaResolvers_length_DirtyBits";
        if (k == ScuffKind.criteriaResolvers_length_MaxValue)
            return "criteriaResolvers_length_MaxValue";
        if (k == ScuffKind.criteriaResolvers_element_head_DirtyBits)
            return "criteriaResolvers_element_head_DirtyBits";
        if (k == ScuffKind.criteriaResolvers_element_head_MaxValue)
            return "criteriaResolvers_element_head_MaxValue";
        if (k == ScuffKind.criteriaResolvers_element_side_MaxValue)
            return "criteriaResolvers_element_side_MaxValue";
        if (
            k ==
            ScuffKind.criteriaResolvers_element_criteriaProof_head_DirtyBits
        ) return "criteriaResolvers_element_criteriaProof_head_DirtyBits";
        if (
            k == ScuffKind.criteriaResolvers_element_criteriaProof_head_MaxValue
        ) return "criteriaResolvers_element_criteriaProof_head_MaxValue";
        if (
            k ==
            ScuffKind.criteriaResolvers_element_criteriaProof_length_DirtyBits
        ) return "criteriaResolvers_element_criteriaProof_length_DirtyBits";
        if (
            k ==
            ScuffKind.criteriaResolvers_element_criteriaProof_length_MaxValue
        ) return "criteriaResolvers_element_criteriaProof_length_MaxValue";
        return "recipient_DirtyBits";
    }

    function toKind(uint256 k) internal pure returns (ScuffKind) {
        return ScuffKind(k);
    }

    function toKindString(uint256 k) internal pure returns (string memory) {
        return toString(toKind(k));
    }
}
