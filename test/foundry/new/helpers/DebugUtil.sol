// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import { Searializer, Execution, ItemType, vm, Vm } from "./Searializer.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { ExpectedBalances } from "./ExpectedBalances.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { console2 } from "forge-std/console2.sol";

import { ArrayHelpers, MemoryPointer } from "seaport/helpers/ArrayHelpers.sol";

import {
    OrderStatusEnum,
    UnavailableReason
} from "seaport-sol/src/SpaceEnums.sol";

import { ForgeEventsLib } from "./event-utils/ForgeEventsLib.sol";

import { TransferEventsLib } from "./event-utils/TransferEventsLib.sol";

struct ContextOutputSelection {
    bool seaport;
    bool conduitController;
    bool caller;
    bool callValue;
    bool recipient;
    bool fuzzParams;
    bool orders;
    bool orderHashes;
    bool previewedOrders;
    bool counter;
    bool fulfillerConduitKey;
    bool criteriaResolvers;
    bool fulfillments;
    bool remainingOfferComponents;
    bool offerFulfillments;
    bool considerationFulfillments;
    bool maximumFulfilled;
    bool basicOrderParameters;
    bool testHelpers;
    bool checks;
    bool expectedZoneAuthorizeCalldataHashes;
    bool expectedZoneValidateCalldataHashes;
    bool expectedContractOrderCalldataHashes;
    bool expectedResults;
    bool expectedImplicitExecutions;
    bool expectedExplicitExecutions;
    bool allExpectedExecutions;
    bool expectedAvailableOrders;
    ItemType executionsFilter;
    bool expectedEventHashes;
    bool actualEvents;
    bool expectedEvents;
    bool returnValues;
    bool nativeExpectedBalances;
    bool erc20ExpectedBalances;
    bool erc721ExpectedBalances;
    bool erc1155ExpectedBalances;
    bool preExecOrderStatuses;
    bool validationErrors;
}

using ForgeEventsLib for Vm.Log;
using ForgeEventsLib for Vm.Log[];
using TransferEventsLib for Execution[];
using FuzzEngineLib for FuzzTestContext;
using ExecutionFilterCast for Execution[];

/**
 * @dev Serialize and write a FuzzTestContext to a `fuzz_debug.json` file.
 *
 * @param context         the FuzzTestContext to serialize.
 * @param outputSelection a ContextOutputSelection struct containing flags
 *                           that define which FuzzTestContext fields to serialize.
 */
