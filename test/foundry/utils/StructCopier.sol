// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import { BasicOrderParameters, CriteriaResolver, AdvancedOrder, AdditionalRecipient, OfferItem, Order, ConsiderationItem, Fulfillment, FulfillmentComponent, OrderParameters, OrderComponents } from "../../../contracts/lib/ConsiderationStructs.sol";
import { ConsiderationInterface } from "../../../contracts/interfaces/ConsiderationInterface.sol";

contract StructCopier {
    Order _tempOrder;
    AdvancedOrder _tempAdvancedOrder;
    FulfillmentComponent[] _tempFulfillmentComponents;

    function setBasicOrderParameters(
        BasicOrderParameters storage dest,
        BasicOrderParameters memory src
    ) internal {
        dest.considerationToken = src.considerationToken;
        dest.considerationIdentifier = src.considerationIdentifier;
        dest.considerationAmount = src.considerationAmount;
        dest.offerer = src.offerer;
        dest.zone = src.zone;
        dest.offerToken = src.offerToken;
        dest.offerIdentifier = src.offerIdentifier;
        dest.offerAmount = src.offerAmount;
        dest.basicOrderType = src.basicOrderType;
        dest.startTime = src.endTime;
        dest.endTime = src.endTime;
        dest.zoneHash = src.zoneHash;
        dest.salt = src.salt;
        dest.offererConduitKey = src.offererConduitKey;
        dest.fulfillerConduitKey = src.fulfillerConduitKey;
        dest.totalOriginalAdditionalRecipients = src
            .totalOriginalAdditionalRecipients;
        setAdditionalRecipients(
            dest.additionalRecipients,
            src.additionalRecipients
        );
        dest.signature = src.signature;
    }

    function setOrderComponents(
        OrderComponents storage dest,
        OrderComponents memory src
    ) internal {
        dest.offerer = src.offerer;
        dest.zone = src.zone;
        setOfferItems(dest.offer, src.offer);
        setConsiderationItems(dest.consideration, src.consideration);
        dest.orderType = src.orderType;
        dest.startTime = src.startTime;
        dest.endTime = src.endTime;
        dest.zoneHash = src.zoneHash;
        dest.salt = src.salt;
        dest.conduitKey = src.conduitKey;
        dest.counter = src.counter;
    }

    function setAdditionalRecipients(
        AdditionalRecipient[] storage dest,
        AdditionalRecipient[] memory src
    ) internal {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; ++i) {
            dest.push(src[i]);
        }
    }

    function setBytes32Array(bytes32[] storage dest, bytes32[] memory src)
        internal
    {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; ++i) {
            dest.push(src[i]);
        }
    }

    function setCriteriaResolver(
        CriteriaResolver storage dest,
        CriteriaResolver memory src
    ) internal {
        dest.orderIndex = src.orderIndex;
        dest.side = src.side;
        dest.index = src.index;
        dest.identifier = src.identifier;
        setBytes32Array(dest.criteriaProof, src.criteriaProof);
    }

    function setOrder(Order storage dest, Order memory src) internal {
        setOrderParameters(dest.parameters, src.parameters);
        dest.signature = src.signature;
    }

    function setOrders(Order[] storage dest, Order[] memory src) internal {
        delete _tempOrder;
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; ++i) {
            setOrder(_tempOrder, src[i]);
            dest.push(_tempOrder);
        }
        delete _tempOrder;
    }

    function setAdvancedOrder(
        AdvancedOrder storage dest,
        AdvancedOrder memory src
    ) internal {
        setOrderParameters(dest.parameters, src.parameters);
        dest.numerator = src.numerator;
        dest.denominator = src.denominator;
        dest.signature = src.signature;
        dest.extraData = src.extraData;
    }

    function setAdvancedOrders(
        AdvancedOrder[] storage dest,
        AdvancedOrder[] memory src
    ) internal {
        // todo: delete might not work with nested non-empty arrays
        delete _tempAdvancedOrder;
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; ++i) {
            setAdvancedOrder(_tempAdvancedOrder, src[i]);
            dest.push(_tempAdvancedOrder);
        }
        delete _tempAdvancedOrder;
    }

    function setOrderParameters(
        OrderParameters storage dest,
        OrderParameters memory src
    ) internal {
        dest.offerer = src.offerer;
        dest.zone = src.zone;
        setOfferItems(dest.offer, src.offer);
        setConsiderationItems(dest.consideration, src.consideration);
        dest.orderType = src.orderType;
        dest.startTime = src.startTime;
        dest.endTime = src.endTime;
        dest.zoneHash = src.zoneHash;
        dest.salt = src.salt;
        dest.conduitKey = src.conduitKey;
        dest.totalOriginalConsiderationItems = src
            .totalOriginalConsiderationItems;
    }

    function setOfferItems(OfferItem[] storage dest, OfferItem[] memory src)
        internal
    {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; ++i) {
            dest.push(src[i]);
        }
    }

    function setConsiderationItems(
        ConsiderationItem[] storage dest,
        ConsiderationItem[] memory src
    ) internal {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; ++i) {
            dest.push(src[i]);
        }
    }

    function setFulfillment(Fulfillment storage dest, Fulfillment memory src)
        internal
    {
        setFulfillmentComponents(dest.offerComponents, src.offerComponents);
        setFulfillmentComponents(
            dest.considerationComponents,
            src.considerationComponents
        );
    }

    function setFulfillments(
        Fulfillment[] storage dest,
        Fulfillment[] memory src
    ) internal {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; ++i) {
            dest.push(src[i]);
        }
    }

    function setFulfillmentComponents(
        FulfillmentComponent[] storage dest,
        FulfillmentComponent[] memory src
    ) internal {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; ++i) {
            dest.push(src[i]);
        }
    }

    function pushFulFillmentComponents(
        FulfillmentComponent[][] storage dest,
        FulfillmentComponent[] memory src
    ) internal {
        setFulfillmentComponents(_tempFulfillmentComponents, src);
        dest.push(_tempFulfillmentComponents);
    }

    function setFulfillmentComponentsArray(
        FulfillmentComponent[][] storage dest,
        FulfillmentComponent[][] memory src
    ) internal {
        while (dest.length != 0) {
            dest.pop();
        }
        for (uint256 i = 0; i < src.length; ++i) {
            pushFulFillmentComponents(dest, src[i]);
        }
    }

    function toConsiderationItems(
        OfferItem[] memory _offerItems,
        address payable receiver
    ) internal pure returns (ConsiderationItem[] memory) {
        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            _offerItems.length
        );
        for (uint256 i = 0; i < _offerItems.length; ++i) {
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
}
