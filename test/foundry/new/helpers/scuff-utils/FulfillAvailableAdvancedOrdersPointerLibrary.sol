pragma solidity ^0.8.17;

import "./ScuffDirectives.sol";
import "./DynArrayDynArrayFulfillmentComponentPointerLibrary.sol";
import "./DynArrayCriteriaResolverPointerLibrary.sol";
import "./DynArrayAdvancedOrderPointerLibrary.sol";
import {
    AdvancedOrder,
    CriteriaResolver,
    FulfillmentComponent
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import "../../../../../contracts/helpers/PointerLibraries.sol";

type FulfillAvailableAdvancedOrdersPointer is uint256;

using Scuff for MemoryPointer;
using FulfillAvailableAdvancedOrdersPointerLibrary for FulfillAvailableAdvancedOrdersPointer global;

/// @dev Library for resolving pointers of encoded calldata for
/// fulfillAvailableAdvancedOrders(AdvancedOrder[],CriteriaResolver[],FulfillmentComponent[][],FulfillmentComponent[][],bytes32,address,uint256)
library FulfillAvailableAdvancedOrdersPointerLibrary {
    enum ScuffKind {
        advancedOrders_element_parameters_offerer_DirtyBits,
        advancedOrders_element_parameters_zone_DirtyBits,
        advancedOrders_element_parameters_offer_element_itemType_DirtyBits,
        advancedOrders_element_parameters_offer_element_itemType_MaxValue,
        advancedOrders_element_parameters_offer_element_token_DirtyBits,
        advancedOrders_element_parameters_consideration_element_itemType_DirtyBits,
        advancedOrders_element_parameters_consideration_element_itemType_MaxValue,
        advancedOrders_element_parameters_consideration_element_token_DirtyBits,
        advancedOrders_element_parameters_consideration_element_recipient_DirtyBits,
        advancedOrders_element_parameters_orderType_DirtyBits,
        advancedOrders_element_parameters_orderType_MaxValue,
        advancedOrders_element_numerator_DirtyBits,
        advancedOrders_element_denominator_DirtyBits,
        criteriaResolvers_element_side_DirtyBits,
        criteriaResolvers_element_side_MaxValue,
        recipient_DirtyBits
    }

    enum ScuffableField {
        advancedOrders,
        criteriaResolvers,
        recipient
    }

    bytes4 internal constant FunctionSelector = 0x87201b41;
    string internal constant FunctionName = "fulfillAvailableAdvancedOrders";
    uint256 internal constant criteriaResolversOffset = 0x20;
    uint256 internal constant offerFulfillmentsOffset = 0x40;
    uint256 internal constant considerationFulfillmentsOffset = 0x60;
    uint256 internal constant fulfillerConduitKeyOffset = 0x80;
    uint256 internal constant recipientOffset = 0xa0;
    uint256 internal constant maximumFulfilledOffset = 0xc0;
    uint256 internal constant HeadSize = 0xe0;
    uint256 internal constant MinimumAdvancedOrdersScuffKind =
        uint256(ScuffKind.advancedOrders_element_parameters_offerer_DirtyBits);
    uint256 internal constant MaximumAdvancedOrdersScuffKind =
        uint256(ScuffKind.advancedOrders_element_denominator_DirtyBits);
    uint256 internal constant MinimumCriteriaResolversScuffKind =
        uint256(ScuffKind.criteriaResolvers_element_side_DirtyBits);
    uint256 internal constant MaximumCriteriaResolversScuffKind =
        uint256(ScuffKind.criteriaResolvers_element_side_MaxValue);

    /// @dev Convert a `MemoryPointer` to a `FulfillAvailableAdvancedOrdersPointer`.
    /// This adds `FulfillAvailableAdvancedOrdersPointerLibrary` functions as members of the pointer
    function wrap(
        MemoryPointer ptr
    ) internal pure returns (FulfillAvailableAdvancedOrdersPointer) {
        return
            FulfillAvailableAdvancedOrdersPointer.wrap(
                MemoryPointer.unwrap(ptr.offset(4))
            );
    }

    /// @dev Convert a `FulfillAvailableAdvancedOrdersPointer` back into a `MemoryPointer`.
    function unwrap(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (MemoryPointer) {
        return
            MemoryPointer.wrap(
                FulfillAvailableAdvancedOrdersPointer.unwrap(ptr)
            );
    }

    function isFunction(bytes4 selector) internal pure returns (bool) {
        return FunctionSelector == selector;
    }

    /// @dev Convert a `bytes` with encoded calldata for `fulfillAvailableAdvancedOrders`to a `FulfillAvailableAdvancedOrdersPointer`.
    /// This adds `FulfillAvailableAdvancedOrdersPointerLibrary` functions as members of the pointer
    function fromBytes(
        bytes memory data
    ) internal pure returns (FulfillAvailableAdvancedOrdersPointer ptrOut) {
        assembly {
            ptrOut := add(data, 0x24)
        }
    }

    /// @dev Encode function calldata
    function encodeFunctionCall(
        AdvancedOrder[] memory _advancedOrders,
        CriteriaResolver[] memory _criteriaResolvers,
        FulfillmentComponent[][] memory _offerFulfillments,
        FulfillmentComponent[][] memory _considerationFulfillments,
        bytes32 _fulfillerConduitKey,
        address _recipient,
        uint256 _maximumFulfilled
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "fulfillAvailableAdvancedOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes)[],(uint256,uint8,uint256,uint256,bytes32[])[],(uint256,uint256)[][],(uint256,uint256)[][],bytes32,address,uint256)",
                _advancedOrders,
                _criteriaResolvers,
                _offerFulfillments,
                _considerationFulfillments,
                _fulfillerConduitKey,
                _recipient,
                _maximumFulfilled
            );
    }

    /// @dev Encode function call from arguments
    function fromArgs(
        AdvancedOrder[] memory _advancedOrders,
        CriteriaResolver[] memory _criteriaResolvers,
        FulfillmentComponent[][] memory _offerFulfillments,
        FulfillmentComponent[][] memory _considerationFulfillments,
        bytes32 _fulfillerConduitKey,
        address _recipient,
        uint256 _maximumFulfilled
    ) internal pure returns (FulfillAvailableAdvancedOrdersPointer ptrOut) {
        bytes memory data = encodeFunctionCall(
            _advancedOrders,
            _criteriaResolvers,
            _offerFulfillments,
            _considerationFulfillments,
            _fulfillerConduitKey,
            _recipient,
            _maximumFulfilled
        );
        ptrOut = fromBytes(data);
    }

    /// @dev Resolve the pointer to the head of `advancedOrders` in memory.
    /// This points to the offset of the item's data relative to `ptr`
    function advancedOrdersHead(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap();
    }

    /// @dev Resolve the `DynArrayAdvancedOrderPointer` pointing to the data buffer of `advancedOrders`
    function advancedOrdersData(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (DynArrayAdvancedOrderPointer) {
        return
            DynArrayAdvancedOrderPointerLibrary.wrap(
                ptr.unwrap().offset(advancedOrdersHead(ptr).readUint256())
            );
    }

    /// @dev Resolve the pointer to the head of `criteriaResolvers` in memory.
    /// This points to the offset of the item's data relative to `ptr`
    function criteriaResolversHead(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(criteriaResolversOffset);
    }

    /// @dev Resolve the `DynArrayCriteriaResolverPointer` pointing to the data buffer of `criteriaResolvers`
    function criteriaResolversData(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (DynArrayCriteriaResolverPointer) {
        return
            DynArrayCriteriaResolverPointerLibrary.wrap(
                ptr.unwrap().offset(criteriaResolversHead(ptr).readUint256())
            );
    }

    /// @dev Resolve the pointer to the head of `offerFulfillments` in memory.
    /// This points to the offset of the item's data relative to `ptr`
    function offerFulfillmentsHead(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(offerFulfillmentsOffset);
    }

    /// @dev Resolve the `DynArrayDynArrayFulfillmentComponentPointer` pointing to the data buffer of `offerFulfillments`
    function offerFulfillmentsData(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (DynArrayDynArrayFulfillmentComponentPointer) {
        return
            DynArrayDynArrayFulfillmentComponentPointerLibrary.wrap(
                ptr.unwrap().offset(offerFulfillmentsHead(ptr).readUint256())
            );
    }

    /// @dev Resolve the pointer to the head of `considerationFulfillments` in memory.
    /// This points to the offset of the item's data relative to `ptr`
    function considerationFulfillmentsHead(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(considerationFulfillmentsOffset);
    }

    /// @dev Resolve the `DynArrayDynArrayFulfillmentComponentPointer` pointing to the data buffer of `considerationFulfillments`
    function considerationFulfillmentsData(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (DynArrayDynArrayFulfillmentComponentPointer) {
        return
            DynArrayDynArrayFulfillmentComponentPointerLibrary.wrap(
                ptr.unwrap().offset(
                    considerationFulfillmentsHead(ptr).readUint256()
                )
            );
    }

    /// @dev Resolve the pointer to the head of `fulfillerConduitKey` in memory.
    /// This points to the beginning of the encoded `bytes32`
    function fulfillerConduitKey(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(fulfillerConduitKeyOffset);
    }

    /// @dev Resolve the pointer to the head of `recipient` in memory.
    /// This points to the beginning of the encoded `address`
    function recipient(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(recipientOffset);
    }

    /// @dev Resolve the pointer to the head of `maximumFulfilled` in memory.
    /// This points to the beginning of the encoded `uint256`
    function maximumFulfilled(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(maximumFulfilledOffset);
    }

    /// @dev Resolve the pointer to the tail segment of the encoded calldata.
    /// This is the beginning of the dynamically encoded data.
    function tail(
        FulfillAvailableAdvancedOrdersPointer ptr
    ) internal pure returns (MemoryPointer) {
        return ptr.unwrap().offset(HeadSize);
    }

    function addScuffDirectives(
        FulfillAvailableAdvancedOrdersPointer ptr,
        ScuffDirectivesArray directives,
        uint256 kindOffset,
        ScuffPositions positions
    ) internal pure {
        /// @dev Add all nested directives in advancedOrders
        ptr.advancedOrdersData().addScuffDirectives(
            directives,
            kindOffset + MinimumAdvancedOrdersScuffKind,
            positions
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
        FulfillAvailableAdvancedOrdersPointer ptr
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
        if (k == ScuffKind.advancedOrders_element_parameters_offerer_DirtyBits)
            return "advancedOrders_element_parameters_offerer_DirtyBits";
        if (k == ScuffKind.advancedOrders_element_parameters_zone_DirtyBits)
            return "advancedOrders_element_parameters_zone_DirtyBits";
        if (
            k ==
            ScuffKind
                .advancedOrders_element_parameters_offer_element_itemType_DirtyBits
        )
            return
                "advancedOrders_element_parameters_offer_element_itemType_DirtyBits";
        if (
            k ==
            ScuffKind
                .advancedOrders_element_parameters_offer_element_itemType_MaxValue
        )
            return
                "advancedOrders_element_parameters_offer_element_itemType_MaxValue";
        if (
            k ==
            ScuffKind
                .advancedOrders_element_parameters_offer_element_token_DirtyBits
        )
            return
                "advancedOrders_element_parameters_offer_element_token_DirtyBits";
        if (
            k ==
            ScuffKind
                .advancedOrders_element_parameters_consideration_element_itemType_DirtyBits
        )
            return
                "advancedOrders_element_parameters_consideration_element_itemType_DirtyBits";
        if (
            k ==
            ScuffKind
                .advancedOrders_element_parameters_consideration_element_itemType_MaxValue
        )
            return
                "advancedOrders_element_parameters_consideration_element_itemType_MaxValue";
        if (
            k ==
            ScuffKind
                .advancedOrders_element_parameters_consideration_element_token_DirtyBits
        )
            return
                "advancedOrders_element_parameters_consideration_element_token_DirtyBits";
        if (
            k ==
            ScuffKind
                .advancedOrders_element_parameters_consideration_element_recipient_DirtyBits
        )
            return
                "advancedOrders_element_parameters_consideration_element_recipient_DirtyBits";
        if (
            k == ScuffKind.advancedOrders_element_parameters_orderType_DirtyBits
        ) return "advancedOrders_element_parameters_orderType_DirtyBits";
        if (k == ScuffKind.advancedOrders_element_parameters_orderType_MaxValue)
            return "advancedOrders_element_parameters_orderType_MaxValue";
        if (k == ScuffKind.advancedOrders_element_numerator_DirtyBits)
            return "advancedOrders_element_numerator_DirtyBits";
        if (k == ScuffKind.advancedOrders_element_denominator_DirtyBits)
            return "advancedOrders_element_denominator_DirtyBits";
        if (k == ScuffKind.criteriaResolvers_element_side_DirtyBits)
            return "criteriaResolvers_element_side_DirtyBits";
        if (k == ScuffKind.criteriaResolvers_element_side_MaxValue)
            return "criteriaResolvers_element_side_MaxValue";
        return "recipient_DirtyBits";
    }

    function toKind(uint256 k) internal pure returns (ScuffKind) {
        return ScuffKind(k);
    }

    function toKindString(uint256 k) internal pure returns (string memory) {
        return toString(toKind(k));
    }
}
