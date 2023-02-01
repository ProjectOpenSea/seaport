// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {
    BadContractSignature_error_selector,
    BadFraction_error_selector,
    BadSignatureV_error_selector,
    CannotCancelOrder_error_selector,
    ConsiderationCriteriaResolverOutOfRange_error_selector,
    ConsiderationLengthNotEqualToTotalOriginal_error_selector,
    ConsiderationNotMet_error_selector,
    CriteriaNotEnabledForItem_error_selector,
    InexactFraction_error_selector,
    InsufficientNativeTokensSupplied_error_selector,
    InvalidBasicOrderParameterEncoding_error_selector,
    InvalidCallToConduit_error_selector,
    InvalidConduit_error_selector,
    InvalidContractOrder_error_selector,
    InvalidERC721TransferAmount_error_selector,
    InvalidFulfillmentComponentData_error_selector,
    InvalidMsgValue_error_selector,
    InvalidNativeOfferItem_error_selector,
    InvalidProof_error_selector,
    InvalidRestrictedOrder_error_selector,
    InvalidSignature_error_selector,
    InvalidSigner_error_selector,
    InvalidTime_error_selector,
    MismatchedOfferAndConsiderationComponents_error_selector,
    MissingFulfillmentComponentOnAggregation_error_selector,
    MissingItemAmount_error_selector,
    MissingOriginalConsiderationItems_error_selector,
    NativeTokenTransferGenericFailure_error_selector,
    NoReentrantCalls_error_selector,
    NoSpecifiedOrdersAvailable_error_selector,
    OfferAndConsiderationRequiredOnFulfillment_error_selector,
    OfferCriteriaResolverOutOfRange_error_selector,
    OrderAlreadyFilled_error_selector,
    OrderCriteriaResolverOutOfRange_error_selector,
    OrderIsCancelled_error_selector,
    OrderPartiallyFilled_error_selector,
    Panic_error_selector,
    PartialFillsNotEnabledForOrder_error_selector,
    UnresolvedConsiderationCriteria_error_selector,
    UnresolvedOfferCriteria_error_selector,
    UnusedItemParameters_error_selector
} from "../../contracts/lib/ConsiderationErrorConstants.sol";

import {
    BadReturnValueFromERC20OnTransfer_error_selector,
    NoContract_error_selector,
    TokenTransferGenericFailure_error_selector
} from "../../contracts/lib/TokenTransferrerConstants.sol";

import {
    generateOrder_selector,
    ratifyOrder_selector,
    validateOrder_selector
} from "../../contracts/lib/ConsiderationConstants.sol";

import { BaseConsiderationTest } from "./utils/BaseConsiderationTest.sol";

import {
    FulfillmentApplicationErrors
} from "../../contracts/interfaces/FulfillmentApplicationErrors.sol";

import {
    AmountDerivationErrors
} from "../../contracts/interfaces/AmountDerivationErrors.sol";

import {
    CriteriaResolutionErrors
} from "../../contracts/interfaces/CriteriaResolutionErrors.sol";

import {
    ZoneInteractionErrors
} from "../../contracts/interfaces/ZoneInteractionErrors.sol";

import {
    SignatureVerificationErrors
} from "../../contracts/interfaces/SignatureVerificationErrors.sol";

import {
    TokenTransferrerErrors
} from "../../contracts/interfaces/TokenTransferrerErrors.sol";

import {
    ReentrancyErrors
} from "../../contracts/interfaces/ReentrancyErrors.sol";

import {
    ConsiderationEventsAndErrors
} from "../../contracts/interfaces/ConsiderationEventsAndErrors.sol";

import {
    ContractOffererInterface
} from "../../contracts/interfaces/ContractOffererInterface.sol";

import { ZoneInterface } from "../../contracts/interfaces/ZoneInterface.sol";