function dumpContext(
    FuzzTestContext memory context,
    ContextOutputSelection memory outputSelection
) {
    string memory jsonOut;
    jsonOut = vm.serializeString("root", "_action", context.actionName());
    if (outputSelection.seaport) {
        jsonOut = Searializer.tojsonAddress(
            "root",
            "seaport",
            address(context.seaport)
        );
    }
    // if (outputSelection.conduitController) {
    //     jsonOut = Searializer.tojsonAddress(
    //         "root",
    //         "conduitController",
    //         address(context.conduitController)
    //     );
    // }
    if (outputSelection.caller) {
        jsonOut = Searializer.tojsonAddress(
            "root",
            "caller",
            context.executionState.caller
        );
    }
    if (outputSelection.recipient) {
        jsonOut = Searializer.tojsonAddress(
            "root",
            "recipient",
            context.executionState.recipient
        );
    }
    if (outputSelection.callValue) {
        jsonOut = Searializer.tojsonUint256(
            "root",
            "callValue",
            context.executionState.value
        );
    }
    if (outputSelection.maximumFulfilled) {
        jsonOut = Searializer.tojsonUint256(
            "root",
            "maximumFulfilled",
            context.executionState.maximumFulfilled
        );
    }
    // if (outputSelection.fuzzParams) {
    //     jsonOut = Searializer.tojsonFuzzParams("root", "fuzzParams", context.fuzzParams);
    // }
    if (outputSelection.orders) {
        jsonOut = Searializer.tojsonDynArrayAdvancedOrder(
            "root",
            "orders",
            context.executionState.orders
        );
    }
    if (outputSelection.orderHashes) {
        bytes32[] memory orderHashes = new bytes32[](
            context.executionState.orderDetails.length
        );

        for (
            uint256 i = 0;
            i < context.executionState.orderDetails.length;
            i++
        ) {
            orderHashes[i] = context.executionState.orderDetails[i].orderHash;
        }

        jsonOut = Searializer.tojsonDynArrayBytes32(
            "root",
            "orderHashes",
            orderHashes
        );
    }
    if (outputSelection.previewedOrders) {
        jsonOut = Searializer.tojsonDynArrayAdvancedOrder(
            "root",
            "previewedOrders",
            context.executionState.previewedOrders
        );
    }
    // if (outputSelection.counter) {
    //     jsonOut = Searializer.tojsonUint256("root", "counter", context.executionState.counter);
    // }
    // if (outputSelection.fulfillerConduitKey) {
    //     jsonOut = Searializer.tojsonBytes32(
    //         "root",
    //         "fulfillerConduitKey",
    //         context.executionState.fulfillerConduitKey
    //     );
    // }
    // if (outputSelection.criteriaResolvers) {
    //     jsonOut = Searializer.tojsonDynArrayCriteriaResolver(
    //         "root",
    //         "criteriaResolvers",
    //         context.executionState.criteriaResolvers
    //     );
    // }
    // if (outputSelection.fulfillments) {
    //     jsonOut = Searializer.tojsonDynArrayFulfillment(
    //         "root",
    //         "fulfillments",
    //         context.executionState.fulfillments
    //     );
    // }
    // if (outputSelection.remainingOfferComponents) {
    //     jsonOut = Searializer.tojsonDynArrayFulfillmentComponent(
    //         "root",
    //         "remainingOfferComponents",
    //         context.executionState.remainingOfferComponents
    //     );
    // }
    // if (outputSelection.offerFulfillments) {
    //     jsonOut = Searializer.tojsonDynArrayDynArrayFulfillmentComponent(
    //         "root",
    //         "offerFulfillments",
    //         context.executionState.offerFulfillments
    //     );
    // }
    // if (outputSelection.considerationFulfillments) {
    //     jsonOut = Searializer.tojsonDynArrayDynArrayFulfillmentComponent(
    //         "root",
    //         "considerationFulfillments",
    //         context.executionState.considerationFulfillments
    //     );
    // }
    // if (outputSelection.maximumFulfilled) {
    //     jsonOut = Searializer.tojsonUint256(
    //         "root",
    //         "maximumFulfilled",
    //         context.executionState.maximumFulfilled
    //     );
    // }
    // if (outputSelection.basicOrderParameters) {
    //     jsonOut = Searializer.tojsonBasicOrderParameters(
    //         "root",
    //         "basicOrderParameters",
    //         context.executionState.basicOrderParameters
    //     );
    // }
    // if (outputSelection.testHelpers) {
    //     jsonOut = Searializer.tojsonAddress(
    //         "root",
    //         "testHelpers",
    //         address(context.testHelpers)
    //     );
    // }
    // if (outputSelection.checks) {
    //     jsonOut = Searializer.tojsonDynArrayBytes4("root", "checks", context.checks);
    // }
    if (outputSelection.preExecOrderStatuses) {
        jsonOut = Searializer.tojsonDynArrayUint256(
            "root",
            "preExecOrderStatuses",
            cast(context.executionState.preExecOrderStatuses)
        );
    }
    // if (outputSelection.expectedZoneValidateCalldataHash) {
    //     jsonOut = Searializer.tojsonDynArrayBytes32(
    //         "root",
    //         "expectedZoneValidateCalldataHash",
    //         context.expectations.expectedZoneValidateCalldataHash
    //     );
    // }
    // if (outputSelection.expectedContractOrderCalldataHashes) {
    //     jsonOut = Searializer.tojsonDynArrayArray2Bytes32(
    //         "root",
    //         "expectedContractOrderCalldataHashes",
    //         context.expectations.expectedContractOrderCalldataHashes
    //     );
    // }
    // if (outputSelection.expectedResults) {
    //     jsonOut = Searializer.tojsonDynArrayResult(
    //         "root",
    //         "expectedResults",
    //         context.expectedResults
    //     );
    // }

    // =====================================================================//
    //                             Executions                               //
    // =====================================================================//

    if (outputSelection.expectedImplicitExecutions) {
        jsonOut = Searializer.tojsonDynArrayExecution(
            "root",
            "expectedImplicitPreExecutions",
            context.expectations.expectedImplicitPreExecutions.filter(
                outputSelection.executionsFilter
            )
        );
        jsonOut = Searializer.tojsonDynArrayExecution(
            "root",
            "expectedImplicitPostExecutions",
            context.expectations.expectedImplicitPostExecutions.filter(
                outputSelection.executionsFilter
            )
        );
    }
    if (outputSelection.expectedExplicitExecutions) {
        jsonOut = Searializer.tojsonDynArrayExecution(
            "root",
            "expectedExplicitExecutions",
            context.expectations.expectedExplicitExecutions.filter(
                outputSelection.executionsFilter
            )
        );
    }
    if (outputSelection.allExpectedExecutions) {
        jsonOut = Searializer.tojsonDynArrayExecution(
            "root",
            "allExpectedExecutions",
            context.expectations.allExpectedExecutions.filter(
                outputSelection.executionsFilter
            )
        );
    }
    if (outputSelection.expectedAvailableOrders) {
        bool[] memory expectedAvailableOrders = new bool[](
            context.executionState.orderDetails.length
        );

        for (
            uint256 i = 0;
            i < context.executionState.orderDetails.length;
            i++
        ) {
            expectedAvailableOrders[i] =
                context.executionState.orderDetails[i].unavailableReason ==
                UnavailableReason.AVAILABLE;
        }

        jsonOut = Searializer.tojsonDynArrayBool(
            "root",
            "expectedAvailableOrders",
            expectedAvailableOrders
        );
    }
    // =====================================================================//
    //                               Events                                 //
    // =====================================================================//
    // if (outputSelection.expectedEventHashes) {
    //     jsonOut = Searializer.tojsonDynArrayBytes32(
    //         "root",
    //         "expectedEventHashes",
    //         context.expectedEventHashes
    //     );
    // }
    if (outputSelection.actualEvents) {
        jsonOut = context.actualEvents.serializeTransferLogs(
            "root",
            "actualEvents"
        );
    }
    if (outputSelection.expectedEvents) {
        jsonOut = context
            .expectations
            .allExpectedExecutions
            .serializeTransferLogs("root", "expectedEvents", context);
    }
    /*if (outputSelection.returnValues) {
        jsonOut = Searializer.tojsonReturnValues(
            "root",
            "returnValues",
            context.returnValues
        );
    } */

    ExpectedBalances balanceChecker = context.testHelpers.balanceChecker();
    if (outputSelection.nativeExpectedBalances) {
        jsonOut = Searializer.tojsonDynArrayNativeAccountDump(
            "root",
            "nativeExpectedBalances",
            balanceChecker.dumpNativeBalances()
        );
    }
    if (outputSelection.erc20ExpectedBalances) {
        jsonOut = Searializer.tojsonDynArrayERC20TokenDump(
            "root",
            "erc20ExpectedBalances",
            balanceChecker.dumpERC20Balances()
        );
    }
    // if (outputSelection.erc721ExpectedBalances) {
    //     jsonOut = Searializer.tojsonDynArrayERC721TokenDump(
    //         "root",
    //         "erc721ExpectedBalances",
    //         balanceChecker.dumpERC721Balances()
    //     );
    // }
    // if (outputSelection.erc1155ExpectedBalances) {
    //     jsonOut = Searializer.tojsonDynArrayERC1155TokenDump(
    //         "root",
    //         "erc1155ExpectedBalances",
    //         balanceChecker.dumpERC1155Balances()
    //     );
    // }
    if (outputSelection.validationErrors) {
        jsonOut = Searializer.tojsonDynArrayValidationErrorsAndWarnings(
            "root",
            "validationErrors",
            context.executionState.validationErrors
        );
    }
    vm.writeJson(jsonOut, "./fuzz_debug.json");
}

