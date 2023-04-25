import { LibPRNG } from "solady/src/utils/LibPRNG.sol";
import "./scuff-utils/Index.sol";

import { FuzzTestContext, MutationState } from "./FuzzTestContextLib.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { dumpScuff } from "./DebugUtil.sol";
import { FuzzHelpers } from "./FuzzHelpers.sol";
import {
    Fulfillment,
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    Execution,
    FulfillmentComponent,
    OfferItem,
    OrderComponents,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-sol/SeaportStructs.sol";

import {
    AdvancedOrderLib,
    OrderParametersLib,
    ConsiderationItemLib,
    ItemType,
    ConsiderationItemLib
} from "seaport-sol/SeaportSol.sol";
import { vm } from "./VmUtils.sol";
import { bound } from "./FuzzGenerators.sol";

contract Scuffuzz {
    using LibPRNG for LibPRNG.PRNG;
    using FuzzEngineLib for FuzzTestContext;
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using FuzzHelpers for AdvancedOrder;
    using OrderParametersLib for OrderParameters;
    using ConsiderationItemLib for ConsiderationItem;

    function getActionCalldata(
        FuzzTestContext memory context
    ) internal view returns (bytes memory data) {
        bytes4 _action = context.action();
        if (_action == context.seaport.fulfillOrder.selector) {
            AdvancedOrder memory order = context.executionState.orders[0];

            data = abi.encodeWithSelector(
                context.seaport.fulfillOrder.selector,
                order.toOrder(),
                context.executionState.fulfillerConduitKey
            );
        } else if (_action == context.seaport.fulfillAdvancedOrder.selector) {
            AdvancedOrder memory order = context.executionState.orders[0];

            data = abi.encodeWithSelector(
                context.seaport.fulfillAdvancedOrder.selector,
                order,
                context.executionState.criteriaResolvers,
                context.executionState.fulfillerConduitKey,
                context.executionState.recipient
            );
        } else if (_action == context.seaport.fulfillBasicOrder.selector) {
            BasicOrderParameters memory basicOrderParameters = context
                .executionState
                .orders[0]
                .toBasicOrderParameters(
                    context.executionState.orders[0].getBasicOrderType()
                );

            basicOrderParameters.fulfillerConduitKey = context
                .executionState
                .fulfillerConduitKey;

            data = abi.encodeWithSelector(
                context.seaport.fulfillBasicOrder.selector,
                basicOrderParameters
            );
        } else if (
            _action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            BasicOrderParameters memory basicOrderParameters = context
                .executionState
                .orders[0]
                .toBasicOrderParameters(
                    context.executionState.orders[0].getBasicOrderType()
                );

            basicOrderParameters.fulfillerConduitKey = context
                .executionState
                .fulfillerConduitKey;

            data = abi.encodeWithSelector(
                context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector,
                basicOrderParameters
            );
        } else if (_action == context.seaport.fulfillAvailableOrders.selector) {
            data = abi.encodeWithSelector(
                context.seaport.fulfillAvailableOrders.selector,
                context.executionState.orders.toOrders(),
                context.executionState.offerFulfillments,
                context.executionState.considerationFulfillments,
                context.executionState.fulfillerConduitKey,
                context.executionState.maximumFulfilled
            );
        } else if (
            _action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            data = abi.encodeWithSelector(
                context.seaport.fulfillAvailableAdvancedOrders.selector,
                context.executionState.orders,
                context.executionState.criteriaResolvers,
                context.executionState.offerFulfillments,
                context.executionState.considerationFulfillments,
                context.executionState.fulfillerConduitKey,
                context.executionState.recipient,
                context.executionState.maximumFulfilled
            );
        } else if (_action == context.seaport.matchOrders.selector) {
            data = abi.encodeWithSelector(
                context.seaport.matchOrders.selector,
                context.executionState.orders.toOrders(),
                context.executionState.fulfillments
            );
        } else if (_action == context.seaport.matchAdvancedOrders.selector) {
            data = abi.encodeWithSelector(
                context.seaport.matchAdvancedOrders.selector,
                context.executionState.orders,
                context.executionState.criteriaResolvers,
                context.executionState.fulfillments,
                context.executionState.recipient
            );
        } else if (_action == context.seaport.cancel.selector) {
            AdvancedOrder[] memory orders = context.executionState.orders;
            OrderComponents[] memory orderComponents = new OrderComponents[](
                orders.length
            );

            for (uint256 i; i < orders.length; ++i) {
                AdvancedOrder memory order = orders[i];
                orderComponents[i] = order
                    .toOrder()
                    .parameters
                    .toOrderComponents(context.executionState.counter);
            }
            data = abi.encodeWithSelector(
                context.seaport.cancel.selector,
                orderComponents
            );
        } else if (_action == context.seaport.validate.selector) {
            data = abi.encodeWithSelector(
                context.seaport.validate.selector,
                context.executionState.orders.toOrders()
            );
        } else {
            revert("FuzzEngine: scuff action not implemented");
        }
    }

    /**
     * @dev Calculate calldata for the selected action and apply
     * a random scuff directive to it.
     * External function to ensure FuzzEngine's memory is not affected
     */
    function getScuffedCalldata(
        FuzzTestContext memory context
    )
        external
        view
        returns (bytes memory callData, ScuffDescription memory description)
    {
        bytes memory callData = getActionCalldata(context);

        ScuffDirective[] memory directives = getScuffDirectivesForCalldata(
            callData
        );

        LibPRNG.PRNG memory prng = LibPRNG.PRNG(context.fuzzParams.seed);
        ScuffDirective directive = directives[
            bound(prng.next(), 0, directives.length - 1)
        ];
        description = getScuffDescription(context._action, directive);
        directive.applyScuff();
        description.scuffedValue = MemoryPointer
            .wrap(description.pointer)
            .readBytes32();
    }

    function innerScuffExecute(
        address _caller,
        address _seaport,
        uint256 callValue,
        bytes memory data
    ) external returns (bool success, bytes memory returnData) {
        if (_caller != address(0)) {
            vm.prank(_caller);
        }
        uint256 gasLimit = 16_000_000;
        assembly {
            success := call(
                gasLimit,
                _seaport,
                callValue,
                add(data, 32),
                mload(data),
                0,
                0
            )
            returnData := mload(0x40)
            mstore(0x40, add(returnData, add(returndatasize(), 0x20)))
            mstore(returnData, returndatasize())
            if returndatasize() {
                returndatacopy(add(returnData, 0x20), 0, returndatasize())
            }
        }
    }
}
