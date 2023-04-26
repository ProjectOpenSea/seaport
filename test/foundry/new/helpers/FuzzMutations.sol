// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { FuzzExecutor } from "./FuzzExecutor.sol";
import { FuzzTestContext, MutationState } from "./FuzzTestContextLib.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import {
    MutationEligibilityLib,
    MutationHelpersLib
} from "./FuzzMutationHelpers.sol";

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
    FulfillmentDetails,
    OrderDetails
} from "seaport-sol/fulfillments/lib/Structs.sol";

import {
    AdvancedOrderLib,
    OrderParametersLib,
    ConsiderationItemLib,
    ItemType,
    BasicOrderType,
    ConsiderationItemLib
} from "seaport-sol/SeaportSol.sol";

import { EOASignature, SignatureMethod, Offerer } from "./FuzzGenerators.sol";

import { ItemType, OrderType, Side } from "seaport-sol/SeaportEnums.sol";

import { ContractOrderRebate } from "seaport-sol/SpaceEnums.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { FuzzInscribers } from "./FuzzInscribers.sol";
import { AdvancedOrdersSpaceGenerator } from "./FuzzGenerators.sol";

import { EIP1271Offerer } from "./EIP1271Offerer.sol";

import { FuzzDerivers, FulfillmentDetailsHelper } from "./FuzzDerivers.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { CheckHelpers } from "./FuzzSetup.sol";

import {
    TestERC20 as TestERC20Strange
} from "../../../../contracts/test/TestERC20.sol";

import { ConduitChoice } from "seaport-sol/StructSpace.sol";

import {
    HashCalldataContractOfferer
} from "../../../../contracts/test/HashCalldataContractOfferer.sol";

import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";

import {
    OffererZoneFailureReason
} from "../../../../contracts/test/OffererZoneFailureReason.sol";

import { FractionStatus, FractionUtil } from "./FractionUtil.sol";

interface TestERC20 {
    function approve(address spender, uint256 amount) external;
}

interface TestNFT {
    function setApprovalForAll(address operator, bool approved) external;
}

