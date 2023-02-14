// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    BasicOrderParameters,
    OrderComponents,
    OrderParameters,
    ConsiderationItem,
    OrderParameters,
    OfferItem,
    AdditionalRecipient
} from "../../../lib/ConsiderationStructs.sol";
import {
    OrderType,
    ItemType,
    BasicOrderType
} from "../../../lib/ConsiderationEnums.sol";
import { StructCopier } from "./StructCopier.sol";
import { AdditionalRecipientLib } from "./AdditionalRecipientLib.sol";

library BasicOrderParametersLib {
    using BasicOrderParametersLib for BasicOrderParameters;
    using AdditionalRecipientLib for AdditionalRecipient[];

    bytes32 private constant BASIC_ORDER_PARAMETERS_MAP_POSITION =
        keccak256("seaport.BasicOrderParametersDefaults");
    bytes32 private constant BASIC_ORDER_PARAMETERS_ARRAY_MAP_POSITION =
        keccak256("seaport.BasicOrderParametersArrayDefaults");

    function clear(BasicOrderParameters storage basicParameters) internal {
        // uninitialized pointers take up no new memory (versus one word for initializing length-0)
        AdditionalRecipient[] memory additionalRecipients;

        basicParameters.considerationToken = address(0);
        basicParameters.considerationIdentifier = 0;
        basicParameters.considerationAmount = 0;
        basicParameters.offerer = payable(address(0));
        basicParameters.zone = address(0);
        basicParameters.offerToken = address(0);
        basicParameters.offerIdentifier = 0;
        basicParameters.offerAmount = 0;
        basicParameters.basicOrderType = BasicOrderType(0);
        basicParameters.startTime = 0;
        basicParameters.endTime = 0;
        basicParameters.zoneHash = bytes32(0);
        basicParameters.salt = 0;
        basicParameters.offererConduitKey = bytes32(0);
        basicParameters.fulfillerConduitKey = bytes32(0);
        basicParameters.totalOriginalAdditionalRecipients = 0;
        StructCopier.setAdditionalRecipients(
            basicParameters.additionalRecipients,
            additionalRecipients
        );
        basicParameters.signature = new bytes(0);
    }

    function clear(
        BasicOrderParameters[] storage basicParametersArray
    ) internal {
        while (basicParametersArray.length > 0) {
            basicParametersArray[basicParametersArray.length - 1].clear();
            basicParametersArray.pop();
        }
    }

    /**
     * @notice clears a default BasicOrderParameters from storage
     * @param defaultName the name of the default to clear
     */
    function clear(string memory defaultName) internal {
        mapping(string => BasicOrderParameters)
            storage orderComponentsMap = _orderComponentsMap();
        BasicOrderParameters storage basicParameters = orderComponentsMap[
            defaultName
        ];
        basicParameters.clear();
    }

    function empty() internal pure returns (BasicOrderParameters memory item) {
        AdditionalRecipient[] memory additionalRecipients;
        item = BasicOrderParameters({
            considerationToken: address(0),
            considerationIdentifier: 0,
            considerationAmount: 0,
            offerer: payable(address(0)),
            zone: address(0),
            offerToken: address(0),
            offerIdentifier: 0,
            offerAmount: 0,
            basicOrderType: BasicOrderType(0),
            startTime: 0,
            endTime: 0,
            zoneHash: bytes32(0),
            salt: 0,
            offererConduitKey: bytes32(0),
            fulfillerConduitKey: bytes32(0),
            totalOriginalAdditionalRecipients: 0,
            additionalRecipients: additionalRecipients,
            signature: new bytes(0)
        });
    }

    /**
     * @notice gets a default BasicOrderParameters from storage
     * @param defaultName the name of the default for retrieval
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (BasicOrderParameters memory item) {
        mapping(string => BasicOrderParameters)
            storage orderComponentsMap = _orderComponentsMap();
        item = orderComponentsMap[defaultName];
    }

    function fromDefaultMany(
        string memory defaultName
    ) internal view returns (BasicOrderParameters[] memory items) {
        mapping(string => BasicOrderParameters[])
            storage orderComponentsArrayMap = _orderComponentsArrayMap();
        items = orderComponentsArrayMap[defaultName];
    }

    /**
     * @notice saves an BasicOrderParameters as a named default
     * @param orderComponents the BasicOrderParameters to save as a default
     * @param defaultName the name of the default for retrieval
     */
    function saveDefault(
        BasicOrderParameters memory orderComponents,
        string memory defaultName
    ) internal returns (BasicOrderParameters memory _orderComponents) {
        mapping(string => BasicOrderParameters)
            storage orderComponentsMap = _orderComponentsMap();
        BasicOrderParameters storage destination = orderComponentsMap[
            defaultName
        ];
        StructCopier.setBasicOrderParameters(destination, orderComponents);
        return orderComponents;
    }

    function saveDefaultMany(
        BasicOrderParameters[] memory orderComponents,
        string memory defaultName
    ) internal returns (BasicOrderParameters[] memory _orderComponents) {
        mapping(string => BasicOrderParameters[])
            storage orderComponentsArrayMap = _orderComponentsArrayMap();
        BasicOrderParameters[] storage destination = orderComponentsArrayMap[
            defaultName
        ];
        StructCopier.setBasicOrderParameters(destination, orderComponents);
        return orderComponents;
    }

    /**
     * @notice makes a copy of an BasicOrderParameters in-memory
     * @param item the BasicOrderParameters to make a copy of in-memory
     */
    function copy(
        BasicOrderParameters memory item
    ) internal pure returns (BasicOrderParameters memory) {
        return
            BasicOrderParameters({
                considerationToken: item.considerationToken,
                considerationIdentifier: item.considerationIdentifier,
                considerationAmount: item.considerationAmount,
                offerer: item.offerer,
                zone: item.zone,
                offerToken: item.offerToken,
                offerIdentifier: item.offerIdentifier,
                offerAmount: item.offerAmount,
                basicOrderType: item.basicOrderType,
                startTime: item.startTime,
                endTime: item.endTime,
                zoneHash: item.zoneHash,
                salt: item.salt,
                offererConduitKey: item.offererConduitKey,
                fulfillerConduitKey: item.fulfillerConduitKey,
                totalOriginalAdditionalRecipients: item
                    .totalOriginalAdditionalRecipients,
                additionalRecipients: item.additionalRecipients.copy(),
                signature: item.signature
            });
    }

    /**
     * @notice gets the storage position of the default BasicOrderParameters map
     */
    function _orderComponentsMap()
        private
        pure
        returns (
            mapping(string => BasicOrderParameters) storage orderComponentsMap
        )
    {
        bytes32 position = BASIC_ORDER_PARAMETERS_MAP_POSITION;
        assembly {
            orderComponentsMap.slot := position
        }
    }

    function _orderComponentsArrayMap()
        private
        pure
        returns (
            mapping(string => BasicOrderParameters[])
                storage orderComponentsArrayMap
        )
    {
        bytes32 position = BASIC_ORDER_PARAMETERS_ARRAY_MAP_POSITION;
        assembly {
            orderComponentsArrayMap.slot := position
        }
    }

    // methods for configuring a single of each of an in-memory BasicOrderParameters's fields, which modifies the
    // BasicOrderParameters in-memory and returns it

    function withConsiderationToken(
        BasicOrderParameters memory item,
        address value
    ) internal pure returns (BasicOrderParameters memory) {
        item.considerationToken = value;
        return item;
    }

    function withConsiderationIdentifier(
        BasicOrderParameters memory item,
        uint256 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.considerationIdentifier = value;
        return item;
    }

    function withConsiderationAmount(
        BasicOrderParameters memory item,
        uint256 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.considerationAmount = value;
        return item;
    }

    function withOfferer(
        BasicOrderParameters memory item,
        address value
    ) internal pure returns (BasicOrderParameters memory) {
        item.offerer = payable(value);
        return item;
    }

    function withZone(
        BasicOrderParameters memory item,
        address value
    ) internal pure returns (BasicOrderParameters memory) {
        item.zone = value;
        return item;
    }

    function withOfferToken(
        BasicOrderParameters memory item,
        address value
    ) internal pure returns (BasicOrderParameters memory) {
        item.offerToken = value;
        return item;
    }

    function withOfferIdentifier(
        BasicOrderParameters memory item,
        uint256 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.offerIdentifier = value;
        return item;
    }

    function withOfferAmount(
        BasicOrderParameters memory item,
        uint256 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.offerAmount = value;
        return item;
    }

    function withBasicOrderType(
        BasicOrderParameters memory item,
        BasicOrderType value
    ) internal pure returns (BasicOrderParameters memory) {
        item.basicOrderType = value;
        return item;
    }

    function withStartTime(
        BasicOrderParameters memory item,
        uint256 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.startTime = value;
        return item;
    }

    function withEndTime(
        BasicOrderParameters memory item,
        uint256 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.endTime = value;
        return item;
    }

    function withZoneHash(
        BasicOrderParameters memory item,
        bytes32 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.zoneHash = value;
        return item;
    }

    function withSalt(
        BasicOrderParameters memory item,
        uint256 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.salt = value;
        return item;
    }

    function withOffererConduitKey(
        BasicOrderParameters memory item,
        bytes32 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.offererConduitKey = value;
        return item;
    }

    function withFulfillerConduitKey(
        BasicOrderParameters memory item,
        bytes32 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.fulfillerConduitKey = value;
        return item;
    }

    function withTotalOriginalAdditionalRecipients(
        BasicOrderParameters memory item,
        uint256 value
    ) internal pure returns (BasicOrderParameters memory) {
        item.totalOriginalAdditionalRecipients = value;
        return item;
    }

    function withAdditionalRecipients(
        BasicOrderParameters memory item,
        AdditionalRecipient[] memory value
    ) internal pure returns (BasicOrderParameters memory) {
        item.additionalRecipients = value;
        return item;
    }

    function withSignature(
        BasicOrderParameters memory item,
        bytes memory value
    ) internal pure returns (BasicOrderParameters memory) {
        item.signature = value;
        return item;
    }
}
