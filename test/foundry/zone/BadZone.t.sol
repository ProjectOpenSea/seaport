// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { BadZone } from "./impl/BadZone.sol";

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

contract BadZoneTest is BaseOrderTest {
    BadZone badZone;

    struct Context {
        ConsiderationInterface seaport;
        uint256 id;
    }

    function setUp() public override {
        super.setUp();
        token1.mint(address(this), 100000);
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testNormalOrder() public {
        uint256 id = 1;
        test(
            this.execOrderWithContext,
            Context({ seaport: consideration, id: id })
        );
        test(
            this.execOrderWithContext,
            Context({ seaport: referenceConsideration, id: id })
        );
    }

    function testOrderNothing() public {
        uint256 id = 2;
        test(
            this.execOrderWithContext,
            Context({ seaport: consideration, id: id })
        );
        test(
            this.execOrderWithContext,
            Context({ seaport: referenceConsideration, id: id })
        );
    }

    function testOrderGarbage() public {
        uint256 id = 2;
        test(
            this.execOrderWithContext,
            Context({ seaport: consideration, id: id })
        );
        test(
            this.execOrderWithContext,
            Context({ seaport: referenceConsideration, id: id })
        );
    }

    function execOrderWithContext(Context memory context) external stateless {
        badZone = new BadZone();

        AdvancedOrder memory badOrder = configureBadZoneOrder(context);
        AdvancedOrder memory normalOrder = configureNormalOrder(context);

        configureFulfillmentComponents();

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);
        advancedOrders[0] = badOrder;
        advancedOrders[1] = normalOrder;
        CriteriaResolver[] memory resolvers;

        context.seaport.fulfillAvailableAdvancedOrders({
            advancedOrders: advancedOrders,
            criteriaResolvers: resolvers,
            offerFulfillments: offerComponentsArray,
            considerationFulfillments: considerationComponentsArray,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0),
            maximumFulfilled: 2
        });
    }

    function addSingleFulfillmentComponentsTo(
        FulfillmentComponent memory component,
        FulfillmentComponent[][] storage target
    ) internal {
        delete fulfillmentComponents;
        fulfillmentComponents.push(component);
        target.push(fulfillmentComponents);
    }

    function configureFulfillmentComponents() internal {
        addSingleFulfillmentComponentsTo(
            FulfillmentComponent({ orderIndex: 0, itemIndex: 0 }),
            offerComponentsArray
        );
        addSingleFulfillmentComponentsTo(
            FulfillmentComponent({ orderIndex: 1, itemIndex: 0 }),
            offerComponentsArray
        );
        addSingleFulfillmentComponentsTo(
            FulfillmentComponent({ orderIndex: 0, itemIndex: 0 }),
            considerationComponentsArray
        );
        addSingleFulfillmentComponentsTo(
            FulfillmentComponent({ orderIndex: 1, itemIndex: 0 }),
            considerationComponentsArray
        );
    }

    function configureBadZoneOrder(Context memory context)
        internal
        returns (AdvancedOrder memory advancedOrder)
    {
        test721_1.mint(address(this), context.id);
        (address offerer, uint256 pkey) = makeAddrAndKey("erc20 offerer");
        vm.prank(offerer);
        token1.approve(address(context.seaport), type(uint256).max);
        token1.mint(offerer, 100);
        addErc20OfferItem(100);
        addErc721ConsiderationItem(payable(offerer), context.id);
        configureOrderParameters(offerer);
        baseOrderParameters.zone = address(badZone);
        _configureOrderComponents(0);
        bytes32 orderHash = context.seaport.getOrderHash(baseOrderComponents);
        bytes memory signature = signOrder(context.seaport, pkey, orderHash);

        advancedOrder = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: ""
        });
    }

    function configureNormalOrder(Context memory context)
        internal
        returns (AdvancedOrder memory advancedOrder)
    {
        delete offerItems;
        delete considerationItems;
        (address offerer, uint256 pkey) = makeAddrAndKey("normal offerer");
        vm.prank(offerer);
        test721_1.setApprovalForAll(address(context.seaport), true);
        test721_1.mint(offerer, 201);
        addErc721OfferItem(201);
        addErc20ConsiderationItem(payable(offerer), 100);

        configureOrderParameters(offerer);
        _configureOrderComponents(0);
        bytes32 orderHash = context.seaport.getOrderHash(baseOrderComponents);
        bytes memory signature = signOrder(context.seaport, pkey, orderHash);

        advancedOrder = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: ""
        });
    }
}
