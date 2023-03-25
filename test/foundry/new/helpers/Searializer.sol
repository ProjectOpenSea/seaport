pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";
import "../../../../contracts/lib/ConsiderationStructs.sol";

address constant VM_ADDRESS = address(
    uint160(uint256(keccak256("hevm cheat code")))
);
Vm constant vm = Vm(VM_ADDRESS);

function serializeAddress(
    string memory objectKey,
    string memory valueKey,
    address value
) returns (string memory) {
    return vm.serializeAddress(objectKey, valueKey, value);
}

function serializeItemType(
    string memory objectKey,
    string memory valueKey,
    ItemType value
) returns (string memory) {
    string[6] memory members = [
        "NATIVE",
        "ERC20",
        "ERC721",
        "ERC1155",
        "ERC721_WITH_CRITERIA",
        "ERC1155_WITH_CRITERIA"
    ];
    uint256 index = uint256(value);
    return vm.serializeString(objectKey, valueKey, members[index]);
}

function serializeUint256(
    string memory objectKey,
    string memory valueKey,
    uint256 value
) returns (string memory) {
    return vm.serializeUint(objectKey, valueKey, value);
}

function serializeOfferItem(
    string memory objectKey,
    string memory valueKey,
    OfferItem memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeItemType(obj, "itemType", value.itemType);
    serializeAddress(obj, "token", value.token);
    serializeUint256(obj, "identifierOrCriteria", value.identifierOrCriteria);
    serializeUint256(obj, "startAmount", value.startAmount);
    string memory finalJson = serializeUint256(
        obj,
        "endAmount",
        value.endAmount
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayOfferItem(
    string memory objectKey,
    string memory valueKey,
    OfferItem[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeOfferItem(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeConsiderationItem(
    string memory objectKey,
    string memory valueKey,
    ConsiderationItem memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeItemType(obj, "itemType", value.itemType);
    serializeAddress(obj, "token", value.token);
    serializeUint256(obj, "identifierOrCriteria", value.identifierOrCriteria);
    serializeUint256(obj, "startAmount", value.startAmount);
    serializeUint256(obj, "endAmount", value.endAmount);
    string memory finalJson = serializeAddress(
        obj,
        "recipient",
        value.recipient
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayConsiderationItem(
    string memory objectKey,
    string memory valueKey,
    ConsiderationItem[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeConsiderationItem(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeOrderType(
    string memory objectKey,
    string memory valueKey,
    OrderType value
) returns (string memory) {
    string[5] memory members = [
        "FULL_OPEN",
        "PARTIAL_OPEN",
        "FULL_RESTRICTED",
        "PARTIAL_RESTRICTED",
        "CONTRACT"
    ];
    uint256 index = uint256(value);
    return vm.serializeString(objectKey, valueKey, members[index]);
}

function serializeBytes32(
    string memory objectKey,
    string memory valueKey,
    bytes32 value
) returns (string memory) {
    return vm.serializeBytes32(objectKey, valueKey, value);
}

function serializeOrderParameters(
    string memory objectKey,
    string memory valueKey,
    OrderParameters memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeAddress(obj, "offerer", value.offerer);
    serializeAddress(obj, "zone", value.zone);
    serializeDynArrayOfferItem(obj, "offer", value.offer);
    serializeDynArrayConsiderationItem(
        obj,
        "consideration",
        value.consideration
    );
    serializeOrderType(obj, "orderType", value.orderType);
    serializeUint256(obj, "startTime", value.startTime);
    serializeUint256(obj, "endTime", value.endTime);
    serializeBytes32(obj, "zoneHash", value.zoneHash);
    serializeUint256(obj, "salt", value.salt);
    serializeBytes32(obj, "conduitKey", value.conduitKey);
    string memory finalJson = serializeUint256(
        obj,
        "totalOriginalConsiderationItems",
        value.totalOriginalConsiderationItems
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeBytes(
    string memory objectKey,
    string memory valueKey,
    bytes memory value
) returns (string memory) {
    return vm.serializeBytes(objectKey, valueKey, value);
}

function serializeOrder(
    string memory objectKey,
    string memory valueKey,
    Order memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeOrderParameters(obj, "parameters", value.parameters);
    string memory finalJson = serializeBytes(obj, "signature", value.signature);
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayOrder(
    string memory objectKey,
    string memory valueKey,
    Order[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeOrder(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeOrderComponents(
    string memory objectKey,
    string memory valueKey,
    OrderComponents memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeAddress(obj, "offerer", value.offerer);
    serializeAddress(obj, "zone", value.zone);
    serializeDynArrayOfferItem(obj, "offer", value.offer);
    serializeDynArrayConsiderationItem(
        obj,
        "consideration",
        value.consideration
    );
    serializeOrderType(obj, "orderType", value.orderType);
    serializeUint256(obj, "startTime", value.startTime);
    serializeUint256(obj, "endTime", value.endTime);
    serializeBytes32(obj, "zoneHash", value.zoneHash);
    serializeUint256(obj, "salt", value.salt);
    serializeBytes32(obj, "conduitKey", value.conduitKey);
    string memory finalJson = serializeUint256(obj, "counter", value.counter);
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayOrderComponents(
    string memory objectKey,
    string memory valueKey,
    OrderComponents[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeOrderComponents(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeDynArrayOrderParameters(
    string memory objectKey,
    string memory valueKey,
    OrderParameters[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeOrderParameters(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeAdvancedOrder(
    string memory objectKey,
    string memory valueKey,
    AdvancedOrder memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeOrderParameters(obj, "parameters", value.parameters);
    serializeUint256(obj, "numerator", value.numerator);
    serializeUint256(obj, "denominator", value.denominator);
    serializeBytes(obj, "signature", value.signature);
    string memory finalJson = serializeBytes(obj, "extraData", value.extraData);
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayAdvancedOrder(
    string memory objectKey,
    string memory valueKey,
    AdvancedOrder[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeAdvancedOrder(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeFulfillmentComponent(
    string memory objectKey,
    string memory valueKey,
    FulfillmentComponent memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeUint256(obj, "orderIndex", value.orderIndex);
    string memory finalJson = serializeUint256(
        obj,
        "itemIndex",
        value.itemIndex
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayFulfillmentComponent(
    string memory objectKey,
    string memory valueKey,
    FulfillmentComponent[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeFulfillmentComponent(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeFulfillment(
    string memory objectKey,
    string memory valueKey,
    Fulfillment memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeDynArrayFulfillmentComponent(
        obj,
        "offerComponents",
        value.offerComponents
    );
    string memory finalJson = serializeDynArrayFulfillmentComponent(
        obj,
        "considerationComponents",
        value.considerationComponents
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayFulfillment(
    string memory objectKey,
    string memory valueKey,
    Fulfillment[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeFulfillment(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeDynArrayDynArrayFulfillmentComponent(
    string memory objectKey,
    string memory valueKey,
    FulfillmentComponent[][] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeDynArrayFulfillmentComponent(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeReceivedItem(
    string memory objectKey,
    string memory valueKey,
    ReceivedItem memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeItemType(obj, "itemType", value.itemType);
    serializeAddress(obj, "token", value.token);
    serializeUint256(obj, "identifier", value.identifier);
    serializeUint256(obj, "amount", value.amount);
    string memory finalJson = serializeAddress(
        obj,
        "recipient",
        value.recipient
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeExecution(
    string memory objectKey,
    string memory valueKey,
    Execution memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeReceivedItem(obj, "item", value.item);
    serializeAddress(obj, "offerer", value.offerer);
    string memory finalJson = serializeBytes32(
        obj,
        "conduitKey",
        value.conduitKey
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayExecution(
    string memory objectKey,
    string memory valueKey,
    Execution[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeExecution(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeOrderArray(
    string memory objectKey,
    string memory valueKey,
    OrderArray memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeDynArrayOrder(obj, "orders", value.orders);
    serializeDynArrayOrderComponents(obj, "orders1", value.orders1);
    serializeDynArrayOrderParameters(obj, "orders2", value.orders2);
    serializeDynArrayAdvancedOrder(obj, "orders3", value.orders3);
    serializeDynArrayFulfillment(obj, "fulfillments", value.fulfillments);
    serializeDynArrayFulfillmentComponent(
        obj,
        "remainingOfferComponents",
        value.remainingOfferComponents
    );
    serializeDynArrayDynArrayFulfillmentComponent(
        obj,
        "offerFulfillments",
        value.offerFulfillments
    );
    string memory finalJson = serializeDynArrayExecution(
        obj,
        "expectedImplicitExecutions",
        value.expectedImplicitExecutions
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}
