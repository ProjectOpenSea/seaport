// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    BasicOrderParameters,
    OrderComponents,
    Fulfillment,
    Execution,
    Order,
    OrderStatus,
    CriteriaResolver
} from "./Structs.sol";

interface ConsiderationInterface {
    function fulfillBasicEthForERC721Order(
        uint256 etherAmount,
        BasicOrderParameters calldata parameters
    ) external payable returns (bool);

    function fulfillBasicEthForERC1155Order(
        uint256 etherAmount,
        uint256 erc1155Amount,
        BasicOrderParameters calldata parameters
    ) external payable returns (bool);

    function fulfillBasicERC20ForERC721Order(
        address erc20Token,
        uint256 erc20Amount,
        BasicOrderParameters calldata parameters
    ) external returns (bool);

    function fulfillBasicERC20ForERC1155Order(
        address erc20Token,
        uint256 erc20Amount,
        uint256 erc1155Amount,
        BasicOrderParameters calldata parameters
    ) external returns (bool);

    function fulfillBasicERC721ForERC20Order(
        address erc20Token,
        uint256 erc20Amount,
        BasicOrderParameters calldata parameters
    ) external returns (bool);

    function fulfillBasicERC1155ForERC20Order(
        address erc20Token,
        uint256 erc20Amount,
        uint256 erc1155Amount,
        BasicOrderParameters calldata parameters
    ) external returns (bool);

    function fulfillOrder(
        Order memory order,
        bool useFulfillerProxy
    ) external payable returns (bool);

    function fulfillOrderWithCriteria(
        Order memory order,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) external payable returns (bool);

    function fulfillPartialOrder(
        Order memory order,
        uint120 numerator,
        uint120 denominator,
        bool useFulfillerProxy
    ) external payable returns (bool);

    function fulfillPartialOrderWithCriteria(
        Order memory order,
        uint120 numerator,
        uint120 denominator,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) external payable returns (bool);

    function matchOrders(
        Order[] memory orders,
        CriteriaResolver[] memory criteriaResolvers,
        Fulfillment[] memory fulfillments
    ) external payable returns (Execution[] memory);

    function cancel(
        OrderComponents[] memory orders
    ) external returns (bool);

    function validate(
        Order[] memory orders
    ) external returns (bool);

    function incrementFacilitatorNonce(
        address offerer,
        address facilitator
    ) external returns (uint256 newNonce);

    function getOrderHash(
        OrderComponents memory order
    ) external view returns (bytes32);

    function getOrderStatus(
        bytes32 orderHash
    ) external view returns (OrderStatus memory);

    function facilitatorNonce(
        address offerer,
        address facilitator
    ) external view returns (uint256);

    function name() external view returns (string memory);
    function version() external view returns (string memory);
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    // TODO: decide what data is required here
    event OrderFulfilled(bytes32 orderHash, address indexed offerer, address facilitator);
    event OrderCancelled(bytes32 orderHash, address indexed offerer, address facilitator);
    event OrderValidated(bytes32 orderHash, address indexed offerer, address facilitator);
    event FacilitatorNonceIncremented(address indexed offerer, address facilitator, uint256 nonce);


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
    error MalleableSignatureS(uint256);
    error BadSignature();
    error InvalidSignature();
    error BadContractSignature();
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
    error CriteriaNotEnabledForOfferedAsset();
    error CriteriaNotEnabledForConsideredAsset();
    error InvalidProof();
    error OnlyOffererOrFacilitatorMayCancel();
    error OnlyOffererOrFacilitatorMayIncrementNonce();
    error BadFraction();
    error InexactFraction();
    error NoReentrantCalls();
    error InvalidUserProxyImplementation();
}