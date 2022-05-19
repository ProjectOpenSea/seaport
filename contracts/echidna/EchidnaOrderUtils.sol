// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { ItemType, BasicOrderType } from "../lib/ConsiderationEnums.sol";

// prettier-ignore
import {
    OrderParameters,
    BasicOrderParameters,
    OrderComponents,
    ConsiderationItem,
    OfferItem,
    AdditionalRecipient
} from "../lib/ConsiderationStructs.sol";

contract EchidnaOrderUtils {
    function convertOrderParametersToOrderComponents(
        OrderParameters memory params,
        uint256 nonce
    ) internal pure returns (OrderComponents memory component) {
        component = OrderComponents({
            offerer: params.offerer,
            zone: params.zone,
            offer: params.offer,
            consideration: params.consideration,
            orderType: params.orderType,
            startTime: params.startTime,
            endTime: params.endTime,
            zoneHash: params.zoneHash,
            salt: params.salt,
            conduitKey: params.conduitKey,
            nonce: nonce
        });
    }

    function convertOrderParametersToBasicOrder(
        OrderParameters memory orderParams,
        bytes memory sig,
        BasicOrderType basicOrderType
    ) internal pure returns (BasicOrderParameters memory) {
        bytes32 conduitKey = orderParams.conduitKey;
        OfferItem memory offer = orderParams.offer[0];
        ConsiderationItem memory consideration = orderParams.consideration[0];
        AdditionalRecipient[] memory additional = new AdditionalRecipient[](0);
        return
            BasicOrderParameters({
                considerationToken: consideration.token,
                considerationIdentifier: consideration.identifierOrCriteria,
                considerationAmount: consideration.startAmount,
                offerer: payable(orderParams.offerer),
                zone: orderParams.zone,
                offerToken: offer.token,
                offerIdentifier: offer.identifierOrCriteria,
                offerAmount: offer.startAmount,
                basicOrderType: basicOrderType,
                startTime: orderParams.startTime,
                endTime: orderParams.endTime,
                zoneHash: orderParams.zoneHash,
                salt: orderParams.salt,
                offererConduitKey: conduitKey,
                fulfillerConduitKey: conduitKey,
                totalOriginalAdditionalRecipients: uint256(0),
                additionalRecipients: additional,
                signature: sig
            });
    }

    function createConsiderationItem(
        ItemType itemType,
        address token,
        uint256 identifierOrCriteria,
        uint256 startAmount,
        uint256 sellForMin,
        address payable seller
    ) internal pure returns (ConsiderationItem memory) {
        return
            ConsiderationItem({
                itemType: itemType,
                token: token,
                identifierOrCriteria: identifierOrCriteria,
                startAmount: startAmount,
                endAmount: sellForMin,
                recipient: seller
            });
    }

    function createOfferItem(
        ItemType itemType,
        address token,
        uint256 identifierOrCriteria,
        uint256 startAmount,
        uint256 endAmount
    ) internal pure returns (OfferItem memory) {
        return
            OfferItem({
                itemType: itemType,
                token: token,
                identifierOrCriteria: identifierOrCriteria,
                startAmount: startAmount,
                endAmount: endAmount
            });
    }
}
