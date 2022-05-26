// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import { CriteriaResolver, AdditionalRecipient, OfferItem, Order, ConsiderationItem, Fulfillment, FulfillmentComponent, OrderParameters, OrderComponents } from "../../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../../contracts/interfaces/ConsiderationInterface.sol";

contract StructCopier {
    FulfillmentComponent[] _tempFulfillmentComponents;

    function toConsiderationItems(
        OfferItem[] memory _offerItems,
        address payable receiver
    ) internal pure returns (ConsiderationItem[] memory) {
        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            _offerItems.length
        );
        for (uint256 i = 0; i < _offerItems.length; i++) {
            considerationItems[i] = ConsiderationItem(
                _offerItems[i].itemType,
                _offerItems[i].token,
                _offerItems[i].identifierOrCriteria,
                _offerItems[i].startAmount,
                _offerItems[i].endAmount,
                receiver
            );
        }
        return considerationItems;
    }

    function toOfferItems(ConsiderationItem[] memory _considerationItems)
        internal
        pure
        returns (OfferItem[] memory)
    {
        OfferItem[] memory _offerItems = new OfferItem[](
            _considerationItems.length
        );
        for (uint256 i = 0; i < _offerItems.length; i++) {
            _offerItems[i] = OfferItem(
                _considerationItems[i].itemType,
                _considerationItems[i].token,
                _considerationItems[i].identifierOrCriteria,
                _considerationItems[i].startAmount,
                _considerationItems[i].endAmount
            );
        }
        return _offerItems;
    }

    function createMirrorOrderParameters(
        OrderParameters memory orderParameters,
        address payable offerer,
        address zone,
        bytes32 conduitKey
    ) public pure returns (OrderParameters memory) {
        OfferItem[] memory _offerItems = toOfferItems(
            orderParameters.consideration
        );
        ConsiderationItem[] memory _considerationItems = toConsiderationItems(
            orderParameters.offer,
            offerer
        );

        OrderParameters memory _mirrorOrderParameters = OrderParameters(
            offerer,
            zone,
            _offerItems,
            _considerationItems,
            orderParameters.orderType,
            orderParameters.startTime,
            orderParameters.endTime,
            orderParameters.zoneHash,
            orderParameters.salt,
            conduitKey,
            _considerationItems.length
        );
        return _mirrorOrderParameters;
    }

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
