pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";
import "../../../../contracts/lib/ConsiderationStructs.sol";
import {
    FuzzParams,
    ReturnValues,
    Result,
    FuzzTestContext
} from "./FuzzTestContextLib.sol";

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

function serializeCriteriaResolver(
    string memory objectKey,
    string memory valueKey,
    CriteriaResolver memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeUint256(obj, "orderIndex", value.orderIndex);
    serializeSide(obj, "side", value.side);
    serializeUint256(obj, "index", value.index);
    serializeUint256(obj, "identifier", value.identifier);
    string memory finalJson = serializeDynArrayBytes32(
        obj,
        "criteriaProof",
        value.criteriaProof
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
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

function serializeDynArrayCriteriaResolver(
    string memory objectKey,
    string memory valueKey,
    CriteriaResolver[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeCriteriaResolver(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeSide(
    string memory objectKey,
    string memory valueKey,
    Side value
) returns (string memory) {
    string[2] memory members = ["OFFER", "CONSIDERATION"];
    uint256 index = uint256(value);
    return vm.serializeString(objectKey, valueKey, members[index]);
}

function serializeFuzzParams(
    string memory objectKey,
    string memory valueKey,
    FuzzParams memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeUint256(obj, "seed", value.seed);
    serializeUint256(obj, "totalOrders", value.totalOrders);
    serializeUint256(obj, "maxOfferItems", value.maxOfferItems);
    string memory finalJson = serializeUint256(
        obj,
        "maxConsiderationItems",
        value.maxConsiderationItems
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
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

function serializeBasicOrderType(
    string memory objectKey,
    string memory valueKey,
    BasicOrderType value
) returns (string memory) {
    string[24] memory members = [
        "ETH_TO_ERC721_FULL_OPEN",
        "ETH_TO_ERC721_PARTIAL_OPEN",
        "ETH_TO_ERC721_FULL_RESTRICTED",
        "ETH_TO_ERC721_PARTIAL_RESTRICTED",
        "ETH_TO_ERC1155_FULL_OPEN",
        "ETH_TO_ERC1155_PARTIAL_OPEN",
        "ETH_TO_ERC1155_FULL_RESTRICTED",
        "ETH_TO_ERC1155_PARTIAL_RESTRICTED",
        "ERC20_TO_ERC721_FULL_OPEN",
        "ERC20_TO_ERC721_PARTIAL_OPEN",
        "ERC20_TO_ERC721_FULL_RESTRICTED",
        "ERC20_TO_ERC721_PARTIAL_RESTRICTED",
        "ERC20_TO_ERC1155_FULL_OPEN",
        "ERC20_TO_ERC1155_PARTIAL_OPEN",
        "ERC20_TO_ERC1155_FULL_RESTRICTED",
        "ERC20_TO_ERC1155_PARTIAL_RESTRICTED",
        "ERC721_TO_ERC20_FULL_OPEN",
        "ERC721_TO_ERC20_PARTIAL_OPEN",
        "ERC721_TO_ERC20_FULL_RESTRICTED",
        "ERC721_TO_ERC20_PARTIAL_RESTRICTED",
        "ERC1155_TO_ERC20_FULL_OPEN",
        "ERC1155_TO_ERC20_PARTIAL_OPEN",
        "ERC1155_TO_ERC20_FULL_RESTRICTED",
        "ERC1155_TO_ERC20_PARTIAL_RESTRICTED"
    ];
    uint256 index = uint256(value);
    return vm.serializeString(objectKey, valueKey, members[index]);
}

function serializeAdditionalRecipient(
    string memory objectKey,
    string memory valueKey,
    AdditionalRecipient memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeUint256(obj, "amount", value.amount);
    string memory finalJson = serializeAddress(
        obj,
        "recipient",
        value.recipient
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayAdditionalRecipient(
    string memory objectKey,
    string memory valueKey,
    AdditionalRecipient[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeAdditionalRecipient(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeBasicOrderParameters(
    string memory objectKey,
    string memory valueKey,
    BasicOrderParameters memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeAddress(obj, "considerationToken", value.considerationToken);
    serializeUint256(
        obj,
        "considerationIdentifier",
        value.considerationIdentifier
    );
    serializeUint256(obj, "considerationAmount", value.considerationAmount);
    serializeAddress(obj, "offerer", value.offerer);
    serializeAddress(obj, "zone", value.zone);
    serializeAddress(obj, "offerToken", value.offerToken);
    serializeUint256(obj, "offerIdentifier", value.offerIdentifier);
    serializeUint256(obj, "offerAmount", value.offerAmount);
    serializeBasicOrderType(obj, "basicOrderType", value.basicOrderType);
    serializeUint256(obj, "startTime", value.startTime);
    serializeUint256(obj, "endTime", value.endTime);
    serializeBytes32(obj, "zoneHash", value.zoneHash);
    serializeUint256(obj, "salt", value.salt);
    serializeBytes32(obj, "offererConduitKey", value.offererConduitKey);
    serializeBytes32(obj, "fulfillerConduitKey", value.fulfillerConduitKey);
    serializeUint256(
        obj,
        "totalOriginalAdditionalRecipients",
        value.totalOriginalAdditionalRecipients
    );
    serializeDynArrayAdditionalRecipient(
        obj,
        "additionalRecipients",
        value.additionalRecipients
    );
    string memory finalJson = serializeBytes(obj, "signature", value.signature);
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayBytes4(
    string memory objectKey,
    string memory valueKey,
    bytes4[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeBytes32(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
}

function serializeResult(
    string memory objectKey,
    string memory valueKey,
    Result value
) returns (string memory) {
    string[4] memory members = [
        "FULFILLMENT",
        "UNAVAILABLE",
        "VALIDATE",
        "CANCEL"
    ];
    uint256 index = uint256(value);
    return vm.serializeString(objectKey, valueKey, members[index]);
}

function serializeDynArrayResult(
    string memory objectKey,
    string memory valueKey,
    Result[] memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    uint256 length = value.length;
    string memory out;
    for (uint256 i; i < length; i++) {
        out = serializeResult(
            obj,
            string.concat("element", vm.toString(i)),
            value[i]
        );
    }
    return vm.serializeString(objectKey, valueKey, out);
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

function serializeBool(
    string memory objectKey,
    string memory valueKey,
    bool value
) returns (string memory) {
    return vm.serializeBool(objectKey, valueKey, value);
}

function serializeDynArrayBool(
    string memory objectKey,
    string memory valueKey,
    bool[] memory value
) returns (string memory) {
    return vm.serializeBool(objectKey, valueKey, value);
}

function serializeReturnValues(
    string memory objectKey,
    string memory valueKey,
    ReturnValues memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeBool(obj, "fulfilled", value.fulfilled);
    serializeBool(obj, "cancelled", value.cancelled);
    serializeBool(obj, "validated", value.validated);
    serializeDynArrayBool(obj, "availableOrders", value.availableOrders);
    string memory finalJson = serializeDynArrayExecution(
        obj,
        "executions",
        value.executions
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}

function serializeDynArrayBytes32(
    string memory objectKey,
    string memory valueKey,
    bytes32[] memory value
) returns (string memory) {
    return vm.serializeBytes32(objectKey, valueKey, value);
}

function serializeFuzzTestContext(
    string memory objectKey,
    string memory valueKey,
    FuzzTestContext memory value
) returns (string memory) {
    string memory obj = string.concat(objectKey, valueKey);
    serializeBytes32(obj, "_action", value._action);
    serializeAddress(obj, "seaport", address(value.seaport));
    serializeAddress(
        obj,
        "conduitController",
        address(value.conduitController)
    );
    serializeAddress(obj, "caller", value.caller);
    serializeAddress(obj, "recipient", value.recipient);
    serializeFuzzParams(obj, "fuzzParams", value.fuzzParams);
    serializeDynArrayAdvancedOrder(obj, "orders", value.orders);
    serializeDynArrayAdvancedOrder(obj, "initialOrders", value.initialOrders);
    serializeUint256(obj, "counter", value.counter);
    serializeBytes32(obj, "fulfillerConduitKey", value.fulfillerConduitKey);
    serializeDynArrayCriteriaResolver(
        obj,
        "criteriaResolvers",
        value.criteriaResolvers
    );
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
    serializeDynArrayDynArrayFulfillmentComponent(
        obj,
        "considerationFulfillments",
        value.considerationFulfillments
    );
    serializeUint256(obj, "maximumFulfilled", value.maximumFulfilled);
    serializeBasicOrderParameters(
        obj,
        "basicOrderParameters",
        value.basicOrderParameters
    );
    serializeAddress(obj, "testHelpers", address(value.testHelpers));
    serializeDynArrayBytes4(obj, "checks", value.checks);
    serializeDynArrayBytes32(
        obj,
        "expectedZoneCalldataHash",
        value.expectedZoneCalldataHash
    );
    serializeDynArrayResult(obj, "expectedResults", value.expectedResults);
    serializeDynArrayExecution(
        obj,
        "expectedImplicitExecutions",
        value.expectedImplicitExecutions
    );
    serializeDynArrayExecution(
        obj,
        "expectedExplicitExecutions",
        value.expectedExplicitExecutions
    );
    serializeDynArrayBytes32(
        obj,
        "expectedEventHashes",
        value.expectedEventHashes
    );
    string memory finalJson = serializeReturnValues(
        obj,
        "returnValues",
        value.returnValues
    );
    return vm.serializeString(objectKey, valueKey, finalJson);
}
