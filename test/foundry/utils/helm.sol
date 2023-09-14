// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { console } from "forge-std/console.sol";
// import { console2 as console } from "forge-std/console2.sol";

import { LibString } from "solady/src/utils/LibString.sol";

import {
    BasicOrderType,
    ItemType,
    OrderType,
    Side
} from "seaport-types/src/lib/ConsiderationEnums.sol";

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
    Order,
    OrderComponents,
    OrderParameters,
    ReceivedItem,
    SpentItem,
    ZoneParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @title helm
 * @author snotrocket.eth
 * @notice helm is an extension of the console.sol library that provides
 *         additional logging functionality for Seaport structs.
 */
library helm {
    function log(OrderComponents memory orderComponents) public view {
        logOrderComponents(orderComponents, 0);
    }

    function log(OrderComponents[] memory orderComponentsArray) public view {
        console.log(gStr(0, "orderComponentsArray: ["));
        for (uint256 j = 0; j < orderComponentsArray.length; j++) {
            logOrderComponents(orderComponentsArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logOrderComponents(
        OrderComponents memory oc,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "OrderComponents: {"));
        console.log(gStr(i + 1, "offerer", oc.offerer));
        console.log(gStr(i + 1, "zone", oc.zone));
        logOffer(oc.offer, i + 1);
        logConsideration(oc.consideration, i + 1);
        console.log(gStr(i + 1, "orderType", _orderTypeStr(oc.orderType)));
        console.log(gStr(i + 1, "startTime", oc.startTime));
        console.log(gStr(i + 1, "endTime", oc.endTime));
        console.log(gStr(i + 1, "zoneHash", oc.zoneHash));
        console.log(gStr(i + 1, "salt", oc.salt));
        console.log(gStr(i + 1, "conduitKey", oc.conduitKey));
        console.log(gStr(i + 1, "counter", oc.counter));
        console.log(gStr(i, "}"));
    }

    function log(OfferItem memory offerItem) public view {
        logOfferItem(offerItem, 0);
    }

    function log(OfferItem[] memory offerItemArray) public view {
        console.log(gStr(0, "offerItemArray: ["));
        for (uint256 j = 0; j < offerItemArray.length; j++) {
            logOfferItem(offerItemArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logOfferItem(
        OfferItem memory oi,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "OfferItem: {"));
        console.log(gStr(i + 1, "itemType", _itemTypeStr(oi.itemType)));
        console.log(gStr(i + 1, "token", oi.token));
        console.log(
            gStr(i + 1, "identifierOrCriteria", oi.identifierOrCriteria)
        );
        console.log(gStr(i + 1, "startAmount", oi.startAmount));
        console.log(gStr(i + 1, "endAmount", oi.endAmount));
        console.log(gStr(i, "}"));
    }

    function log(ConsiderationItem memory considerationItem) public view {
        logConsiderationItem(considerationItem, 0);
    }

    function log(
        ConsiderationItem[] memory considerationItemArray
    ) public view {
        console.log(gStr(0, "considerationItemArray: ["));
        for (uint256 j = 0; j < considerationItemArray.length; j++) {
            logConsiderationItem(considerationItemArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logConsiderationItem(
        ConsiderationItem memory ci,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "ConsiderationItem: {"));
        console.log(gStr(i + 1, "itemType", _itemTypeStr(ci.itemType)));
        console.log(gStr(i + 1, "token", ci.token));
        console.log(
            gStr(i + 1, "identifierOrCriteria", ci.identifierOrCriteria)
        );
        console.log(gStr(i + 1, "startAmount", ci.startAmount));
        console.log(gStr(i + 1, "endAmount", ci.endAmount));
        console.log(gStr(i, "}"));
    }

    function log(SpentItem memory spentItem) public view {
        logSpentItem(spentItem, 0);
    }

    function log(SpentItem[] memory spentItemArray) public view {
        console.log(gStr(0, "spentItemArray: ["));
        for (uint256 j = 0; j < spentItemArray.length; j++) {
            logSpentItem(spentItemArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logSpentItem(
        SpentItem memory si,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "SpentItem: {"));
        console.log(gStr(i + 1, "itemType", _itemTypeStr(si.itemType)));
        console.log(gStr(i + 1, "token", si.token));
        console.log(gStr(i + 1, "identifier", si.identifier));
        console.log(gStr(i + 1, "amount", si.amount));
        console.log(gStr(i, "}"));
    }

    function log(ReceivedItem memory receivedItem) public view {
        logReceivedItem(receivedItem, 0);
    }

    function log(ReceivedItem[] memory receivedItemArray) public view {
        console.log(gStr(0, "receivedItemArray: ["));
        for (uint256 j = 0; j < receivedItemArray.length; j++) {
            logReceivedItem(receivedItemArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logReceivedItem(
        ReceivedItem memory ri,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "ReceivedItem: {"));
        console.log(gStr(i + 1, "itemType", _itemTypeStr(ri.itemType)));
        console.log(gStr(i + 1, "token", ri.token));
        console.log(gStr(i + 1, "identifier", ri.identifier));
        console.log(gStr(i + 1, "amount", ri.amount));
        console.log(gStr(i + 1, "recipient", ri.recipient));
        console.log(gStr(i, "}"));
    }

    function log(BasicOrderParameters memory basicOrderParameters) public view {
        logBasicOrderParameters(basicOrderParameters, 0);
    }

    function log(
        BasicOrderParameters[] memory basicOrderParametersArray
    ) public view {
        console.log(gStr(0, "basicOrderParametersArray: ["));
        for (uint256 j = 0; j < basicOrderParametersArray.length; j++) {
            logBasicOrderParameters(basicOrderParametersArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logBasicOrderParameters(
        BasicOrderParameters memory bop,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "BasicOrderParameters: {"));
        console.log(gStr(i + 1, "considerationToken", bop.considerationToken));
        console.log(
            gStr(i + 1, "considerationIdentifier", bop.considerationIdentifier)
        );
        console.log(
            gStr(i + 1, "considerationAmount", bop.considerationAmount)
        );
        console.log(gStr(i + 1, "offerer", bop.offerer));
        console.log(gStr(i + 1, "zone", bop.zone));
        console.log(gStr(i + 1, "offerToken", bop.offerToken));
        console.log(gStr(i + 1, "offerIdentifier", bop.offerIdentifier));
        console.log(gStr(i + 1, "offerAmount", bop.offerAmount));
        console.log(
            gStr(
                i + 1,
                "basicOrderType",
                _basicOrderTypeStr(bop.basicOrderType)
            )
        );
        console.log(gStr(i + 1, "startTime", bop.startTime));
        console.log(gStr(i + 1, "endTime", bop.endTime));
        console.log(gStr(i + 1, "zoneHash", bop.zoneHash));
        console.log(gStr(i + 1, "salt", bop.salt));
        console.log(gStr(i + 1, "offererConduitKey", bop.offererConduitKey));
        console.log(
            gStr(i + 1, "fulfillerConduitKey", bop.fulfillerConduitKey)
        );
        console.log(
            gStr(
                i + 1,
                "totalOriginalAdditionalRecipients",
                bop.totalOriginalAdditionalRecipients
            )
        );
        console.log(gStr(i + 1, "additionalRecipients: ["));
        for (uint256 j = 0; j < bop.additionalRecipients.length; j++) {
            logAdditionalRecipient(bop.additionalRecipients[j], i + 1);
        }
        console.log(gStr(i + 1, "]"));
        console.log(gStr(i + 1, "signature", bop.signature));
        console.log(gStr(i, "}"));
    }

    function log(AdditionalRecipient memory additionalRecipient) public view {
        logAdditionalRecipient(additionalRecipient, 0);
    }

    function log(
        AdditionalRecipient[] memory additionalRecipientArray
    ) public view {
        console.log(gStr(0, "additionalRecipientArray: ["));
        for (uint256 j = 0; j < additionalRecipientArray.length; j++) {
            logAdditionalRecipient(additionalRecipientArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logAdditionalRecipient(
        AdditionalRecipient memory ar,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "AdditionalRecipient: {"));
        console.log(gStr(i + 1, "recipient", ar.recipient));
        console.log(gStr(i + 1, "amount", ar.amount));
        console.log(gStr(i, "}"));
    }

    function log(OrderParameters memory orderParameters) public view {
        logOrderParameters(orderParameters, 0);
    }

    function log(OrderParameters[] memory orderParametersArray) public view {
        console.log(gStr(0, "orderParametersArray: ["));
        for (uint256 j = 0; j < orderParametersArray.length; j++) {
            logOrderParameters(orderParametersArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logOrderParameters(
        OrderParameters memory op,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "OrderParameters: {"));
        console.log(gStr(i + 1, "offerer", op.offerer));
        console.log(gStr(i + 1, "zone", op.zone));
        logOffer(op.offer, i + 1);
        logConsideration(op.consideration, i + 1);
        console.log(gStr(i + 1, "orderType", _orderTypeStr(op.orderType)));
        console.log(gStr(i + 1, "startTime", op.startTime));
        console.log(gStr(i + 1, "endTime", op.endTime));
        console.log(gStr(i + 1, "zoneHash", op.zoneHash));
        console.log(gStr(i + 1, "salt", op.salt));
        console.log(gStr(i + 1, "conduitKey", op.conduitKey));
        console.log(
            gStr(
                i + 1,
                "totalOriginalConsiderationItems",
                op.totalOriginalConsiderationItems
            )
        );
        console.log(gStr(i, "}"));
    }

    function log(Order memory order) public view {
        logOrder(order, 0);
    }

    function log(Order[] memory orderArray) public view {
        console.log(gStr(0, "orderArray: ["));
        for (uint256 j = 0; j < orderArray.length; j++) {
            logOrder(orderArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logOrder(
        Order memory order,
        uint256 i /* indent */
    ) internal view {
        console.log(gStr(i, "Order: {"));
        logOrderParameters(order.parameters, i + 1);
        console.log(gStr(i + 1, "signature", order.signature));
        console.log(gStr(i, "}"));
    }

    function log(AdvancedOrder memory advancedOrder) public view {
        logAdvancedOrder(advancedOrder, 0);
    }

    function log(AdvancedOrder[] memory advancedOrderArray) public view {
        console.log(gStr(0, "advancedOrderArray: ["));
        for (uint256 j = 0; j < advancedOrderArray.length; j++) {
            logAdvancedOrder(advancedOrderArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logAdvancedOrder(
        AdvancedOrder memory advancedOrder,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "AdvancedOrder: {"));
        logOrderParameters(advancedOrder.parameters, i + 1);
        console.log(gStr(i + 1, "numerator", advancedOrder.numerator));
        console.log(gStr(i + 1, "denominator", advancedOrder.denominator));
        console.log(gStr(i + 1, "signature", advancedOrder.signature));
        console.log(gStr(i + 1, "extraData", advancedOrder.extraData));
        console.log(gStr(i, "}"));
    }

    function log(CriteriaResolver memory criteriaResolver) public view {
        logCriteriaResolver(criteriaResolver, 0);
    }

    function log(CriteriaResolver[] memory criteriaResolverArray) public view {
        console.log(gStr(0, "criteriaResolverArray: ["));
        for (uint256 j = 0; j < criteriaResolverArray.length; j++) {
            logCriteriaResolver(criteriaResolverArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logCriteriaResolver(
        CriteriaResolver memory cr,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "CriteriaResolver: {"));
        console.log(gStr(i + 1, "orderIndex", cr.orderIndex));
        console.log(gStr(i + 1, "side", _sideStr(cr.side)));
        console.log(gStr(i + 1, "index", cr.index));
        console.log(gStr(i + 1, "identifier", cr.identifier));
        for (uint256 j = 0; j < cr.criteriaProof.length; j++) {
            console.log(gStr(i + 2, "criteriaProof", cr.criteriaProof[j]));
        }
        console.log(gStr(i, "}"));
    }

    function log(Fulfillment memory fulfillment) public view {
        logFulfillment(fulfillment, 0);
    }

    function log(Fulfillment[] memory fulfillmentArray) public view {
        console.log(gStr(0, "fulfillmentArray: ["));
        for (uint256 j = 0; j < fulfillmentArray.length; j++) {
            logFulfillment(fulfillmentArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logFulfillment(
        Fulfillment memory f,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "Fulfillment: {"));
        console.log(gStr(i + 1, "offerComponents: ["));
        for (uint256 j = 0; j < f.offerComponents.length; j++) {
            logFulfillmentComponent(f.offerComponents[j], i + 2);
        }
        console.log(gStr(i + 1, "]"));
        console.log(gStr(i + 1, "considerationComponents: ["));
        for (uint256 j = 0; j < f.considerationComponents.length; j++) {
            logFulfillmentComponent(f.considerationComponents[j], i + 2);
        }
        console.log(gStr(i + 1, "]"));
        console.log(gStr(i, "}"));
    }

    function log(FulfillmentComponent memory fulfillmentComponent) public view {
        logFulfillmentComponent(fulfillmentComponent, 0);
    }

    function log(
        FulfillmentComponent[] memory fulfillmentComponentArray
    ) public view {
        console.log(gStr(0, "fulfillmentComponentArray: ["));
        for (uint256 j = 0; j < fulfillmentComponentArray.length; j++) {
            logFulfillmentComponent(fulfillmentComponentArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logFulfillmentComponent(
        FulfillmentComponent memory fc,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "FulfillmentComponent: {"));
        console.log(gStr(i + 1, "orderIndex", fc.orderIndex));
        console.log(gStr(i + 1, "itemIndex", fc.itemIndex));
        console.log(gStr(i, "}"));
    }

    function log(Execution memory execution) public view {
        logExecution(execution, 0);
    }

    function log(Execution[] memory executionArray) public view {
        console.log(gStr(0, "executionArray: ["));
        for (uint256 j = 0; j < executionArray.length; j++) {
            logExecution(executionArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logExecution(
        Execution memory execution,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "Execution: {"));
        logReceivedItem(execution.item, i + 1);
        console.log(gStr(i + 1, "offerer", execution.offerer));
        console.log(gStr(i + 1, "conduitKey", execution.conduitKey));
        console.log(gStr(i, "}"));
    }

    function log(ZoneParameters memory zoneParameters) public view {
        logZoneParameters(zoneParameters, 0);
    }

    function log(ZoneParameters[] memory zoneParametersArray) public view {
        console.log(gStr(0, "zoneParametersArray: ["));
        for (uint256 j = 0; j < zoneParametersArray.length; j++) {
            logZoneParameters(zoneParametersArray[j], 1);
        }
        console.log(gStr(0, "]"));
    }

    function logZoneParameters(
        ZoneParameters memory zp,
        uint256 i // indent
    ) internal view {
        console.log(gStr(i, "ZoneParameters: {"));
        console.log(gStr(i + 1, "orderHash", zp.orderHash));
        console.log(gStr(i + 1, "fulfiller", zp.fulfiller));
        console.log(gStr(i + 1, "offerer", zp.offerer));
        console.log(gStr(i + 1, "offer: ["));
        for (uint256 j = 0; j < zp.offer.length; j++) {
            logSpentItem(zp.offer[j], i + 1);
        }
        console.log(gStr(i + 1, "]"));
        console.log(gStr(i + 1, "consideration: ["));
        for (uint256 j = 0; j < zp.consideration.length; j++) {
            logReceivedItem(zp.consideration[j], i + 1);
        }
        console.log(gStr(i + 1, "]"));
        console.log(gStr(i + 1, "extraData", zp.extraData));
        console.log(gStr(i + 1, "orderHashes: ["));
        for (uint256 j = 0; j < zp.orderHashes.length; j++) {
            console.log(gStr(i + 2, "", zp.orderHashes[j]));
        }
        console.log(gStr(i + 1, "]"));
        console.log(gStr(i + 1, "startTime", zp.startTime));
        console.log(gStr(i + 1, "endTime", zp.endTime));
        console.log(gStr(i + 1, "zoneHash", zp.zoneHash));
        console.log(gStr(i, "}"));
    }

    ////////////////////////////////////////////////////////////////////////////
    //                              Helpers                                   //
    ////////////////////////////////////////////////////////////////////////////

    function generateIndentString(
        uint256 i // indent
    ) public pure returns (string memory) {
        string memory indentString = "";
        for (uint256 j = 0; j < i; j++) {
            indentString = string.concat(indentString, "    ");
        }
        return indentString;
    }

    function gStr(
        // generateString
        uint256 i, // indent
        string memory stringToIndent
    ) public pure returns (string memory) {
        string memory indentString = generateIndentString(i);
        return string.concat(indentString, stringToIndent);
    }

    function gStr(
        uint256 i, // indent
        string memory labelString,
        string memory valueString
    ) public pure returns (string memory) {
        string memory indentString = generateIndentString(i);
        return
            string.concat(
                indentString,
                string.concat(labelString, ": ", valueString)
            );
    }

    function gStr(
        uint256 i, // indent
        string memory labelString,
        uint256 value
    ) public pure returns (string memory) {
        string memory indentString = generateIndentString(i);
        return
            string.concat(
                indentString,
                string.concat(labelString, ": ", LibString.toString(value))
            );
    }

    function gStr(
        uint256 i, // indent
        string memory labelString,
        address value
    ) public pure returns (string memory) {
        string memory indentString = generateIndentString(i);
        return
            string.concat(
                indentString,
                string.concat(labelString, ": ", LibString.toHexString(value))
            );
    }

    function gStr(
        uint256 i, // indent
        string memory labelString,
        bytes32 value
    ) public pure returns (string memory) {
        string memory indentString = generateIndentString(i);
        return
            string.concat(
                indentString,
                string.concat(
                    labelString,
                    ": ",
                    LibString.toHexString(uint256(value))
                )
            );
    }

    function gStr(
        uint256 i, // indent
        string memory labelString,
        bytes memory value
    ) public pure returns (string memory) {
        string memory indentString = generateIndentString(i);
        return
            string.concat(
                indentString,
                string.concat(labelString, ": ", LibString.toHexString(value))
            );
    }

    ////////////////////////////////////////////////////////////////////////////
    //                              Log Arrays                                //
    ////////////////////////////////////////////////////////////////////////////

    function logOffer(
        OfferItem[] memory offer,
        uint256 i /* indent */
    ) public view {
        console.log(gStr(i, "offer: ["));
        for (uint256 j = 0; j < offer.length; j++) {
            logOfferItem(offer[j], i + 1);
        }
        console.log(gStr(i, "]"));
    }

    function logConsideration(
        ConsiderationItem[] memory consideration,
        uint256 i // indent
    ) public view {
        console.log(gStr(i, "consideration: ["));
        for (uint256 j = 0; j < consideration.length; j++) {
            logConsiderationItem(consideration[j], i + 1);
        }
        console.log(gStr(i, "]"));
    }

    ////////////////////////////////////////////////////////////////////////////
    //                          Get Enum String Values                        //
    ////////////////////////////////////////////////////////////////////////////

    function _itemTypeStr(
        ItemType itemType
    ) internal pure returns (string memory) {
        if (itemType == ItemType.NATIVE) return "NATIVE";
        if (itemType == ItemType.ERC20) return "ERC20";
        if (itemType == ItemType.ERC721) return "ERC721";
        if (itemType == ItemType.ERC1155) return "ERC1155";
        if (itemType == ItemType.ERC721_WITH_CRITERIA)
            return "ERC721_WITH_CRITERIA";
        if (itemType == ItemType.ERC1155_WITH_CRITERIA)
            return "ERC1155_WITH_CRITERIA";

        return "UNKNOWN";
    }

    function _orderTypeStr(
        OrderType orderType
    ) internal pure returns (string memory) {
        if (orderType == OrderType.FULL_OPEN) return "FULL_OPEN";
        if (orderType == OrderType.PARTIAL_OPEN) return "PARTIAL_OPEN";
        if (orderType == OrderType.FULL_RESTRICTED) return "FULL_RESTRICTED";
        if (orderType == OrderType.PARTIAL_RESTRICTED)
            return "PARTIAL_RESTRICTED";
        if (orderType == OrderType.CONTRACT) return "CONTRACT";

        return "UNKNOWN";
    }

    function _basicOrderTypeStr(
        BasicOrderType basicOrderType
    ) internal pure returns (string memory) {
        if (basicOrderType == BasicOrderType.ETH_TO_ERC721_FULL_OPEN)
            return "ETH_TO_ERC721_FULL_OPEN";
        if (basicOrderType == BasicOrderType.ETH_TO_ERC721_PARTIAL_OPEN)
            return "ETH_TO_ERC721_PARTIAL_OPEN";
        if (basicOrderType == BasicOrderType.ETH_TO_ERC721_FULL_RESTRICTED)
            return "ETH_TO_ERC721_FULL_RESTRICTED";
        if (basicOrderType == BasicOrderType.ETH_TO_ERC721_PARTIAL_RESTRICTED)
            return "ETH_TO_ERC721_PARTIAL_RESTRICTED";
        if (basicOrderType == BasicOrderType.ETH_TO_ERC1155_FULL_OPEN)
            return "ETH_TO_ERC1155_FULL_OPEN";
        if (basicOrderType == BasicOrderType.ETH_TO_ERC1155_PARTIAL_OPEN)
            return "ETH_TO_ERC1155_PARTIAL_OPEN";
        if (basicOrderType == BasicOrderType.ETH_TO_ERC1155_FULL_RESTRICTED)
            return "ETH_TO_ERC1155_FULL_RESTRICTED";
        if (basicOrderType == BasicOrderType.ETH_TO_ERC1155_PARTIAL_RESTRICTED)
            return "ETH_TO_ERC1155_PARTIAL_RESTRICTED";
        if (basicOrderType == BasicOrderType.ERC20_TO_ERC721_FULL_OPEN)
            return "ERC20_TO_ERC721_FULL_OPEN";
        if (basicOrderType == BasicOrderType.ERC20_TO_ERC721_PARTIAL_OPEN)
            return "ERC20_TO_ERC721_PARTIAL_OPEN";
        if (basicOrderType == BasicOrderType.ERC20_TO_ERC721_FULL_RESTRICTED)
            return "ERC20_TO_ERC721_FULL_RESTRICTED";
        if (basicOrderType == BasicOrderType.ERC20_TO_ERC721_PARTIAL_RESTRICTED)
            return "ERC20_TO_ERC721_PARTIAL_RESTRICTED";
        if (basicOrderType == BasicOrderType.ERC20_TO_ERC1155_FULL_OPEN)
            return "ERC20_TO_ERC1155_FULL_OPEN";
        if (basicOrderType == BasicOrderType.ERC20_TO_ERC1155_PARTIAL_OPEN)
            return "ERC20_TO_ERC1155_PARTIAL_OPEN";
        if (basicOrderType == BasicOrderType.ERC20_TO_ERC1155_FULL_RESTRICTED)
            return "ERC20_TO_ERC1155_FULL_RESTRICTED";
        if (
            basicOrderType == BasicOrderType.ERC20_TO_ERC1155_PARTIAL_RESTRICTED
        ) return "ERC20_TO_ERC1155_PARTIAL_RESTRICTED";
        if (basicOrderType == BasicOrderType.ERC721_TO_ERC20_FULL_OPEN)
            return "ERC721_TO_ERC20_FULL_OPEN";
        if (basicOrderType == BasicOrderType.ERC721_TO_ERC20_PARTIAL_OPEN)
            return "ERC721_TO_ERC20_PARTIAL_OPEN";
        if (basicOrderType == BasicOrderType.ERC721_TO_ERC20_FULL_RESTRICTED)
            return "ERC721_TO_ERC20_FULL_RESTRICTED";
        if (basicOrderType == BasicOrderType.ERC721_TO_ERC20_PARTIAL_RESTRICTED)
            return "ERC721_TO_ERC20_PARTIAL_RESTRICTED";
        if (basicOrderType == BasicOrderType.ERC1155_TO_ERC20_FULL_OPEN)
            return "ERC1155_TO_ERC20_FULL_OPEN";
        if (basicOrderType == BasicOrderType.ERC1155_TO_ERC20_PARTIAL_OPEN)
            return "ERC1155_TO_ERC20_PARTIAL_OPEN";
        if (basicOrderType == BasicOrderType.ERC1155_TO_ERC20_FULL_RESTRICTED)
            return "ERC1155_TO_ERC20_FULL_RESTRICTED";
        if (
            basicOrderType == BasicOrderType.ERC1155_TO_ERC20_PARTIAL_RESTRICTED
        ) return "ERC1155_TO_ERC20_PARTIAL_RESTRICTED";

        return "UNKNOWN";
    }

    function _sideStr(Side side) internal pure returns (string memory) {
        if (side == Side.OFFER) return "OFFER";
        if (side == Side.CONSIDERATION) return "CONSIDERATION";

        return "UNKNOWN";
    }
}