library MutationFilters {
    using FuzzEngineLib for FuzzTestContext;
    using FuzzHelpers for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder;
    using FuzzDerivers for FuzzTestContext;
    using MutationHelpersLib for FuzzTestContext;
    using FulfillmentDetailsHelper for FuzzTestContext;

    function ineligibleWhenUnavailable(
        FuzzTestContext memory context,
        uint256 orderIndex
    ) internal pure returns (bool) {
        return !context.expectations.expectedAvailableOrders[orderIndex];
    }

    function ineligibleForOfferItemMissingApproval(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        bool locatedEligibleOfferItem;
        for (uint256 i = 0; i < order.parameters.offer.length; ++i) {
            OfferItem memory item = order.parameters.offer[i];
            if (
                !context.isFilteredOrNative(
                    item,
                    order.parameters.offerer,
                    order.parameters.conduitKey
                )
            ) {
                locatedEligibleOfferItem = true;
                break;
            }
        }

        if (!locatedEligibleOfferItem) {
            return true;
        }

        return false;
    }

    function ineligibleForCallerMissingApproval(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The caller does not provide any items during match actions.
        bytes4 action = context.action();
        if (
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector
        ) {
            return true;
        }

        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        // On basic orders, the caller does not need ERC20 approvals when
        // accepting bids (as the offerer provides the ERC20 tokens).
        uint256 eligibleItemTotal = order.parameters.consideration.length;
        if (
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            if (order.parameters.offer[0].itemType == ItemType.ERC20) {
                eligibleItemTotal = 1;
            }
        }

        bool locatedEligibleOfferItem;
        for (uint256 i = 0; i < eligibleItemTotal; ++i) {
            ConsiderationItem memory item = order.parameters.consideration[i];
            if (!context.isFilteredOrNative(item)) {
                locatedEligibleOfferItem = true;
                break;
            }
        }

        if (!locatedEligibleOfferItem) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidMsgValue(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();
        if (
            action != context.seaport.fulfillBasicOrder.selector &&
            action !=
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForInsufficientNativeTokens(
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (context.expectations.expectedImpliedNativeExecutions != 0) {
            return true;
        }

        uint256 minimumRequired = context.expectations.minimumValue;

        if (minimumRequired == 0) {
            return true;
        }

        return false;
    }

    function ineligibleForNativeTokenTransferGenericFailure(
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (context.expectations.expectedImpliedNativeExecutions == 0) {
            return true;
        }

        uint256 minimumRequired = context.expectations.minimumValue;

        if (minimumRequired == 0) {
            return true;
        }

        return false;
    }

    function ineligibleWhenNotAdvancedOrWithNoAvailableItems(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.fulfillOrder.selector ||
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            return true;
        }

        bool locatedItem;
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            if (ineligibleWhenUnavailable(context, i)) {
                continue;
            }

            AdvancedOrder memory order = context.executionState.previewedOrders[
                i
            ];
            uint256 items = order.parameters.offer.length +
                order.parameters.consideration.length;
            if (items != 0) {
                locatedItem = true;
                break;
            }
        }

        if (!locatedItem) {
            return true;
        }

        return false;
    }

    function ineligibleWhenNotAdvanced(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.fulfillOrder.selector ||
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidProof_Merkle(
        CriteriaResolver memory criteriaResolver,
        uint256 /* criteriaResolverIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (
            ineligibleWhenNotAdvancedOrUnavailable(
                context,
                criteriaResolver.orderIndex
            )
        ) {
            return true;
        }

        if (criteriaResolver.criteriaProof.length == 0) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidProof_Wildcard(
        CriteriaResolver memory criteriaResolver,
        uint256 /* criteriaResolverIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (
            ineligibleWhenNotAdvancedOrUnavailable(
                context,
                criteriaResolver.orderIndex
            )
        ) {
            return true;
        }

        if (criteriaResolver.criteriaProof.length != 0) {
            return true;
        }

        return false;
    }

    function ineligibleForOfferCriteriaResolverFailure(
        CriteriaResolver memory criteriaResolver,
        uint256 /* criteriaResolverIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (
            ineligibleWhenNotAdvancedOrUnavailable(
                context,
                criteriaResolver.orderIndex
            )
        ) {
            return true;
        }

        if (criteriaResolver.side != Side.OFFER) {
            return true;
        }

        return false;
    }

    function ineligibleForConsiderationCriteriaResolverFailure(
        CriteriaResolver memory criteriaResolver,
        uint256 /* criteriaResolverIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (
            ineligibleWhenNotAdvancedOrUnavailable(
                context,
                criteriaResolver.orderIndex
            )
        ) {
            return true;
        }

        if (criteriaResolver.side != Side.CONSIDERATION) {
            return true;
        }

        return false;
    }

    function ineligibleWhenNotAdvancedOrUnavailable(
        FuzzTestContext memory context,
        uint256 orderIndex
    ) internal view returns (bool) {
        if (ineligibleWhenNotAdvanced(context)) {
            return true;
        }

        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        return false;
    }

    function neverIneligible(
        FuzzTestContext memory /* context */
    ) internal pure returns (bool) {
        return false;
    }

    function ineligibleWhenContractOrder(
        AdvancedOrder memory order
    ) internal pure returns (bool) {
        return order.parameters.orderType == OrderType.CONTRACT;
    }

    function ineligibleWhenNotAvailableOrContractOrder(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (ineligibleWhenContractOrder(order)) {
            return true;
        }

        return ineligibleWhenUnavailable(context, orderIndex);
    }

    function ineligibleWhenNotContractOrder(
        AdvancedOrder memory order
    ) internal pure returns (bool) {
        return order.parameters.orderType != OrderType.CONTRACT;
    }

    function ineligibleWhenNotRestrictedOrder(
        AdvancedOrder memory order
    ) internal pure returns (bool) {
        return (order.parameters.orderType != OrderType.FULL_RESTRICTED &&
            order.parameters.orderType != OrderType.PARTIAL_RESTRICTED);
    }

    function ineligibleWhenNotAvailableOrNotContractOrder(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (ineligibleWhenNotContractOrder(order)) {
            return true;
        }

        return ineligibleWhenUnavailable(context, orderIndex);
    }

    function ineligibleWhenFulfillAvailable(
        AdvancedOrder memory /* order */,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleWhenNotContractOrderOrFulfillAvailable(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleWhenNotContractOrder(order)) {
            return true;
        }
        return ineligibleWhenFulfillAvailable(order, orderIndex, context);
    }

    function ineligibleWhenNotAvailableOrNotRestrictedOrder(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (ineligibleWhenNotRestrictedOrder(order)) {
            return true;
        }

        return ineligibleWhenUnavailable(context, orderIndex);
    }

    function ineligibleWhenNotActiveTime(
        AdvancedOrder memory order
    ) internal view returns (bool) {
        return (order.parameters.startTime > block.timestamp ||
            order.parameters.endTime <= block.timestamp);
    }

    function ineligibleWhenPastMaxFulfilled(
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        uint256 remainingFulfillable = context.executionState.maximumFulfilled;

        if (remainingFulfillable == 0) {
            return true;
        }

        for (
            uint256 i = 0;
            i < context.expectations.expectedAvailableOrders.length;
            ++i
        ) {
            if (context.expectations.expectedAvailableOrders[i]) {
                remainingFulfillable -= 1;
            }

            if (remainingFulfillable == 0) {
                return orderIndex > i;
            }
        }

        return false;
    }

    function ineligibleWhenNotActiveTimeOrNotContractOrder(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // TODO: get more precise about when this is allowed or not
        if (
            context.advancedOrdersSpace.orders[orderIndex].rebate !=
            ContractOrderRebate.NONE
        ) {
            return true;
        }

        if (ineligibleWhenNotActiveTime(order)) {
            return true;
        }

        if (ineligibleWhenPastMaxFulfilled(orderIndex, context)) {
            return true;
        }

        if (ineligibleWhenNotContractOrder(order)) {
            return true;
        }

        OffererZoneFailureReason failureReason = HashCalldataContractOfferer(
            payable(order.parameters.offerer)
        ).failureReasons(context.executionState.orderHashes[orderIndex]);

        return (failureReason ==
            OffererZoneFailureReason.ContractOfferer_generateReverts);
    }

    function ineligibleWhenNotActiveTimeOrNotContractOrderOrNoOffer(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (order.parameters.offer.length == 0) {
            return true;
        }

        return
            ineligibleWhenNotActiveTimeOrNotContractOrder(
                order,
                orderIndex,
                context
            );
    }

    function ineligibleWhenNotActiveTimeOrNotContractOrderOrNoConsideration(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (order.parameters.consideration.length == 0) {
            return true;
        }

        return
            ineligibleWhenNotActiveTimeOrNotContractOrder(
                order,
                orderIndex,
                context
            );
    }

    function ineligibleForAnySignatureFailure(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (
            ineligibleWhenNotAvailableOrContractOrder(
                order,
                orderIndex,
                context
            )
        ) {
            return true;
        }

        if (order.parameters.offerer == context.executionState.caller) {
            return true;
        }

        (bool isValidated, , , ) = context.seaport.getOrderStatus(
            context.executionState.orderHashes[orderIndex]
        );

        if (isValidated) {
            return true;
        }

        return false;
    }

    function ineligibleForEOASignature(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForAnySignatureFailure(order, orderIndex, context)) {
            return true;
        }

        if (order.parameters.offerer.code.length != 0) {
            return true;
        }

        return false;
    }

    function ineligibleForFulfillmentIngestingFunctions(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (
            action == context.seaport.fulfillAdvancedOrder.selector ||
            action == context.seaport.fulfillOrder.selector ||
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForBadContractSignature(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForAnySignatureFailure(order, orderIndex, context)) {
            return true;
        }

        if (order.parameters.offerer.code.length == 0) {
            return true;
        }

        // TODO: this is overly restrictive but gets us to missing magic
        try EIP1271Offerer(payable(order.parameters.offerer)).is1271() returns (
            bool ok
        ) {
            if (!ok) {
                return true;
            }
        } catch {
            return true;
        }

        return false;
    }

    function ineligibleForConsiderationLengthNotEqualToTotalOriginal(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (order.parameters.orderType != OrderType.CONTRACT) {
            return true;
        }

        if (order.parameters.consideration.length == 0) {
            return true;
        }

        return false;
    }

    function ineligibleForMissingOriginalConsiderationItems(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (order.parameters.orderType == OrderType.CONTRACT) {
            return true;
        }

        if (order.parameters.consideration.length == 0) {
            return true;
        }

        return false;
    }

    // Determine if an order is unavailable, has been validated, has an offerer
    // with code, has an offerer equal to the caller, or is a contract order.
    function ineligibleForInvalidSignature(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForEOASignature(order, orderIndex, context)) {
            return true;
        }

        if (order.signature.length != 64 && order.signature.length != 65) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidSigner(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForEOASignature(order, orderIndex, context)) {
            return true;
        }

        bool validLength = order.signature.length < 837 &&
            order.signature.length > 63 &&
            ((order.signature.length - 35) % 32) < 2;
        if (!validLength) {
            return true;
        }

        return false;
    }

    function ineligibleForBadSignatureV(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForEOASignature(order, orderIndex, context)) {
            return true;
        }

        if (order.signature.length != 65) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidTime(
        AdvancedOrder memory /* order */,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidConduit(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal returns (bool) {
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            return true;
        }

        if (order.parameters.conduitKey == bytes32(0)) {
            return true;
        }

        FulfillmentDetails memory details = context.toFulfillmentDetails();

        // Note: We're speculatively applying the mutation here and slightly
        // breaking the rules. Make sure to undo this mutation.
        bytes32 oldConduitKey = order.parameters.conduitKey;
        details.orders[orderIndex].conduitKey = keccak256("invalid conduit");
        (
            Execution[] memory explicitExecutions,
            ,
            Execution[] memory implicitExecutionsPost,

        ) = context.getExecutionsFromRegeneratedFulfillments(
                details,
                context.executionState.value
            );

        // Look for invalid executions in explicit executions
        bool locatedInvalidConduitExecution;
        for (uint256 i; i < explicitExecutions.length; ++i) {
            if (
                explicitExecutions[i].conduitKey ==
                keccak256("invalid conduit") &&
                explicitExecutions[i].item.itemType != ItemType.NATIVE
            ) {
                locatedInvalidConduitExecution = true;
                break;
            }
        }

        // If we haven't found one yet, keep looking in implicit executions...
        if (!locatedInvalidConduitExecution) {
            for (uint256 i = 0; i < implicitExecutionsPost.length; ++i) {
                if (
                    implicitExecutionsPost[i].conduitKey ==
                    keccak256("invalid conduit") &&
                    implicitExecutionsPost[i].item.itemType != ItemType.NATIVE
                ) {
                    locatedInvalidConduitExecution = true;
                    break;
                }
            }
        }

        // Note: mutation is undone here as referenced above.
        details.orders[orderIndex].conduitKey = oldConduitKey;

        if (!locatedInvalidConduitExecution) {
            return true;
        }

        return false;
    }

    function ineligibleForBadFraction(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (
            action == context.seaport.fulfillOrder.selector ||
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector ||
            action == context.seaport.matchOrders.selector
        ) {
            return true;
        }

        // TODO: In cases where an order is skipped since it's fully filled,
        // cancelled, or generation failed, it's still possible to get a bad
        // fraction error. We want to exclude cases where the time is wrong or
        // maximum fulfilled has already been met. (So this check is
        // over-excluding potentially eligible orders).
        return
            ineligibleWhenNotAvailableOrContractOrder(
                order,
                orderIndex,
                context
            );
    }

    function ineligibleForBadFraction_noFill(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (action == context.seaport.fulfillAvailableAdvancedOrders.selector) {
            return true;
        }

        return ineligibleForBadFraction(order, orderIndex, context);
    }

    function ineligibleForCannotCancelOrder(
        AdvancedOrder memory /* order */,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (action != context.seaport.cancel.selector) {
            return true;
        }

        return false;
    }

    function ineligibleForOrderIsCancelled(
        AdvancedOrder memory order,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            return true;
        }

        if (order.parameters.orderType == OrderType.CONTRACT) {
            return true;
        }

        return false;
    }

    function ineligibleForOrderAlreadyFilled(
        AdvancedOrder memory order,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (order.parameters.orderType == OrderType.CONTRACT) {
            return true;
        }

        bytes4 action = context.action();

        // TODO: verify whether match / matchAdvanced are actually ineligible
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector ||
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector ||
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForBadFractionPartialContractOrder(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (order.parameters.orderType != OrderType.CONTRACT) {
            return true;
        }

        if (ineligibleWhenNotAdvancedOrUnavailable(context, orderIndex)) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidFulfillmentComponentData(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForFulfillmentIngestingFunctions(context)) {
            return true;
        }

        return false;
    }

    function ineligibleForMissingFulfillmentComponentOnAggregation(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForFulfillmentIngestingFunctions(context)) {
            return true;
        }

        bytes4 action = context.action();

        if (
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForOfferAndConsiderationRequiredOnFulfillment(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForFulfillmentIngestingFunctions(context)) {
            return true;
        }

        bytes4 action = context.action();

        if (
            action != context.seaport.matchOrders.selector &&
            action != context.seaport.matchAdvancedOrders.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForMismatchedFulfillmentOfferAndConsiderationComponents_Modified(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (
            action != context.seaport.matchAdvancedOrders.selector &&
            action != context.seaport.matchOrders.selector
        ) {
            return true;
        }

        if (context.executionState.fulfillments.length < 1) {
            return true;
        }

        FulfillmentComponent[] memory firstOfferComponents = (
            context.executionState.fulfillments[0].offerComponents
        );

        for (uint256 i = 0; i < firstOfferComponents.length; ++i) {
            FulfillmentComponent memory component = (firstOfferComponents[i]);
            if (
                context
                    .executionState
                    .orders[component.orderIndex]
                    .parameters
                    .offer
                    .length <= component.itemIndex
            ) {
                return true;
            }
        }

        return false;
    }

    function ineligibleForMismatchedFulfillmentOfferAndConsiderationComponents_Swapped(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (
            action != context.seaport.matchAdvancedOrders.selector &&
            action != context.seaport.matchOrders.selector
        ) {
            return true;
        }

        if (context.executionState.fulfillments.length < 2) {
            return true;
        }

        FulfillmentComponent memory firstOfferComponent = (
            context.executionState.fulfillments[0].offerComponents[0]
        );

        SpentItem memory item = context
            .executionState
            .orderDetails[firstOfferComponent.orderIndex]
            .offer[firstOfferComponent.itemIndex];
        for (
            uint256 i = 1;
            i < context.executionState.fulfillments.length;
            ++i
        ) {
            FulfillmentComponent memory considerationComponent = (
                context.executionState.fulfillments[i].considerationComponents[
                    0
                ]
            );

            ReceivedItem memory compareItem = context
                .executionState
                .orderDetails[considerationComponent.orderIndex]
                .consideration[considerationComponent.itemIndex];
            if (
                item.itemType != compareItem.itemType ||
                item.token != compareItem.token ||
                item.identifier != compareItem.identifier
            ) {
                return false;
            }
        }

        return true;
    }

    function ineligibleForMissingItemAmount_OfferItem_FulfillAvailable(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();
        if (
            action != context.seaport.fulfillAvailableAdvancedOrders.selector &&
            action != context.seaport.fulfillAvailableOrders.selector
        ) {
            return true;
        }

        for (
            uint256 i;
            i < context.executionState.offerFulfillments.length;
            i++
        ) {
            FulfillmentComponent memory fulfillmentComponent = context
                .executionState
                .offerFulfillments[i][0];

            if (
                context
                    .executionState
                    .orders[fulfillmentComponent.orderIndex]
                    .parameters
                    .offer
                    .length <= fulfillmentComponent.itemIndex
            ) {
                return true;
            }

            if (
                context
                    .executionState
                    .orderDetails[fulfillmentComponent.orderIndex]
                    .offer[fulfillmentComponent.itemIndex]
                    .itemType != ItemType.ERC721
            ) {
                if (
                    context.expectations.expectedAvailableOrders[
                        fulfillmentComponent.orderIndex
                    ]
                ) {
                    return false;
                }
            }
        }

        return true;
    }

    function ineligibleForMissingItemAmount_OfferItem_Match(
        FuzzTestContext memory /* context */
    ) internal pure returns (bool) {
        return true;
    }

    function ineligibleForMissingItemAmount_OfferItem(
        AdvancedOrder memory order,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableAdvancedOrders.selector ||
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector ||
            action == context.seaport.matchOrders.selector
        ) {
            return true;
        }

        if (
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            if (
                order.parameters.consideration[0].itemType == ItemType.ERC721 ||
                order.parameters.consideration[0].itemType == ItemType.ERC1155
            ) {
                uint256 totalConsiderationAmount;
                for (
                    uint256 i = 1;
                    i < order.parameters.consideration.length;
                    ++i
                ) {
                    totalConsiderationAmount += order
                        .parameters
                        .consideration[i]
                        .startAmount;
                }

                if (totalConsiderationAmount > 0) {
                    return true;
                }
            }
        }

        if (order.parameters.offer.length == 0) {
            return true;
        }

        // At least one offer item must be native, ERC20, or ERC1155
        bool hasValidItem;
        for (uint256 i; i < order.parameters.offer.length; i++) {
            OfferItem memory item = order.parameters.offer[i];
            if (
                item.itemType != ItemType.ERC721 &&
                item.itemType != ItemType.ERC721_WITH_CRITERIA
            ) {
                hasValidItem = true;
                break;
            }
        }
        if (!hasValidItem) {
            return true;
        }

        // Offerer must not also be consideration recipient for all items
        bool offererIsNotRecipient;
        for (uint256 i; i < order.parameters.consideration.length; i++) {
            ConsiderationItem memory item = order.parameters.consideration[i];
            if (item.recipient != order.parameters.offerer) {
                offererIsNotRecipient = true;
                break;
            }
        }
        if (!offererIsNotRecipient) {
            return true;
        }

        return false;
    }

    function ineligibleForMissingItemAmount_ConsiderationItem(
        AdvancedOrder memory /* order */,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        // Order must be available
        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        // Order must have at least one offer item
        if (
            context
                .executionState
                .previewedOrders[orderIndex]
                .parameters
                .offer
                .length < 1
        ) {
            return true;
        }

        // At least one consideration item must be native, ERC20, or ERC1155
        bool hasValidItem;
        for (
            uint256 i;
            i <
            context
                .executionState
                .previewedOrders[orderIndex]
                .parameters
                .consideration
                .length;
            i++
        ) {
            ConsiderationItem memory item = context
                .executionState
                .previewedOrders[orderIndex]
                .parameters
                .consideration[i];
            if (
                item.itemType != ItemType.ERC721 &&
                item.itemType != ItemType.ERC721_WITH_CRITERIA
            ) {
                hasValidItem = true;
                break;
            }
        }
        if (!hasValidItem) {
            return true;
        }

        return false;
    }

    function ineligibleForNoContract(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        // Can't be one of the fulfillAvailable actions.
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.fulfillAvailableAdvancedOrders.selector
        ) {
            return true;
        }

        // One non-native execution is necessary.
        for (
            uint256 i;
            i < context.expectations.expectedExplicitExecutions.length;
            i++
        ) {
            if (
                context.expectations.expectedExplicitExecutions[i].item.token !=
                address(0)
            ) {
                return false;
            }
        }

        return true;
    }

    function ineligibleForUnusedItemParameters_Token(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // Reverts with MismatchedFulfillmentOfferAndConsiderationComponents(uint256)
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableAdvancedOrders.selector ||
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector ||
            action == context.seaport.matchOrders.selector
        ) {
            return true;
        }

        if (ineligibleWhenOrderHasRebates(order, orderIndex, context)) {
            return true;
        }

        for (uint256 i; i < order.parameters.offer.length; i++) {
            OfferItem memory item = order.parameters.offer[i];
            if (item.itemType == ItemType.NATIVE) {
                return false;
            }
        }
        for (uint256 i; i < order.parameters.consideration.length; i++) {
            ConsiderationItem memory item = order.parameters.consideration[i];
            if (item.itemType == ItemType.NATIVE) {
                return false;
            }
        }

        return true;
    }

    function ineligibleWhenOrderHasRebates(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        if (order.parameters.orderType == OrderType.CONTRACT) {
            if (
                context.executionState.orderDetails[orderIndex].offer.length !=
                order.parameters.offer.length ||
                context
                    .executionState
                    .orderDetails[orderIndex]
                    .consideration
                    .length !=
                order.parameters.consideration.length
            ) {
                return true;
            }
        }

        return false;
    }

    function ineligibleForUnusedItemParameters_Identifier(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // Reverts with MismatchedFulfillmentOfferAndConsiderationComponents(uint256)
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableAdvancedOrders.selector ||
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector ||
            action == context.seaport.matchOrders.selector
        ) {
            return true;
        }

        if (ineligibleWhenOrderHasRebates(order, orderIndex, context)) {
            return true;
        }

        for (uint256 i; i < order.parameters.consideration.length; i++) {
            ConsiderationItem memory item = order.parameters.consideration[i];
            if (
                item.itemType == ItemType.ERC20 ||
                item.itemType == ItemType.NATIVE
            ) {
                return false;
            }
        }

        return true;
    }

    function ineligibleForInvalidERC721TransferAmount(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // TODO: this is so the item is not filtered; add test case where
        // executions are checked. Also deals with partial fills
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableAdvancedOrders.selector ||
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector ||
            action == context.seaport.fulfillAdvancedOrder.selector ||
            action == context.seaport.matchOrders.selector
        ) {
            return true;
        }

        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (ineligibleWhenOrderHasRebates(order, orderIndex, context)) {
            return true;
        }

        for (uint256 i; i < order.parameters.offer.length; i++) {
            OfferItem memory item = order.parameters.offer[i];
            if (
                item.itemType == ItemType.ERC721 ||
                item.itemType == ItemType.ERC721_WITH_CRITERIA
            ) {
                return false;
            }
        }

        for (uint256 i; i < order.parameters.consideration.length; i++) {
            ConsiderationItem memory item = order.parameters.consideration[i];
            if (
                item.itemType == ItemType.ERC721 ||
                item.itemType == ItemType.ERC721_WITH_CRITERIA
            ) {
                return false;
            }
        }

        return true;
    }

    function ineligibleForConsiderationNotMet(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // Method must be fulfill or match
        bytes4 action = context.action();
        if (
            action != context.seaport.fulfillAvailableAdvancedOrders.selector &&
            action != context.seaport.fulfillAvailableOrders.selector &&
            action != context.seaport.matchAdvancedOrders.selector &&
            action != context.seaport.matchOrders.selector
        ) {
            return true;
        }

        // TODO: Probably overfiltering
        if (order.numerator != order.denominator) {
            return true;
        }

        // Must not be a contract order
        if (order.parameters.orderType == OrderType.CONTRACT) {
            return true;
        }

        // Order must be available
        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        // Order must have at least one consideration item
        if (order.parameters.consideration.length == 0) {
            return true;
        }

        return false;
    }

    function ineligibleForPartialFillsNotEnabledForOrder(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // Exclude methods that don't support partial fills
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillAvailableOrders.selector ||
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.fulfillOrder.selector ||
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            return true;
        }

        // Exclude partial and contract orders
        if (
            order.parameters.orderType == OrderType.PARTIAL_OPEN ||
            order.parameters.orderType == OrderType.PARTIAL_RESTRICTED ||
            order.parameters.orderType == OrderType.CONTRACT
        ) {
            return true;
        }

        // Order must be available
        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        return false;
    }

    function ineligibleForPanic_PartialFillOverflow(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();
        if (
            action != context.seaport.fulfillAvailableAdvancedOrders.selector &&
            action != context.seaport.matchAdvancedOrders.selector &&
            action != context.seaport.fulfillAdvancedOrder.selector
        ) {
            return true;
        }

        // TODO: this overfits a bit, instead use time + max fulfilled
        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        return (order.parameters.orderType != OrderType.PARTIAL_OPEN &&
            order.parameters.orderType != OrderType.PARTIAL_RESTRICTED);
    }

    function ineligibleForInexactFraction(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (
            ineligibleForPanic_PartialFillOverflow(order, orderIndex, context)
        ) {
            return true;
        }

        if (
            order.parameters.offer.length +
                order.parameters.consideration.length ==
            0
        ) {
            return true;
        }

        uint256 itemAmount = order.parameters.offer.length == 0
            ? order.parameters.consideration[0].startAmount
            : order.parameters.offer[0].startAmount;

        if (itemAmount == 0) {
            itemAmount = order.parameters.offer.length == 0
                ? order.parameters.consideration[0].endAmount
                : order.parameters.offer[0].endAmount;
        }

        // This isn't perfect, but odds of hitting it are slim to none
        if (itemAmount > type(uint120).max - 1) {
            itemAmount = 664613997892457936451903530140172392;
        }

        (, , uint256 totalFilled, uint256 totalSize) = (
            context.seaport.getOrderStatus(
                context.executionState.orderHashes[orderIndex]
            )
        );

        return (FractionUtil
            .getPartialFillResults(
                uint120(totalFilled),
                uint120(totalSize),
                1,
                uint120(itemAmount + 1)
            )
            .status == FractionStatus.INVALID);
    }

    function ineligibleForNoSpecifiedOrdersAvailable(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // Must be a fulfill available method
        bytes4 action = context.action();
        if (
            action != context.seaport.fulfillAvailableAdvancedOrders.selector &&
            action != context.seaport.fulfillAvailableOrders.selector
        ) {
            return true;
        }

        // Exclude orders with criteria resolvers
        // TODO: Overfilter? Without this check, this test reverts with
        // ConsiderationCriteriaResolverOutOfRange()
        if (context.executionState.criteriaResolvers.length > 0) {
            return true;
        }

        return false;
    }
}

