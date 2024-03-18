// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    Execution,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType, OrderType, Side } from "seaport-sol/src/SeaportEnums.sol";

import {
    AdvancedOrderLib,
    OrderParametersLib,
    ConsiderationItemLib,
    ItemType,
    BasicOrderType,
    ConsiderationItemLib
} from "seaport-sol/src/SeaportSol.sol";

import {
    FulfillmentDetails,
    OrderDetails
} from "seaport-sol/src/fulfillments/lib/Structs.sol";

import {
    ContractOrderRebate,
    UnavailableReason
} from "seaport-sol/src/SpaceEnums.sol";

import { FractionStatus, FractionUtil } from "./FractionUtil.sol";

import {
    AdvancedOrdersSpaceGenerator,
    Offerer,
    SignatureMethod
} from "./FuzzGenerators.sol";

import { FuzzTestContext, MutationState } from "./FuzzTestContextLib.sol";

import { FuzzEngineLib } from "./FuzzEngineLib.sol";

import { FuzzInscribers } from "./FuzzInscribers.sol";

import { FulfillmentDetailsHelper, FuzzDerivers } from "./FuzzDerivers.sol";

import { CheckHelpers } from "./FuzzSetup.sol";

import { FuzzExecutor } from "./FuzzExecutor.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import {
    MutationEligibilityLib,
    MutationHelpersLib
} from "./FuzzMutationHelpers.sol";

import { EIP1271Offerer } from "./EIP1271Offerer.sol";

import {
    HashCalldataContractOfferer
} from "../../../../contracts/test/HashCalldataContractOfferer.sol";

import {
    HashValidationZoneOfferer
} from "../../../../contracts/test/HashValidationZoneOfferer.sol";

import {
    OffererZoneFailureReason
} from "../../../../contracts/test/OffererZoneFailureReason.sol";

interface TestERC20 {
    function approve(address spender, uint256 amount) external;
}

interface TestNFT {
    function setApprovalForAll(address operator, bool approved) external;
}