/**
 * @dev Helper to cast dumpContext to a pure function.
 */
function pureDumpContext()
    pure
    returns (
        function(FuzzTestContext memory, ContextOutputSelection memory)
            internal
            pure pureFn
    )
{
    function(FuzzTestContext memory, ContextOutputSelection memory)
        internal viewFn = dumpContext;
    assembly {
        pureFn := viewFn
    }
}

function cast(OrderStatusEnum[] memory a) pure returns (uint256[] memory b) {
    assembly {
        b := a
    }
}

/**
 * @dev Serialize and write transfer related fields from FuzzTestContext to a
 *      `fuzz_debug.json` file.
 */
function dumpTransfers(FuzzTestContext memory context) view {
    ContextOutputSelection memory selection;
    selection.allExpectedExecutions = true;
    selection.expectedEvents = true;
    selection.actualEvents = true;
    pureDumpContext()(context, selection);
    console2.log("Dumped transfer data to ./fuzz_debug.json");
}

/**
 * @dev Serialize and write execution related fields from FuzzTestContext to a
 *      `fuzz_debug.json` file.
 */
function dumpExecutions(FuzzTestContext memory context) view {
    ContextOutputSelection memory selection;
    selection.orders = true;
    selection.orderHashes = true;
    selection.allExpectedExecutions = true;
    selection.nativeExpectedBalances = true;
    selection.expectedAvailableOrders = true;
    selection.seaport = true;
    selection.caller = true;
    selection.callValue = true;
    selection.maximumFulfilled = true;
    selection.testHelpers = true;
    selection.recipient = true;
    selection.expectedExplicitExecutions = true;
    selection.expectedImplicitExecutions = true;
    selection.executionsFilter = ItemType.ERC1155_WITH_CRITERIA; // no filter
    selection.orders = true;
    selection.preExecOrderStatuses = true;
    selection.validationErrors = true;
    pureDumpContext()(context, selection);
    console2.log("Dumped executions and balances to ./fuzz_debug.json");
}

library ExecutionFilterCast {
    using ExecutionFilterCast for *;

    function filter(
        Execution[] memory executions,
        ItemType itemType
    ) internal pure returns (Execution[] memory) {
        if (uint256(itemType) > 3) return executions;
        return
            ArrayHelpers.filterWithArg.asExecutionsFilterByItemType()(
                executions,
                ExecutionFilterCast.isItemType,
                itemType
            );
    }

    function isItemType(
        Execution memory execution,
        ItemType itemType
    ) internal pure returns (bool) {
        return execution.item.itemType == itemType;
    }

    function asExecutionsFilterByItemType(
        function(
            MemoryPointer,
            function(MemoryPointer, MemoryPointer) internal pure returns (bool),
            MemoryPointer
        ) internal pure returns (MemoryPointer) fnIn
    )
        internal
        pure
        returns (
            function(
                Execution[] memory,
                function(Execution memory, ItemType)
                    internal
                    pure
                    returns (bool),
                ItemType
            ) internal pure returns (Execution[] memory) fnOut
        )
    {
        assembly {
            fnOut := fnIn
        }
    }
}
