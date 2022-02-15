// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {
    OrderType,
    AssetType,
    Side
} from "./Enums.sol";

import {
    OfferedAsset,
    ReceivedAsset,
    OrderParameters,
    OrderComponents,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    Order,
    OrderStatus,
    CriteriaResolver
} from "./Structs.sol";

interface ConsiderationInterface {
    function fulfillOrder(Order memory order) external payable returns (bool);
    function fulfillOrderWithCriteria(
        Order memory order,
        CriteriaResolver[] memory criteriaResolvers
    ) external payable returns (bool);
    function fulfillPartialOrder(
        Order memory order,
        uint120 numerator,
        uint120 denominator
    ) external payable returns (bool);
    function matchOrders(
        Order[] memory orders,
        CriteriaResolver[] memory criteriaResolvers,
        Fulfillment[] memory fulfillments
    ) external payable returns (Execution[] memory);
    function cancel(
        OrderComponents[] memory orders
    ) external returns (bool ok);
    function validate(
        Order[] memory orders
    ) external returns (bool ok);
    function incrementFacilitatorNonce(
        address offerer,
        address facilitator
    ) external returns (uint256 nonce);

    function getOrderHash(
        OrderComponents memory order
    ) external view returns (bytes32);
    function name() external view returns (string memory);
    function version() external view returns (string memory);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function getOrderStatus(bytes32 orderHash) external view returns (OrderStatus memory);
    function facilitatorNonce(address offerer, address facilitator) external view returns (uint256);

    // TODO: decide what data is required here
    event OrderFulfilled(bytes32 orderHash, address indexed offerer, address facilitator);
    event OrderCancelled(bytes32 orderHash, address indexed offerer, address facilitator);
    event OrderValidated(bytes32 orderHash, address indexed offerer, address facilitator);
    event FacilitatorNonceIncremented(address indexed offerer, address facilitator, uint256 nonce);

    error NoOffersWithCriteriaOnBasicMatch();
    error NoConsiderationWithCriteriaOnBasicMatch();
    error OrderUsed(bytes32);
    error InvalidTime();
    error InvalidSubmitterOnRestrictedOrder();
    error NoOfferOnFulfillment();
    error NoConsiderationOnFulfillment();
    error FulfilledOrderIndexOutOfRange();
    error FulfilledOrderOfferIndexOutOfRange();
    error FulfillmentOrderIndexOutOfRange();
    error FulfillmentOrderConsiderationIndexOutOfRange();
    error BadSignatureLength(uint256);
    error BadSignatureV(uint8);
    error MalleableSignatureS(uint256);
    error BadSignature();
    error InvalidSignature();
    error BadContractSignature();
    error MismatchedFulfillmentOfferComponents();
    error MismatchedFulfillmentConsiderationComponents();
    error ConsiderationNotMet(uint256 orderIndex, uint256 considerationIndex, uint256 shortfallAmount);
    error EtherTransferGenericFailure(address account, uint256 amount);
    error ERC20TransferGenericFailure(address token, address account, uint256 amount);
    error ERC721TransferGenericFailure(address token, address account, uint256 identifier);
    error ERC1155TransferGenericFailure(address token, address account, uint256 identifier, uint256 amount);
    error BadReturnValueFromERC20OnTransfer(address token, address account, uint256 amount);
    error ERC20TransferNoContract(address);
    error ERC721TransferNoContract(address);
    error ERC1155TransferNoContract(address);
    error PartialFillsNotEnabledForOrder();
    error OrderIsCancelled(bytes32);
    error OrderAlreadyValidated(bytes32);
    error OrderCriteriaResolverOutOfRange();
    error UnresolvedOfferCriteria();
    error UnresolvedConsiderationCriteria();
    error OfferCriteriaResolverOutOfRange();
    error ConsiderationCriteriaResolverOutOfRange();
    error CriteriaNotEnabledForOfferedAsset();
    error CriteriaNotEnabledForConsideredAsset();
    error InvalidProof();
    error OnlyOffererOrFacilitatorMayCancel();
    error OnlyOffererOrFacilitatorMayIncrementNonce();
    error BadFraction();
    error InexactFraction();
    error NoReentrantCalls();
}