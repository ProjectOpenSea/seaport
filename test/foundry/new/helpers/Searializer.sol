// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm, vm } from "./VmUtils.sol";

import {
    AdditionalRecipient,
    AdvancedOrder,
    BasicOrderParameters,
    ConsiderationItem,
    CriteriaResolver,
    Execution,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    OrderParameters,
    ReceivedItem
} from "seaport-sol/src/SeaportStructs.sol";

import {
    BasicOrderType,
    ItemType,
    OrderType,
    Side
} from "seaport-sol/src/SeaportEnums.sol";

import { Result } from "./FuzzHelpers.sol";

import {
    FuzzParams,
    FuzzTestContext,
    ReturnValues
} from "./FuzzTestContextLib.sol";

import {
    ERC1155AccountDump,
    ERC1155TokenDump,
    ERC20TokenDump,
    ERC721TokenDump,
    ExpectedBalancesDump,
    NativeAccountDump
} from "./ExpectedBalances.sol";

import { withLabel } from "./Labeler.sol";

import {
    ErrorsAndWarnings
} from "../../../../contracts/helpers/order-validator/SeaportValidator.sol";

import {
    IssueStringHelpers
} from "../../../../contracts/helpers/order-validator/lib/SeaportValidatorTypes.sol";

/**
 * @notice A helper library to seralize test data as JSON.
 */
