// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Consideration } from "seaport-core/src/lib/Consideration.sol";
import { Order, OrderComponents } from "seaport-types/src/lib/ConsiderationStructs.sol";
import { OrderType } from "seaport-types/src/lib/ConsiderationEnums.sol";

/**
 * @title OptimizedSeaport
 * @notice An optimized version of Seaport with additional features and gas optimizations
 */
contract OptimizedSeaport is Consideration {
    // Cache for frequently accessed data
    mapping(bytes32 => bool) private _cancelledOrders;
    mapping(address => uint256) private _orderCounts;
    
    // Events for better tracking
    event OrderCancelled(bytes32 indexed orderHash);
    event OrderFulfilled(bytes32 indexed orderHash, address indexed fulfiller);
    event BatchOrdersFulfilled(bytes32[] orderHashes, address indexed fulfiller);

    constructor(address conduitController) Consideration(conduitController) {}

    /**
     * @notice Cancel multiple orders in a single transaction
     * @param orderHashes Array of order hashes to cancel
     */
    function cancelOrders(bytes32[] calldata orderHashes) external {
        for (uint256 i = 0; i < orderHashes.length; i++) {
            _cancelledOrders[orderHashes[i]] = true;
            emit OrderCancelled(orderHashes[i]);
        }
    }

    /**
     * @notice Fulfill multiple orders in a single transaction
     * @param orders Array of orders to fulfill
     * @param fulfillerConduitKey The conduit key to use for fulfillment
     * @return fulfilled Array of booleans indicating which orders were fulfilled
     */
    function fulfillOrders(
        Order[] calldata orders,
        bytes32 fulfillerConduitKey
    ) external payable returns (bool[] memory fulfilled) {
        fulfilled = new bool[](orders.length);
        bytes32[] memory orderHashes = new bytes32[](orders.length);

        for (uint256 i = 0; i < orders.length; i++) {
            // Skip if order is cancelled
            bytes32 orderHash = _deriveOrderHash(
                _toOrderComponentsReturnType(_decodeOrderAsOrderComponents)(
                    CalldataStart.pptr()
                )
            );
            if (_cancelledOrders[orderHash]) continue;

            // Use the most efficient fulfillment method based on order type
            if (_isBasicOrder(orders[i])) {
                fulfilled[i] = _validateAndFulfillBasicOrder();
            } else {
                fulfilled[i] = _validateAndFulfillAdvancedOrder(
                    _toAdvancedOrderReturnType(_decodeOrderAsAdvancedOrder)(
                        CalldataStart.pptr()
                    ),
                    new CriteriaResolver[](0),
                    fulfillerConduitKey,
                    msg.sender
                );
            }

            if (fulfilled[i]) {
                orderHashes[i] = orderHash;
                _orderCounts[msg.sender]++;
            }
        }

        emit BatchOrdersFulfilled(orderHashes, msg.sender);
    }

    /**
     * @notice Check if an order is a basic order
     * @param order The order to check
     * @return bool True if the order is a basic order
     */
    function _isBasicOrder(Order calldata order) internal pure returns (bool) {
        return order.parameters.orderType == OrderType.FULL_OPEN ||
               order.parameters.orderType == OrderType.PARTIAL_OPEN;
    }

    /**
     * @notice Get the number of orders fulfilled by an address
     * @param user The address to check
     * @return uint256 The number of orders fulfilled
     */
    function getOrderCount(address user) external view returns (uint256) {
        return _orderCounts[user];
    }

    /**
     * @notice Check if an order is cancelled
     * @param orderHash The hash of the order to check
     * @return bool True if the order is cancelled
     */
    function isOrderCancelled(bytes32 orderHash) external view returns (bool) {
        return _cancelledOrders[orderHash];
    }

    /**
     * @dev Internal pure function to retrieve and return the name of this contract
     * @return The name of this contract
     */
    function _name() internal pure override returns (string memory) {
        return "OptimizedSeaport";
    }

    /**
     * @dev Internal pure function to retrieve the name of this contract as a string
     * @return The name of this contract as a string
     */
    function _nameString() internal pure override returns (string memory) {
        return "OptimizedSeaport";
    }
} 