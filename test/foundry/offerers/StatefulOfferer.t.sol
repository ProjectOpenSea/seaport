// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { StatefulRatifierOfferer } from "./impl/StatefulRatifierOfferer.sol";

import {
    ERC20Interface,
    ERC721Interface
} from "../../../contracts/interfaces/AbridgedTokenInterfaces.sol";

import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";

import {
    OfferItem,
    ConsiderationItem,
    AdvancedOrder,
    CriteriaResolver,
    OrderComponents,
    FulfillmentComponent
} from "../../../contracts/lib/ConsiderationStructs.sol";

import { OrderType } from "../../../contracts/lib/ConsiderationEnums.sol";

contract StatefulOffererTest is BaseOrderTest {
    StatefulRatifierOfferer offerer;

    struct Context {
        ConsiderationInterface consideration;
        uint8 numToAdd;
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testFulfillAdvanced() public {
        test(
            this.execFulfillAdvanced,
            Context({ consideration: consideration, numToAdd: 0 })
        );
        test(
            this.execFulfillAdvanced,
            Context({ consideration: referenceConsideration, numToAdd: 0 })
        );
    }

    function execFulfillAdvanced(Context memory context) public stateless {
        offerer = new StatefulRatifierOfferer(
            address(context.consideration),
            ERC20Interface(address(token1)),
            ERC721Interface(address(test721_1)),
            1
        );
        addErc20OfferItem(1);
        addErc721ConsiderationItem(payable(address(offerer)), 42);
        addErc721ConsiderationItem(payable(address(offerer)), 43);
        addErc721ConsiderationItem(payable(address(offerer)), 44);

        test721_1.mint(address(this), 42);
        test721_1.mint(address(this), 43);
        test721_1.mint(address(this), 44);

        _configureOrderParameters({
            offerer: address(offerer),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;

        configureOrderComponents(0);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: "context"
        });

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        context.consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertTrue(offerer.called());
    }

    function testCancelAdvancedRevert() public {
        test(
            this.execCancelAdvancedRevert,
            Context({ consideration: consideration, numToAdd: 0 })
        );
        test(
            this.execCancelAdvancedRevert,
            Context({ consideration: referenceConsideration, numToAdd: 0 })
        );
    }

    function execCancelAdvancedRevert(Context memory context) public stateless {
        offerer = new StatefulRatifierOfferer(
            address(context.consideration),
            ERC20Interface(address(token1)),
            ERC721Interface(address(test721_1)),
            1
        );
        addErc20OfferItem(1);
        addErc721ConsiderationItem(payable(address(offerer)), 42);

        test721_1.mint(address(this), 42);

        _configureOrderParameters({
            offerer: address(offerer),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;

        configureOrderComponents(0);

        OrderComponents[] memory myBaseOrderComponents = new OrderComponents[](
            1
        );
        myBaseOrderComponents[0] = baseOrderComponents;

        vm.prank(address(offerer));
        // Contract orders cannot be cancelled.
        vm.expectRevert(abi.encodeWithSignature("CannotCancelOrder()"));
        context.consideration.cancel(myBaseOrderComponents);
    }

    function testFulfillAdvancedFuzz(uint8 numToAdd) public {
        numToAdd = uint8(bound(numToAdd, 1, 255));
        test(
            this.execFulfillAdvancedFuzz,
            Context({ consideration: consideration, numToAdd: numToAdd })
        );
        test(
            this.execFulfillAdvancedFuzz,
            Context({
                consideration: referenceConsideration,
                numToAdd: numToAdd
            })
        );
    }

    function execFulfillAdvancedFuzz(Context memory context) public stateless {
        offerer = new StatefulRatifierOfferer(
            address(context.consideration),
            ERC20Interface(address(token1)),
            ERC721Interface(address(test721_1)),
            context.numToAdd
        );
        addErc20OfferItem(1);
        addErc721ConsiderationItem(payable(address(offerer)), 42);
        addErc721ConsiderationItem(payable(address(offerer)), 43);
        addErc721ConsiderationItem(payable(address(offerer)), 44);

        test721_1.mint(address(this), 42);
        test721_1.mint(address(this), 43);
        test721_1.mint(address(this), 44);

        _configureOrderParameters({
            offerer: address(offerer),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;

        configureOrderComponents(0);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: "context"
        });

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);

        context.consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertTrue(offerer.called());
    }

    function testMatchAdvancedOrders() public {
        test(
            this.execMatchAdvancedOrders,
            Context({ consideration: consideration, numToAdd: 0 })
        );
        test(
            this.execMatchAdvancedOrders,
            Context({ consideration: referenceConsideration, numToAdd: 0 })
        );
    }

    function execMatchAdvancedOrders(
        Context memory context
    ) external stateless {
        offerer = new StatefulRatifierOfferer(
            address(context.consideration),
            ERC20Interface(address(token1)),
            ERC721Interface(address(test721_1)),
            1
        );
        addErc20OfferItem(1);
        addErc721ConsiderationItem(payable(address(offerer)), 42);
        addErc721ConsiderationItem(payable(address(offerer)), 43);
        addErc721ConsiderationItem(payable(address(offerer)), 44);

        _configureOrderParameters({
            offerer: address(offerer),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;

        configureOrderComponents(0);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: "context"
        });

        AdvancedOrder memory mirror = createMirrorContractOffererOrder(
            context,
            "mirroroooor",
            order
        );

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = order;
        orders[1] = mirror;

        //match first order offer to second order consideration
        createFulfillmentFromComponentsAndAddToFulfillments({
            _offer: FulfillmentComponent({ orderIndex: 0, itemIndex: 0 }),
            _consideration: FulfillmentComponent({
                orderIndex: 1,
                itemIndex: 0
            })
        });
        // match second order first offer to first order first consideration
        createFulfillmentFromComponentsAndAddToFulfillments({
            _offer: FulfillmentComponent({ orderIndex: 1, itemIndex: 0 }),
            _consideration: FulfillmentComponent({
                orderIndex: 0,
                itemIndex: 0
            })
        });
        // match second order second offer to first order second consideration
        createFulfillmentFromComponentsAndAddToFulfillments({
            _offer: FulfillmentComponent({ orderIndex: 1, itemIndex: 1 }),
            _consideration: FulfillmentComponent({
                orderIndex: 0,
                itemIndex: 1
            })
        });
        // match second order third offer to first order third consideration
        createFulfillmentFromComponentsAndAddToFulfillments({
            _offer: FulfillmentComponent({ orderIndex: 1, itemIndex: 2 }),
            _consideration: FulfillmentComponent({
                orderIndex: 0,
                itemIndex: 2
            })
        });

        context.consideration.matchAdvancedOrders({
            orders: orders,
            criteriaResolvers: criteriaResolvers,
            fulfillments: fulfillments,
            recipient: address(0)
        });
        assertTrue(offerer.called());
    }

    function testFulfillAvailableAdvancedOrders() public {
        test(
            this.execFulfillAvailableAdvancedOrders,
            Context({ consideration: consideration, numToAdd: 0 })
        );
        test(
            this.execFulfillAvailableAdvancedOrders,
            Context({ consideration: referenceConsideration, numToAdd: 0 })
        );
    }

    function execFulfillAvailableAdvancedOrders(
        Context memory context
    ) external stateless {
        offerer = new StatefulRatifierOfferer(
            address(context.consideration),
            ERC20Interface(address(token1)),
            ERC721Interface(address(test721_1)),
            1
        );
        addErc20OfferItem(1);
        addErc721ConsiderationItem(payable(address(offerer)), 42);
        addErc721ConsiderationItem(payable(address(offerer)), 43);
        addErc721ConsiderationItem(payable(address(offerer)), 44);

        test721_1.mint(address(this), 42);
        test721_1.mint(address(this), 43);
        test721_1.mint(address(this), 44);
        _configureOrderParameters({
            offerer: address(offerer),
            zone: address(0),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.orderType = OrderType.CONTRACT;

        configureOrderComponents(0);

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: "context"
        });

        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order;
        offerComponents.push(
            FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
        );
        offerComponentsArray.push(offerComponents);

        considerationComponents.push(
            FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
        );
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;
        considerationComponents.push(
            FulfillmentComponent({ orderIndex: 0, itemIndex: 1 })
        );
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;
        considerationComponents.push(
            FulfillmentComponent({ orderIndex: 0, itemIndex: 2 })
        );
        considerationComponentsArray.push(considerationComponents);

        context.consideration.fulfillAvailableAdvancedOrders({
            advancedOrders: orders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerComponentsArray,
            considerationFulfillments: considerationComponentsArray,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0),
            maximumFulfilled: 1
        });
        assertTrue(offerer.called());
    }

    function createMirrorContractOffererOrder(
        Context memory context,
        string memory _offerer,
        AdvancedOrder memory advancedOrder
    ) internal returns (AdvancedOrder memory) {
        delete offerItems;
        delete considerationItems;

        (address _offererAddr, uint256 pkey) = makeAddrAndKey(_offerer);
        test721_1.mint(address(_offererAddr), 42);
        test721_1.mint(address(_offererAddr), 43);
        test721_1.mint(address(_offererAddr), 44);

        vm.prank(_offererAddr);
        test721_1.setApprovalForAll(address(context.consideration), true);

        for (uint256 i; i < advancedOrder.parameters.offer.length; i++) {
            OfferItem memory _offerItem = advancedOrder.parameters.offer[i];

            addConsiderationItem({
                itemType: _offerItem.itemType,
                token: _offerItem.token,
                identifier: _offerItem.identifierOrCriteria,
                startAmount: _offerItem.startAmount,
                endAmount: _offerItem.endAmount,
                recipient: payable(_offererAddr)
            });
        }
        // do the same for considerationItem -> offerItem
        for (
            uint256 i;
            i < advancedOrder.parameters.consideration.length;
            i++
        ) {
            ConsiderationItem memory _considerationItem = advancedOrder
                .parameters
                .consideration[i];

            addOfferItem({
                itemType: _considerationItem.itemType,
                token: _considerationItem.token,
                identifier: _considerationItem.identifierOrCriteria,
                startAmount: _considerationItem.startAmount,
                endAmount: _considerationItem.endAmount
            });
        }

        _configureOrderParameters({
            offerer: _offererAddr,
            zone: advancedOrder.parameters.zone,
            zoneHash: advancedOrder.parameters.zoneHash,
            salt: advancedOrder.parameters.salt,
            useConduit: false
        });

        configureOrderComponents(0);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            pkey,
            orderHash
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: advancedOrder.denominator,
            denominator: advancedOrder.numerator,
            signature: signature,
            extraData: ""
        });

        return order;
    }
}
