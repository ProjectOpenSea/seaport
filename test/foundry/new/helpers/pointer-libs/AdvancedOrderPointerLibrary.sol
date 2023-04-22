// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./BytesPointerLibrary.sol";
import "./OrderParametersPointerLibrary.sol";
import "seaport-sol/../PointerLibraries.sol";

type AdvancedOrderPointer is uint256;

using Scuff for MemoryPointer;
using AdvancedOrderPointerLibrary for AdvancedOrderPointer global;

/// @dev Library for resolving pointers of encoded AdvancedOrder
/// struct AdvancedOrder {
///   OrderParameters parameters;
///   uint120 numerator;
///   uint120 denominator;
///   bytes signature;
///   bytes extraData;
/// }
library AdvancedOrderPointerLibrary {
    enum ScuffKind {
        parameters_HeadOverflow,
        parameters_offerer_Overflow,
        parameters_zone_Overflow,
        parameters_offer_HeadOverflow,
        parameters_offer_LengthOverflow,
        parameters_offer_element_itemType_Overflow,
        parameters_offer_element_token_Overflow,
        parameters_consideration_HeadOverflow,
        parameters_consideration_LengthOverflow,
        parameters_consideration_element_itemType_Overflow,
        parameters_consideration_element_token_Overflow,
        parameters_consideration_element_recipient_Overflow,
        parameters_orderType_Overflow,
        numerator_Overflow,
        denominator_Overflow,
        signature_HeadOverflow,
        signature_LengthOverflow,
        signature_DirtyLowerBits,
        extraData_HeadOverflow,
        extraData_LengthOverflow,
        extraData_DirtyLowerBits
    }

    uint256 internal constant numeratorOffset = 0x20;
    uint256 internal constant OverflowedNumerator =
        0x01000000000000000000000000000000;
    uint256 internal constant denominatorOffset = 0x40;
    uint256 internal constant OverflowedDenominator =
        0x01000000000000000000000000000000;
    uint256 internal constant signatureOffset = 0x60;
    uint256 internal constant extraDataOffset = 0x80;
    uint256 internal constant HeadSize = 0xa0;
    uint256 internal constant MinimumParametersScuffKind =
        uint256(ScuffKind.parameters_offerer_Overflow);
    uint256 internal constant MaximumParametersScuffKind =
        uint256(ScuffKind.parameters_orderType_Overflow);
    uint256 internal constant MinimumSignatureScuffKind =
        uint256(ScuffKind.signature_LengthOverflow);
    uint256 internal constant MaximumSignatureScuffKind =
        uint256(ScuffKind.signature_DirtyLowerBits);
    uint256 internal constant MinimumExtraDataScuffKind =
        uint256(ScuffKind.extraData_LengthOverflow);
    uint256 internal constant MaximumExtraDataScuffKind =
        uint256(ScuffKind.extraData_DirtyLowerBits);

    /// @dev Convert a `MemoryPointer` to a `AdvancedOrderPointer`.
    /// This adds `AdvancedOrderPointerLibrary` functions as members of the pointer
    function wrap(
        MemoryPointer ptr
    ) internal pure returns (AdvancedOrderPointer) {
        return AdvancedOrderPointer.wrap(MemoryPointer.unwrap(ptr));
    }

    /// @dev Convert a `AdvancedOrderPointer` back into a `MemoryPointer`.
    function unwrap(
        AdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return MemoryPointer.wrap(AdvancedOrderPointer.unwrap(ptr));
    }

    /// @dev Resolve the pointer to the head of `parameters` in memory.
    /// This points to the offset of the item's data relative to `ptr`
    function parametersHead(
        AdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap();
    }

    /// @dev Resolve the `OrderParametersPointer` pointing to the data buffer of `parameters`
    function parametersData(
        AdvancedOrderPointer ptr
    ) internal pure returns (OrderParametersPointer) {
        return
            OrderParametersPointerLibrary.wrap(
                ptr.unwrap().offset(parametersHead(ptr).readUint256())
            );
    }

    /// @dev Add dirty bits to the head for `parameters` (offset relative to parent).
    function addDirtyBitsToParametersOffset(
        AdvancedOrderPointer ptr
    ) internal pure {
        parametersHead(ptr).addDirtyBitsBefore(224);
    }

    /// @dev Resolve the pointer to the head of `numerator` in memory.
    /// This points to the beginning of the encoded `uint120`
    function numerator(
        AdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(numeratorOffset);
    }

    /// @dev Cause `numerator` to overflow
    function overflowNumerator(AdvancedOrderPointer ptr) internal pure {
        numerator(ptr).write(OverflowedNumerator);
    }

    /// @dev Resolve the pointer to the head of `denominator` in memory.
    /// This points to the beginning of the encoded `uint120`
    function denominator(
        AdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(denominatorOffset);
    }

    /// @dev Cause `denominator` to overflow
    function overflowDenominator(AdvancedOrderPointer ptr) internal pure {
        denominator(ptr).write(OverflowedDenominator);
    }

    /// @dev Resolve the pointer to the head of `signature` in memory.
    /// This points to the offset of the item's data relative to `ptr`
    function signatureHead(
        AdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(signatureOffset);
    }

    /// @dev Resolve the `BytesPointer` pointing to the data buffer of `signature`
    function signatureData(
        AdvancedOrderPointer ptr
    ) internal pure returns (BytesPointer) {
        return
            BytesPointerLibrary.wrap(
                ptr.unwrap().offset(signatureHead(ptr).readUint256())
            );
    }

    /// @dev Add dirty bits to the head for `signature` (offset relative to parent).
    function addDirtyBitsToSignatureOffset(
        AdvancedOrderPointer ptr
    ) internal pure {
        signatureHead(ptr).addDirtyBitsBefore(224);
    }

    /// @dev Resolve the pointer to the head of `extraData` in memory.
    /// This points to the offset of the item's data relative to `ptr`
    function extraDataHead(
        AdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(extraDataOffset);
    }

    /// @dev Resolve the `BytesPointer` pointing to the data buffer of `extraData`
    function extraDataData(
        AdvancedOrderPointer ptr
    ) internal pure returns (BytesPointer) {
        return
            BytesPointerLibrary.wrap(
                ptr.unwrap().offset(extraDataHead(ptr).readUint256())
            );
    }

    /// @dev Add dirty bits to the head for `extraData` (offset relative to parent).
    function addDirtyBitsToExtraDataOffset(
        AdvancedOrderPointer ptr
    ) internal pure {
        extraDataHead(ptr).addDirtyBitsBefore(224);
    }

    /// @dev Resolve the pointer to the tail segment of the struct.
    /// This is the beginning of the dynamically encoded data.
    function tail(
        AdvancedOrderPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(HeadSize);
    }

    function addScuffDirectives(
        AdvancedOrderPointer ptr,
        ScuffDirectivesArray directives,
        uint256 kindOffset
    ) internal pure {
        /// @dev Overflow offset for `parameters`
        directives.push(
            Scuff.lower(
                uint256(ScuffKind.parameters_HeadOverflow) + kindOffset,
                224,
                ptr.parametersHead()
            )
        );
        /// @dev Add all nested directives in parameters
        ptr.parametersData().addScuffDirectives(
            directives,
            kindOffset + MinimumParametersScuffKind
        );
        /// @dev Induce overflow in `numerator`
        directives.push(
            Scuff.upper(
                uint256(ScuffKind.numerator_Overflow) + kindOffset,
                136,
                ptr.numerator()
            )
        );
        /// @dev Induce overflow in `denominator`
        directives.push(
            Scuff.upper(
                uint256(ScuffKind.denominator_Overflow) + kindOffset,
                136,
                ptr.denominator()
            )
        );
        /// @dev Overflow offset for `signature`
        directives.push(
            Scuff.lower(
                uint256(ScuffKind.signature_HeadOverflow) + kindOffset,
                224,
                ptr.signatureHead()
            )
        );
        /// @dev Add all nested directives in signature
        ptr.signatureData().addScuffDirectives(
            directives,
            kindOffset + MinimumSignatureScuffKind
        );
        /// @dev Overflow offset for `extraData`
        directives.push(
            Scuff.lower(
                uint256(ScuffKind.extraData_HeadOverflow) + kindOffset,
                224,
                ptr.extraDataHead()
            )
        );
        /// @dev Add all nested directives in extraData
        ptr.extraDataData().addScuffDirectives(
            directives,
            kindOffset + MinimumExtraDataScuffKind
        );
    }

    function getScuffDirectives(
        AdvancedOrderPointer ptr
    ) internal pure returns (ScuffDirective[] memory) {
        ScuffDirectivesArray directives = Scuff.makeUnallocatedArray();
        addScuffDirectives(ptr, directives, 0);
        return directives.finalize();
    }

    function toString(ScuffKind k) internal pure returns (string memory) {
        if (k == ScuffKind.parameters_HeadOverflow)
            return "parameters_HeadOverflow";
        if (k == ScuffKind.parameters_offerer_Overflow)
            return "parameters_offerer_Overflow";
        if (k == ScuffKind.parameters_zone_Overflow)
            return "parameters_zone_Overflow";
        if (k == ScuffKind.parameters_offer_HeadOverflow)
            return "parameters_offer_HeadOverflow";
        if (k == ScuffKind.parameters_offer_LengthOverflow)
            return "parameters_offer_LengthOverflow";
        if (k == ScuffKind.parameters_offer_element_itemType_Overflow)
            return "parameters_offer_element_itemType_Overflow";
        if (k == ScuffKind.parameters_offer_element_token_Overflow)
            return "parameters_offer_element_token_Overflow";
        if (k == ScuffKind.parameters_consideration_HeadOverflow)
            return "parameters_consideration_HeadOverflow";
        if (k == ScuffKind.parameters_consideration_LengthOverflow)
            return "parameters_consideration_LengthOverflow";
        if (k == ScuffKind.parameters_consideration_element_itemType_Overflow)
            return "parameters_consideration_element_itemType_Overflow";
        if (k == ScuffKind.parameters_consideration_element_token_Overflow)
            return "parameters_consideration_element_token_Overflow";
        if (k == ScuffKind.parameters_consideration_element_recipient_Overflow)
            return "parameters_consideration_element_recipient_Overflow";
        if (k == ScuffKind.parameters_orderType_Overflow)
            return "parameters_orderType_Overflow";
        if (k == ScuffKind.numerator_Overflow) return "numerator_Overflow";
        if (k == ScuffKind.denominator_Overflow) return "denominator_Overflow";
        if (k == ScuffKind.signature_HeadOverflow)
            return "signature_HeadOverflow";
        if (k == ScuffKind.signature_LengthOverflow)
            return "signature_LengthOverflow";
        if (k == ScuffKind.signature_DirtyLowerBits)
            return "signature_DirtyLowerBits";
        if (k == ScuffKind.extraData_HeadOverflow)
            return "extraData_HeadOverflow";
        if (k == ScuffKind.extraData_LengthOverflow)
            return "extraData_LengthOverflow";
        return "extraData_DirtyLowerBits";
    }

    function toKind(uint256 k) internal pure returns (ScuffKind) {
        return ScuffKind(k);
    }
}
