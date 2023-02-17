// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    FulfillmentComponent,
    OfferItem
} from "../../../lib/ConsiderationStructs.sol";
import { Side } from "../../../lib/ConsiderationEnums.sol";
import { ArrayLib } from "./ArrayLib.sol";
import { StructCopier } from "./StructCopier.sol";

library FulfillmentComponentLib {
    bytes32 private constant FULFILLMENT_COMPONENT_MAP_POSITION =
        keccak256("seaport.FulfillmentComponentDefaults");
    bytes32 private constant FULFILLMENT_COMPONENTS_MAP_POSITION =
        keccak256("seaport.FulfillmentComponentsDefaults");

    using ArrayLib for bytes32[];

    /**
     * @notice clears a default FulfillmentComponent from storage
     * @param defaultName the name of the default to clear
     */

    function clear(string memory defaultName) internal {
        mapping(string => FulfillmentComponent)
            storage fulfillmentComponentMap = _fulfillmentComponentMap();
        FulfillmentComponent storage component = fulfillmentComponentMap[
            defaultName
        ];
        clear(component);
    }

    function clear(FulfillmentComponent storage component) internal {
        component.orderIndex = 0;
        component.itemIndex = 0;
    }

    function clear(FulfillmentComponent[] storage components) internal {
        while (components.length > 0) {
            clear(components[components.length - 1]);
            components.pop();
        }
    }

    /**
     * @notice gets a default FulfillmentComponent from storage
     * @param defaultName the name of the default for retrieval
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (FulfillmentComponent memory component) {
        mapping(string => FulfillmentComponent)
            storage fulfillmentComponentMap = _fulfillmentComponentMap();
        component = fulfillmentComponentMap[defaultName];
    }

    function fromDefaultMany(
        string memory defaultName
    ) internal view returns (FulfillmentComponent[] memory components) {
        mapping(string => FulfillmentComponent[])
            storage fulfillmentComponentMap = _fulfillmentComponentsMap();
        components = fulfillmentComponentMap[defaultName];
    }

    /**
     * @notice saves an FulfillmentComponent as a named default
     * @param fulfillmentComponent the FulfillmentComponent to save as a default
     * @param defaultName the name of the default for retrieval
     */
    function saveDefault(
        FulfillmentComponent memory fulfillmentComponent,
        string memory defaultName
    ) internal returns (FulfillmentComponent memory _fulfillmentComponent) {
        mapping(string => FulfillmentComponent)
            storage fulfillmentComponentMap = _fulfillmentComponentMap();
        FulfillmentComponent storage component = fulfillmentComponentMap[
            defaultName
        ];
        component.orderIndex = fulfillmentComponent.orderIndex;
        component.itemIndex = fulfillmentComponent.itemIndex;
        return fulfillmentComponent;
    }

    function saveDefaultMany(
        FulfillmentComponent[] memory fulfillmentComponents,
        string memory defaultName
    ) internal returns (FulfillmentComponent[] memory _fulfillmentComponents) {
        mapping(string => FulfillmentComponent[])
            storage fulfillmentComponentsMap = _fulfillmentComponentsMap();
        FulfillmentComponent[] storage components = fulfillmentComponentsMap[
            defaultName
        ];
        clear(components);
        StructCopier.setFulfillmentComponents(
            components,
            fulfillmentComponents
        );

        return fulfillmentComponents;
    }

    /**
     * @notice makes a copy of an FulfillmentComponent in-memory
     * @param component the FulfillmentComponent to make a copy of in-memory
     */
    function copy(
        FulfillmentComponent memory component
    ) internal pure returns (FulfillmentComponent memory) {
        return
            FulfillmentComponent({
                orderIndex: component.orderIndex,
                itemIndex: component.itemIndex
            });
    }

    function copy(
        FulfillmentComponent[] memory components
    ) internal pure returns (FulfillmentComponent[] memory) {
        FulfillmentComponent[] memory copiedItems = new FulfillmentComponent[](
            components.length
        );
        for (uint256 i = 0; i < components.length; i++) {
            copiedItems[i] = copy(components[i]);
        }
        return copiedItems;
    }

    function empty() internal pure returns (FulfillmentComponent memory) {
        return FulfillmentComponent({ orderIndex: 0, itemIndex: 0 });
    }

    /**
     * @notice gets the storage position of the default FulfillmentComponent map
     */
    function _fulfillmentComponentMap()
        private
        pure
        returns (
            mapping(string => FulfillmentComponent)
                storage fulfillmentComponentMap
        )
    {
        bytes32 position = FULFILLMENT_COMPONENT_MAP_POSITION;
        assembly {
            fulfillmentComponentMap.slot := position
        }
    }

    function _fulfillmentComponentsMap()
        private
        pure
        returns (
            mapping(string => FulfillmentComponent[])
                storage fulfillmentComponentsMap
        )
    {
        bytes32 position = FULFILLMENT_COMPONENTS_MAP_POSITION;
        assembly {
            fulfillmentComponentsMap.slot := position
        }
    }

    // methods for configuring a single of each of an FulfillmentComponent's fields, which modifies the
    // FulfillmentComponent
    // in-place and
    // returns it

    function withOrderIndex(
        FulfillmentComponent memory component,
        uint256 orderIndex
    ) internal pure returns (FulfillmentComponent memory) {
        component.orderIndex = orderIndex;
        return component;
    }

    function withItemIndex(
        FulfillmentComponent memory component,
        uint256 itemIndex
    ) internal pure returns (FulfillmentComponent memory) {
        component.itemIndex = itemIndex;
        return component;
    }
}
