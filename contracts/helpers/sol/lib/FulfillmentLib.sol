// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    Fulfillment,
    FulfillmentComponent
} from "../../../lib/ConsiderationStructs.sol";
import { Side } from "../../../lib/ConsiderationEnums.sol";
import { ArrayLib } from "./ArrayLib.sol";
import { FulfillmentComponentLib } from "./FulfillmentComponentLib.sol";
import { StructCopier } from "./StructCopier.sol";

library FulfillmentLib {
    bytes32 private constant FULFILLMENT_MAP_POSITION =
        keccak256("seaport.FulfillmentDefaults");
    bytes32 private constant FULFILLMENTS_MAP_POSITION =
        keccak256("seaport.FulfillmentsDefaults");

    using FulfillmentComponentLib for FulfillmentComponent[];
    using StructCopier for FulfillmentComponent[];

    /**
     * @notice clears a default Fulfillment from storage
     * @param defaultName the name of the default to clear
     */

    function clear(string memory defaultName) internal {
        mapping(string => Fulfillment)
            storage fulfillmentMap = _fulfillmentMap();
        Fulfillment storage _fulfillment = fulfillmentMap[defaultName];
        // clear all fields
        FulfillmentComponent[] memory components;
        _fulfillment.offerComponents.setFulfillmentComponents(components);
        _fulfillment.considerationComponents.setFulfillmentComponents(
            components
        );
    }

    /**
     * @notice gets a default Fulfillment from storage
     * @param defaultName the name of the default for retrieval
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (Fulfillment memory _fulfillment) {
        mapping(string => Fulfillment)
            storage fulfillmentMap = _fulfillmentMap();
        _fulfillment = fulfillmentMap[defaultName];
    }

    function fromDefaultMany(
        string memory defaultName
    ) internal view returns (Fulfillment[] memory _fulfillments) {
        mapping(string => Fulfillment[])
            storage fulfillmentsMap = _fulfillmentsMap();
        _fulfillments = fulfillmentsMap[defaultName];
    }

    /**
     * @notice saves an Fulfillment as a named default
     * @param fulfillment the Fulfillment to save as a default
     * @param defaultName the name of the default for retrieval
     */
    function saveDefault(
        Fulfillment memory fulfillment,
        string memory defaultName
    ) internal returns (Fulfillment memory _fulfillment) {
        mapping(string => Fulfillment)
            storage fulfillmentMap = _fulfillmentMap();
        StructCopier.setFulfillment(fulfillmentMap[defaultName], fulfillment);

        return fulfillment;
    }

    function saveDefaultMany(
        Fulfillment[] memory fulfillments,
        string memory defaultName
    ) internal returns (Fulfillment[] memory _fulfillments) {
        mapping(string => Fulfillment[])
            storage fulfillmentsMap = _fulfillmentsMap();
        StructCopier.setFulfillments(
            fulfillmentsMap[defaultName],
            fulfillments
        );
        return fulfillments;
    }

    /**
     * @notice makes a copy of an Fulfillment in-memory
     * @param _fulfillment the Fulfillment to make a copy of in-memory
     */
    function copy(
        Fulfillment memory _fulfillment
    ) internal pure returns (Fulfillment memory) {
        return
            Fulfillment({
                offerComponents: _fulfillment.offerComponents.copy(),
                considerationComponents: _fulfillment
                    .considerationComponents
                    .copy()
            });
    }

    function copy(
        Fulfillment[] memory _fulfillments
    ) internal pure returns (Fulfillment[] memory) {
        Fulfillment[] memory copiedItems = new Fulfillment[](
            _fulfillments.length
        );
        for (uint256 i = 0; i < _fulfillments.length; i++) {
            copiedItems[i] = copy(_fulfillments[i]);
        }
        return copiedItems;
    }

    function empty() internal pure returns (Fulfillment memory) {
        FulfillmentComponent[] memory components;
        return
            Fulfillment({
                offerComponents: components,
                considerationComponents: components
            });
    }

    /**
     * @notice gets the storage position of the default Fulfillment map
     */
    function _fulfillmentMap()
        private
        pure
        returns (mapping(string => Fulfillment) storage fulfillmentMap)
    {
        bytes32 position = FULFILLMENT_MAP_POSITION;
        assembly {
            fulfillmentMap.slot := position
        }
    }

    function _fulfillmentsMap()
        private
        pure
        returns (mapping(string => Fulfillment[]) storage fulfillmentsMap)
    {
        bytes32 position = FULFILLMENTS_MAP_POSITION;
        assembly {
            fulfillmentsMap.slot := position
        }
    }

    // methods for configuring a single of each of an Fulfillment's fields, which modifies the
    // Fulfillment
    // in-place and
    // returns it

    function withOfferComponents(
        Fulfillment memory _fulfillment,
        FulfillmentComponent[] memory components
    ) internal pure returns (Fulfillment memory) {
        _fulfillment.offerComponents = components.copy();
        return _fulfillment;
    }

    function withConsiderationComponents(
        Fulfillment memory _fulfillment,
        FulfillmentComponent[] memory components
    ) internal pure returns (Fulfillment memory) {
        _fulfillment.considerationComponents = components.copy();
        return _fulfillment;
    }
}
