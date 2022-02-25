// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

/// @title ConsiderationEventsAndErrors contains all events and errors for Consideration.
/// @author 0age
interface ConsiderationEventsAndErrors {
    event OrderFulfilled(bytes32 orderHash, address indexed offerer, address indexed zone);
    event OrderCancelled(bytes32 orderHash, address indexed offerer, address indexed zone);
    event OrderValidated(bytes32 orderHash, address indexed offerer, address indexed zone);
    event NonceIncremented(uint256 newNonce, address indexed offerer, address indexed zone);

    error OrderUsed(bytes32);
    error InvalidTime();
    error InvalidSubmitterOnRestrictedOrder();
    error OfferAndConsiderationRequiredOnFulfillment();
    error NoConsiderationOnFulfillment();
    error FulfilledOrderIndexOutOfRange();
    error FulfilledOrderOfferIndexOutOfRange();
    error FulfilledOrderConsiderationIndexOutOfRange();
    error BadSignatureLength(uint256);
    error BadSignatureV(uint8);
    error BadSignature();
    error InvalidSignature();
    error BadContractSignature();
    error MismatchedFulfillmentOfferAndConsiderationComponents();
    error MismatchedFulfillmentOfferComponents();
    error MismatchedFulfillmentConsiderationComponents();
    error ConsiderationNotMet(uint256 orderIndex, uint256 considerationIndex, uint256 shortfallAmount);
    error EtherTransferGenericFailure(address account, uint256 amount);
    error TokenTransferGenericFailure(address token, address from, address to, uint256 identifier, uint256 amount);
    error ERC1155BatchTransferGenericFailure(address token, address from, address to, uint256[] identifiers, uint256[] amounts);
    error BadReturnValueFromERC20OnTransfer(address token, address from, address to, uint256 amount);
    error NoContract(address);
    error PartialFillsNotEnabledForOrder();
    error OrderIsCancelled(bytes32);
    error OrderAlreadyValidated(bytes32);
    error OrderNotUnused(bytes32);
    error OrderCriteriaResolverOutOfRange();
    error UnresolvedOfferCriteria();
    error UnresolvedConsiderationCriteria();
    error OfferCriteriaResolverOutOfRange();
    error ConsiderationCriteriaResolverOutOfRange();
    error CriteriaNotEnabledForOfferedItem();
    error CriteriaNotEnabledForConsideredItem();
    error InvalidProof();
    error InvalidCanceller();
    error InvalidNonceIncrementor();
    error BadFraction();
    error InexactFraction();
    error NoReentrantCalls();
    error InvalidProxyImplementation();
}