contract ConstantsTest is BaseConsiderationTest {
    function _test(uint256 _constant, bytes4 selector) public {
        uint256 _selector = uint256(bytes32(selector) >> uint256(256 - 32));
        assertEq(_constant, _selector);
    }

    function testMissingFulfillmentComponentOnAggregation_error_selector()
        public
    {
        _test(
            MissingFulfillmentComponentOnAggregation_error_selector,
            FulfillmentApplicationErrors
                .MissingFulfillmentComponentOnAggregation
                .selector
        );
    }

    function testOfferAndConsiderationRequiredOnFulfillment_error_selector()
        public
    {
        _test(
            OfferAndConsiderationRequiredOnFulfillment_error_selector,
            FulfillmentApplicationErrors
                .OfferAndConsiderationRequiredOnFulfillment
                .selector
        );
    }

    function testMismatchedFulfillmentOfferAndConsiderationComponents_error_selector()
        public
    {
        _test(
            MismatchedOfferAndConsiderationComponents_error_selector,
            FulfillmentApplicationErrors
                .MismatchedFulfillmentOfferAndConsiderationComponents
                .selector
        );
    }

    function testInvalidFulfillmentComponentData_error_selector() public {
        _test(
            InvalidFulfillmentComponentData_error_selector,
            FulfillmentApplicationErrors
                .InvalidFulfillmentComponentData
                .selector
        );
    }

    function testInexactFraction_error_selector() public {
        _test(
            InexactFraction_error_selector,
            AmountDerivationErrors.InexactFraction.selector
        );
    }

    function testOrderCriteriaResolverOutOfRange_error_selector() public {
        _test(
            OrderCriteriaResolverOutOfRange_error_selector,
            CriteriaResolutionErrors.OrderCriteriaResolverOutOfRange.selector
        );
    }

    function testUnresolvedOfferCriteria_error_selector() public {
        _test(
            UnresolvedOfferCriteria_error_selector,
            CriteriaResolutionErrors.UnresolvedOfferCriteria.selector
        );
    }

    function testUnresolvedConsiderationCriteria_error_selector() public {
        _test(
            UnresolvedConsiderationCriteria_error_selector,
            CriteriaResolutionErrors.UnresolvedConsiderationCriteria.selector
        );
    }

    function testOfferCriteriaResolverOutOfRange_error_selector() public {
        _test(
            OfferCriteriaResolverOutOfRange_error_selector,
            CriteriaResolutionErrors.OfferCriteriaResolverOutOfRange.selector
        );
    }

    function testConsiderationCriteriaResolverOutOfRange_error_selector()
        public
    {
        _test(
            ConsiderationCriteriaResolverOutOfRange_error_selector,
            CriteriaResolutionErrors
                .ConsiderationCriteriaResolverOutOfRange
                .selector
        );
    }

    function testCriteriaNotEnabledForItem_error_selector() public {
        _test(
            CriteriaNotEnabledForItem_error_selector,
            CriteriaResolutionErrors.CriteriaNotEnabledForItem.selector
        );
    }

    function testInvalidProof_error_selector() public {
        _test(
            InvalidProof_error_selector,
            CriteriaResolutionErrors.InvalidProof.selector
        );
    }

    function testInvalidRestrictedOrder_error_selector() public {
        _test(
            InvalidRestrictedOrder_error_selector,
            ZoneInteractionErrors.InvalidRestrictedOrder.selector
        );
    }

    function testInvalidContractOrder_error_selector() public {
        _test(
            InvalidContractOrder_error_selector,
            ZoneInteractionErrors.InvalidContractOrder.selector
        );
    }

    function testBadSignatureV_error_selector() public {
        _test(
            BadSignatureV_error_selector,
            SignatureVerificationErrors.BadSignatureV.selector
        );
    }

    function testInvalidSigner_error_selector() public {
        _test(
            InvalidSigner_error_selector,
            SignatureVerificationErrors.InvalidSigner.selector
        );
    }

    function testInvalidSignature_error_selector() public {
        _test(
            InvalidSignature_error_selector,
            SignatureVerificationErrors.InvalidSignature.selector
        );
    }

    function testBadContractSignature_error_selector() public {
        _test(
            BadContractSignature_error_selector,
            SignatureVerificationErrors.BadContractSignature.selector
        );
    }

    function testInvalidERC721TransferAmount_error_selector() public {
        _test(
            InvalidERC721TransferAmount_error_selector,
            TokenTransferrerErrors.InvalidERC721TransferAmount.selector
        );
    }

    function testMissingItemAmount_error_selector() public {
        _test(
            MissingItemAmount_error_selector,
            TokenTransferrerErrors.MissingItemAmount.selector
        );
    }

    function testUnusedItemParameters_error_selector() public {
        _test(
            UnusedItemParameters_error_selector,
            TokenTransferrerErrors.UnusedItemParameters.selector
        );
    }

    function testBadReturnValueFromERC20OnTransfer_error_selector() public {
        _test(
            BadReturnValueFromERC20OnTransfer_error_selector,
            TokenTransferrerErrors.BadReturnValueFromERC20OnTransfer.selector
        );
    }

    function testNoContract_error_selector() public {
        _test(
            NoContract_error_selector,
            TokenTransferrerErrors.NoContract.selector
        );
    }

    function testTokenTransferGenericFailure_error_selector() public {
        _test(
            TokenTransferGenericFailure_error_selector,
            TokenTransferrerErrors.TokenTransferGenericFailure.selector
        );
    }

    function testNoReentrantCalls_error_selector() public {
        _test(
            NoReentrantCalls_error_selector,
            ReentrancyErrors.NoReentrantCalls.selector
        );
    }

    function testOrderAlreadyFilled_error_selector() public {
        _test(
            OrderAlreadyFilled_error_selector,
            ConsiderationEventsAndErrors.OrderAlreadyFilled.selector
        );
    }

    function testInvalidTime_error_selector() public {
        _test(
            InvalidTime_error_selector,
            ConsiderationEventsAndErrors.InvalidTime.selector
        );
    }

    function testInvalidConduit_error_selector() public {
        _test(
            InvalidConduit_error_selector,
            ConsiderationEventsAndErrors.InvalidConduit.selector
        );
    }

    function testMissingOriginalConsiderationItems_error_selector() public {
        _test(
            MissingOriginalConsiderationItems_error_selector,
            ConsiderationEventsAndErrors
                .MissingOriginalConsiderationItems
                .selector
        );
    }

    function testInvalidCallToConduit_error_selector() public {
        _test(
            InvalidCallToConduit_error_selector,
            ConsiderationEventsAndErrors.InvalidCallToConduit.selector
        );
    }

    function testConsiderationNotMet_error_selector() public {
        _test(
            ConsiderationNotMet_error_selector,
            ConsiderationEventsAndErrors.ConsiderationNotMet.selector
        );
    }

    function testInsufficientNativeTokensSupplied_error_selector() public {
        _test(
            InsufficientNativeTokensSupplied_error_selector,
            ConsiderationEventsAndErrors
                .InsufficientNativeTokensSupplied
                .selector
        );
    }

    function testNativeTokenTransferGenericFailure_error_selector() public {
        _test(
            NativeTokenTransferGenericFailure_error_selector,
            ConsiderationEventsAndErrors
                .NativeTokenTransferGenericFailure
                .selector
        );
    }

    function testPartialFillsNotEnabledForOrder_error_selector() public {
        _test(
            PartialFillsNotEnabledForOrder_error_selector,
            ConsiderationEventsAndErrors.PartialFillsNotEnabledForOrder.selector
        );
    }

    function testOrderIsCancelled_error_selector() public {
        _test(
            OrderIsCancelled_error_selector,
            ConsiderationEventsAndErrors.OrderIsCancelled.selector
        );
    }

    function testOrderPartiallyFilled_error_selector() public {
        _test(
            OrderPartiallyFilled_error_selector,
            ConsiderationEventsAndErrors.OrderPartiallyFilled.selector
        );
    }

    function testCannotCancelOrder_error_selector() public {
        _test(
            CannotCancelOrder_error_selector,
            ConsiderationEventsAndErrors.CannotCancelOrder.selector
        );
    }

    function testBadFraction_error_selector() public {
        _test(
            BadFraction_error_selector,
            ConsiderationEventsAndErrors.BadFraction.selector
        );
    }

    function testInvalidMsgValue_error_selector() public {
        _test(
            InvalidMsgValue_error_selector,
            ConsiderationEventsAndErrors.InvalidMsgValue.selector
        );
    }

    function testInvalidBasicOrderParameterEncoding_error_selector() public {
        _test(
            InvalidBasicOrderParameterEncoding_error_selector,
            ConsiderationEventsAndErrors
                .InvalidBasicOrderParameterEncoding
                .selector
        );
    }

    function testNoSpecifiedOrdersAvailable_error_selector() public {
        _test(
            NoSpecifiedOrdersAvailable_error_selector,
            ConsiderationEventsAndErrors.NoSpecifiedOrdersAvailable.selector
        );
    }

    function testInvalidNativeOfferItem_error_selector() public {
        _test(
            InvalidNativeOfferItem_error_selector,
            ConsiderationEventsAndErrors.InvalidNativeOfferItem.selector
        );
    }

    function testConsiderationLengthNotEqualToTotalOriginal_error_selector()
        public
    {
        _test(
            ConsiderationLengthNotEqualToTotalOriginal_error_selector,
            ConsiderationEventsAndErrors
                .ConsiderationLengthNotEqualToTotalOriginal
                .selector
        );
    }

    function testPanic_error_selector() public {
        bytes memory panicSig = abi.encodeWithSignature("Panic(uint256)", 0);
        uint256 selector = uint256(bytes32(panicSig) >> uint256(256 - 32));

        assertEq(Panic_error_selector, selector);
    }

    function testGenerateOrder_selector() public {
        _test(
            generateOrder_selector,
            ContractOffererInterface.generateOrder.selector
        );
    }

    function testRatifyOrder_selector() public {
        _test(
            ratifyOrder_selector,
            ContractOffererInterface.ratifyOrder.selector
        );
    }

    function testValidateOrder_selector() public {
        _test(validateOrder_selector, ZoneInterface.validateOrder.selector);
    }
}
