// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { FuzzExecutor } from "./FuzzExecutor.sol";
import { FuzzTestContext, MutationState } from "./FuzzTestContextLib.sol";
import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { OrderEligibilityLib } from "./FuzzMutationHelpers.sol";

import {
    AdvancedOrder,
    Execution,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    OrderComponents,
    OrderParameters
} from "seaport-sol/SeaportStructs.sol";

import { ItemType, Side } from "seaport-sol/SeaportEnums.sol";

import {
    AdvancedOrderLib,
    OrderParametersLib
} from "seaport-sol/SeaportSol.sol";

import { EOASignature, SignatureMethod, Offerer } from "./FuzzGenerators.sol";

import { OrderType } from "seaport-sol/SeaportEnums.sol";

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { FuzzInscribers } from "./FuzzInscribers.sol";
import { AdvancedOrdersSpaceGenerator } from "./FuzzGenerators.sol";

import { EIP1271Offerer } from "./EIP1271Offerer.sol";

import { FuzzDerivers } from "./FuzzDerivers.sol";

import { ConduitChoice } from "seaport-sol/StructSpace.sol";

import "forge-std/console.sol";

library MutationFilters {
    using FuzzEngineLib for FuzzTestContext;
    using AdvancedOrderLib for AdvancedOrder;
    using FuzzDerivers for FuzzTestContext;

    function ineligibleForAnySignatureFailure(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (order.parameters.orderType == OrderType.CONTRACT) {
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
        uint256 /* orderIndex */,
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

        // Note: We're speculatively applying the mutation here and slightly
        // breaking the rules. Make sure to undo this mutation.
        bytes32 oldConduitKey = order.parameters.conduitKey;
        order.parameters.conduitKey = keccak256("invalid conduit");
        (
            Execution[] memory implicitExecutions,
            Execution[] memory explicitExecutions
        ) = context.getDerivedExecutions();

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
            for (uint256 i = 0; i < implicitExecutions.length; ++i) {
                if (
                    implicitExecutions[i].conduitKey ==
                    keccak256("invalid conduit") &&
                    implicitExecutions[i].item.itemType != ItemType.NATIVE
                ) {
                    locatedInvalidConduitExecution = true;
                    break;
                }
            }
        }
        order.parameters.conduitKey = oldConduitKey;

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
        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (order.parameters.orderType == OrderType.CONTRACT) {
            return true;
        }

        return false;
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
        AdvancedOrder memory /* order */,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

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
        bytes4 action = context.action();
        if (order.parameters.orderType != OrderType.CONTRACT) {
            return true;
        }

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

        if (!context.expectations.expectedAvailableOrders[orderIndex]) {
            return true;
        }

        if (order.numerator == 1 && order.denominator == 1) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidFulfillmentComponentData(
        AdvancedOrder memory /* order */,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleForFulfillmentIngestingFunctions(context)) {
            return true;
        }

        return false;
    }

    function ineligibleForMissingFulfillmentComponentOnAggregation(
        AdvancedOrder memory /* order */,
        uint256 /* orderIndex */,
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
        AdvancedOrder memory /* order */,
        uint256 /* orderIndex */,
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

    function ineligibleForMismatchedFulfillmentOfferAndConsiderationComponents(
        AdvancedOrder memory /* order */,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal returns (bool) {
        bytes4 action = context.action();

        if (action != context.seaport.matchAdvancedOrders.selector) {
            return true;
        }

        return false;
    }
}

contract FuzzMutations is Test, FuzzExecutor {
    using FuzzEngineLib for FuzzTestContext;
    using OrderEligibilityLib for FuzzTestContext;
    using AdvancedOrderLib for AdvancedOrder;
    using OrderParametersLib for OrderParameters;
    using FuzzDerivers for FuzzTestContext;
    using FuzzInscribers for AdvancedOrder;

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
        // TODO: Remove this if we can, since this modifies bulk signatures.
        if (order.parameters.offerer.code.length == 0) {
            context
                .advancedOrdersSpace
                .orders[orderIndex]
                .signatureMethod = SignatureMethod.EOA;
            context
                .advancedOrdersSpace
                .orders[orderIndex]
                .eoaSignatureType = EOASignature.STANDARD;
        }
        if (context.executionState.caller != order.parameters.offerer) {
            AdvancedOrdersSpaceGenerator._signOrders(
                context.advancedOrdersSpace,
                context.executionState.orders,
                context.generatorContext
            );
        }
        context = context.withDerivedFulfillments();
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

        order.numerator = 2;
        order.denominator = 1;

        exec(context);
    }

    function mutation_orderIsCancelled(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;

        bytes32 orderHash = context.executionState.orderHashes[orderIndex];
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
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.inscribeOrderStatusNumeratorAndDenominator(1, 1, context.seaport);

        exec(context);
    }

    function mutation_cannotCancelOrder(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        context.executionState.caller = address(
            uint160(order.parameters.offerer) - 1
        );

        exec(context);
    }

    function mutation_badFraction_partialContractOrder(
        FuzzTestContext memory context
    ) external {
        context.setIneligibleOrders(
            MutationFilters.ineligibleForBadFractionPartialContractOrder
        );

        (AdvancedOrder memory order, ) = context.selectEligibleOrder();

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

    function mutation_offerAndConsiderationRequiredOnFulfillment(
        FuzzTestContext memory context
    ) external {
        context.executionState.fulfillments[0] = Fulfillment({
            offerComponents: new FulfillmentComponent[](0),
            considerationComponents: new FulfillmentComponent[](0)
        });

        exec(context);
    }

    function mutation_mismatchedFulfillmentOfferAndConsiderationComponents(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        Fulfillment memory selectedFulfillment = context
            .executionState
            .fulfillments[mutationState.fulfillmentIndex];

        uint256 orderIndex = selectedFulfillment.offerComponents[0].orderIndex;
        uint256 itemIndex = selectedFulfillment.offerComponents[0].itemIndex;

        AdvancedOrder memory order = context.executionState.orders[orderIndex];
        OfferItem memory offerItem = order.parameters.offer[itemIndex];

        offerItem.identifierOrCriteria = offerItem.identifierOrCriteria + 1;

        // TODO: Remove this if we can, since this modifies bulk signatures.
        if (order.parameters.offerer.code.length == 0) {
            context
                .advancedOrdersSpace
                .orders[orderIndex]
                .signatureMethod = SignatureMethod.EOA;
            context
                .advancedOrdersSpace
                .orders[orderIndex]
                .eoaSignatureType = EOASignature.STANDARD;
        }
        if (context.executionState.caller != order.parameters.offerer) {
            AdvancedOrdersSpaceGenerator._signOrders(
                context.advancedOrdersSpace,
                context.executionState.orders,
                context.generatorContext
            );
        }

        if (
            context.advancedOrdersSpace.orders[orderIndex].signatureMethod ==
            SignatureMethod.VALIDATE
        ) {
            order.inscribeOrderStatusValidated(true, context.seaport);
        }

        exec(context);
    }

    // /**
    //  * @dev Revert with an error when the initial offer item named by a
    //  *      fulfillment component does not match the type, token, identifier,
    //  *      or conduit preference of the initial consideration item.
    //  *
    //  * @param fulfillmentIndex The index of the fulfillment component that
    //  *                         does not match the initial offer item.
    //  */
    // error MismatchedFulfillmentOfferAndConsiderationComponents(
    //     uint256 fulfillmentIndex
    // );
}
