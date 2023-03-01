// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "../helpers/PointerLibraries.sol";
import "../lib/ConsiderationDecoder.sol";
import "../lib/ConsiderationStructs.sol";

// interface ITestDecoder {
//   function decodeBytes(bytes calldata) external pure returns (bytes memory);

// }

contract TestDecoder is ConsiderationDecoder {
    function decodeBytes(bytes calldata) external pure returns (bytes memory) {
        bytes memory data = _toBytesReturnType(_decodeBytes)(
            CalldataStart.pptr()
        );
        return data;
    }

    function decodeOffer(OfferItem[] calldata)
        external
        pure
        returns (OfferItem[] memory)
    {
        OfferItem[] memory data = _toOfferReturnType(_decodeOffer)(
            CalldataStart.pptr()
        );
        return data;
    }

    function decodeConsideration(ConsiderationItem[] calldata)
        external
        pure
        returns (ConsiderationItem[] memory)
    {
        ConsiderationItem[] memory data = _toConsiderationReturnType(
            _decodeConsideration
        )(CalldataStart.pptr());
        return data;
    }

    function decodeOrderParameters(OrderParameters calldata)
        external
        pure
        returns (OrderParameters memory)
    {
        OrderParameters memory data = _toOrderParametersReturnType(
            _decodeOrderParameters
        )(CalldataStart.pptr());
        return data;
    }

    function decodeOrder(Order calldata) external pure returns (Order memory) {
        Order memory data = _toOrderReturnType(_decodeOrder)(
            CalldataStart.pptr()
        );
        return data;
    }

    function decodeAdvancedOrder(AdvancedOrder calldata)
        external
        pure
        returns (AdvancedOrder memory)
    {
        AdvancedOrder memory data = _toAdvancedOrderReturnType(
            _decodeAdvancedOrder
        )(CalldataStart.pptr());
        return data;
    }

    function decodeOrderAsAdvancedOrder(Order calldata)
        external
        pure
        returns (AdvancedOrder memory)
    {
        AdvancedOrder memory data = _toAdvancedOrderReturnType(
            _decodeOrderAsAdvancedOrder
        )(CalldataStart.pptr());
        return data;
    }

    function decodeOrdersAsAdvancedOrders(Order[] calldata)
        external
        pure
        returns (AdvancedOrder[] memory)
    {
        AdvancedOrder[] memory data = _toAdvancedOrdersReturnType(
            _decodeOrdersAsAdvancedOrders
        )(CalldataStart.pptr());
        return data;
    }

    function decodeCriteriaResolver(CriteriaResolver calldata)
        external
        pure
        returns (CriteriaResolver memory)
    {
        CriteriaResolver memory data = _toCriteriaResolverReturnType(
            _decodeCriteriaResolver
        )(CalldataStart.pptr());
        return data;
    }

    function decodeCriteriaResolvers(CriteriaResolver[] calldata)
        external
        pure
        returns (CriteriaResolver[] memory)
    {
        CriteriaResolver[] memory data = _toCriteriaResolversReturnType(
            _decodeCriteriaResolvers
        )(CalldataStart.pptr());
        return data;
    }

    function decodeOrders(Order[] calldata)
        external
        pure
        returns (Order[] memory)
    {
        Order[] memory data = _toOrdersReturnType(_decodeOrders)(
            CalldataStart.pptr()
        );
        return data;
    }

    function decodeFulfillmentComponents(FulfillmentComponent[] calldata)
        external
        pure
        returns (FulfillmentComponent[] memory)
    {
        FulfillmentComponent[] memory data = _toFulfillmentComponentsReturnType(
            _decodeFulfillmentComponents
        )(CalldataStart.pptr());
        return data;
    }

    function decodeNestedFulfillmentComponents(
        FulfillmentComponent[][] calldata
    ) external pure returns (FulfillmentComponent[][] memory) {
        FulfillmentComponent[][]
            memory data = _toNestedFulfillmentComponentsReturnType(
                _decodeNestedFulfillmentComponents
            )(CalldataStart.pptr());
        return data;
    }

    function decodeAdvancedOrders(AdvancedOrder[] calldata)
        external
        pure
        returns (AdvancedOrder[] memory)
    {
        AdvancedOrder[] memory data = _toAdvancedOrdersReturnType(
            _decodeAdvancedOrders
        )(CalldataStart.pptr());
        return data;
    }

    function decodeFulfillment(Fulfillment calldata)
        external
        pure
        returns (Fulfillment memory)
    {
        Fulfillment memory data = _toFulfillmentReturnType(_decodeFulfillment)(
            CalldataStart.pptr()
        );
        return data;
    }

    function decodeFulfillments(Fulfillment[] calldata)
        external
        pure
        returns (Fulfillment[] memory)
    {
        Fulfillment[] memory data = _toFulfillmentsReturnType(
            _decodeFulfillments
        )(CalldataStart.pptr());
        return data;
    }

    function decodeOrderComponentsAsOrderParameters(OrderComponents calldata)
        external
        pure
        returns (OrderParameters memory)
    {
        OrderParameters memory data = _toOrderParametersReturnType(
            _decodeOrderComponentsAsOrderParameters
        )(CalldataStart.pptr());
        return data;
    }

    function _toBytesReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer) internal pure returns (bytes memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    function _toOfferReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (OfferItem[] memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    function _toConsiderationReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (ConsiderationItem[] memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    function _toOrderReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer) internal pure returns (Order memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    function _toFulfillmentComponentsReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (FulfillmentComponent[] memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    function _toFulfillmentReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (Fulfillment memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }

    function _toCriteriaResolverReturnType(
        function(CalldataPointer) internal pure returns (MemoryPointer) inFn
    )
        internal
        pure
        returns (
            function(CalldataPointer)
                internal
                pure
                returns (CriteriaResolver memory) outFn
        )
    {
        assembly {
            outFn := inFn
        }
    }
}