library Searializer {
    function tojsonBytes32(
        string memory objectKey,
        string memory valueKey,
        bytes32 value
    ) internal returns (string memory) {
        return vm.serializeBytes32(objectKey, valueKey, value);
    }

    function tojsonAddress(
        string memory objectKey,
        string memory valueKey,
        address value
    ) internal returns (string memory) {
        return vm.serializeString(objectKey, valueKey, withLabel(value));
    }

    function tojsonUint256(
        string memory objectKey,
        string memory valueKey,
        uint256 value
    ) internal returns (string memory) {
        return vm.serializeUint(objectKey, valueKey, value);
    }

    function tojsonFuzzParams(
        string memory objectKey,
        string memory valueKey,
        FuzzParams memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonUint256(obj, "seed", value.seed);
        tojsonUint256(obj, "totalOrders", value.totalOrders);
        tojsonUint256(obj, "maxOfferItems", value.maxOfferItems);
        string memory finalJson = tojsonUint256(
            obj,
            "maxConsiderationItems",
            value.maxConsiderationItems
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonItemType(
        string memory objectKey,
        string memory valueKey,
        ItemType value
    ) internal returns (string memory) {
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

    function tojsonOfferItem(
        string memory objectKey,
        string memory valueKey,
        OfferItem memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonItemType(obj, "itemType", value.itemType);
        tojsonAddress(obj, "token", value.token);
        tojsonUint256(obj, "identifierOrCriteria", value.identifierOrCriteria);
        tojsonUint256(obj, "startAmount", value.startAmount);
        string memory finalJson = tojsonUint256(
            obj,
            "endAmount",
            value.endAmount
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayOfferItem(
        string memory objectKey,
        string memory valueKey,
        OfferItem[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonOfferItem(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonConsiderationItem(
        string memory objectKey,
        string memory valueKey,
        ConsiderationItem memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonItemType(obj, "itemType", value.itemType);
        tojsonAddress(obj, "token", value.token);
        tojsonUint256(obj, "identifierOrCriteria", value.identifierOrCriteria);
        tojsonUint256(obj, "startAmount", value.startAmount);
        tojsonUint256(obj, "endAmount", value.endAmount);
        string memory finalJson = tojsonAddress(
            obj,
            "recipient",
            value.recipient
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayConsiderationItem(
        string memory objectKey,
        string memory valueKey,
        ConsiderationItem[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonConsiderationItem(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonOrderType(
        string memory objectKey,
        string memory valueKey,
        OrderType value
    ) internal returns (string memory) {
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

    function tojsonOrderParameters(
        string memory objectKey,
        string memory valueKey,
        OrderParameters memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonAddress(obj, "offerer", value.offerer);
        tojsonAddress(obj, "zone", value.zone);
        tojsonDynArrayOfferItem(obj, "offer", value.offer);
        tojsonDynArrayConsiderationItem(
            obj,
            "consideration",
            value.consideration
        );
        tojsonOrderType(obj, "orderType", value.orderType);
        tojsonUint256(obj, "startTime", value.startTime);
        tojsonUint256(obj, "endTime", value.endTime);
        tojsonBytes32(obj, "zoneHash", value.zoneHash);
        tojsonUint256(obj, "salt", value.salt);
        tojsonBytes32(obj, "conduitKey", value.conduitKey);
        string memory finalJson = tojsonUint256(
            obj,
            "totalOriginalConsiderationItems",
            value.totalOriginalConsiderationItems
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonBytes(
        string memory objectKey,
        string memory valueKey,
        bytes memory value
    ) internal returns (string memory) {
        return vm.serializeBytes(objectKey, valueKey, value);
    }

    function tojsonAdvancedOrder(
        string memory objectKey,
        string memory valueKey,
        AdvancedOrder memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonOrderParameters(obj, "parameters", value.parameters);
        tojsonUint256(obj, "numerator", value.numerator);
        tojsonUint256(obj, "denominator", value.denominator);
        tojsonBytes(obj, "signature", value.signature);
        string memory finalJson = tojsonBytes(
            obj,
            "extraData",
            value.extraData
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayAdvancedOrder(
        string memory objectKey,
        string memory valueKey,
        AdvancedOrder[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonAdvancedOrder(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonSide(
        string memory objectKey,
        string memory valueKey,
        Side value
    ) internal returns (string memory) {
        string[2] memory members = ["OFFER", "CONSIDERATION"];
        uint256 index = uint256(value);
        return vm.serializeString(objectKey, valueKey, members[index]);
    }

    function tojsonDynArrayBytes32(
        string memory objectKey,
        string memory valueKey,
        bytes32[] memory value
    ) internal returns (string memory) {
        return vm.serializeBytes32(objectKey, valueKey, value);
    }

    function tojsonCriteriaResolver(
        string memory objectKey,
        string memory valueKey,
        CriteriaResolver memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonUint256(obj, "orderIndex", value.orderIndex);
        tojsonSide(obj, "side", value.side);
        tojsonUint256(obj, "index", value.index);
        tojsonUint256(obj, "identifier", value.identifier);
        string memory finalJson = tojsonDynArrayBytes32(
            obj,
            "criteriaProof",
            value.criteriaProof
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayCriteriaResolver(
        string memory objectKey,
        string memory valueKey,
        CriteriaResolver[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonCriteriaResolver(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonFulfillmentComponent(
        string memory objectKey,
        string memory valueKey,
        FulfillmentComponent memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonUint256(obj, "orderIndex", value.orderIndex);
        string memory finalJson = tojsonUint256(
            obj,
            "itemIndex",
            value.itemIndex
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayFulfillmentComponent(
        string memory objectKey,
        string memory valueKey,
        FulfillmentComponent[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonFulfillmentComponent(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonFulfillment(
        string memory objectKey,
        string memory valueKey,
        Fulfillment memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonDynArrayFulfillmentComponent(
            obj,
            "offerComponents",
            value.offerComponents
        );
        string memory finalJson = tojsonDynArrayFulfillmentComponent(
            obj,
            "considerationComponents",
            value.considerationComponents
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayFulfillment(
        string memory objectKey,
        string memory valueKey,
        Fulfillment[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonFulfillment(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonDynArrayDynArrayFulfillmentComponent(
        string memory objectKey,
        string memory valueKey,
        FulfillmentComponent[][] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonDynArrayFulfillmentComponent(
                obj,
                vm.toString(i),
                value[i]
            );
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonBasicOrderType(
        string memory objectKey,
        string memory valueKey,
        BasicOrderType value
    ) internal returns (string memory) {
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

    function tojsonAdditionalRecipient(
        string memory objectKey,
        string memory valueKey,
        AdditionalRecipient memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonUint256(obj, "amount", value.amount);
        string memory finalJson = tojsonAddress(
            obj,
            "recipient",
            value.recipient
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayAdditionalRecipient(
        string memory objectKey,
        string memory valueKey,
        AdditionalRecipient[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonAdditionalRecipient(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonBasicOrderParameters(
        string memory objectKey,
        string memory valueKey,
        BasicOrderParameters memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonAddress(obj, "considerationToken", value.considerationToken);
        tojsonUint256(
            obj,
            "considerationIdentifier",
            value.considerationIdentifier
        );
        tojsonUint256(obj, "considerationAmount", value.considerationAmount);
        tojsonAddress(obj, "offerer", value.offerer);
        tojsonAddress(obj, "zone", value.zone);
        tojsonAddress(obj, "offerToken", value.offerToken);
        tojsonUint256(obj, "offerIdentifier", value.offerIdentifier);
        tojsonUint256(obj, "offerAmount", value.offerAmount);
        tojsonBasicOrderType(obj, "basicOrderType", value.basicOrderType);
        tojsonUint256(obj, "startTime", value.startTime);
        tojsonUint256(obj, "endTime", value.endTime);
        tojsonBytes32(obj, "zoneHash", value.zoneHash);
        tojsonUint256(obj, "salt", value.salt);
        tojsonBytes32(obj, "offererConduitKey", value.offererConduitKey);
        tojsonBytes32(obj, "fulfillerConduitKey", value.fulfillerConduitKey);
        tojsonUint256(
            obj,
            "totalOriginalAdditionalRecipients",
            value.totalOriginalAdditionalRecipients
        );
        tojsonDynArrayAdditionalRecipient(
            obj,
            "additionalRecipients",
            value.additionalRecipients
        );
        string memory finalJson = tojsonBytes(
            obj,
            "signature",
            value.signature
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayBytes4(
        string memory objectKey,
        string memory valueKey,
        bytes4[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonBytes32(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonArray2Bytes32(
        string memory objectKey,
        string memory valueKey,
        bytes32[2] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonBytes32(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonDynArrayArray2Bytes32(
        string memory objectKey,
        string memory valueKey,
        bytes32[2][] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonArray2Bytes32(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonResult(
        string memory objectKey,
        string memory valueKey,
        Result value
    ) internal returns (string memory) {
        string[4] memory members = [
            "FULFILLMENT",
            "UNAVAILABLE",
            "VALIDATE",
            "CANCEL"
        ];
        uint256 index = uint256(value);
        return vm.serializeString(objectKey, valueKey, members[index]);
    }

    function tojsonDynArrayResult(
        string memory objectKey,
        string memory valueKey,
        Result[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonResult(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonReceivedItem(
        string memory objectKey,
        string memory valueKey,
        ReceivedItem memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonItemType(obj, "itemType", value.itemType);
        tojsonAddress(obj, "token", value.token);
        tojsonUint256(obj, "identifier", value.identifier);
        tojsonUint256(obj, "amount", value.amount);
        string memory finalJson = tojsonAddress(
            obj,
            "recipient",
            value.recipient
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonExecution(
        string memory objectKey,
        string memory valueKey,
        Execution memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonReceivedItem(obj, "item", value.item);
        tojsonAddress(obj, "offerer", value.offerer);
        string memory finalJson = tojsonBytes32(
            obj,
            "conduitKey",
            value.conduitKey
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayExecution(
        string memory objectKey,
        string memory valueKey,
        Execution[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonExecution(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonLog(
        string memory objectKey,
        string memory valueKey,
        Vm.Log memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonDynArrayBytes32(obj, "topics", value.topics);
        tojsonBytes(obj, "data", value.data);
        string memory finalJson = tojsonAddress(obj, "emitter", value.emitter);
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayLog(
        string memory objectKey,
        string memory valueKey,
        Vm.Log[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonLog(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonBool(
        string memory objectKey,
        string memory valueKey,
        bool value
    ) internal returns (string memory) {
        return vm.serializeBool(objectKey, valueKey, value);
    }

    function tojsonDynArrayBool(
        string memory objectKey,
        string memory valueKey,
        bool[] memory value
    ) internal returns (string memory) {
        return vm.serializeBool(objectKey, valueKey, value);
    }

    function tojsonReturnValues(
        string memory objectKey,
        string memory valueKey,
        ReturnValues memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonBool(obj, "fulfilled", value.fulfilled);
        tojsonBool(obj, "cancelled", value.cancelled);
        tojsonBool(obj, "validated", value.validated);
        tojsonDynArrayBool(obj, "availableOrders", value.availableOrders);
        string memory finalJson = tojsonDynArrayExecution(
            obj,
            "executions",
            value.executions
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonFuzzTestContext(
        string memory objectKey,
        string memory valueKey,
        FuzzTestContext memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonBytes32(obj, "_action", value._action);
        tojsonAddress(obj, "seaport", address(value.seaport));
        tojsonAddress(
            obj,
            "conduitController",
            address(value.conduitController)
        );
        tojsonAddress(obj, "caller", value.executionState.caller);
        tojsonAddress(obj, "recipient", value.executionState.recipient);
        tojsonFuzzParams(obj, "fuzzParams", value.fuzzParams);
        tojsonDynArrayAdvancedOrder(obj, "orders", value.executionState.orders);
        tojsonDynArrayAdvancedOrder(
            obj,
            "previewedOrders",
            value.executionState.previewedOrders
        );
        tojsonUint256(obj, "counter", value.executionState.counter);
        tojsonBytes32(
            obj,
            "fulfillerConduitKey",
            value.executionState.fulfillerConduitKey
        );
        tojsonDynArrayCriteriaResolver(
            obj,
            "criteriaResolvers",
            value.executionState.criteriaResolvers
        );
        tojsonDynArrayFulfillment(
            obj,
            "fulfillments",
            value.executionState.fulfillments
        );
        tojsonDynArrayFulfillmentComponent(
            obj,
            "remainingOfferComponents",
            value.executionState.remainingOfferComponents
        );
        tojsonDynArrayDynArrayFulfillmentComponent(
            obj,
            "offerFulfillments",
            value.executionState.offerFulfillments
        );
        tojsonDynArrayDynArrayFulfillmentComponent(
            obj,
            "considerationFulfillments",
            value.executionState.considerationFulfillments
        );
        tojsonUint256(
            obj,
            "maximumFulfilled",
            value.executionState.maximumFulfilled
        );
        tojsonBasicOrderParameters(
            obj,
            "basicOrderParameters",
            value.executionState.basicOrderParameters
        );
        tojsonAddress(obj, "testHelpers", address(value.testHelpers));
        tojsonDynArrayBytes4(obj, "checks", value.checks);
        tojsonDynArrayBytes32(
            obj,
            "expectedZoneAuthorizeCalldataHashes",
            value.expectations.expectedZoneAuthorizeCalldataHashes
        );
        tojsonDynArrayBytes32(
            obj,
            "expectedZoneValidateCalldataHashes",
            value.expectations.expectedZoneValidateCalldataHashes
        );
        tojsonDynArrayArray2Bytes32(
            obj,
            "expectedContractOrderCalldataHashes",
            value.expectations.expectedContractOrderCalldataHashes
        );
        tojsonDynArrayResult(
            obj,
            "expectedResults",
            value.expectations.expectedResults
        );
        tojsonDynArrayExecution(
            obj,
            "expectedImplicitPreExecutions",
            value.expectations.expectedImplicitPreExecutions
        );
        tojsonDynArrayExecution(
            obj,
            "expectedImplicitPostExecutions",
            value.expectations.expectedImplicitPostExecutions
        );
        tojsonDynArrayExecution(
            obj,
            "expectedExplicitExecutions",
            value.expectations.expectedExplicitExecutions
        );
        tojsonDynArrayExecution(
            obj,
            "allExpectedExecutions",
            value.expectations.allExpectedExecutions
        );
        tojsonDynArrayBytes32(
            obj,
            "expectedTransferEventHashes",
            value.expectations.expectedTransferEventHashes
        );
        tojsonDynArrayBytes32(
            obj,
            "expectedSeaportEventHashes",
            value.expectations.expectedSeaportEventHashes
        );
        tojsonDynArrayLog(obj, "actualEvents", value.actualEvents);
        string memory finalJson = tojsonReturnValues(
            obj,
            "returnValues",
            value.returnValues
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonNativeAccountDump(
        string memory objectKey,
        string memory valueKey,
        NativeAccountDump memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonAddress(obj, "account", value.account);
        string memory finalJson = tojsonUint256(obj, "balance", value.balance);
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayNativeAccountDump(
        string memory objectKey,
        string memory valueKey,
        NativeAccountDump[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonNativeAccountDump(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonDynArrayAddress(
        string memory objectKey,
        string memory valueKey,
        address[] memory value
    ) internal returns (string memory) {
        return vm.serializeString(objectKey, valueKey, withLabel(value));
    }

    function tojsonDynArrayUint256(
        string memory objectKey,
        string memory valueKey,
        uint256[] memory value
    ) internal returns (string memory) {
        return vm.serializeUint(objectKey, valueKey, value);
    }

    function tojsonERC20TokenDump(
        string memory objectKey,
        string memory valueKey,
        ERC20TokenDump memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonAddress(obj, "token", value.token);
        tojsonDynArrayAddress(obj, "accounts", value.accounts);
        string memory finalJson = tojsonDynArrayUint256(
            obj,
            "balances",
            value.balances
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayDynArrayUint256(
        string memory objectKey,
        string memory valueKey,
        uint256[][] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonDynArrayUint256(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonERC721TokenDump(
        string memory objectKey,
        string memory valueKey,
        ERC721TokenDump memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonAddress(obj, "token", value.token);
        tojsonDynArrayAddress(obj, "accounts", value.accounts);
        string memory finalJson = tojsonDynArrayDynArrayUint256(
            obj,
            "accountIdentifiers",
            value.accountIdentifiers
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonERC1155AccountDump(
        string memory objectKey,
        string memory valueKey,
        ERC1155AccountDump memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonAddress(obj, "account", value.account);
        tojsonDynArrayUint256(obj, "identifiers", value.identifiers);
        string memory finalJson = tojsonDynArrayUint256(
            obj,
            "balances",
            value.balances
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayERC1155AccountDump(
        string memory objectKey,
        string memory valueKey,
        ERC1155AccountDump[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonERC1155AccountDump(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonERC1155TokenDump(
        string memory objectKey,
        string memory valueKey,
        ERC1155TokenDump memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonAddress(obj, "token", value.token);
        string memory finalJson = tojsonDynArrayERC1155AccountDump(
            obj,
            "accounts",
            value.accounts
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayERC20TokenDump(
        string memory objectKey,
        string memory valueKey,
        ERC20TokenDump[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonERC20TokenDump(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonDynArrayERC721TokenDump(
        string memory objectKey,
        string memory valueKey,
        ERC721TokenDump[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonERC721TokenDump(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonDynArrayERC1155TokenDump(
        string memory objectKey,
        string memory valueKey,
        ERC1155TokenDump[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            out = tojsonERC1155TokenDump(obj, vm.toString(i), value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonExpectedBalancesDump(
        string memory objectKey,
        string memory valueKey,
        ExpectedBalancesDump memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        tojsonDynArrayERC20TokenDump(obj, "erc20", value.erc20);
        tojsonDynArrayERC721TokenDump(obj, "erc721", value.erc721);
        string memory finalJson = tojsonDynArrayERC1155TokenDump(
            obj,
            "erc1155",
            value.erc1155
        );
        return vm.serializeString(objectKey, valueKey, finalJson);
    }

    function tojsonDynArrayValidationErrorsAndWarnings(
        string memory objectKey,
        string memory valueKey,
        ErrorsAndWarnings[] memory value
    ) internal returns (string memory) {
        string memory obj = string.concat(objectKey, valueKey);
        uint256 length = value.length;
        string memory out;
        for (uint256 i; i < length; i++) {
            if (value[i].errors.length > 0) {
                out = tojsonDynArrayValidationErrorMessages(
                    obj,
                    vm.toString(i),
                    value[i].errors
                );
            }
        }
        return vm.serializeString(objectKey, valueKey, out);
    }

    function tojsonDynArrayValidationErrorMessages(
        string memory objectKey,
        string memory valueKey,
        uint16[] memory value
    ) internal returns (string memory) {
        uint256 length = value.length;
        string[] memory out = new string[](length);
        for (uint256 i; i < length; i++) {
            out[i] = IssueStringHelpers.toIssueString(value[i]);
        }
        return vm.serializeString(objectKey, valueKey, out);
    }
}