library MutationFilters {
    using AdvancedOrderLib for AdvancedOrder;
    using FulfillmentDetailsHelper for FuzzTestContext;
    using FuzzDerivers for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;
    using FuzzHelpers for AdvancedOrder;
    using MutationHelpersLib for FuzzTestContext;

    // The following functions are ineligibility helpers. They're prefixed with
    // `ineligibleWhen` and then have a description of what they check for. They
    // can be stitched together to form the eligibility filter for a given
    // mutation. The eligibility filters are prefixed with `ineligibleFor`
    // followed by the name of the failure the mutation targets.

    function ineligibleWhenUnavailable(
        FuzzTestContext memory context,
        uint256 orderIndex
    ) internal pure returns (bool) {
        return
            context.executionState.orderDetails[orderIndex].unavailableReason !=
            UnavailableReason.AVAILABLE;
    }

    function ineligibleWhenBasic(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleWhenFulfillAvailable(
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

    function ineligibleWhenMatch(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();
        if (
            action == context.seaport.matchOrders.selector ||
            action == context.seaport.matchAdvancedOrders.selector
        ) {
            return true;
        }

        return false;
    }

    function ineligibleWhenNotMatch(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();
        if (
            action != context.seaport.matchOrders.selector &&
            action != context.seaport.matchAdvancedOrders.selector
        ) {
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
            action == context.seaport.fulfillOrder.selector ||
            action == context.seaport.matchOrders.selector ||
            ineligibleWhenBasic(context)
        ) {
            return true;
        }

        return false;
    }

    function ineligibleWhenUnavailableOrNotAdvanced(
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

    function ineligibleWhenNotContractOrderOrFulfillAvailable(
        AdvancedOrder memory order,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleWhenNotContractOrder(order)) {
            return true;
        }
        return ineligibleWhenFulfillAvailable(context);
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

    function ineligibleWhenFulfillAvailableOrNotAvailableOrNotRestricted(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (ineligibleWhenNotRestrictedOrder(order)) {
            return true;
        }

        if (ineligibleWhenFulfillAvailable(context)) {
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

    function ineligibleWhenNoConsiderationLength(
        AdvancedOrder memory order
    ) internal pure returns (bool) {
        return order.parameters.consideration.length == 0;
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
            i < context.executionState.orderDetails.length;
            ++i
        ) {
            if (
                context.executionState.orderDetails[i].unavailableReason ==
                UnavailableReason.AVAILABLE
            ) {
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
        ).failureReasons(
                context.executionState.orderDetails[orderIndex].orderHash
            );

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
        if (ineligibleWhenNoConsiderationLength(order)) {
            return true;
        }

        return
            ineligibleWhenNotActiveTimeOrNotContractOrder(
                order,
                orderIndex,
                context
            );
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

    function ineligibleWhenAnySignatureFailureRequired(
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
            context.executionState.orderDetails[orderIndex].orderHash
        );

        if (isValidated) {
            return true;
        }

        return false;
    }

    function ineligibleWhenEOASignatureFailureRequire(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        if (
            ineligibleWhenAnySignatureFailureRequired(
                order,
                orderIndex,
                context
            )
        ) {
            return true;
        }

        if (order.parameters.offerer.code.length != 0) {
            return true;
        }

        return false;
    }

    function ineligibleWhenNotFulfillmentIngestingFunction(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        bytes4 action = context.action();

        if (
            action == context.seaport.fulfillAdvancedOrder.selector ||
            action == context.seaport.fulfillOrder.selector ||
            ineligibleWhenBasic(context)
        ) {
            return true;
        }

        return false;
    }

    // The following functions are ineligibility filters.  These should
    // encapsulate the logic for determining whether an order is ineligible
    // for a given mutation. These functions are wired up with their
    // corresponding mutation in `FuzzMutationSelectorLib.sol`.

    function ineligibleForOfferItemMissingApproval(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        // The target failure can't be triggered if the order isn't available.
        // Seaport only checks for approval when the order is available and
        // therefore items might actually be transferred.
        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        // The target failure can't be triggered if the order doesn't have an
        // offer item that is non-native and non-filtered. Native tokens don't
        // have the approval concept and filtered items are not transferred so
        // they don't get checked.
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
        // The target failure can't be triggerer when calling the match
        // functions because the caller does not provide any items during match
        // actions.
        if (ineligibleWhenMatch(context)) {
            return true;
        }

        // The target failure can't be triggered if the order isn't available.
        // Approval is not required for items on unavailable orders as their
        // associated transfers are not attempted.
        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        // The target failure can't be triggered on some basic order routes; the
        // caller does not need ERC20 approvals when accepting bids (as the
        // offerer provides the ERC20 tokens).
        uint256 eligibleItemTotal = order.parameters.consideration.length;
        if (ineligibleWhenBasic(context)) {
            if (order.parameters.offer[0].itemType == ItemType.ERC20) {
                eligibleItemTotal = 1;
            }
        }

        // The target failure can't be triggered if the order doesn't have a
        // consideration item that is non-native and non-filtered. Native tokens
        // don't have the approval concept and filtered items are not
        // transferred so approvals are not required.
        bool locatedEligibleConsiderationItem;
        for (uint256 i = 0; i < eligibleItemTotal; ++i) {
            ConsiderationItem memory item = order.parameters.consideration[i];
            if (!context.isFilteredOrNative(item)) {
                locatedEligibleConsiderationItem = true;
                break;
            }
        }

        if (!locatedEligibleConsiderationItem) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidMsgValue(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be triggered when calling a non-basic
        // function because only the BasicOrderFiller checks the msg.value and
        // enforces payable and non-payable routes. Exception: reentrancy.
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
        // The target failure can't be triggered unless the context produces at
        // least one native token transfer.
        if (context.expectations.expectedImpliedNativeExecutions != 0) {
            return true;
        }

        // The target failure cannot be triggered unless some amount of native
        // tokens are actually required.
        uint256 minimumRequired = context.expectations.minimumValue;

        if (minimumRequired == 0) {
            return true;
        }

        return false;
    }

    function ineligibleForNativeTokenTransferGenericFailure(
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        // The target failure can't be triggered unless the context produces at
        // least one native token transfer.
        if (context.expectations.expectedImpliedNativeExecutions == 0) {
            return true;
        }

        // The target failure cannot be triggered unless some amount of native
        // tokens are actually required.
        uint256 minimumRequired = context.expectations.minimumValue;

        if (minimumRequired == 0) {
            return true;
        }

        return false;
    }

    function ineligibleForCriteriaNotEnabledForItem(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be reached unless the function call is an
        // advanced type. Non-advanced functions don't have the criteria concept
        // and the test framework doesn't pass them in.
        if (ineligibleWhenNotAdvanced(context)) {
            return true;
        }

        // The target failure can't be triggered if there is no order that is
        // available and has items.
        bool locatedItem;
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            if (ineligibleWhenUnavailable(context, i)) {
                continue;
            }

            AdvancedOrder memory order = context.executionState.orders[i];

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

    function ineligibleForInvalidProof_Merkle(
        CriteriaResolver memory criteriaResolver,
        uint256 /* criteriaResolverIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be reached unless the function call is an
        // advanced type. Non-advanced functions don't have the criteria concept
        // and the test framework doesn't pass them in. Further, the criteria
        // resolver must point to an available order.
        if (
            ineligibleWhenUnavailableOrNotAdvanced(
                context,
                criteriaResolver.orderIndex
            )
        ) {
            return true;
        }

        // The target failure can't be triggered if there is no criteria proof.
        // The presence of a criteria proof serves as a proxy for non-wildcard
        // criteria.
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
        // The target failure can't be reached unless the function call is an
        // advanced type. Non-advanced functions don't have the criteria concept
        // and the test framework doesn't pass them in. Further, the criteria
        // resolver must point to an available order.
        if (
            ineligibleWhenUnavailableOrNotAdvanced(
                context,
                criteriaResolver.orderIndex
            )
        ) {
            return true;
        }

        // The target failure can't be triggered if there are one or criteria
        // proofs. The presence of a criteria proof serves as a proxy for
        // non-wildcard criteria.
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
        // The target failure can't be reached unless the function call is an
        // advanced type. Non-advanced functions don't have the criteria concept
        // and the test framework doesn't pass them in. Further, the criteria
        // resolver must point to an available order.
        if (
            ineligibleWhenUnavailableOrNotAdvanced(
                context,
                criteriaResolver.orderIndex
            )
        ) {
            return true;
        }

        // This filter handles the offer side. The next one handles the
        // consideration side. They're split out because the mutations need to
        // be done differently.
        if (criteriaResolver.side != Side.OFFER) {
            return true;
        }

        // The target failure can't be triggered if the criteria resolver is
        // referring to a collection-level criteria item on a contract order.
        if (
            context
                .executionState
                .orders[criteriaResolver.orderIndex]
                .parameters
                .orderType ==
            OrderType.CONTRACT &&
            context
                .executionState
                .orders[criteriaResolver.orderIndex]
                .parameters
                .offer[criteriaResolver.index]
                .identifierOrCriteria ==
            0
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForConsiderationCriteriaResolverFailure(
        CriteriaResolver memory criteriaResolver,
        uint256 /* criteriaResolverIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be reached unless the function call is an
        // advanced type. Non-advanced functions don't have the criteria concept
        // and the test framework doesn't pass them in. Further, the criteria
        // resolver must point to an available order.
        if (
            ineligibleWhenUnavailableOrNotAdvanced(
                context,
                criteriaResolver.orderIndex
            )
        ) {
            return true;
        }

        // This one handles the consideration side.  The previous one handles
        // the offer side.
        if (criteriaResolver.side != Side.CONSIDERATION) {
            return true;
        }

        // The target failure can't be triggered if the criteria resolver is
        // referring to a collection-level criteria item on a contract order.
        if (
            context
                .executionState
                .orders[criteriaResolver.orderIndex]
                .parameters
                .orderType ==
            OrderType.CONTRACT &&
            context
                .executionState
                .orders[criteriaResolver.orderIndex]
                .parameters
                .consideration[criteriaResolver.index]
                .identifierOrCriteria ==
            0
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForConsiderationLengthNotEqualToTotalOriginal(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        // The target failure can't be triggered if the order isn't available.
        // Seaport only compares the consideration length to the total original
        // length if the order is not skipped.
        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        // TODO: This is slightly overly restrictive. It's possible to trigger
        // this by calling validate directly, which is not something the test
        // framework does yet.
        //
        // The target failure can't be triggered if the order is not a contract
        // order. Seaport only compares the consideration length to the total
        // original length in `_getGeneratedOrder`, which is contract order
        // specific (except in validate, as described in the TODO above).
        if (order.parameters.orderType != OrderType.CONTRACT) {
            return true;
        }

        // The target failure can't be triggered if the consideration length is
        // 0. TODO: this is a limitation of the current mutation; support cases
        // where 0-length consideration can still trigger this error by
        // increasing totalOriginalConsiderationItems rather than decreasing it.
        if (ineligibleWhenNoConsiderationLength(order)) {
            return true;
        }

        return false;
    }

    function ineligibleForMissingOriginalConsiderationItems(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal pure returns (bool) {
        // The target failure can't be triggered if the order isn't available.
        // Seaport only checks for missing original consideration items if the
        // order is not skipped.
        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        // The target failure can't be triggered if the order is a contract
        // order because this check lies on a branch taken only by non-contract
        // orders.
        if (ineligibleWhenContractOrder(order)) {
            return true;
        }

        return false;
    }

    function ineligibleForBadContractSignature(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be triggered if tampering with the signature
        // has no effect, e.g. when the order is validated on chain or when the
        // offerer is the caller.
        if (
            ineligibleWhenAnySignatureFailureRequired(
                order,
                orderIndex,
                context
            )
        ) {
            return true;
        }

        // The target failure can't be triggered if the offerer is not a
        // contract. Seaport only checks 1271 signatures if the offerer is a
        // contract.
        if (order.parameters.offerer.code.length == 0) {
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
        // The target failure can't be triggered if tampering with an EOA
        // signature has no effect, e.g. when the order is validated on chain or
        // when the offerer is the caller. If an order is already validated on
        // chain, the signature that gets passed in isn't checked.  If the
        // caller is the offerer, that is an ad-hoc signature. The target
        // failure can't be triggered if the offerer is a 1271 contract, because
        // Seaport provides a different error message in that case
        // (BadContractSignature).
        if (
            ineligibleWhenEOASignatureFailureRequire(order, orderIndex, context)
        ) {
            return true;
        }

        // NOTE: it is possible to hit the target failure with other signature
        // lengths, but this test specifically targets ECDSA signatures.
        //
        // The target failure can't be triggered if the signature isn't a
        // normal ECDSA signature or a compact 2098 signature.
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
        // The target failure can't be triggered if tampering with an EOA
        // signature has no effect, e.g. when the order is validated on chain or
        // when the offerer is the caller. If an order is already validated on
        // chain, the signature that gets passed in isn't checked. The target
        // failure can't be triggered if the offerer is a 1271 contract, because
        // Seaport provides a different error message in that case
        // (BadContractSignature).
        if (
            ineligibleWhenEOASignatureFailureRequire(order, orderIndex, context)
        ) {
            return true;
        }

        return false;
    }

    function ineligibleForBadSignatureV(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be triggered if tampering with an EOA
        // signature has no effect, e.g. when the order is validated on chain or
        // when the offerer is the caller. If an order is already validated on
        // chain, the signature that gets passed in isn't checked. The target
        // failure can't be triggered if the offerer is a 1271 contract, because
        // Seaport provides a different error message in that case
        // (BadContractSignature).
        if (
            ineligibleWhenEOASignatureFailureRequire(order, orderIndex, context)
        ) {
            return true;
        }

        // The target failure can't be triggered if the signature is a normal
        // ECDSA signature because the v value is only checked if the signature
        // is 65 bytes long.
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
        // The target failure can't be triggered if the function call allows
        // the order to be skipped.
        if (ineligibleWhenFulfillAvailable(context)) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidConduit(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal returns (bool) {
        // The target failure can't be triggered if the function call allows
        // the order to be skipped.
        if (ineligibleWhenFulfillAvailable(context)) {
            return true;
        }

        // This is just an optimization that allows the filter to bail out early
        // and avoid a costly set of checks.
        if (order.parameters.conduitKey == bytes32(0)) {
            return true;
        }

        // The target failure can't be triggered if the conduit key on the order
        // isn't used in an execution on a non-native item. Counduit validity is
        // only checked when there's an execution.

        // Get the fulfillment details.
        FulfillmentDetails memory details = context.toFulfillmentDetails(
            context.executionState.value
        );

        // Note: We're speculatively applying the mutation here and slightly
        // breaking the rules. Make sure to undo this mutation.
        bytes32 oldConduitKey = order.parameters.conduitKey;
        details.orders[orderIndex].conduitKey = keccak256("invalid conduit");
        (
            Execution[] memory explicitExecutions,
            ,
            Execution[] memory implicitExecutionsPost,

        ) = context.getExecutionsFromRegeneratedFulfillments(details);

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
        // The target failure can't be reached unless the function call is an
        // advanced type. Non-advanced functions don't have the fraction concept
        // and the test framework doesn't pass them in.
        if (ineligibleWhenNotAdvanced(context)) {
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
        // The target failure can't be reached unless the function call is
        // fulfillAvailableAdvancedOrders, which would just skip the order.
        // Otherwise the eligibility is the same as ineligibleForBadFraction.
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
        // The target failure can't be reached unless the function call is
        // cancelOrder. Note that the testing framework doesn't currently call
        // cancelOrder.
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
        // The target failure can't be reached if the function call is one of
        // the fulfillAvailable functions, because the order will be skipped
        // without triggering the failure.
        if (ineligibleWhenFulfillAvailable(context)) {
            return true;
        }

        // The target failure can't be triggered if the order is a contract
        // order because all instances where the target failure can be hit are
        // on non-contract order paths.
        if (ineligibleWhenContractOrder(order)) {
            return true;
        }

        return false;
    }

    function ineligibleForOrderAlreadyFilled(
        AdvancedOrder memory order,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be reached if the function call is one of
        // the fulfillAvailable functions, because the order will be skipped
        // without triggering the failure.
        //
        // It might be possible to remove ineligibleWhenBasic and instead
        // differentiate between partially filled and non-filled orders, but it
        // is probably a heavy lift in the test framework as it currently is. As
        // of right now, it's not possible to consistently hit the target
        // failure on a partially filled order when calling a basic function.
        if (
            ineligibleWhenFulfillAvailable(context) ||
            ineligibleWhenBasic(context)
        ) {
            return true;
        }

        // The target failure can't be triggered if the order is a contract
        // order because all instances where the target failure can be hit are
        // on non-contract order paths.
        if (ineligibleWhenContractOrder(order)) {
            return true;
        }

        return false;
    }

    function ineligibleForBadFractionPartialContractOrder(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be reached unless the order is a contract
        // order. The target failure here is the one in the
        // `_validateOrderAndUpdateStatus` function, inside the `if
        // (orderParameters.orderType == OrderType.CONTRACT) {` block.
        if (order.parameters.orderType != OrderType.CONTRACT) {
            return true;
        }

        if (ineligibleWhenUnavailableOrNotAdvanced(context, orderIndex)) {
            return true;
        }

        return false;
    }

    function ineligibleForInvalidFulfillmentComponentData(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // TODO: This filter can be relaxed and probably the others below that
        //       are similar. These failures should be triggerable with both
        //       functions that accept Fulfillment[] and functions that accept
        //       FulfillmentComponent[]. All of these fulfillment failure tests
        //       should be revisited.
        //
        // The target failure can't be reached unless the function call is
        // a type that accepts fulfillment arguments.
        if (ineligibleWhenNotFulfillmentIngestingFunction(context)) {
            return true;
        }

        return false;
    }

    function ineligibleForMissingFulfillmentComponentOnAggregation(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be reached unless the function call is
        // a type that accepts fulfillment arguments.
        if (ineligibleWhenNotFulfillmentIngestingFunction(context)) {
            return true;
        }

        if (ineligibleWhenMatch(context)) {
            return true;
        }

        return false;
    }

    function ineligibleForOfferAndConsiderationRequiredOnFulfillment(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be reached unless the function call is
        // a type that accepts fulfillment arguments.
        if (ineligibleWhenNotFulfillmentIngestingFunction(context)) {
            return true;
        }

        if (ineligibleWhenNotMatch(context)) {
            return true;
        }

        if (context.executionState.fulfillments.length == 0) {
            return true;
        }

        return false;
    }

    function ineligibleForMismatchedFulfillmentOfferAndConsiderationComponents_Modified(
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // This revert lies on a path in `_applyFulfillment`, which is only
        // called by `_matchAdvancedOrders`, which is only called by the match*
        // functions.
        if (ineligibleWhenNotMatch(context)) {
            return true;
        }

        // The context needs to have at least one existing fulfillment, because
        // the failure test checks the case where a fulfillment is modified.
        if (context.executionState.fulfillments.length < 1) {
            return true;
        }

        // Grab the offer components from the first fulfillment. The first isn't
        // special, but it's the only one that needs to be checked, because it's
        // the only one that will be modified in the mutation. This is just a
        // simplification/convenience.
        FulfillmentComponent[] memory firstOfferComponents = (
            context.executionState.fulfillments[0].offerComponents
        );

        // Iterate over the offer components and check if any of them have an
        // item index that is out of bounds for the order. The mutation modifies
        // the token of the offer item at the given index, so the index needs to
        // be within range. This can happen when contract orders modify their
        // offer or consideration lengths, or in the case of erroneous input for
        // fulfillments.
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
        // This revert lies on a path in `_applyFulfillment`, which is only
        // called by `_matchAdvancedOrders`, which is only called by the match*
        // functions.
        if (ineligibleWhenNotMatch(context)) {
            return true;
        }

        // The context needs to have at least two existing fulfillments, because
        // this failure test checks the case where fulfillments are swapped.
        if (context.executionState.fulfillments.length < 2) {
            return true;
        }

        // Grab the first offer components from the first fulfillment. There's
        // nothing special about the first fulfillment or the first offer
        // components, but they're the only ones that need to be checked,
        // because they're the only ones that will be modified in the mutation.
        FulfillmentComponent memory firstOfferComponent = (
            context.executionState.fulfillments[0].offerComponents[0]
        );

        // Get the item pointed to by the first offer component.
        SpentItem memory item = context
            .executionState
            .orderDetails[firstOfferComponent.orderIndex]
            .offer[firstOfferComponent.itemIndex];

        // Iterate over the remaining fulfillments and check that the offer item
        // can be paired with a consideration item that's incompatible with it
        // in such a way that the target failure can be triggered.
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
        // There are three flavors of this mutation. This one is for the
        // fulfillAvailable functions.
        bytes4 action = context.action();
        if (
            action != context.seaport.fulfillAvailableAdvancedOrders.selector &&
            action != context.seaport.fulfillAvailableOrders.selector
        ) {
            return true;
        }

        // Iterate over offer fulfillments.
        for (
            uint256 i;
            i < context.executionState.offerFulfillments.length;
            i++
        ) {
            // Get the first fulfillment component from the current offer
            // fulfillment.
            FulfillmentComponent memory fulfillmentComponent = context
                .executionState
                .offerFulfillments[i][0];

            // If the item index is out of bounds, then the mutation can't be
            // applied.
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

            // If the fulfillmentComponent's item type is not ERC721 and the
            // order is available, then the mutation can be applied. 721s are
            // ruled out because the mutation needs to change the start and end
            // amounts to 0, which triggers a different revert for 721s. The
            // order being unavailable is ruled out because the order needs to
            // be processed for the target failure to be hit.
            if (
                context
                    .executionState
                    .orderDetails[fulfillmentComponent.orderIndex]
                    .offer[fulfillmentComponent.itemIndex]
                    .itemType != ItemType.ERC721
            ) {
                if (
                    context
                        .executionState
                        .orderDetails[fulfillmentComponent.orderIndex]
                        .unavailableReason == UnavailableReason.AVAILABLE
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
        // TODO: finish this filter and write a corresponding mutation.
        return true;
    }

    function ineligibleForMissingItemAmount_OfferItem(
        AdvancedOrder memory order,
        uint256 /* orderIndex */,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The fulfillAvailable functions are ruled out because they're handled
        // separately. Match functions are ruled out because they need to be
        // handled separately, too (but are not yet).
        if (
            ineligibleWhenFulfillAvailable(context) ||
            ineligibleWhenMatch(context)
        ) {
            return true;
        }

        // Only a subset of basic orders are eligible for this mutation. This
        // portion of the filter prevents an Arithmetic over/underflow — as bids
        // are paid from the offerer, setting the offer amount to zero will
        // result in an underflow when attempting to reduce that offer amount as
        // part of paying out additional recipient items.
        if (
            ineligibleWhenBasic(context) &&
            order.parameters.consideration.length > 1 &&
            (order.parameters.consideration[0].itemType == ItemType.ERC721 ||
                order.parameters.consideration[0].itemType == ItemType.ERC1155)
        ) {
            return true;
        }

        // There needs to be one or more offer items to tamper with.
        if (order.parameters.offer.length == 0) {
            return true;
        }

        // At least one offer item must be native, ERC20, or ERC1155. 721s
        // with amounts of 0 trigger a different revert.
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

        // Offerer must not also be consideration recipient for all items,
        // otherwise the check that triggers the target failure will not be hit
        // and the function call will not revert.
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
        // This filter works basically the same as the OfferItem bookend to it.
        // Order must be available.
        if (ineligibleWhenUnavailable(context, orderIndex)) {
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
        // Can't be one of the fulfillAvailable actions, or else the orders will
        // just be skipped and the target failure will not be hit. It'll pass or
        // revert with NoSpecifiedOrdersAvailable or something instead.
        if (ineligibleWhenFulfillAvailable(context)) {
            return true;
        }

        // One non-native execution is necessary to trigger the target failure.
        // Seaport will only check for a contract if there the context results
        // in an execution that is not native.
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
        // The target failure can't be triggered if the order isn't available.
        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        // The target failure cannot be triggered in fulfillAvailable cases —
        // they trip a InvalidFulfillmentComponentData error instead. TODO:
        // perform the mutation on all items that are part of a single
        // fulfillment element.
        if (ineligibleWhenFulfillAvailable(context)) {
            return true;
        }

        // The target failure cannot be triggered in match cases — they trip a
        // MismatchedFulfillmentOfferAndConsiderationComponents(uint256) error
        // instead. TODO: perform the mutation on all items that are part of a
        // single fulfillment element.
        if (ineligibleWhenMatch(context)) {
            return true;
        }

        // The target failure is not eligible when rebates are present that may
        // strip out the unused item parameters. TODO: take a more granular and
        // precise approach here; only reduced total offer items is actually a
        // problem, and even those only if all eligible offer items are removed.
        if (ineligibleWhenOrderHasRebates(order, orderIndex, context)) {
            return true;
        }

        // The order must have at least one native item to tamper with. It can't
        // be a 20, 721, or 1155, because only native items get checked for the
        // existence of an unused contract address parameter.
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

    function ineligibleForUnusedItemParameters_Identifier(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // The target failure can't be triggered if the order isn't available.
        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        // The target failure cannot be triggered in fulfillAvailable cases —
        // they trip a InvalidFulfillmentComponentData error instead. TODO:
        // perform the mutation on all items that are part of a single
        // fulfillment element.
        if (ineligibleWhenFulfillAvailable(context)) {
            return true;
        }

        // The target failure cannot be triggered in match cases — they trip a
        // MismatchedFulfillmentOfferAndConsiderationComponents(uint256) error
        // instead. TODO: perform the mutation on all items that are part of a
        // single fulfillment element.
        if (ineligibleWhenMatch(context)) {
            return true;
        }

        // The target failure is not eligible when rebates are present that may
        // strip out the unused item parameters. TODO: take a more granular and
        // precise approach here; only reduced total offer items is actually a
        // problem, and even those only if all eligible offer items are removed.
        if (ineligibleWhenOrderHasRebates(order, orderIndex, context)) {
            return true;
        }

        // The order must have at least one native or ERC20 consideration
        // item to tamper with. It can't be a 721 or 1155, because only native
        // and ERC20 items get checked for the existence of an unused
        // identifier parameter.
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
            action == context.seaport.fulfillAdvancedOrder.selector ||
            ineligibleWhenFulfillAvailable(context) ||
            ineligibleWhenMatch(context)
        ) {
            return true;
        }

        // The target failure can't be triggered if the order isn't available.
        // Seaport only checks for an invalid 721 transfer amount if the
        // item is actually about to be transferred, which means it needs to be
        // on an available order.
        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        // The target failure is not eligible when rebates are present that may
        // strip out the unused item parameters. TODO: take a more granular and
        // precise approach here; only modified item amounts are actually a
        // problem, and even those only if there is only one eligible item.
        if (ineligibleWhenOrderHasRebates(order, orderIndex, context)) {
            return true;
        }

        // The order must have at least one 721 item to tamper with.
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
        // The target failure can't be triggered on paths other than those
        // enumerated below, because the revert lies on code paths that are
        // only reached by those top level function calls.
        bytes4 action = context.action();
        if (
            action != context.seaport.fulfillAvailableAdvancedOrders.selector &&
            action != context.seaport.fulfillAvailableOrders.selector &&
            action != context.seaport.matchAdvancedOrders.selector &&
            action != context.seaport.matchOrders.selector
        ) {
            return true;
        }

        // TODO: This check is overly restrictive and is here as a simplifying
        // assumption. Explore removing it.
        if (order.numerator != order.denominator) {
            return true;
        }

        // The target failure can't be triggered if the order is a contract
        // order because this check lies on a branch taken only by non-contract
        // orders.
        if (ineligibleWhenContractOrder(order)) {
            return true;
        }

        // The target failure can't be triggered if the order isn't available.
        // Seaport only checks for proper consideration if the order is not
        // skipped.
        if (ineligibleWhenUnavailable(context, orderIndex)) {
            return true;
        }

        // The target failure can't be triggered if the order doesn't require
        // any consideration.
        if (ineligibleWhenNoConsiderationLength(order)) {
            return true;
        }

        return false;
    }

    function ineligibleForPartialFillsNotEnabledForOrder(
        AdvancedOrder memory order,
        uint256 orderIndex,
        FuzzTestContext memory context
    ) internal view returns (bool) {
        // Exclude methods that don't support partial fills.
        if (ineligibleWhenNotAdvanced(context)) {
            return true;
        }

        // Exclude partial and contract orders. It's not possible to trigger
        // the target failure on an order that supports partial fills. Contract
        // orders give a different revert.
        if (
            order.parameters.orderType == OrderType.PARTIAL_OPEN ||
            order.parameters.orderType == OrderType.PARTIAL_RESTRICTED ||
            ineligibleWhenContractOrder(order)
        ) {
            return true;
        }

        // The target failure can't be triggered if the order isn't available.
        // Seaport only checks whether partial fills are enabled if the order
        // is not skipped.
        if (ineligibleWhenUnavailable(context, orderIndex)) {
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
        if (ineligibleWhenUnavailable(context, orderIndex)) {
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
                context.executionState.orderDetails[orderIndex].orderHash
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
        // The target failure can't be triggered by top level function calls
        // other than those enumerated below because it lies on
        // fulfillAvaialable*-specific code paths.
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
    using AdvancedOrderLib for AdvancedOrder;
    using CheckHelpers for FuzzTestContext;
    using ConsiderationItemLib for ConsiderationItem;
    using FuzzDerivers for FuzzTestContext;
    using FuzzEngineLib for FuzzTestContext;
    using FuzzHelpers for AdvancedOrder;
    using FuzzInscribers for AdvancedOrder;
    using MutationEligibilityLib for FuzzTestContext;
    using MutationFilters for FuzzTestContext;
    using MutationHelpersLib for FuzzTestContext;
    using OrderParametersLib for OrderParameters;

    function mutation_invalidContractOrderGenerateReverts(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashCalldataContractOfferer.
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

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashCalldataContractOfferer.
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

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashCalldataContractOfferer.
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

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashCalldataContractOfferer.
        HashCalldataContractOfferer(payable(order.parameters.offerer))
            .setFailureReason(
                orderHash,
                OffererZoneFailureReason.ContractOfferer_InvalidMagicValue
            );

        exec(context);
    }

    function mutation_invalidRestrictedOrderAuthorizeRevertsMatchReverts(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashValidationZone. Note that only
        // non-fulfillAvailable* functions revert at the seaport level when the
        // zone reverts on authorize.
        HashValidationZoneOfferer(payable(order.parameters.zone))
            .setAuthorizeFailureReason(
                orderHash,
                OffererZoneFailureReason.Zone_authorizeRevertsMatchReverts
            );

        exec(context);
    }

    function mutation_invalidRestrictedOrderReverts(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashValidationZoneOfferer.
        HashValidationZoneOfferer(payable(order.parameters.zone))
            .setValidateFailureReason(
                orderHash,
                OffererZoneFailureReason.Zone_validateReverts
            );

        exec(context);
    }

    function mutation_invalidRestrictedOrderAuthorizeInvalidMagicValue(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashValidationZone.
        HashValidationZoneOfferer(payable(order.parameters.zone))
            .setAuthorizeFailureReason(
                orderHash,
                OffererZoneFailureReason.Zone_authorizeInvalidMagicValue
            );

        exec(context);
    }

    function mutation_invalidRestrictedOrderValidateInvalidMagicValue(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;
        bytes32 orderHash = mutationState.selectedOrderHash;

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashValidationZone.
        HashValidationZoneOfferer(payable(order.parameters.zone))
            .setValidateFailureReason(
                orderHash,
                OffererZoneFailureReason.Zone_validateInvalidMagicValue
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

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashCalldataContractOfferer and by mutating the amount
        // of the first item in the offer.
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

        // This mutation triggers a revert by mutating the amount of the first
        // item in the offer. It triggers an `InvalidContractOrder` revert
        // because the start amount of a contract order offer item must be equal
        // to the end amount.
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

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashCalldataContractOfferer and by calling a function
        // that stores a value in the contract offerer that causes the contract
        // offerer to change the length of the offer in its `generate` function.
        offerer.setFailureReason(
            orderHash,
            OffererZoneFailureReason.ContractOfferer_IncorrectMinimumReceived
        );

        // TODO: operate on a fuzzed item (this always operates on last item)
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

        // This triggers an `InvalidContractOrder` revert because the start
        // amount of a contract order consideration item must be equal to the
        // end amount.
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

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashCalldataContractOfferer and by calling a function
        // that stores a value in the contract offerer that causes the contract
        // offerer to add an extra item to the consideration in its `generate`
        // function.
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

        // This mutation triggers a revert by setting a failure reason that gets
        // stored in the HashCalldataContractOfferer and by calling a function
        // that stores a value in the contract offerer that causes the contract
        // offerer to change the amount of a consideration item in its
        // `generate` function.
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

        // This mutation triggers a revert by pranking an approval revocation on
        // a non-filtered, non-native item in the offer. The offerer needs to
        // have approved items that will be transferred.

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

        // This mutation triggers a revert by pranking an approval revocation on
        // a non-filtered, non-native item in the consideration. The caller
        // needs to have approved items that will be transferred.

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

        // This mutation triggers a revert by setting the msg.value to an
        // incorrect value. The msg.value must be equal to or greater than the
        // amount of native tokens required for payable routes and must be
        // 0 for nonpayable routes.

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

        // This mutation triggers a revert by setting the msg.value to one less
        // than the minimum required value. In this test framework, the minimum
        // required value is calculated to be the lowest possible value that
        // will not trigger a revert.  Lowering it by one will trigger a revert
        // because the caller isn't putting enough money in to cover everything.

        context.executionState.value = minimumRequired - 1;

        exec(context);
    }

    function mutation_criteriaNotEnabledForItem(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */
    ) external {
        // This mutation triggers a revert by adding a criteria resolver for an
        // item that does not have the correct item type. It's not permitted to
        // add a criteria resolver for an item that is not a *WithCriteria type.

        // Grab the old resolvers.
        CriteriaResolver[] memory oldResolvers = context
            .executionState
            .criteriaResolvers;
        // Make a new array with one more slot.
        CriteriaResolver[] memory newResolvers = new CriteriaResolver[](
            oldResolvers.length + 1
        );
        // Copy the old resolvers into the new array.
        for (uint256 i = 0; i < oldResolvers.length; ++i) {
            newResolvers[i] = oldResolvers[i];
        }

        uint256 orderIndex;
        Side side;

        // Iterate over orders.
        for (
            ;
            orderIndex < context.executionState.orders.length;
            ++orderIndex
        ) {
            // Skip unavailable orders.
            if (context.ineligibleWhenUnavailable(orderIndex)) {
                continue;
            }

            // Grab the order at the current index.
            AdvancedOrder memory order = context.executionState.orders[
                orderIndex
            ];

            // If it has an offer, set the side to offer and break, otherwise
            // if it has a consideration, set the side to consideration and
            // break.
            if (order.parameters.offer.length > 0) {
                side = Side.OFFER;
                break;
            } else if (order.parameters.consideration.length > 0) {
                side = Side.CONSIDERATION;
                break;
            }
        }

        // Add a new resolver to the end of the array with the correct index and
        // side, but with empty values otherwise.
        newResolvers[oldResolvers.length] = CriteriaResolver({
            orderIndex: orderIndex,
            side: side,
            index: 0,
            identifier: 0,
            criteriaProof: new bytes32[](0)
        });

        // Set the new resolvers to the execution state.
        context.executionState.criteriaResolvers = newResolvers;

        exec(context);
    }

    function mutation_invalidSignature(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // This mutation triggers a revert by setting the signature to a
        // signature with an invalid length. Seaport rejects signatures that
        // are not one of the valid lengths.

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

        // This mutation triggers a revert by setting the signature to a
        // signature that recovers to an invalid address. Seaport rejects
        // signatures that do not recover to the correct signer address.

        order.signature[0] = bytes1(uint8(order.signature[0]) ^ 0x01);

        exec(context);
    }

    function mutation_invalidSigner_ModifiedOrder(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // This mutation triggers a revert by changing the order so that the
        // otherwise-valid signature is for a different order. Seaport rejects
        // signatures that do not recover to the correct signer address.

        order.parameters.salt ^= 0x01;

        exec(context);
    }

    function mutation_badSignatureV(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // This mutation triggers a revert by setting the byte at the end of the
        // signature to a value that is not 27 or 28. Seaport rejects
        // signatures that do not have a valid V value.

        order.signature[64] = 0xff;

        exec(context);
    }

    function mutation_badContractSignature_BadSignature(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // This mutation triggers a revert by setting the signature to a
        // signature that recovers to an invalid address, but only in cases
        // where a 1271 contract is the signer. Seaport rejects signatures that
        // do not recover to the correct signer address.

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

        // This mutation triggers a revert by changing the order so that the
        // otherwise-valid signature is for a different order, but only in cases
        // where a 1271 contract is the signer. Seaport rejects signatures that
        // do not recover to the correct signer address.

        order.parameters.salt ^= 0x01;

        exec(context);
    }

    function mutation_badContractSignature_MissingMagic(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // This mutation triggers a revert by calling a function on the 1271
        // offerer that causes it to not return the magic value. Seaport
        // requires that 1271 contracts return the magic value.

        EIP1271Offerer(payable(order.parameters.offerer)).returnEmpty();

        exec(context);
    }

    function mutation_considerationLengthNotEqualToTotalOriginal_ExtraItems(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // This mutation triggers a revert by setting the total original
        // consideration items value to a value that is less than the length of
        // the consideration array of a contract order (tips on a contract
        // order). The total original consideration items value must be equal to
        // the length of the consideration array.

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

        // This mutation triggers a revert by setting the total original
        // consideration items value to a value that is greater than the length
        // of the consideration array of a contract order (tips on a contract
        // order). The total original consideration items value must be equal to
        // the length of the consideration array.

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

        // This mutation triggers a revert by setting the total original
        // consideration items value to a value that is greater than the length
        // of the consideration array of a non-contract order. The total
        // original consideration items value must be equal to the length of the
        // consideration array.

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

        // This mutation triggers a revert by setting the start time to a value
        // that is in the future. The start time must be in the past.

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

        // This mutation triggers a revert by setting the end time to a value
        // that is not in the future. The end time must be in the future.

        order.parameters.startTime = block.timestamp - 1;
        order.parameters.endTime = block.timestamp;

        exec(context);
    }

    function mutation_invalidConduit(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        // This mutation triggers a revert by setting the conduit key to an
        // invalid value. The conduit key must correspond to a real, valid
        // conduit.

        // Note: We should also adjust approvals for any items approved on the
        // old conduit, but the error here will be thrown before transfers
        // begin to occur.
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        order.parameters.conduitKey = keccak256("invalid conduit");

        _signOrValidateMutatedOrder(context, orderIndex);

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

        // This mutation triggers a revert by setting the numerator to 0. The
        // numerator must be greater than 0.

        order.numerator = 0;

        exec(context);
    }

    function mutation_badFraction_Overfill(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // This mutation triggers a revert by setting the numerator to a value
        // that is greater than the denominator. The numerator must be less than
        // or equal to the denominator.

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

        // This mutation triggers a revert by using cheatcodes to mark the order
        // as cancelled in the Seaport internal mapping. A cancelled order
        // cannot be filled.

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

        // This mutation triggers a revert by using cheatcodes to mark the order
        // as filled in the Seaport internal mapping. An order that has already
        // been filled cannot be filled again.

        order.inscribeOrderStatusNumeratorAndDenominator(1, 1, context.seaport);

        exec(context);
    }

    function mutation_cannotCancelOrder(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        AdvancedOrder memory order = mutationState.selectedOrder;

        // This mutation triggers a revert by setting the caller as an address
        // that is not the offerer. Only the offerer can cancel an order.

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

        // This mutation triggers a revert by setting the numerator to a value
        // that is less than the denominator. Contract orders can't have a
        // partial fill.

        order.numerator = 6;
        order.denominator = 9;

        exec(context);
    }

    function mutation_invalidFulfillmentComponentData(
        FuzzTestContext memory context
    ) external {
        // This mutation triggers a revert by modifying or creating a
        // fulfillment component that uses an order index that is out of bounds.
        // The order index must be within bounds.

        if (context.executionState.fulfillments.length != 0) {
            // If there's already one or more fulfillments, just set the order index
            // for the first fulfillment's consideration component to an invalid
            // value.
            context
                .executionState
                .fulfillments[0]
                .considerationComponents[0]
                .orderIndex = context.executionState.orders.length;
        } else {
            // Otherwise, create a new, empty fulfillment.
            context.executionState.fulfillments = new Fulfillment[](1);

            context
                .executionState
                .fulfillments[0]
                .offerComponents = new FulfillmentComponent[](1);

            context
                .executionState
                .fulfillments[0]
                .considerationComponents = new FulfillmentComponent[](1);

            context
                .executionState
                .fulfillments[0]
                .considerationComponents[0]
                .orderIndex = context.executionState.orders.length;
        }

        // Do the same sort of thing for offer fulfillments and consideration
        // fulfillments.
        if (context.executionState.offerFulfillments.length != 0) {
            context.executionState.offerFulfillments[0][0].orderIndex = context
                .executionState
                .orders
                .length;
        } else if (
            context.executionState.considerationFulfillments.length != 0
        ) {
            context
            .executionState
            .considerationFulfillments[0][0].orderIndex = context
                .executionState
                .orders
                .length;
        } else {
            context.executionState.considerationFulfillments = (
                new FulfillmentComponent[][](1)
            );

            context.executionState.considerationFulfillments[0] = (
                new FulfillmentComponent[](1)
            );

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
        // This mutation triggers a revert by creating or swapping in an empty
        // fulfillment component array.  At least one fulfillment component must
        // be supplied.

        // If the mutation side is OFFER and there are no offer fulfillments,
        // create a new, empty offer fulfillment. Otherwise, reset the first
        // offer fulfillment to an empty FulfillmentComponent array.  If the
        // mutation side is CONSIDERATION, reset the first consideration
        // fulfillment to an empty FulfillmentComponent array.
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
        // This mutation triggers a revert by setting the offerComponents and
        // considerationComponents arrays to empty FulfillmentComponent arrays.
        // At least one offer component and one consideration component must be
        // supplied.

        context.executionState.fulfillments[0] = Fulfillment({
            offerComponents: new FulfillmentComponent[](0),
            considerationComponents: new FulfillmentComponent[](0)
        });

        exec(context);
    }

    function mutation_mismatchedFulfillmentOfferAndConsiderationComponents_Modified(
        FuzzTestContext memory context
    ) external {
        // This mutation triggers a revert by modifying the token addresses of
        // all of the offer items referenced in the first fulfillment's offer
        // components.  Corresponding offer and consideration components must
        // each target the same item.

        // Get the first fulfillment's offer components.
        FulfillmentComponent[] memory firstOfferComponents = (
            context.executionState.fulfillments[0].offerComponents
        );

        // Iterate over the offer components and modify the token address of
        // each corresponding offer item. This preserves the intended
        // aggregation and filtering patterns, but causes the offer and
        // consideration components to have mismatched token addresses.
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

        // "Resign" the orders.
        for (uint256 i = 0; i < context.executionState.orders.length; ++i) {
            _signOrValidateMutatedOrder(context, i);
        }

        exec(context);
    }

    function mutation_mismatchedFulfillmentOfferAndConsiderationComponents_Swapped(
        FuzzTestContext memory context
    ) external {
        // This mutation triggers a revert by shuffling around the offer
        // components in such a way that an item with an incorrect type,
        // address, or identifier is attempted to be paired up with a
        // consideration component that expects the pre-suhffle type, address,
        // or identifier. A fulfillment's offer and condieration components must
        // harmonize.

        // Store a reference to the first fulfillment's offer components for
        // later use.
        FulfillmentComponent[] memory firstOfferComponents = (
            context.executionState.fulfillments[0].offerComponents
        );

        // Get the first fulfillment's first offer component.
        FulfillmentComponent memory firstOfferComponent = (
            firstOfferComponents[0]
        );

        // Use the indexes in the first offer component to get the item.
        SpentItem memory item = context
            .executionState
            .orderDetails[firstOfferComponent.orderIndex]
            .offer[firstOfferComponent.itemIndex];

        // Start iterating at the second fulfillment, since the first is the one
        // that gets mutated.
        uint256 i = 1;
        for (; i < context.executionState.fulfillments.length; ++i) {
            // Get the first consideration component of the current fulfillment.
            FulfillmentComponent memory considerationComponent = (
                context.executionState.fulfillments[i].considerationComponents[
                    0
                ]
            );

            // Use the indexes in the first consideration component to get the
            // item that needs to be compared against.
            ReceivedItem memory compareItem = context
                .executionState
                .orderDetails[considerationComponent.orderIndex]
                .consideration[considerationComponent.itemIndex];

            // If it's not a match, then it works for the mutation, so break.
            if (
                item.itemType != compareItem.itemType ||
                item.token != compareItem.token ||
                item.identifier != compareItem.identifier
            ) {
                break;
            }
        }

        // Swap offer components of the first and current fulfillments.
        FulfillmentComponent[] memory swappedOfferComponents = (
            context.executionState.fulfillments[i].offerComponents
        );

        // Set up a pointer that will be used temporarily in the shuffle.
        bytes32 swappedPointer;

        assembly {
            // Store the pointer to the swapped offer components.
            swappedPointer := swappedOfferComponents
            // Set the swapped offer components to the first offer components.
            swappedOfferComponents := firstOfferComponents
            // Set the first offer components to non-compatible offer
            // components.
            firstOfferComponents := swappedPointer
        }

        // Set the offer components of the first fulfillment to the mutated
        // firstOfferComponents.
        context
            .executionState
            .fulfillments[0]
            .offerComponents = firstOfferComponents;

        // Set the offer components of the current fulfillment to the offer
        // components that were originally in the first fulfillment.
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

        // This mutation works by jamming in a proof for the selected criteria
        // resolver, but only operates on criteria resolvers that aren't
        // expected to have proofs at all, see
        // ineligibleForInvalidProof_Wildcard.

        bytes32[] memory criteriaProof = new bytes32[](1);
        resolver.criteriaProof = criteriaProof;

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

        // This mutation triggers a revert by modifying the first proof element
        // in a criteria resolver's proof array. Seaport will reject a criteria
        // resolver if the the identifiers, criteria, and proof do not
        // harmonize.

        bytes32 firstProofElement = resolver.criteriaProof[0];
        resolver.criteriaProof[0] = bytes32(uint256(firstProofElement) ^ 1);

        exec(context);
    }

    function mutation_orderCriteriaResolverOutOfRange(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */
    ) external {
        // This mutation works by adding an extra criteria resolver with an
        // order index that's out of range. The order index on a criteria
        // resolver must be within the range of the orders array.

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
        // This mutation works by mutating an existing criteria resolver to have
        // an item index that's out of range. The item index on a criteria
        // resolver must be within the range of the order's offer array if the
        // criteria resolver's side is OFFER, as is the case for this mutation.

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
        // This mutation works by mutating an existing criteria resolver to have
        // an item index that's out of range. The item index on a criteria
        // resolver must be within the range of the order's consideration
        // array if the criteria resolver's side is CONSIDERATION, as is the
        // case for this mutation.

        uint256 criteriaResolverIndex = mutationState
            .selectedCriteriaResolverIndex;
        CriteriaResolver memory resolver = context
            .executionState
            .criteriaResolvers[criteriaResolverIndex];

        AdvancedOrder memory order = context.executionState.orders[
            resolver.orderIndex
        ];
        resolver.index = order.parameters.consideration.length;

        exec(context);
    }

    function mutation_unresolvedCriteria(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        // This mutation works by copying over all the criteria resolvers except
        // for the selected one, which is left empty. Without a criteria
        // resolver, the item with a *WITH_CRITERIA type will be left unresolved
        // by the end of the _applyCriteriaResolvers* functions, which is not
        // permitted.

        uint256 criteriaResolverIndex = mutationState
            .selectedCriteriaResolverIndex;

        CriteriaResolver[] memory oldResolvers = context
            .executionState
            .criteriaResolvers;
        CriteriaResolver[] memory newResolvers = new CriteriaResolver[](
            oldResolvers.length - 1
        );

        // Iterate from 0 to the selected criteria resolver index and copy
        // resolvers.
        for (uint256 i = 0; i < criteriaResolverIndex; ++i) {
            newResolvers[i] = oldResolvers[i];
        }

        // Iterate from the selected criteria resolver index + 1 to the end and
        // copy resolvers.
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
        // This mutation works by setting the amount of the first eligible item
        // in an offer to 0. Items cannot have 0 amounts.

        // Iterate over all the offer fulfillments. This mutation needs to be
        // applied to a an item that won't be filtered. The presence of a
        // fulfillment that points to the item serves as a proxy that the item's
        // transfer won't be filtered.
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

            // The item cannot be a 721, because setting the amount of a 721 to
            // 0 triggers a different revert.
            if (
                context
                    .executionState
                    .orderDetails[fulfillmentComponent.orderIndex]
                    .offer[fulfillmentComponent.itemIndex]
                    .itemType != ItemType.ERC721
            ) {
                // The order must be available.
                if (
                    context
                        .executionState
                        .orderDetails[fulfillmentComponent.orderIndex]
                        .unavailableReason == UnavailableReason.AVAILABLE
                ) {
                    // For all orders, set the start and end amounts to 0.
                    order
                        .parameters
                        .offer[fulfillmentComponent.itemIndex]
                        .startAmount = 0;
                    order
                        .parameters
                        .offer[fulfillmentComponent.itemIndex]
                        .endAmount = 0;

                    // For contract orders, tell the test contract about the
                    // mutation so that it knows to give back bad amounts.
                    if (order.parameters.orderType == OrderType.CONTRACT) {
                        HashCalldataContractOfferer(
                            payable(order.parameters.offerer)
                        ).addItemAmountMutation(
                                Side.OFFER,
                                fulfillmentComponent.itemIndex,
                                0,
                                context
                                    .executionState
                                    .orderDetails[
                                        fulfillmentComponent.orderIndex
                                    ]
                                    .orderHash
                            );
                    }

                    _signOrValidateMutatedOrder(
                        context,
                        fulfillmentComponent.orderIndex
                    );

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
        // This mutation works by setting the amount of the first eligible item
        // in an offer to 0. Items cannot have 0 amounts.

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

        _signOrValidateMutatedOrder(context, orderIndex);

        exec(context);
    }

    function mutation_missingItemAmount_ConsiderationItem(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        // This mutation works in the same way as
        // mutation_missingItemAmount_OfferItem_FulfillAvailable aboce, except
        // that it targets consideration items instead of offer items.  Items
        // cannot have 0 amounts.

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

        _signOrValidateMutatedOrder(context, orderIndex);

        exec(context);
    }

    function mutation_noContract(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        // This mutation works by changing the contract address of token from
        // an actual token address to a non-contract address. The token address
        // has to be swapped throughout all orders to avoid hitting earlier
        // reverts, such as aggregation reverts or mismatch reverts.  Seaport
        // rejects calls to non-contract addresses.

        address targetContract;

        // Iterate over expectedExplicitExecutions to find a token address.
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

        // Iterate over orders and replace all instances of the target contract
        // address with the selected arbitrary address.
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

            _signOrValidateMutatedOrder(context, i);
        }

        exec(context);
    }

    function mutation_unusedItemParameters_Token(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        // This mutation works by setting the token address of the first
        // eligible item in an offer to a nonzero address. An item with
        // ItemType.NATIVE cannot have a nonzero token address.

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

        // For basic orders, the additional recipient items also need to be
        // modified.
        bytes4 action = context.action();
        if (
            action == context.seaport.fulfillBasicOrder.selector ||
            action ==
            context.seaport.fulfillBasicOrder_efficient_6GL6yc.selector
        ) {
            for (
                uint256 i = 1;
                i < order.parameters.consideration.length;
                i++
            ) {
                ConsiderationItem memory item = order.parameters.consideration[
                    i
                ];

                if (item.itemType == ItemType.NATIVE) {
                    item.token = address(1);
                }
            }
        }

        _signOrValidateMutatedOrder(context, orderIndex);

        exec(context);
    }

    function mutation_unusedItemParameters_Identifier(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        // This mutation works by setting the identifier of the first eligible
        // item in an offer to a nonzero value. An item with ItemType.NATIVE
        // or ItemType.ERC20 cannot have a nonzero identifier.

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

        // Note that additional recipients do not need to be modified as
        // identifiers for them are automatically set to 0.

        _signOrValidateMutatedOrder(context, orderIndex);

        exec(context);
    }

    function mutation_invalidERC721TransferAmount(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        // This mutation works by setting the amount of the first eligible
        // item in an offer to an invalid value. An item with ItemType.ERC721
        // or ItemType.ERC721_WITH_CRITERIA must have an amount of 1.

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

        _signOrValidateMutatedOrder(context, orderIndex);

        exec(context);
    }

    function mutation_considerationNotMet(
        FuzzTestContext memory context,
        MutationState memory mutationState
    ) external {
        uint256 orderIndex = mutationState.selectedOrderIndex;
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // This mutation works by adding a new consideration item to the order.
        // An attempt to fill an order must include all the consideration items
        // that the order specifies. Since the test framework supplies exactly
        // the right number of native tokens to fill the order (before this
        // mutation), adding a new consideration item will cause the order to
        // fail.

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

        // This mutation works by setting the demoninator of the fraction to a
        // value that does not nicely divide. Remainders are not permissible.

        // Get an item's start amount.
        uint256 itemAmount = order.parameters.offer.length == 0
            ? order.parameters.consideration[0].startAmount
            : order.parameters.offer[0].startAmount;

        // If the item's start amount is 0, get an item's end amount.
        if (itemAmount == 0) {
            itemAmount = order.parameters.offer.length == 0
                ? order.parameters.consideration[0].endAmount
                : order.parameters.offer[0].endAmount;
        }

        // If the item amount is huge, set it to a value that's very large but
        // less than type(uint120).max.
        // This isn't perfect, but odds of hitting it are slim to none.
        // type(uint120).max is 1329227995784915872903807060280344575.
        // The hardcoded value below is just above type(uint120).max / 2.
        // 664613997892457936451903530140172392 - (type(uint120).max / 2) = 0x69
        if (itemAmount > type(uint120).max - 1) {
            itemAmount = 664613997892457936451903530140172392;
        }

        // Set the order's numerator to 1 and denominator to the item amount
        // plus 1. This will result in a division that produces a remainder.
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

        // This mutation works by setting the demoninator of the order to a
        // value and the on chain denominator to values that, when summed
        // together, trigger a panic. The EVM doesn't like overflows.

        // (664613997892457936451903530140172393 +
        // 664613997892457936451903530140172297) > type(uint120).max

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

        // This mutation works by mutating the order to ask for a partial fill
        // on functions that don't support partial fills. Seaport will reject a
        // denominator that is not 1 for functions that don't support partial
        // fills.

        order.numerator = 1;
        order.denominator = 10;

        exec(context);
    }

    function mutation_noSpecifiedOrdersAvailable(
        FuzzTestContext memory context,
        MutationState memory /* mutationState */
    ) external {
        // This mutation works by wiping out all the orders. Seaport reverts if
        // `_validateOrdersAndPrepareToFulfill` finishes its loop and produces
        // no unskipped orders.
        for (uint256 i; i < context.executionState.orders.length; i++) {
            AdvancedOrder memory order = context.executionState.orders[i];
            order.parameters.endTime = 0;

            _signOrValidateMutatedOrder(context, i);
        }

        exec(context);
    }

    /**
     * @dev Helper function to sign or validate a mutated order, depending on
     *      which is necessary.
     *
     * @param context    The fuzz test context.
     * @param orderIndex The index of the order to sign or validate.
     */
    function _signOrValidateMutatedOrder(
        FuzzTestContext memory context,
        uint256 orderIndex
    ) private {
        AdvancedOrder memory order = context.executionState.orders[orderIndex];

        // If an order has been validated, then the mutated order should be
        // validated too so that we're conforming the failure paths as closely
        // as possible to the success paths.
        if (
            context.advancedOrdersSpace.orders[orderIndex].signatureMethod ==
            SignatureMethod.VALIDATE
        ) {
            order.inscribeOrderStatusValidated(true, context.seaport);
        } else if (context.executionState.caller != order.parameters.offerer) {
            // It's not necessary to sign an order if the caller is the offerer.
            // But if the caller is not the offerer, then sign the order using
            // the function from the order generator.
            AdvancedOrdersSpaceGenerator._signOrders(
                context.advancedOrdersSpace,
                context.executionState.orders,
                context.generatorContext
            );
        }
    }
}
