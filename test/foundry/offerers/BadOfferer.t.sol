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
    BadOfferer badOfferer;

    struct Context {
        ConsiderationInterface seaport;
        uint256 id;
        bool eoa;
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
        uint256 id = 101;
        test(
            this.execOrderWithContext,
            Context({ seaport: consideration, id: id, eoa: false })
        );
        test(
            this.execOrderWithContext,
            Context({ seaport: referenceConsideration, id: id, eoa: false })
        );
    }

    function testOrderNothing() public {
        uint256 id = 102;
        test(
            this.execOrderWithContext,
            Context({ seaport: consideration, id: id, eoa: false })
        );
        test(
            this.execOrderWithContext,
            Context({ seaport: referenceConsideration, id: id, eoa: false })
        );
    }

    function testOrderRevert() public {
        uint256 id = 103;
        test(
            this.execOrderWithContext,
            Context({ seaport: consideration, id: id, eoa: false })
        );
        test(
            this.execOrderWithContext,
            Context({ seaport: referenceConsideration, id: id, eoa: false })
        );
    }

    function testOrderGarbage() public {
        uint256 id = 104;
        test(
            this.execOrderWithContext,
            Context({ seaport: consideration, id: id, eoa: false })
        );
        test(
            this.execOrderWithContext,
            Context({ seaport: referenceConsideration, id: id, eoa: false })
        );
    }

    function testOrderEoa() public {
        uint256 id = 101;
        test(
            this.execOrderWithContext,
            Context({ seaport: consideration, id: id, eoa: true })
        );
        test(
            this.execOrderWithContext,
            Context({ seaport: referenceConsideration, id: id, eoa: true })
        );
    }

    function execOrderWithContext(Context memory context) external stateless {
        if (!context.eoa) {
            badOfferer = new BadOfferer(
                address(context.seaport),
                ERC20Interface(address(token1)),
                ERC721Interface(address(test721_1))
            );
        } else {
            badOfferer = BadOfferer(makeAddr("eoa"));
        }

        AdvancedOrder memory badOrder = configureBadOffererOrder(context.id);
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

    function configureBadOffererOrder(uint256 id)
        internal
        returns (AdvancedOrder memory advancedOrder)
    {
        test721_1.mint(address(this), id);

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
            recipient: payable(address(badOfferer))
        });
        OrderParameters memory orderParameters = OrderParameters({
            offerer: address(badOfferer),
            zone: address(0),
            offer: offer,
            consideration: cons,
            orderType: OrderType.CONTRACT,
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

    function configureNormalOrder(Context memory context)
        internal
        returns (AdvancedOrder memory advancedOrder)
    {
        (address offerer, uint256 pkey) = makeAddrAndKey("normal offerer");
        vm.prank(offerer);
        test721_1.setApprovalForAll(address(context.seaport), true);
        test721_1.mint(offerer, 201);
        addErc20ConsiderationItem(payable(offerer), 100);
        addErc721OfferItem(201);
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