contract FuzzMutations is Test, FuzzExecutor {
    using FuzzEngineLib for FuzzTestContext;
    using MutationEligibilityLib for FuzzTestContext;
    using AdvancedOrderLib for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder;
    using OrderParametersLib for OrderParameters;
    using FuzzDerivers for FuzzTestContext;
    using FuzzInscribers for AdvancedOrder;
    using CheckHelpers for FuzzTestContext;
    using MutationHelpersLib for FuzzTestContext;
    using MutationFilters for FuzzTestContext;
    using ConsiderationItemLib for ConsiderationItem;

    function mutation_invalidContractOrderGenerateReverts(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        HashCalldataContractOfferer(payable(order.parameters.offerer))
            .setFailureReason(
                orderHash,
                OffererZoneFailureReason.ContractOfferer_generateReverts
            );

        exec(context);
    }

    function mutation_invalidContractOrderGenerateReturnsInvalidEncoding(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        HashCalldataContractOfferer(payable(order.parameters.offerer))
            .setFailureReason(
                orderHash,
                OffererZoneFailureReason
                    .ContractOfferer_generateReturnsInvalidEncoding
            );

        exec(context);
    }

    function mutation_invalidContractOrderRatifyReverts(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        HashCalldataContractOfferer(payable(order.parameters.offerer))
            .setFailureReason(
                orderHash,
                OffererZoneFailureReason.ContractOfferer_ratifyReverts
            );

        exec(context);
    }

    function mutation_invalidContractOrderInvalidMagicValue(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        HashCalldataContractOfferer(payable(order.parameters.offerer))
            .setFailureReason(
                orderHash,
                OffererZoneFailureReason.ContractOfferer_InvalidMagicValue
            );

        exec(context);
    }

    function mutation_invalidRestrictedOrderReverts(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        HashValidationZoneOfferer(payable(order.parameters.zone))
            .setFailureReason(orderHash, OffererZoneFailureReason.Zone_reverts);

        exec(context);
    }

    function mutation_invalidRestrictedOrderInvalidMagicValue(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        HashValidationZoneOfferer(payable(order.parameters.zone))
            .setFailureReason(
                orderHash,
                OffererZoneFailureReason.Zone_InvalidMagicValue
            );

        exec(context);
    }

    function mutation_invalidContractOrderInsufficientMinimumReceived(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        HashCalldataContractOfferer offerer = HashCalldataContractOfferer(
            payable(order.parameters.offerer)
        );

        offerer.setFailureReason(
            orderHash,
            OffererZoneFailureReason.ContractOfferer_InsufficientMinimumReceived
        );

        // TODO: operate on a fuzzed item (this is always the first item)
        offerer.addItemAmountMutation(
            Side.OFFER,
            0,
            order.parameters.offer[0].startAmount - 1,
            orderHash
        );

        exec(context);
    }

    function mutation_invalidContractOrderOfferAmountMismatch(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.parameters.offer[0].startAmount = 1;
        order.parameters.offer[0].endAmount = 2;

        exec(context);
    }

    function mutation_invalidContractOrderIncorrectMinimumReceived(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        HashCalldataContractOfferer offerer = HashCalldataContractOfferer(
            payable(order.parameters.offerer)
        );

        offerer.setFailureReason(
            orderHash,
            OffererZoneFailureReason.ContractOfferer_IncorrectMinimumReceived
        );

        // TODO: operate on a fuzzed item (this always operates on the last item)
        offerer.addDropItemMutation(
            Side.OFFER,
            order.parameters.offer.length - 1,
            orderHash
        );

        exec(context);
    }

    function mutation_invalidContractOrderConsiderationAmountMismatch(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.parameters.consideration[0].startAmount =
            order.parameters.consideration[0].endAmount +
            1;

        exec(context);
    }

    function mutation_invalidContractOrderExcessMaximumSpent(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        HashCalldataContractOfferer offerer = HashCalldataContractOfferer(
            payable(order.parameters.offerer)
        );

        offerer.setFailureReason(
            orderHash,
            OffererZoneFailureReason.ContractOfferer_ExcessMaximumSpent
        );

        offerer.addExtraItemMutation(
            Side.CONSIDERATION,
            ReceivedItem({
                itemType: ItemType.NATIVE,
                token: address(0),
                identifier: 0,
                amount: 1,
                recipient: payable(order.parameters.offerer)
            }),
            orderHash
        );

        exec(context);
    }

    function mutation_invalidContractOrderIncorrectMaximumSpent(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        HashCalldataContractOfferer offerer = HashCalldataContractOfferer(
            payable(order.parameters.offerer)
        );

        offerer.setFailureReason(
            orderHash,
            OffererZoneFailureReason.ContractOfferer_IncorrectMaximumSpent
        );

        // TODO: operate on a fuzzed item (this is always the first item)
        offerer.addItemAmountMutation(
            Side.CONSIDERATION,
            0,
            order.parameters.consideration[0].startAmount + 1,
            orderHash
        );

        exec(context);
    }

    function mutation_offerItemMissingApproval(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;

        // TODO: pick a random item (this always picks the first one)
        OfferItem memory item;
        for (uint256 i = 0; i < order.parameters.offer.length; ++i) {
            item = order.parameters.offer[i];
            if (
                !context.isFilteredOrNative(
                    item,
                    order.parameters.offerer,
                    order.parameters.conduitKey
                )
            ) {
                break;
            }
        }

        address approveTo = context.getApproveTo(order.parameters);
        vm.prank(order.parameters.offerer);
        if (item.itemType == ItemType.ERC20) {
            TestERC20(item.token).approve(approveTo, 0);
        } else {
            TestNFT(item.token).setApprovalForAll(approveTo, false);
        }

        exec(context);
    }

    function mutation_callerMissingApproval(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;

        // TODO: pick a random item (this always picks the first one)
        ConsiderationItem memory item;
        for (uint256 i = 0; i < order.parameters.consideration.length; ++i) {
            item = order.parameters.consideration[i];
            if (!context.isFilteredOrNative(item)) {
                break;
            }
        }

        address approveTo = context.getApproveTo();
        vm.prank(context.executionState.caller);
        if (item.itemType == ItemType.ERC20) {
            TestERC20(item.token).approve(approveTo, 0);
        } else {
            TestNFT(item.token).setApprovalForAll(approveTo, false);
        }

        exec(context);
    }

    function mutation_invalidMsgValue(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */
    ) external {
        AdvancedOrder memory order = context.executionState.orders[0];

        BasicOrderType orderType = order.getBasicOrderType();

        // BasicOrderType 0-7 are payable Native-Token routes
        if (uint8(orderType) < 8) {
            context.executionState.value = 0;
            // BasicOrderType 8 and above are nonpayable Token-Token routes
        } else {
            vm.deal(context.executionState.caller, 1);
            context.executionState.value = 1;
        }

        exec(context);
    }

    function mutation_insufficientNativeTokensSupplied(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */
    ) external {
        uint256 minimumRequired = context.expectations.minimumValue;

        context.executionState.value = minimumRequired - 1;

        exec(context);
    }

    function mutation_criteriaNotEnabledForItem(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */
    ) external {
        CriteriaResolver[] memory oldResolvers = context
            .executionState
            .criteriaResolvers;
        CriteriaResolver[] memory newResolvers = new CriteriaResolver[](
            oldResolvers.length + 1
        );
        for (uint256 i = 0; i < oldResolvers.length; ++i) {
            newResolvers[i] = oldResolvers[i];
        }

        uint256 orderIndex;
        Side side;

        for (
            ;
            orderIndex < context.executionState.orders.length;
            ++orderIndex
        ) {
            if (context.ineligibleWhenUnavailable(orderIndex)) {
                continue;
            }

            AdvancedOrder memory order = context.executionState.previewedOrders[
                orderIndex
            ];
            if (order.parameters.offer.length > 0) {
                side = Side.OFFER;
                break;
            } else if (order.parameters.consideration.length > 0) {
                side = Side.CONSIDERATION;
                break;
            }
        }

        newResolvers[oldResolvers.length] = CriteriaResolver({
            orderIndex: orderIndex,
            side: side,
            index: 0,
            identifier: 0,
            criteriaProof: new bytes32[](0)
        });

        context.executionState.criteriaResolvers = newResolvers;

        exec(context);
    }

    function mutation_invalidSignature(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // TODO: fuzz on size of invalid signature
        order.signature = "";

        exec(context);
    }

    function mutation_invalidSigner_BadSignature(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.signature[0] = bytes1(uint8(order.signature[0]) ^ 0x01);

        exec(context);
    }

    function mutation_invalidSigner_ModifiedOrder(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.parameters.salt ^= 0x01;

        exec(context);
    }

    function mutation_badSignatureV(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.signature[64] = 0xff;

        exec(context);
    }

    function mutation_badContractSignature_BadSignature(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        if (order.signature.length == 0) {
            order.signature = new bytes(1);
        }

        order.signature[0] ^= 0x01;

        exec(context);
    }

    function mutation_badContractSignature_ModifiedOrder(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.parameters.salt ^= 0x01;

        exec(context);
    }

    function mutation_badContractSignature_MissingMagic(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        EIP1271Offerer(payable(order.parameters.offerer)).returnEmpty();

        exec(context);
    }

    function mutation_considerationLengthNotEqualToTotalOriginal_ExtraItems(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];
        order.parameters.totalOriginalConsiderationItems =
            order.parameters.consideration.length -
            1;

        exec(context);
    }

    function mutation_considerationLengthNotEqualToTotalOriginal_MissingItems(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];
        order.parameters.totalOriginalConsiderationItems =
            order.parameters.consideration.length +
            1;

        exec(context);
    }

    function mutation_missingOriginalConsiderationItems(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];
        order.parameters.totalOriginalConsiderationItems =
            order.parameters.consideration.length +
            1;

        exec(context);
    }

    function mutation_invalidTime_NotStarted(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.parameters.startTime = block.timestamp + 1;
        order.parameters.endTime = block.timestamp + 2;

        exec(context);
    }

    function mutation_invalidTime_Expired(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.parameters.startTime = block.timestamp - 1;
        order.parameters.endTime = block.timestamp;

        exec(context);
    }

    function mutation_invalidConduit(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        // Note: We should also adjust approvals for any items approved on the
        // old conduit, but the error here will be thrown before transfers
        // begin to occur.
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.parameters.conduitKey = keccak256("invalid conduit");
        if (
            context.advancedOrdersSpace.orders[orderIndex].signatureMethod ==
            SignatureMethod.VALIDATE
        ) {
            order.inscribeOrderStatusValidated(true, context.seaport);
        } else if (context.executionState.caller != order.parameters.offerer) {
            AdvancedOrdersSpaceGenerator._signOrders(
                context.advancedOrdersSpace,
                context.executionState.orders,
                context.generatorContext
            );
        }

        context
            .executionState
            .previewedOrders[orderIndex]
            .parameters
            .conduitKey = keccak256("invalid conduit");

        context = context.withDerivedOrderDetails().withDerivedFulfillments();
        if (
            context.advancedOrdersSpace.orders[orderIndex].signatureMethod ==
            SignatureMethod.VALIDATE
        ) {
            order.inscribeOrderStatusValidated(true, context.seaport);
        }

        exec(context);
    }

    function mutation_badFraction_NoFill(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.numerator = 0;

        exec(context);
    }

    function mutation_badFraction_Overfill(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // TODO: fuzz on a range of potential overfill amounts
        order.numerator = 2;
        order.denominator = 1;

        exec(context);
    }

    function mutation_orderIsCancelled(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        bytes32 orderHash = mutationState.selectedOrderHash;
        FuzzInscribers.inscribeOrderStatusCancelled(
            orderHash,
            true,
            context.seaport
        );

        exec(context);
    }

    function mutation_orderAlreadyFilled(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;

        order.inscribeOrderStatusNumeratorAndDenominator(1, 1, context.seaport);

        exec(context);
    }

    function mutation_cannotCancelOrder(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;

        context.executionState.caller = address(
            uint160(order.parameters.offerer) - 1
        );

        exec(context);
    }

    function mutation_badFraction_partialContractOrder(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.numerator = 6;
        order.denominator = 9;

        exec(context);
    }

    function mutation_invalidFulfillmentComponentData(
        FuzzTestContext memory context
    ) external {
        if (context.executionState.fulfillments.length != 0) {
            context
                .executionState
                .fulfillments[0]
                .considerationComponents[0]
                .orderIndex = context.executionState.orders.length;
        }

        if (context.executionState.offerFulfillments.length != 0) {
            context.executionState.offerFulfillments[0][0].orderIndex = context
                .executionState
                .orders
                .length;
        }

        if (context.executionState.considerationFulfillments.length != 0) {
            context
            .executionState
            .considerationFulfillments[0][0].orderIndex = context
                .executionState
                .orders
                .length;
        }

        exec(context);
    }

    function mutation_missingFulfillmentComponentOnAggregation(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        if (mutationState.side == Side.OFFER) {
            if (context.executionState.offerFulfillments.length == 0) {
                context
                    .executionState
                    .offerFulfillments = new FulfillmentComponent[][](1);
            } else {
                context.executionState.offerFulfillments[
                    0
                ] = new FulfillmentComponent[](0);
            }
        } else if (mutationState.side == Side.CONSIDERATION) {
            context.executionState.considerationFulfillments[
                0
            ] = new FulfillmentComponent[](0);
        }

        exec(context);
    }

    function mutation_invalidMerkleProof(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 criteriaResolverIndex = mutationState
            .selectedCriteriaResolverIndex;
        CriteriaResolver memory resolver = context
            .executionState
            .criteriaResolvers[criteriaResolverIndex];

        bytes32 firstProofElement = resolver.criteriaProof[0];
        resolver.criteriaProof[0] = bytes32(uint256(firstProofElement) ^ 1);

        exec(context);
    }

    function mutation_offerAndConsiderationRequiredOnFulfillment(
        FuzzTestContext memory context
    ) external {
        context.executionState.fulfillments[0] = Fulfillment({
            offerComponents: new FulfillmentComponent[](0),
            considerationComponents: new FulfillmentComponent[](0)
        });

        exec(context);
    }

    function mutation_mismatchedFulfillmentOfferAndConsiderationComponents_Modified(
        FuzzTestContext memory context
    ) external {
        FulfillmentComponent[] memory firstOfferComponents = (
            context.executionState.fulfillments[0].offerComponents
        );

        for (uint256 i = 0; i < firstOfferComponents.length; ++i) {
            FulfillmentComponent memory component = (firstOfferComponents[i]);
            address token = context
                .executionState
                .orders[component.orderIndex]
                .parameters
                .offer[component.itemIndex]
                .token;
            address modifiedToken = address(uint160(token) ^ 1);
            context
                .executionState
                .orders[component.orderIndex]
                .parameters
                .offer[component.itemIndex]
                .token = modifiedToken;
        }

        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            AdvancedOrder memory order = context.executionState.orders[i];

            if (
                context.advancedOrdersSpace.orders[i].signatureMethod ==
                SignatureMethod.VALIDATE
            ) {
                order.inscribeOrderStatusValidated(true, context.seaport);
            } else if (
                context.executionState.caller != order.parameters.offerer
            ) {
                AdvancedOrdersSpaceGenerator._signOrders(
                    context.advancedOrdersSpace,
                    context.executionState.orders,
                    context.generatorContext
                );
            }
        }

        exec(context);
    }

    function mutation_mismatchedFulfillmentOfferAndConsiderationComponents_Swapped(
        FuzzTestContext memory context
    ) external {
        FulfillmentComponent[] memory firstOfferComponents = (
            context.executionState.fulfillments[0].offerComponents
        );

        FulfillmentComponent memory firstOfferComponent = (
            firstOfferComponents[0]
        );

        SpentItem memory item = context
            .executionState
            .orderDetails[firstOfferComponent.orderIndex]
            .offer[firstOfferComponent.itemIndex];
        uint256 i = 1;
        for (; i < context.executionState.fulfillments.length; ++i) {
            FulfillmentComponent memory considerationComponent = (
                context.executionState.fulfillments[i].considerationComponents[
                    0
                ]
            );
            ReceivedItem memory compareItem = context
                .executionState
                .orderDetails[considerationComponent.orderIndex]
                .consideration[considerationComponent.itemIndex];
            if (
                item.itemType != compareItem.itemType ||
                item.token != compareItem.token ||
                item.identifier != compareItem.identifier
            ) {
                break;
            }
        }

        // swap offer components
        FulfillmentComponent[] memory swappedOfferComponents = (
            context.executionState.fulfillments[i].offerComponents
        );

        bytes32 swappedPointer;
        assembly {
            swappedPointer := swappedOfferComponents
            swappedOfferComponents := firstOfferComponents
            firstOfferComponents := swappedPointer
        }

        context
            .executionState
            .fulfillments[0]
            .offerComponents = firstOfferComponents;
        context
            .executionState
            .fulfillments[i]
            .offerComponents = swappedOfferComponents;

        exec(context);
    }

    function mutation_invalidWildcardProof(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 criteriaResolverIndex = mutationState
            .selectedCriteriaResolverIndex;
        CriteriaResolver memory resolver = context
            .executionState
            .criteriaResolvers[criteriaResolverIndex];

        bytes32[] memory criteriaProof = new bytes32[](1);
        resolver.criteriaProof = criteriaProof;

        exec(context);
    }

    function mutation_orderCriteriaResolverOutOfRange(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */
    ) external {
        CriteriaResolver[] memory oldResolvers = context
            .executionState
            .criteriaResolvers;
        CriteriaResolver[] memory newResolvers = new CriteriaResolver[](
            oldResolvers.length + 1
        );
        for (uint256 i = 0; i < oldResolvers.length; ++i) {
            newResolvers[i] = oldResolvers[i];
        }

        newResolvers[oldResolvers.length] = CriteriaResolver({
            orderIndex: context.executionState.orders.length,
            side: Side.OFFER,
            index: 0,
            identifier: 0,
            criteriaProof: new bytes32[](0)
        });

        context.executionState.criteriaResolvers = newResolvers;

        exec(context);
    }

    function mutation_offerCriteriaResolverOutOfRange(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 criteriaResolverIndex = mutationState
            .selectedCriteriaResolverIndex;
        CriteriaResolver memory resolver = context
            .executionState
            .criteriaResolvers[criteriaResolverIndex];

        OrderDetails memory order = context.executionState.orderDetails[
            resolver.orderIndex
        ];
        resolver.index = order.offer.length;

        exec(context);
    }

    function mutation_considerationCriteriaResolverOutOfRange(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 criteriaResolverIndex = mutationState
            .selectedCriteriaResolverIndex;
        CriteriaResolver memory resolver = context
            .executionState
            .criteriaResolvers[criteriaResolverIndex];

        OrderDetails memory order = context.executionState.orderDetails[
            resolver.orderIndex
        ];
        resolver.index = order.consideration.length;

        exec(context);
    }

    function mutation_unresolvedCriteria(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 criteriaResolverIndex = mutationState
            .selectedCriteriaResolverIndex;

        CriteriaResolver[] memory oldResolvers = context
            .executionState
            .criteriaResolvers;
        CriteriaResolver[] memory newResolvers = new CriteriaResolver[](
            oldResolvers.length - 1
        );
        for (uint256 i = 0; i < criteriaResolverIndex; ++i) {
            newResolvers[i] = oldResolvers[i];
        }

        for (
            uint256 i = criteriaResolverIndex + 1;
            i < oldResolvers.length;
            ++i
        ) {
            newResolvers[i - 1] = oldResolvers[i];
        }

        context.executionState.criteriaResolvers = newResolvers;

        exec(context);
    }

    function mutation_missingItemAmount_OfferItem_FulfillAvailable(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */
    ) external {
        for (
            uint256 i;
            i < context.executionState.offerFulfillments.length;
            i++
        ) {
            FulfillmentComponent memory fulfillmentComponent = context
                .executionState
                .offerFulfillments[i][0];

            AdvancedOrder memory order = context.executionState.orders[
                fulfillmentComponent.orderIndex
            ];

            if (
                context
                    .executionState
                    .orderDetails[fulfillmentComponent.orderIndex]
                    .offer[fulfillmentComponent.itemIndex]
                    .itemType != ItemType.ERC721
            ) {
                if (
                    context.expectations.expectedAvailableOrders[
                        fulfillmentComponent.orderIndex
                    ]
                ) {
                    order
                        .parameters
                        .offer[fulfillmentComponent.itemIndex]
                        .startAmount = 0;
                    order
                        .parameters
                        .offer[fulfillmentComponent.itemIndex]
                        .endAmount = 0;

                    if (order.parameters.orderType == OrderType.CONTRACT) {
                        HashCalldataContractOfferer(
                            payable(order.parameters.offerer)
                        ).addItemAmountMutation(
                                Side.OFFER,
                                fulfillmentComponent.itemIndex,
                                0,
                                context.executionState.orderHashes[
                                    fulfillmentComponent.orderIndex
                                ]
                            );
                    }

                    if (
                        context
                            .advancedOrdersSpace
                            .orders[fulfillmentComponent.orderIndex]
                            .signatureMethod == SignatureMethod.VALIDATE
                    ) {
                        order.inscribeOrderStatusValidated(
                            true,
                            context.seaport
                        );
                    } else {
                        AdvancedOrdersSpaceGenerator._signOrders(
                            context.advancedOrdersSpace,
                            context.executionState.orders,
                            context.generatorContext
                        );
                    }

                    break;
                }
            }
        }

        exec(context);
    }

    function mutation_missingItemAmount_OfferItem(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        uint256 firstNon721OfferItem;
        for (uint256 i; i < order.parameters.offer.length; i++) {
            OfferItem memory item = order.parameters.offer[i];
            if (
                item.itemType != ItemType.ERC721 &&
                item.itemType != ItemType.ERC721_WITH_CRITERIA
            ) {
                firstNon721OfferItem = i;
                break;
            }
        }

        order.parameters.offer[firstNon721OfferItem].startAmount = 0;
        order.parameters.offer[firstNon721OfferItem].endAmount = 0;

        if (
            context.advancedOrdersSpace.orders[orderIndex].signatureMethod ==
            SignatureMethod.VALIDATE
        ) {
            order.inscribeOrderStatusValidated(true, context.seaport);
        } else if (context.executionState.caller != order.parameters.offerer) {
            AdvancedOrdersSpaceGenerator._signOrders(
                context.advancedOrdersSpace,
                context.executionState.orders,
                context.generatorContext
            );
        }

        exec(context);
    }

    function mutation_missingItemAmount_ConsiderationItem(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        uint256 firstNon721ConsiderationItem;
        for (uint256 i; i < order.parameters.consideration.length; i++) {
            ConsiderationItem memory item = order.parameters.consideration[i];
            if (
                item.itemType != ItemType.ERC721 &&
                item.itemType != ItemType.ERC721_WITH_CRITERIA
            ) {
                firstNon721ConsiderationItem = i;
                break;
            }
        }

        order
            .parameters
            .consideration[firstNon721ConsiderationItem]
            .startAmount = 0;
        order
            .parameters
            .consideration[firstNon721ConsiderationItem]
            .endAmount = 0;

        if (order.parameters.orderType == OrderType.CONTRACT) {
            HashCalldataContractOfferer(payable(order.parameters.offerer))
                .addItemAmountMutation(
                    Side.CONSIDERATION,
                    firstNon721ConsiderationItem,
                    0,
                    mutationState.selectedOrderHash
                );
        }

        if (
            context.advancedOrdersSpace.orders[orderIndex].signatureMethod ==
            SignatureMethod.VALIDATE
        ) {
            order.inscribeOrderStatusValidated(true, context.seaport);
        } else if (context.executionState.caller != order.parameters.offerer) {
            AdvancedOrdersSpaceGenerator._signOrders(
                context.advancedOrdersSpace,
                context.executionState.orders,
                context.generatorContext
            );
        }

        exec(context);
    }

    function mutation_noContract(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        address targetContract;

        for (
            uint256 i;
            i < context.expectations.expectedExplicitExecutions.length;
            i++
        ) {
            address candidate = context
                .expectations
                .expectedExplicitExecutions[i]
                .item
                .token;

            if (candidate != address(0)) {
                targetContract = candidate;
                break;
            }
        }

        for (uint256 i; i < context.executionState.orders.length; i++) {
            AdvancedOrder memory order = context.executionState.orders[i];

            for (uint256 j; j < order.parameters.consideration.length; j++) {
                ConsiderationItem memory item = order.parameters.consideration[
                    j
                ];
                if (item.token == targetContract) {
                    item.token = mutationState.selectedArbitraryAddress;
                }
            }

            for (uint256 j; j < order.parameters.offer.length; j++) {
                OfferItem memory item = order.parameters.offer[j];
                if (item.token == targetContract) {
                    item.token = mutationState.selectedArbitraryAddress;
                }
            }

            if (
                context.advancedOrdersSpace.orders[i].signatureMethod ==
                SignatureMethod.VALIDATE
            ) {
                order.inscribeOrderStatusValidated(true, context.seaport);
            } else if (
                context.executionState.caller != order.parameters.offerer
            ) {
                AdvancedOrdersSpaceGenerator._signOrders(
                    context.advancedOrdersSpace,
                    context.executionState.orders,
                    context.generatorContext
                );
            }
        }

        exec(context);
    }

    function mutation_unusedItemParameters_Token(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // Add nonzero token address to first native item
        bool nativeItemFound;
        for (uint256 i; i < order.parameters.offer.length; i++) {
            OfferItem memory item = order.parameters.offer[i];
            if (item.itemType == ItemType.NATIVE) {
                item.token = address(1);
                nativeItemFound = true;
                break;
            }
        }

        if (!nativeItemFound) {
            for (uint256 i; i < order.parameters.consideration.length; i++) {
                ConsiderationItem memory item = order.parameters.consideration[
                    i
                ];

                if (item.itemType == ItemType.NATIVE) {
                    item.token = address(1);
                    nativeItemFound = true;
                    break;
                }
            }
        }

        // Re-sign order
        if (
            context.advancedOrdersSpace.orders[orderIndex].signatureMethod ==
            SignatureMethod.VALIDATE
        ) {
            order.inscribeOrderStatusValidated(true, context.seaport);
        } else if (context.executionState.caller != order.parameters.offerer) {
            AdvancedOrdersSpaceGenerator._signOrders(
                context.advancedOrdersSpace,
                context.executionState.orders,
                context.generatorContext
            );
        }

        exec(context);
    }

    function mutation_unusedItemParameters_Identifier(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // Add nonzero identifierOrCriteria to first valid item
        bool validItemFound;
        for (uint256 i; i < order.parameters.offer.length; i++) {
            OfferItem memory item = order.parameters.offer[i];
            if (
                item.itemType == ItemType.ERC20 ||
                item.itemType == ItemType.NATIVE
            ) {
                item.identifierOrCriteria = 1;
                validItemFound = true;
                break;
            }
        }

        if (!validItemFound) {
            for (uint256 i; i < order.parameters.consideration.length; i++) {
                ConsiderationItem memory item = order.parameters.consideration[
                    i
                ];
                if (
                    item.itemType == ItemType.ERC20 ||
                    item.itemType == ItemType.NATIVE
                ) {
                    item.identifierOrCriteria = 1;
                    validItemFound = true;
                    break;
                }
            }
        }

        // Re-sign order
        if (
            context.advancedOrdersSpace.orders[orderIndex].signatureMethod ==
            SignatureMethod.VALIDATE
        ) {
            order.inscribeOrderStatusValidated(true, context.seaport);
        } else if (context.executionState.caller != order.parameters.offerer) {
            AdvancedOrdersSpaceGenerator._signOrders(
                context.advancedOrdersSpace,
                context.executionState.orders,
                context.generatorContext
            );
        }

        exec(context);
    }

    function mutation_invalidERC721TransferAmount(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // Add invalid amount to first valid item
        bool validItemFound;
        for (uint256 i; i < order.parameters.offer.length; i++) {
            OfferItem memory item = order.parameters.offer[i];
            if (
                item.itemType == ItemType.ERC721 ||
                item.itemType == ItemType.ERC721_WITH_CRITERIA
            ) {
                item.startAmount = 2;
                item.endAmount = 2;
                validItemFound = true;
                break;
            }
        }

        if (!validItemFound) {
            for (uint256 i; i < order.parameters.consideration.length; i++) {
                ConsiderationItem memory item = order.parameters.consideration[
                    i
                ];
                if (
                    item.itemType == ItemType.ERC721 ||
                    item.itemType == ItemType.ERC721_WITH_CRITERIA
                ) {
                    item.startAmount = 2;
                    item.endAmount = 2;
                    validItemFound = true;
                    break;
                }
            }
        }

        // Re-sign order
        if (
            context.advancedOrdersSpace.orders[orderIndex].signatureMethod ==
            SignatureMethod.VALIDATE
        ) {
            order.inscribeOrderStatusValidated(true, context.seaport);
        } else if (context.executionState.caller != order.parameters.offerer) {
            AdvancedOrdersSpaceGenerator._signOrders(
                context.advancedOrdersSpace,
                context.executionState.orders,
                context.generatorContext
            );
        }

        exec(context);
    }

    function mutation_considerationNotMet(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        ConsiderationItem[] memory newConsideration = new ConsiderationItem[](
            order.parameters.consideration.length + 1
        );
        for (uint256 i; i < order.parameters.consideration.length; i++) {
            newConsideration[i] = order.parameters.consideration[i];
        }
        newConsideration[
            order.parameters.consideration.length
        ] = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.NATIVE)
            .withAmount(100);
        order.parameters.consideration = newConsideration;

        exec(context);
    }

    function mutation_inexactFraction(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        uint256 itemAmount = order.parameters.offer.length == 0
            ? order.parameters.consideration[0].startAmount
            : order.parameters.offer[0].startAmount;

        if (itemAmount == 0) {
            itemAmount = order.parameters.offer.length == 0
                ? order.parameters.consideration[0].endAmount
                : order.parameters.offer[0].endAmount;
        }

        // This isn't perfect, but odds of hitting it are slim to none
        if (itemAmount > type(uint120).max - 1) {
            itemAmount = 664613997892457936451903530140172392;
        }

        order.numerator = 1;
        order.denominator = uint120(itemAmount) + 1;

        exec(context);
    }

    function mutation_partialFillOverflow(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.numerator = 1;
        order.denominator = 664613997892457936451903530140172393;

        order.inscribeOrderStatusNumeratorAndDenominator(
            1,
            664613997892457936451903530140172297,
            context.seaport
        );

        exec(context);
    }

    function mutation_partialFillsNotEnabledForOrder(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.numerator = 1;
        order.denominator = 10;

        exec(context);
    }

    function mutation_noSpecifiedOrdersAvailable(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */
    ) external {
        for (uint256 i; i < context.executionState.orders.length; i++) {
            AdvancedOrder memory order = context.executionState.orders[i];
            order.parameters.consideration = new ConsiderationItem[](0);
            order.parameters.totalOriginalConsiderationItems = 0;

            // Re-sign order
            if (
                context.advancedOrdersSpace.orders[i].signatureMethod ==
                SignatureMethod.VALIDATE
            ) {
                order.inscribeOrderStatusValidated(true, context.seaport);
            } else if (
                context.executionState.caller != order.parameters.offerer
            ) {
                AdvancedOrdersSpaceGenerator._signOrders(
                    context.advancedOrdersSpace,
                    context.executionState.orders,
                    context.generatorContext
                );
            }
        }
        context.executionState.offerFulfillments = new FulfillmentComponent[][](
            0
        );
        context
            .executionState
            .considerationFulfillments = new FulfillmentComponent[][](0);

        exec(context);
    }
}
