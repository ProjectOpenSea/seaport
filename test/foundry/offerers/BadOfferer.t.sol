// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { BadOfferer } from "./impl/BadOfferer.sol";
import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../../../contracts/interfaces/AbridgedTokenInterfaces.sol";
import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";

import {
    OfferItem,
    ConsiderationItem,
    AdvancedOrder,
    CriteriaResolver,
    SpentItem,
    OrderParameters,
    OrderComponents,
    ReceivedItem,
    FulfillmentComponent,
    Fulfillment
} from "../../../contracts/lib/ConsiderationStructs.sol";
import {
    ItemType,
    OrderType
} from "../../../contracts/lib/ConsiderationEnums.sol";

contract BadOffererTest is BaseOrderTest {
    BadOfferer test;

    struct Context {
        ConsiderationInterface seaport;
    }

    function setUp() public override {
        super.setUp();

        test721_1.mint(address(this), 1);
    }

    function testNormalOrder() public {}

    function execNormalOrder(Context memory context) external {
        test = new BadOfferer(
            address(context.seaport),
            ERC20Interface(token1),
            ERC721Interface(test721_1)
        );
    }

    function configureBadOffererOrder(uint256 id)
        internal
        returns (AdvancedOrder memory advancedOrder)
    {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC20,
            token: address(token1),
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });
        ConsiderationItem[] memory cons = new ConsiderationItem[](1);
        cons[0] = ConsiderationItem({
            itemType: ItemType.ERC721,
            token: address(test721_1),
            identifierOrCriteria: id,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(address(test))
        });
        OrderParameters memory orderParameters = OrderParameters({
            offerer: address(test),
            zone: address(0),
            offer: offer,
            consideration: cons,
            orderType: OrderType.FULL_OPEN,
            startTime: 1,
            endTime: 101,
            zoneHash: bytes32(0),
            salt: 0,
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: 1
        });
        advancedOrder = AdvancedOrder({
            parameters: orderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: ""
        });
    }
}
