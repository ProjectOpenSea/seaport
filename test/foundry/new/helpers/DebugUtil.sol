// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import { Searializer, Execution, ItemType, vm, Vm } from "./Searializer.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

import { ExpectedBalances } from "./ExpectedBalances.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { console2 } from "forge-std/console2.sol";

import { ArrayHelpers, MemoryPointer } from "seaport-sol/../ArrayHelpers.sol";

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
    bool initialOrders;
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
    bool expectedZoneCalldataHash;
    bool expectedContractOrderCalldataHashes;
    bool expectedResults;
    bool expectedImplicitExecutions;
    bool expectedExplicitExecutions;
    bool allExpectedExecutions;
    ItemType executionsFilter;
    bool expectedEventHashes;
    bool actualEvents;
    bool expectedEvents;
    bool returnValues;
    bool nativeExpectedBalances;
    bool erc20ExpectedBalances;
    bool erc721ExpectedBalances;
    bool erc1155ExpectedBalances;
}

using ForgeEventsLib for Vm.Log;
using ForgeEventsLib for Vm.Log[];
using TransferEventsLib for Execution[];
using FuzzEngineLib for FuzzTestContext;
using ExecutionFilterCast for Execution[];

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
        jsonOut = Searializer.tojsonAddress("root", "caller", context.caller);
    }
    if (outputSelection.recipient) {
        jsonOut = Searializer.tojsonAddress(
            "root",
            "recipient",
            context.recipient
        );
    }
    if (outputSelection.callValue) {
        jsonOut = Searializer.tojsonUint256(
            "root",
            "callValue",
            context.getNativeTokensToSupply()
        );
    }
    // if (outputSelection.fuzzParams) {
    //     jsonOut = Searializer.tojsonFuzzParams("root", "fuzzParams", context.fuzzParams);
    // }
    if (outputSelection.orders) {
        jsonOut = Searializer.tojsonDynArrayAdvancedOrder(
            "root",
            "orders",
            context.orders
        );
    }
    // if (outputSelection.initialOrders) {
    //     jsonOut = Searializer.tojsonDynArrayAdvancedOrder(
    //         "root",
    //         "initialOrders",
    //         context.initialOrders
    //     );
    // }
    // if (outputSelection.counter) {
    //     jsonOut = Searializer.tojsonUint256("root", "counter", context.counter);
    // }
    // if (outputSelection.fulfillerConduitKey) {
    //     jsonOut = Searializer.tojsonBytes32(
    //         "root",
    //         "fulfillerConduitKey",
    //         context.fulfillerConduitKey
    //     );
    // }
    // if (outputSelection.criteriaResolvers) {
    //     jsonOut = Searializer.tojsonDynArrayCriteriaResolver(
    //         "root",
    //         "criteriaResolvers",
    //         context.criteriaResolvers
    //     );
    // }
    // if (outputSelection.fulfillments) {
    //     jsonOut = Searializer.tojsonDynArrayFulfillment(
    //         "root",
    //         "fulfillments",
    //         context.fulfillments
    //     );
    // }
    // if (outputSelection.remainingOfferComponents) {
    //     jsonOut = Searializer.tojsonDynArrayFulfillmentComponent(
    //         "root",
    //         "remainingOfferComponents",
    //         context.remainingOfferComponents
    //     );
    // }
    // if (outputSelection.offerFulfillments) {
    //     jsonOut = Searializer.tojsonDynArrayDynArrayFulfillmentComponent(
    //         "root",
    //         "offerFulfillments",
    //         context.offerFulfillments
    //     );
    // }
    // if (outputSelection.considerationFulfillments) {
    //     jsonOut = Searializer.tojsonDynArrayDynArrayFulfillmentComponent(
    //         "root",
    //         "considerationFulfillments",
    //         context.considerationFulfillments
    //     );
    // }
    // if (outputSelection.maximumFulfilled) {
    //     jsonOut = Searializer.tojsonUint256(
    //         "root",
    //         "maximumFulfilled",
    //         context.maximumFulfilled
    //     );
    // }
    // if (outputSelection.basicOrderParameters) {
    //     jsonOut = Searializer.tojsonBasicOrderParameters(
    //         "root",
    //         "basicOrderParameters",
    //         context.basicOrderParameters
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
    // if (outputSelection.expectedZoneCalldataHash) {
    //     jsonOut = Searializer.tojsonDynArrayBytes32(
    //         "root",
    //         "expectedZoneCalldataHash",
    //         context.expectedZoneCalldataHash
    //     );
    // }
    // if (outputSelection.expectedContractOrderCalldataHashes) {
    //     jsonOut = Searializer.tojsonDynArrayArray2Bytes32(
    //         "root",
    //         "expectedContractOrderCalldataHashes",
    //         context.expectedContractOrderCalldataHashes
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
            "expectedImplicitExecutions",
            context.expectedImplicitExecutions.filter(
                outputSelection.executionsFilter
            )
        );
    }
    if (outputSelection.expectedExplicitExecutions) {
        jsonOut = Searializer.tojsonDynArrayExecution(
            "root",
            "expectedExplicitExecutions",
            context.expectedExplicitExecutions.filter(
                outputSelection.executionsFilter
            )
        );
    }
    if (outputSelection.allExpectedExecutions) {
        jsonOut = Searializer.tojsonDynArrayExecution(
            "root",
            "allExpectedExecutions",
            context.allExpectedExecutions.filter(
                outputSelection.executionsFilter
            )
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
        jsonOut = context.allExpectedExecutions.serializeTransferLogs(
            "root",
            "expectedEvents",
            context
        );
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
    vm.writeJson(jsonOut, "./fuzz_debug.json");
}

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

function dumpTransfers(FuzzTestContext memory context) view {
    ContextOutputSelection memory selection;
    selection.allExpectedExecutions = true;
    selection.expectedEvents = true;
    selection.actualEvents = true;
    pureDumpContext()(context, selection);
    console2.log("Dumped transfer data to ./fuzz_debug.json");
}

function dumpExecutions(FuzzTestContext memory context) view {
    ContextOutputSelection memory selection;
    selection.orders = true;
    selection.allExpectedExecutions = true;
    selection.nativeExpectedBalances = true;
    selection.seaport = true;
    selection.caller = true;
    selection.callValue = true;
    selection.testHelpers = true;
    selection.recipient = true;
    selection.expectedExplicitExecutions = true;
    selection.expectedImplicitExecutions = true;
    selection.executionsFilter = ItemType.ERC1155_WITH_CRITERIA; // no filter
    selection.orders = true;
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
