// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    AdvancedOrder,
    CriteriaResolver,
    OfferItem,
    ConsiderationItem,
    OrderParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { Side } from "seaport-types/src/lib/ConsiderationEnums.sol";

import { CriteriaHelperLib } from "./CriteriaHelperLib.sol";

import { HelperItemLib } from "./HelperItemLib.sol";

import {
    NavigatorAdvancedOrder,
    NavigatorConsiderationItem,
    NavigatorOfferItem,
    NavigatorOrderParameters
} from "./SeaportNavigatorTypes.sol";

library NavigatorAdvancedOrderLib {
    using CriteriaHelperLib for uint256[];
    using HelperItemLib for NavigatorConsiderationItem;
    using HelperItemLib for NavigatorOfferItem;

    /*
     * @dev Converts an array of AdvancedOrders to an array of
     *      NavigatorAdvancedOrders.
     */
    function fromAdvancedOrders(
        AdvancedOrder[] memory orders
    ) internal pure returns (NavigatorAdvancedOrder[] memory) {
        NavigatorAdvancedOrder[]
            memory helperOrders = new NavigatorAdvancedOrder[](orders.length);
        for (uint256 i; i < orders.length; i++) {
            helperOrders[i] = fromAdvancedOrder(orders[i]);
        }
        return helperOrders;
    }

    /*
     * @dev Converts an AdvancedOrder to a NavigatorAdvancedOrder.
     */
    function fromAdvancedOrder(
        AdvancedOrder memory order
    ) internal pure returns (NavigatorAdvancedOrder memory) {
        // Copy over the offer items.
        NavigatorOfferItem[] memory offerItems = new NavigatorOfferItem[](
            order.parameters.offer.length
        );
        for (uint256 i; i < order.parameters.offer.length; i++) {
            OfferItem memory item = order.parameters.offer[i];
            offerItems[i] = NavigatorOfferItem({
                itemType: item.itemType,
                token: item.token,
                identifier: item.identifierOrCriteria,
                startAmount: item.startAmount,
                endAmount: item.endAmount,
                candidateIdentifiers: new uint256[](0)
            });
        }

        // Copy over the consideration items.
        NavigatorConsiderationItem[]
            memory considerationItems = new NavigatorConsiderationItem[](
                order.parameters.consideration.length
            );
        for (uint256 i; i < order.parameters.consideration.length; i++) {
            ConsiderationItem memory item = order.parameters.consideration[i];
            considerationItems[i] = NavigatorConsiderationItem({
                itemType: item.itemType,
                token: item.token,
                identifier: item.identifierOrCriteria,
                startAmount: item.startAmount,
                endAmount: item.endAmount,
                recipient: item.recipient,
                candidateIdentifiers: new uint256[](0)
            });
        }
        return
            NavigatorAdvancedOrder({
                parameters: NavigatorOrderParameters({
                    offerer: order.parameters.offerer,
                    zone: order.parameters.zone,
                    offer: offerItems,
                    consideration: considerationItems,
                    orderType: order.parameters.orderType,
                    startTime: order.parameters.startTime,
                    endTime: order.parameters.endTime,
                    zoneHash: order.parameters.zoneHash,
                    salt: order.parameters.salt,
                    conduitKey: order.parameters.conduitKey,
                    totalOriginalConsiderationItems: order
                        .parameters
                        .totalOriginalConsiderationItems
                }),
                numerator: order.numerator,
                denominator: order.denominator,
                signature: order.signature,
                extraData: order.extraData
            });
    }

    /*
     * @dev Converts an array of NavigatorAdvancedOrders to an array of
     *      AdvancedOrders and an array of CriteriaResolvers.
     */
    function toAdvancedOrder(
        NavigatorAdvancedOrder memory order,
        uint256 orderIndex
    ) internal pure returns (AdvancedOrder memory, CriteriaResolver[] memory) {
        // Create an array of CriteriaResolvers to be populated in the for loop
        // below. It might be longer than it needs to be, but it gets trimmed in
        // the assembly block below.
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](
            order.parameters.offer.length +
                order.parameters.consideration.length
        );
        uint256 criteriaResolverLen;

        // Copy over the offer items, converting candidate identifiers to a
        // criteria root if necessary and populating the criteria resolvers
        // array.
        OfferItem[] memory offer = new OfferItem[](
            order.parameters.offer.length
        );
        for (uint256 i; i < order.parameters.offer.length; i++) {
            NavigatorOfferItem memory item = order.parameters.offer[i];
            if (item.hasCriteria()) {
                item.validate();
                offer[i] = OfferItem({
                    itemType: item.normalizeType(),
                    token: item.token,
                    identifierOrCriteria: uint256(
                        item.candidateIdentifiers.criteriaRoot()
                    ),
                    startAmount: item.startAmount,
                    endAmount: item.endAmount
                });
                criteriaResolvers[criteriaResolverLen] = CriteriaResolver({
                    orderIndex: orderIndex,
                    side: Side.OFFER,
                    index: i,
                    identifier: item.identifier,
                    criteriaProof: item.candidateIdentifiers.criteriaProof(
                        item.identifier
                    )
                });
                criteriaResolverLen++;
            } else {
                offer[i] = OfferItem({
                    itemType: item.itemType,
                    token: item.token,
                    identifierOrCriteria: item.identifier,
                    startAmount: item.startAmount,
                    endAmount: item.endAmount
                });
            }
        }

        // Copy over the consideration items, converting candidate identifiers
        // to a criteria root if necessary and populating the criteria resolvers
        // array.
        ConsiderationItem[] memory consideration = new ConsiderationItem[](
            order.parameters.consideration.length
        );
        for (uint256 i; i < order.parameters.consideration.length; i++) {
            NavigatorConsiderationItem memory item = order
                .parameters
                .consideration[i];
            if (item.hasCriteria()) {
                item.validate();
                consideration[i] = ConsiderationItem({
                    itemType: item.normalizeType(),
                    token: item.token,
                    identifierOrCriteria: uint256(
                        item.candidateIdentifiers.criteriaRoot()
                    ),
                    startAmount: item.startAmount,
                    endAmount: item.endAmount,
                    recipient: item.recipient
                });
                criteriaResolvers[criteriaResolverLen] = CriteriaResolver({
                    orderIndex: orderIndex,
                    side: Side.CONSIDERATION,
                    index: i,
                    identifier: item.identifier,
                    criteriaProof: item.candidateIdentifiers.criteriaProof(
                        item.identifier
                    )
                });
                criteriaResolverLen++;
            } else {
                consideration[i] = ConsiderationItem({
                    itemType: item.itemType,
                    token: item.token,
                    identifierOrCriteria: item.identifier,
                    startAmount: item.startAmount,
                    endAmount: item.endAmount,
                    recipient: item.recipient
                });
            }
        }

        // This just encodes the length of the array that we gradually built up
        // above. It's just a way of creating an array of arbitrary length. It's
        // initialized to its longest possible length at the top, then populated
        // partially or fully in the for loop above. Finally, the length is set
        // here surgically.
        assembly {
            mstore(criteriaResolvers, criteriaResolverLen)
        }

        return (
            AdvancedOrder({
                parameters: OrderParameters({
                    offerer: order.parameters.offerer,
                    zone: order.parameters.zone,
                    offer: offer,
                    consideration: consideration,
                    orderType: order.parameters.orderType,
                    startTime: order.parameters.startTime,
                    endTime: order.parameters.endTime,
                    zoneHash: order.parameters.zoneHash,
                    salt: order.parameters.salt,
                    conduitKey: order.parameters.conduitKey,
                    totalOriginalConsiderationItems: order
                        .parameters
                        .totalOriginalConsiderationItems
                }),
                numerator: order.numerator,
                denominator: order.denominator,
                signature: order.signature,
                extraData: order.extraData
            }),
            criteriaResolvers
        );
    }

    /*
     * @dev Converts an array of NavigatorAdvancedOrders to an array of
     *      AdvancedOrders and an array of CriteriaResolvers.
     */
    function toAdvancedOrders(
        NavigatorAdvancedOrder[] memory orders
    )
        internal
        pure
        returns (AdvancedOrder[] memory, CriteriaResolver[] memory)
    {
        // Create an array of AdvancedOrders to be populated in the for loop
        // below.
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](
            orders.length
        );

        // Create an array of CriteriaResolvers to be populated in the for loop
        // below. It might be longer than it needs to be, but it gets trimmed in
        // the assembly block below.
        uint256 maxCriteriaResolvers;
        for (uint256 i; i < orders.length; i++) {
            NavigatorOrderParameters memory parameters = orders[i].parameters;
            maxCriteriaResolvers += (parameters.offer.length +
                parameters.consideration.length);
        }
        uint256 criteriaResolverIndex;
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](
            maxCriteriaResolvers
        );

        // Copy over the NavigatorAdvancedOrder[] orders to the AdvancedOrder[]
        // array, converting and populating the criteria resolvers array.
        for (uint256 i = 0; i < orders.length; i++) {
            (
                AdvancedOrder memory order,
                CriteriaResolver[] memory orderResolvers
            ) = toAdvancedOrder(orders[i], i);
            advancedOrders[i] = order;
            for (uint256 j; j < orderResolvers.length; j++) {
                criteriaResolvers[criteriaResolverIndex] = orderResolvers[j];
                criteriaResolverIndex++;
            }
        }

        // This just encodes the length of the array that we gradually built up
        // above. It's just a way of creating an array of arbitrary length. It's
        // initialized to its longest possible length at the top, then populated
        // partially or fully in the for loop above. Finally, the length is set
        // here surgically.
        assembly {
            mstore(criteriaResolvers, criteriaResolverIndex)
        }

        return (advancedOrders, criteriaResolvers);
    }
}
