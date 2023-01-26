// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import {
    ConsiderationErrorsWrapper
} from "./utils/ConsiderationErrorsWrapper.sol";

import { Side } from "../../contracts/lib/ConsiderationEnums.sol";

import "../../contracts/lib/ConsiderationConstants.sol";

contract ConsiderationErrors is BaseOrderTest, ConsiderationErrorsWrapper {
    address someAddress;
    bytes32 someBytes32;

    constructor() {
        someAddress = makeAddr("someAddress");
        someBytes32 = keccak256(abi.encodePacked("someBytes32"));
    }

    function test_revertBadFraction() public {
        vm.expectRevert(abi.encodeWithSignature("BadFraction()"));
        this.__revertBadFraction();
    }

    function test_revertConsiderationNotMet() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "ConsiderationNotMet(uint256,uint256,uint256)",
                1,
                2,
                3
            )
        );
        this.__revertConsiderationNotMet(1, 2, 3);
    }

    function test_revertCriteriaNotEnabledForItem() public {
        vm.expectRevert(abi.encodeWithSignature("CriteriaNotEnabledForItem()"));
        this.__revertCriteriaNotEnabledForItem();
    }

    function test_revertInsufficientNativeTokensSupplied() public {
        vm.expectRevert(
            abi.encodeWithSignature("InsufficientNativeTokensSupplied()")
        );
        this.__revertInsufficientNativeTokensSupplied();
    }

    function test_revertInvalidBasicOrderParameterEncoding() public {
        vm.expectRevert(
            abi.encodeWithSignature("InvalidBasicOrderParameterEncoding()")
        );
        this.__revertInvalidBasicOrderParameterEncoding();
    }

    function test_revertInvalidCallToConduit() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidCallToConduit(address)",
                someAddress
            )
        );
        this.__revertInvalidCallToConduit(someAddress);
    }

    function test_revertInvalidConduit() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidConduit(bytes32,address)",
                someBytes32,
                someAddress
            )
        );
        this.__revertInvalidConduit(someBytes32, someAddress);
    }

    function test_revertInvalidERC721TransferAmount() public {
        vm.expectRevert(
            abi.encodeWithSignature("InvalidERC721TransferAmount(uint256)", 4)
        );
        this.__revertInvalidERC721TransferAmount(4);
    }

    function test_revertInvalidMsgValue() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidMsgValue(uint256)", 5));
        this.__revertInvalidMsgValue(5);
    }

    function test_revertInvalidNativeOfferItem() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidNativeOfferItem()"));
        this.__revertInvalidNativeOfferItem();
    }

    function test_revertInvalidProof() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidProof()"));
        this.__revertInvalidProof();
    }

    function test_revertInvalidContractOrder() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidContractOrder(bytes32)",
                someBytes32
            )
        );
        this.__revertInvalidContractOrder(someBytes32);
    }

    function test_revertInvalidTime() public {
        vm.expectRevert(
            abi.encodeWithSignature("InvalidTime(uint256,uint256)", 6, 7)
        );
        this.__revertInvalidTime(6, 7);
    }

    function test_revertMismatchedFulfillmentOfferAndConsiderationComponents()
        public
    {
        vm.expectRevert(
            abi.encodeWithSignature(
                "MismatchedFulfillmentOfferAndConsiderationComponents(uint256)",
                8
            )
        );
        this.__revertMismatchedFulfillmentOfferAndConsiderationComponents(8);
    }

    function test_revertMissingOriginalConsiderationItems() public {
        vm.expectRevert(
            abi.encodeWithSignature("MissingOriginalConsiderationItems()")
        );
        this.__revertMissingOriginalConsiderationItems();
    }

    function test_revertNoReentrantCalls() public {
        vm.expectRevert(abi.encodeWithSignature("NoReentrantCalls()"));
        this.__revertNoReentrantCalls();
    }

    function test_revertNoSpecifiedOrdersAvailable() public {
        vm.expectRevert(
            abi.encodeWithSignature("NoSpecifiedOrdersAvailable()")
        );
        this.__revertNoSpecifiedOrdersAvailable();
    }

    function test_revertOfferAndConsiderationRequiredOnFulfillment() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "OfferAndConsiderationRequiredOnFulfillment()"
            )
        );
        this.__revertOfferAndConsiderationRequiredOnFulfillment();
    }

    function test_revertOrderAlreadyFilled() public {
        vm.expectRevert(
            abi.encodeWithSignature("OrderAlreadyFilled(bytes32)", someBytes32)
        );
        this.__revertOrderAlreadyFilled(someBytes32);
    }

    function test_revertOrderCriteriaResolverOutOfRange() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "OrderCriteriaResolverOutOfRange(uint8)",
                Side.CONSIDERATION
            )
        );
        this.__revertOrderCriteriaResolverOutOfRange(Side.CONSIDERATION);
    }

    function test_revertOrderIsCancelled() public {
        vm.expectRevert(
            abi.encodeWithSignature("OrderIsCancelled(bytes32)", someBytes32)
        );
        this.__revertOrderIsCancelled(someBytes32);
    }

    function test_revertOrderPartiallyFilled() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "OrderPartiallyFilled(bytes32)",
                someBytes32
            )
        );
        this.__revertOrderPartiallyFilled(someBytes32);
    }

    function test_revertPartialFillsNotEnabledForOrder() public {
        vm.expectRevert(
            abi.encodeWithSignature("PartialFillsNotEnabledForOrder()")
        );
        this.__revertPartialFillsNotEnabledForOrder();
    }

    function test_revertUnresolvedConsiderationCriteria() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "UnresolvedConsiderationCriteria(uint256,uint256)",
                9,
                10
            )
        );
        this.__revertUnresolvedConsiderationCriteria(9, 10);
    }

    function test_revertUnresolvedOfferCriteria() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "UnresolvedOfferCriteria(uint256,uint256)",
                11,
                12
            )
        );
        this.__revertUnresolvedOfferCriteria(11, 12);
    }

    function test_revertUnusedItemParameters() public {
        vm.expectRevert(abi.encodeWithSignature("UnusedItemParameters()"));
        this.__revertUnusedItemParameters();
    }
}
