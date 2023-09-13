// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import {
    AdvancedOrderLib,
    ConsiderationItemLib,
    FulfillmentComponentLib,
    FulfillmentLib,
    OfferItemLib,
    OrderComponentsLib,
    OrderLib,
    OrderParametersLib
} from "seaport-sol/src/SeaportSol.sol";

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
} from "seaport-sol/src/SeaportStructs.sol";

import {
    BasicOrderType,
    ItemType,
    OrderType,
    Side
} from "seaport-sol/src/SeaportEnums.sol";

import { helm } from "../../contracts/helpers/helm.sol";

contract helmTest is Test {
    using AdvancedOrderLib for AdvancedOrder;
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using FulfillmentComponentLib for FulfillmentComponent;
    using FulfillmentComponentLib for FulfillmentComponent[];
    using FulfillmentLib for Fulfillment;
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderParametersLib for OrderParameters;

    using helm for AdvancedOrder;
    using helm for BasicOrderParameters;
    using helm for CriteriaResolver;
    using helm for Execution;
    using helm for Fulfillment;
    using helm for FulfillmentComponent;
    using helm for Order;
    using helm for OrderComponents;
    using helm for OrderComponents[];
    using helm for OrderParameters;
    using helm for ZoneParameters;

    function testLogOrderComponents() public view {
        OfferItem[] memory offer = new OfferItem[](2);
        offer[0] = OfferItem({
            itemType: ItemType(1),
            token: address(0x0),
            identifierOrCriteria: 0,
            startAmount: 0,
            endAmount: 0
        });
        offer[1] = OfferItem({
            itemType: ItemType(2),
            token: address(0x01),
            identifierOrCriteria: 1,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = ConsiderationItem({
            itemType: ItemType(1),
            token: address(0x0),
            identifierOrCriteria: 0,
            startAmount: 0,
            endAmount: 0,
            recipient: payable(0x0)
        });
        consideration[1] = ConsiderationItem({
            itemType: ItemType(2),
            token: address(0x01),
            identifierOrCriteria: 1,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(address(0x01))
        });

        OrderComponents memory orderComponents = OrderComponents({
            offerer: address(0x0),
            zone: address(0x0),
            offer: offer,
            consideration: consideration,
            orderType: OrderType(0),
            startTime: 0,
            endTime: 0,
            zoneHash: bytes32(uint256(0x012345)),
            salt: 0,
            conduitKey: bytes32(uint256(0x98765)),
            counter: 0
        });

        orderComponents.log();
        helm.log(orderComponents);

        OrderComponents[] memory orderComponentsArray = new OrderComponents[](
            2
        );
        orderComponentsArray[0] = orderComponents;
        orderComponentsArray[1] = orderComponents;

        orderComponentsArray.log();
    }

    function testLogBasicOrderParameters() public view {
        AdditionalRecipient[]
            memory additionalRecipients = new AdditionalRecipient[](2);
        additionalRecipients[0] = AdditionalRecipient({
            recipient: payable(address(0x0)),
            amount: 0
        });
        additionalRecipients[1] = AdditionalRecipient({
            recipient: payable(address(0x1)),
            amount: 1
        });

        BasicOrderParameters
            memory basicOrderParameters = BasicOrderParameters({
                considerationToken: address(0x0),
                considerationIdentifier: 0,
                considerationAmount: 0,
                offerer: payable(address(0x0)),
                zone: address(0x0),
                offerToken: address(0x0),
                offerIdentifier: 0,
                offerAmount: 0,
                basicOrderType: BasicOrderType(0),
                startTime: 0,
                endTime: 0,
                zoneHash: bytes32(uint256(0x012345)),
                salt: 0,
                offererConduitKey: bytes32(uint256(0x98765)),
                fulfillerConduitKey: bytes32(uint256(0x5678)),
                totalOriginalAdditionalRecipients: 0,
                additionalRecipients: new AdditionalRecipient[](0),
                signature: bytes(
                    abi.encodePacked(
                        type(uint256).max,
                        (type(uint256).max >> 8)
                    )
                )
            });

        basicOrderParameters.log();
    }

    function testLogOrder() public view {
        OfferItem[] memory offer = new OfferItem[](2);
        offer[0] = OfferItem({
            itemType: ItemType(1),
            token: address(0x0),
            identifierOrCriteria: 0,
            startAmount: 0,
            endAmount: 0
        });
        offer[1] = OfferItem({
            itemType: ItemType(2),
            token: address(0x01),
            identifierOrCriteria: 1,
            startAmount: 1,
            endAmount: 1
        });

        ConsiderationItem[] memory consideration = new ConsiderationItem[](2);
        consideration[0] = ConsiderationItem({
            itemType: ItemType(1),
            token: address(0x0),
            identifierOrCriteria: 0,
            startAmount: 0,
            endAmount: 0,
            recipient: payable(0x0)
        });
        consideration[1] = ConsiderationItem({
            itemType: ItemType(2),
            token: address(0x01),
            identifierOrCriteria: 1,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(address(0x01))
        });

        OrderParameters memory orderParameters = OrderParameters({
            offerer: address(0x0),
            zone: address(0x0),
            offer: offer,
            consideration: consideration,
            orderType: OrderType(0),
            startTime: 0,
            endTime: 0,
            zoneHash: bytes32(uint256(0x012345)),
            salt: 0,
            conduitKey: bytes32(uint256(0x98765)),
            totalOriginalConsiderationItems: 0
        });

        orderParameters.log();

        Order memory order = Order({
            parameters: orderParameters,
            signature: bytes(
                abi.encodePacked(type(uint256).max, (type(uint256).max >> 8))
            )
        });

        order.log();

        AdvancedOrder memory advancedOrder = AdvancedOrder({
            parameters: orderParameters,
            numerator: 0,
            denominator: 0,
            signature: bytes(
                abi.encodePacked(type(uint256).max, (type(uint256).max >> 8))
            ),
            extraData: bytes(
                abi.encodePacked(type(uint256).max, (type(uint256).max >> 8))
            )
        });

        advancedOrder.log();
    }

    function testLogCriteriaResolver() public view {
        // /**
        //  * @dev A criteria resolver specifies an order, side (offer vs. consideration),
        //  *      and item index. It then provides a chosen identifier (i.e. tokenId)
        //  *      alongside a merkle proof demonstrating the identifier meets the required
        //  *      criteria.
        //  */
        // struct CriteriaResolver {
        //     uint256 orderIndex;
        //     Side side;
        //     uint256 index;
        //     uint256 identifier;
        //     bytes32[] criteriaProof;
        // }

        bytes32[] memory criteriaProof = new bytes32[](2);
        criteriaProof[0] = bytes32(uint256(0x012345));
        criteriaProof[1] = bytes32(uint256(0x6789));

        CriteriaResolver memory criteriaResolver = CriteriaResolver({
            orderIndex: 0,
            side: Side(0),
            index: 0,
            identifier: 0,
            criteriaProof: criteriaProof
        });

        criteriaResolver.log();
    }

    function testLogFulfillment() public view {
        FulfillmentComponent[]
            memory fulfillmentComponents = new FulfillmentComponent[](2);
        fulfillmentComponents[0] = FulfillmentComponent({
            orderIndex: 0,
            itemIndex: 0
        });
        fulfillmentComponents[1] = FulfillmentComponent({
            orderIndex: 1,
            itemIndex: 1
        });

        fulfillmentComponents[1].log();

        Fulfillment memory fulfillment = Fulfillment({
            offerComponents: fulfillmentComponents,
            considerationComponents: fulfillmentComponents
        });

        fulfillment.log();
    }

    function testLogExecution() public view {
        Execution memory execution = Execution({
            item: ReceivedItem({
                itemType: ItemType(1),
                token: address(0x0),
                identifier: 0,
                amount: 0,
                recipient: payable(address(0x0))
            }),
            offerer: address(0x0),
            conduitKey: bytes32(uint256(0x98765))
        });

        execution.log();
    }

    // /**
    //  * @dev Restricted orders are validated post-execution by calling validateOrder
    //  *      on the zone. This struct provides context about the order fulfillment
    //  *      and any supplied extraData, as well as all order hashes fulfilled in a
    //  *      call to a match or fulfillAvailable method.
    //  */
    // struct ZoneParameters {
    //     bytes32 orderHash;
    //     address fulfiller;
    //     address offerer;
    //     SpentItem[] offer;
    //     ReceivedItem[] consideration;
    //     bytes extraData;
    //     bytes32[] orderHashes;
    //     uint256 startTime;
    //     uint256 endTime;
    //     bytes32 zoneHash;
    // }

    function testLogZoneParameters() public view {
        SpentItem[] memory offer = new SpentItem[](2);
        offer[0] = SpentItem({
            itemType: ItemType(1),
            token: address(0x0),
            identifier: 0,
            amount: 0
        });
        offer[1] = SpentItem({
            itemType: ItemType(2),
            token: address(0x01),
            identifier: 1,
            amount: 1
        });

        ReceivedItem[] memory consideration = new ReceivedItem[](2);
        consideration[0] = ReceivedItem({
            itemType: ItemType(1),
            token: address(0x0),
            identifier: 0,
            amount: 0,
            recipient: payable(address(0x0))
        });
        consideration[1] = ReceivedItem({
            itemType: ItemType(2),
            token: address(0x01),
            identifier: 1,
            amount: 1,
            recipient: payable(address(0x01))
        });

        ZoneParameters memory zoneParameters = ZoneParameters({
            orderHash: bytes32(uint256(0x012345)),
            fulfiller: address(0x0),
            offerer: address(0x0),
            offer: offer,
            consideration: consideration,
            extraData: bytes(
                abi.encodePacked(type(uint256).max, (type(uint256).max >> 8))
            ),
            orderHashes: new bytes32[](0),
            startTime: 0,
            endTime: 0,
            zoneHash: bytes32(uint256(0x98765))
        });

        zoneParameters.log();
    }
}
