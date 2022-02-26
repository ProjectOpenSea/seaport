// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    BasicOrderParameters,
    OrderComponents,
    Fulfillment,
    Execution,
    BatchExecution,
    Order,
    PartialOrder,
    OrderStatus,
    CriteriaResolver
} from "../lib/Structs.sol";

/// @title ConsiderationInterface contains all external function interfaces for Consideration.
/// @author 0age
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
        PartialOrder memory partialOrder,
        bool useFulfillerProxy
    ) external payable returns (bool);

    function fulfillPartialOrderWithCriteria(
        PartialOrder memory partialOrder,
        CriteriaResolver[] memory criteriaResolvers,
        bool useFulfillerProxy
    ) external payable returns (bool);

    function matchOrders(
        Order[] memory orders,
        CriteriaResolver[] memory criteriaResolvers,
        Fulfillment[] memory fulfillments
    ) external payable returns (
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    );

    function matchPartialOrders(
        PartialOrder[] memory orders,
        CriteriaResolver[] memory criteriaResolvers,
        Fulfillment[] memory fulfillments
    ) external payable returns (
        Execution[] memory standardExecutions,
        BatchExecution[] memory batchExecutions
    );

    function cancel(
        OrderComponents[] memory orders
    ) external returns (bool);

    function validate(
        Order[] memory orders
    ) external returns (bool);

    function incrementNonce(
        address offerer,
        address zone
    ) external returns (uint256 newNonce);

    function getOrderHash(
        OrderComponents memory order
    ) external view returns (bytes32);

    function getOrderStatus(
        bytes32 orderHash
    ) external view returns (OrderStatus memory);

    function getNonce(
        address offerer,
        address zone
    ) external view returns (uint256);

    function name() external view returns (string memory);
    function version() external view returns (string memory);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}