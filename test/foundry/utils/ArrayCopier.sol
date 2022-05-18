// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import { CriteriaResolver, AdditionalRecipient, OfferItem, Order, ConsiderationItem, Fulfillment, FulfillmentComponent, OrderParameters, OrderComponents } from "../../../contracts/lib/ConsiderationStructs.sol";

contract ArrayCopier {
    FulfillmentComponent[] _tempFulfillmentComponents;

    function copyOrderComponents(
        OrderComponents storage dest,
        OrderComponents memory src
    ) internal {
        dest.offerer = src.offerer;
        dest.zone = src.zone;
        copyOfferItems(dest.offer, src.offer);
        copyConsiderationItems(dest.consideration, src.consideration);
        dest.orderType = src.orderType;
        dest.startTime = src.startTime;
        dest.endTime = src.endTime;
        dest.zoneHash = src.zoneHash;
        dest.salt = src.salt;
        dest.conduitKey = src.conduitKey;
        dest.nonce = src.nonce;
    }

    function copyAdditionalRecipients(
        AdditionalRecipient[] storage dest,
        AdditionalRecipient[] memory src
    ) internal {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; i++) {
            dest.push(src[i]);
        }
    }

    function copyBytes32Array(bytes32[] storage dest, bytes32[] memory src)
        internal
    {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; i++) {
            dest.push(src[i]);
        }
    }

    function copyCriteriaResolver(
        CriteriaResolver storage dest,
        CriteriaResolver memory src
    ) internal {
        dest.orderIndex = src.orderIndex;
        dest.side = src.side;
        dest.index = src.index;
        dest.identifier = src.identifier;
        copyBytes32Array(dest.criteriaProof, src.criteriaProof);
    }

    function copyOrder(Order storage dest, Order memory src) internal {
        copyOrderParameters(dest.parameters, src.parameters);
        dest.signature = src.signature;
    }

    function copyOrders(Order[] storage dest, Order[] memory src) internal {}

    function copyOrderParameters(
        OrderParameters storage dest,
        OrderParameters memory src
    ) internal {
        dest.offerer = src.offerer;
        dest.zone = src.zone;
        copyOfferItems(dest.offer, src.offer);
        copyConsiderationItems(dest.consideration, src.consideration);
        dest.orderType = src.orderType;
        dest.startTime = src.startTime;
        dest.endTime = src.endTime;
        dest.zoneHash = src.zoneHash;
        dest.salt = src.salt;
        dest.conduitKey = src.conduitKey;
        dest.totalOriginalConsiderationItems = src
            .totalOriginalConsiderationItems;
    }

    function pushFulFillmentComponents(
        FulfillmentComponent[][] storage dest,
        FulfillmentComponent[] memory src
    ) internal {
        delete _tempFulfillmentComponents;

        for (uint256 i = 0; i < src.length; i++) {
            _tempFulfillmentComponents.push(src[i]);
        }
        dest.push(_tempFulfillmentComponents);
        delete _tempFulfillmentComponents;
    }

    function copyOfferItems(OfferItem[] storage dest, OfferItem[] memory src)
        internal
    {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; i++) {
            dest.push(src[i]);
        }
    }

    function copyConsiderationItems(
        ConsiderationItem[] storage dest,
        ConsiderationItem[] memory src
    ) internal {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; i++) {
            dest.push(src[i]);
        }
    }

    function copyFulfillments(
        Fulfillment[] storage dest,
        Fulfillment[] memory src
    ) internal {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; i++) {
            dest.push(src[i]);
        }
    }

    function copyFulfillmentComponents(
        FulfillmentComponent[] storage dest,
        FulfillmentComponent[] memory src
    ) internal {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; i++) {
            dest.push(src[i]);
        }
    }

    function copyFulfillmentComponentsArray(
        FulfillmentComponent[][] storage dest,
        FulfillmentComponent[][] memory src
    ) internal {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; i++) {
            copyFulfillmentComponents(dest[i], src[i]);
        }
    }
}
