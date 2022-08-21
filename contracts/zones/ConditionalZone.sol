// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";
import { SeaportInterface } from "../interfaces/SeaportInterface.sol";

import {
    AdvancedOrder,
    CriteriaResolver
} from "../lib/ConsiderationStructs.sol";

/**
 * @title  ConditionalZone
 * @author Slokh
 * @notice ConditionalZone allows for orders validated by logic gates.
 */
contract ConditionalZone is ZoneInterface {
    SeaportInterface seaport;

    enum LogicGate {
        AND,
        OR,
        XOR,
        NAND,
        NOR,
        XNOR
    }

    struct Condition {
        LogicGate logicGate;
        bytes32[] orderHashes;
    }

    constructor(address seaportAddress) {
        seaport = SeaportInterface(seaportAddress);
    }

    /**
     * @notice Check if a given order is currently valid.
     *
     * @dev This function is called by Seaport whenever extraData is not
     *      provided by the caller.
     *
     * @param orderHash The hash of the order.
     * @param caller    The caller in question.
     * @param offerer   The offerer in question.
     * @param zoneHash  The hash to provide upon calling the zone.
     *
     * @return validOrderMagicValue A magic value indicating if the order is
     *                              currently valid.
     */
    function isValidOrder(
        bytes32 orderHash,
        address caller,
        address offerer,
        bytes32 zoneHash
    ) external pure override returns (bytes4 validOrderMagicValue) {
        orderHash;
        caller;
        offerer;
        zoneHash;

        // If the order has a zoneHash, extraData must be provided to be validated against.
        if (zoneHash != "") {
            revert("Must provide extraData");
        }

        // Return the selector of isValidOrder as the magic value.
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    /**
     * @notice Check if a given order including extraData is currently valid.
     *
     * @dev This function is called by Seaport whenever any extraData is
     *      provided by the caller.
     *
     * @param orderHash         The hash of the order.
     * @param caller            The caller in question.
     * @param order             The order in question.
     * @param priorOrderHashes  The order hashes of each order supplied prior to
     *                          the current order as part of a "match" variety
     *                          of order fulfillment.
     * @param criteriaResolvers The criteria resolvers corresponding to
     *                          the order.
     *
     * @return validOrderMagicValue A magic value indicating if the order is
     *                              currently valid.
     */
    function isValidOrderIncludingExtraData(
        bytes32 orderHash,
        address caller,
        AdvancedOrder calldata order,
        bytes32[] calldata priorOrderHashes,
        CriteriaResolver[] calldata criteriaResolvers
    ) external view override returns (bytes4 validOrderMagicValue) {
        orderHash;
        caller;
        priorOrderHashes;
        criteriaResolvers;

        // Only validate if there is a zoneHash
        if (order.parameters.zoneHash != "") {
            if (order.parameters.zoneHash != keccak256(order.extraData)) {
                revert("Hash does not match");
            }

            Condition memory condition = decodeCondition(order.extraData);

            // TODO: Optimize this entire loop
            uint256 conditionResult;
            for (uint256 i = 0; i < condition.orderHashes.length; i++) {
                (
                    ,
                    bool isCancelled,
                    uint256 totalFilled,
                    uint256 totalSize
                ) = seaport.getOrderStatus(condition.orderHashes[i]);

                // If the an order in the condition is cancelled, this order can never be valid.
                if (isCancelled) {
                    revert("A dependant order is cancelled");
                }

                uint256 isFilled = totalFilled > 0 && totalFilled == totalSize
                    ? 1
                    : 0;
                if (i == 0) {
                    conditionResult = isFilled;
                } else if (
                    condition.logicGate == LogicGate.AND ||
                    condition.logicGate == LogicGate.NAND
                ) {
                    conditionResult = conditionResult & isFilled;
                } else if (
                    condition.logicGate == LogicGate.OR ||
                    condition.logicGate == LogicGate.NOR
                ) {
                    conditionResult = conditionResult | isFilled;
                } else if (
                    condition.logicGate == LogicGate.XOR ||
                    condition.logicGate == LogicGate.XNOR
                ) {
                    conditionResult = conditionResult ^ isFilled;
                }
            }

            uint256 expectedResult = condition.logicGate == LogicGate.NAND ||
                condition.logicGate == LogicGate.NOR ||
                condition.logicGate == LogicGate.XNOR
                ? 0
                : 1;

            if (conditionResult != expectedResult) {
                revert("Condition not met");
            }
        }

        // Return the selector of isValidOrder as the magic value.
        validOrderMagicValue = ZoneInterface.isValidOrder.selector;
    }

    function decodeCondition(bytes memory _data)
        public
        pure
        returns (Condition memory condition)
    {
        uint256 dataLength = _data.length;

        uint8 tempLogicGate;
        assembly {
            tempLogicGate := mload(add(_data, 1))
        }
        condition.logicGate = LogicGate(tempLogicGate);

        bytes32[] memory orderHashes = new bytes32[](dataLength / 32);
        uint256 index = 0;
        bytes32 temp;

        for (uint256 i = 33; i <= dataLength; i += 32) {
            assembly {
                temp := mload(add(_data, i))
            }
            orderHashes[index] = temp;
            index++;
        }

        condition.orderHashes = orderHashes;
    }

    function encodeCondition(Condition memory condition)
        public
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            uint8(condition.logicGate),
            condition.orderHashes
        );
    }
}
