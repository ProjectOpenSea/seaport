// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { BaseConduitTest } from "../conduit/BaseConduitTest.sol";

import { TestZone } from "./impl/TestZone.sol";

import {
    TestTransferValidationZoneOfferer
} from "../../../contracts/test/TestTransferValidationZoneOfferer.sol";

import {
    PostFulfillmentStatefulTestZone
} from "./impl/PostFullfillmentStatefulTestZone.sol";

import {
    ConsiderationItem,
    OfferItem,
    ItemType,
    AdvancedOrder,
    CriteriaResolver,
    BasicOrderParameters,
    AdditionalRecipient,
    FulfillmentComponent
} from "../../../contracts/lib/ConsiderationStructs.sol";

import {
    OrderType,
    Side,
    BasicOrderType
} from "../../../contracts/lib/ConsiderationEnums.sol";

import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";

contract PostFulfillmentCheckTest is BaseOrderTest {
    TestZone zone = new TestZone();
    PostFulfillmentStatefulTestZone statefulZone =
        new PostFulfillmentStatefulTestZone(50);

    struct Context {
        ConsiderationInterface consideration;
        uint8 numOriginalAdditional;
        uint8 numTips;
    }
    struct EthConsideration {
        address payable recipient;
        uint256 amount;
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {
            fail();
        } catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function setUp() public override {
        super.setUp();
        conduitController.updateChannel(address(conduit), address(this), true);
        referenceConduitController.updateChannel(
            address(referenceConduit),
            address(this),
            true
        );
        vm.label(address(zone), "TestZone");
    }

    function testAscendingAmount() public {
        test(
            this.execAscendingAmount,
            Context({
                consideration: consideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
        test(
            this.execAscendingAmount,
            Context({
                consideration: referenceConsideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
    }

    function execAscendingAmount(Context memory context) public stateless {
        addErc20OfferItem(1, 101);
        addErc721ConsiderationItem(alice, 42);
        test721_1.mint(address(this), 42);

        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        configureOrderComponents(0);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: "extradata"
        });
        CriteriaResolver[] memory criteriaResolvers;
        vm.warp(50);
        context.consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testResolvedCriteria() public {
        test(
            this.execResolvedCriteria,
            Context({
                consideration: consideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
        test(
            this.execResolvedCriteria,
            Context({
                consideration: referenceConsideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
    }

    function execResolvedCriteria(Context memory context) public stateless {
        addErc20OfferItem(1, 101);
        addErc721ConsiderationItem(alice, 0);
        considerationItems[0].itemType = ItemType.ERC721_WITH_CRITERIA;
        test721_1.mint(address(this), 42);

        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        configureOrderComponents(0);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: "extradata"
        });
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](1);
        criteriaResolvers[0] = CriteriaResolver({
            orderIndex: 0,
            side: Side.CONSIDERATION,
            index: 0,
            identifier: 42,
            criteriaProof: new bytes32[](0)
        });
        vm.warp(50);
        context.consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testStateChange() public {
        test(
            this.execStateChange,
            Context({
                consideration: consideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
        test(
            this.execStateChange,
            Context({
                consideration: referenceConsideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
    }

    function execStateChange(Context memory context) public stateless {
        addErc20OfferItem(1, 101);
        addErc721ConsiderationItem(alice, 0);
        considerationItems[0].itemType = ItemType.ERC721_WITH_CRITERIA;
        test721_1.mint(address(this), 42);

        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        configureOrderComponents(0);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: "extradata"
        });
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](1);
        criteriaResolvers[0] = CriteriaResolver({
            orderIndex: 0,
            side: Side.CONSIDERATION,
            index: 0,
            identifier: 42,
            criteriaProof: new bytes32[](0)
        });
        vm.warp(50);
        context.consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertTrue(statefulZone.called());
    }

    function testBasicStateful() public {
        test(
            this.execBasicStateful,
            Context({
                consideration: consideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
        test(
            this.execBasicStateful,
            Context({
                consideration: referenceConsideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
    }

    function execBasicStateful(Context memory context) public stateless {
        addErc20OfferItem(50);
        addErc721ConsiderationItem(alice, 42);
        addErc20ConsiderationItem(bob, 1);
        addErc20ConsiderationItem(cal, 1);

        test721_1.mint(address(this), 42);

        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        configureOrderComponents(0);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        BasicOrderParameters
            memory basicOrderParameters = toBasicOrderParameters(
                baseOrderComponents,
                BasicOrderType.ERC721_TO_ERC20_FULL_RESTRICTED,
                signature
            );
        basicOrderParameters.additionalRecipients = new AdditionalRecipient[](
            2
        );
        basicOrderParameters.additionalRecipients[0] = AdditionalRecipient({
            recipient: bob,
            amount: 1
        });
        basicOrderParameters.additionalRecipients[1] = AdditionalRecipient({
            recipient: cal,
            amount: 1
        });
        basicOrderParameters.totalOriginalAdditionalRecipients = 2;
        vm.warp(50);
        context.consideration.fulfillBasicOrder({
            parameters: basicOrderParameters
        });
    }

    function testExectBasicStatefulWithConduit() public {
        test(
            this.execBasicStatefulWithConduit,
            Context({
                consideration: consideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
        test(
            this.execBasicStatefulWithConduit,
            Context({
                consideration: referenceConsideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
    }

    function execBasicStatefulWithConduit(
        Context memory context
    ) public stateless {
        addErc20OfferItem(50);
        addErc721ConsiderationItem(alice, 42);
        addErc20ConsiderationItem(bob, 1);
        addErc20ConsiderationItem(cal, 1);

        test721_1.mint(address(this), 42);

        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: true
        });
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        configureOrderComponents(0);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        BasicOrderParameters
            memory basicOrderParameters = toBasicOrderParameters(
                baseOrderComponents,
                BasicOrderType.ERC721_TO_ERC20_FULL_RESTRICTED,
                signature
            );
        basicOrderParameters.additionalRecipients = new AdditionalRecipient[](
            2
        );
        basicOrderParameters.additionalRecipients[0] = AdditionalRecipient({
            recipient: bob,
            amount: 1
        });
        basicOrderParameters.additionalRecipients[1] = AdditionalRecipient({
            recipient: cal,
            amount: 1
        });
        basicOrderParameters.totalOriginalAdditionalRecipients = 2;
        vm.warp(50);
        context.consideration.fulfillBasicOrder({
            parameters: basicOrderParameters
        });
    }

    function testBasicStateful(
        uint8 numOriginalAdditional,
        uint8 numTips
    ) public {
        test(
            this.execBasicStatefulFuzz,
            Context({
                consideration: consideration,
                numOriginalAdditional: numOriginalAdditional,
                numTips: numTips
            })
        );
        test(
            this.execBasicStatefulFuzz,
            Context({
                consideration: referenceConsideration,
                numOriginalAdditional: numOriginalAdditional,
                numTips: numTips
            })
        );
    }

    function execBasicStatefulFuzz(Context memory context) external stateless {
        // keep track of each additional recipient so we can check their balances
        address[] memory allAdditional = new address[](
            uint256(context.numOriginalAdditional) + context.numTips
        );
        // make new stateful zone with a larger amount so each additional recipient can receive
        statefulZone = new PostFulfillmentStatefulTestZone(5000);
        // clear storage array just in case
        delete additionalRecipients;

        // create core order
        addErc20OfferItem(5000);
        addErc721ConsiderationItem(alice, 42);

        // loop over original additional
        for (uint256 i = 0; i < context.numOriginalAdditional; i++) {
            // create specific labeled address
            address payable recipient = payable(
                makeAddr(string.concat("original additional ", vm.toString(i)))
            );
            // add to all additional
            allAdditional[i] = recipient;
            // add to consideration items that will be hashed with order
            addErc20ConsiderationItem(recipient, 1);
            // add to the additional recipients array included with the basic order
            additionalRecipients.push(
                AdditionalRecipient({ recipient: recipient, amount: 1 })
            );
        }
        // do the same with additional recipients
        for (uint256 i = 0; i < context.numTips; i++) {
            // create specific labeled address
            address payable recipient = payable(
                makeAddr(string.concat("additional ", vm.toString(i)))
            );
            // add to all additional
            allAdditional[i + context.numOriginalAdditional] = recipient;
            // do not add to consideration items that will be hashed with order
            // add to the additional recipients array included with the basic order
            additionalRecipients.push(
                AdditionalRecipient({ recipient: recipient, amount: 1 })
            );
        }

        // mint token to fulfiller
        test721_1.mint(address(this), 42);

        // configure order parameters
        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        // override settings parameters
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        // configure order components for signing
        configureOrderComponents(0);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        // convert to basic order parameters
        BasicOrderParameters
            memory basicOrderParameters = toBasicOrderParameters(
                baseOrderComponents,
                BasicOrderType.ERC721_TO_ERC20_FULL_RESTRICTED,
                signature
            );
        // update additional recipients
        basicOrderParameters.additionalRecipients = additionalRecipients;
        basicOrderParameters.totalOriginalAdditionalRecipients = context
            .numOriginalAdditional;
        context.consideration.fulfillBasicOrder({
            parameters: basicOrderParameters
        });

        // assertions
        assertTrue(statefulZone.called());
        for (uint256 i = 0; i < allAdditional.length; i++) {
            assertEq(
                token1.balanceOf(allAdditional[i]),
                1,
                "additional recipient has incorrect balance"
            );
        }
    }

    // function testBasicStatefulWithConduit(
    //     uint8 numOriginalAdditional,
    //     uint8 numTips
    // ) public {
    //     vm.assume(numOriginalAdditional < 0)
    //     test(
    //         this.execBasicStatefulWithConduitFuzz,
    //         Context({
    //             consideration: consideration,
    //             numOriginalAdditional: numOriginalAdditional,
    //             numTips: numTips
    //         })
    //     );
    //     test(
    //         this.execBasicStatefulWithConduitFuzz,
    //         Context({
    //             consideration: referenceConsideration,
    //             numOriginalAdditional: numOriginalAdditional,
    //             numTips: numTips
    //         })
    //     );
    // }

    // function execBasicStatefulWithConduitFuzz(
    //     Context memory context
    // ) external stateless {
    //     // keep track of each additional recipient so we can check their balances
    //     address[] memory allAdditional = new address[](
    //         uint256(context.numOriginalAdditional) + context.numTips
    //     );
    //     // make new stateful zone with a larger amount so each additional recipient can receive
    //     statefulZone = new PostFulfillmentStatefulTestZone(5000);
    //     // clear storage array just in case
    //     delete additionalRecipients;

    //     // create core order
    //     addErc20OfferItem(5000);
    //     addErc721ConsiderationItem(alice, 42);

    //     // loop over original additional
    //     for (uint256 i = 0; i < context.numOriginalAdditional; i++) {
    //         // create specific labeled address
    //         address payable recipient = payable(
    //             makeAddr(string.concat("original additional ", vm.toString(i)))
    //         );
    //         // add to all additional
    //         allAdditional[i] = recipient;
    //         // add to consideration items that will be hashed with order
    //         addErc20ConsiderationItem(recipient, 1);
    //         // add to the additional recipients array included with the basic order
    //         additionalRecipients.push(
    //             AdditionalRecipient({ recipient: recipient, amount: 1 })
    //         );
    //     }
    //     // do the same with additional recipients
    //     for (uint256 i = 0; i < context.numTips; i++) {
    //         // create specific labeled address
    //         address payable recipient = payable(
    //             makeAddr(string.concat("additional ", vm.toString(i)))
    //         );
    //         // add to all additional
    //         allAdditional[i + context.numOriginalAdditional] = recipient;
    //         // do not add to consideration items that will be hashed with order
    //         // add to the additional recipients array included with the basic order
    //         additionalRecipients.push(
    //             AdditionalRecipient({ recipient: recipient, amount: 1 })
    //         );
    //     }

    //     // mint token to fulfiller
    //     test721_1.mint(address(this), 42);

    //     // configure order parameters
    //     _configureOrderParameters({
    //         offerer: alice,
    //         zone: address(statefulZone),
    //         zoneHash: bytes32(0),
    //         salt: 0,
    //         useConduit: true
    //     });
    //     // override settings parameters
    //     baseOrderParameters.startTime = 1;
    //     baseOrderParameters.endTime = 101;
    //     baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

    //     // configure order components for signing
    //     configureOrderComponents(0);
    //     bytes32 orderHash = context.consideration.getOrderHash(
    //         baseOrderComponents
    //     );
    //     bytes memory signature = signOrder(
    //         context.consideration,
    //         alicePk,
    //         orderHash
    //     );

    //     // convert to basic order parameters
    //     BasicOrderParameters
    //         memory basicOrderParameters = toBasicOrderParameters(
    //             baseOrderComponents,
    //             BasicOrderType.ERC721_TO_ERC20_FULL_RESTRICTED,
    //             signature
    //         );
    //     // update additional recipients
    //     basicOrderParameters.additionalRecipients = additionalRecipients;
    //     basicOrderParameters.totalOriginalAdditionalRecipients = context
    //         .numOriginalAdditional;
    //     context.consideration.fulfillBasicOrder({
    //         parameters: basicOrderParameters
    //     });

    //     // assertions
    //     assertTrue(statefulZone.called());
    //     for (uint256 i = 0; i < allAdditional.length; i++) {
    //         assertEq(
    //             token1.balanceOf(allAdditional[i]),
    //             1,
    //             "additional recipient has incorrect balance"
    //         );
    //     }
    // }

    function testFulfillAvailableAdvancedAscending() public {
        test(
            this.execFulfillAvailableAdvancedAscending,
            Context({
                consideration: consideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
        // todo: fix ref impl
        // test(
        //     this.execFulfillAvailableAdvancedAscending,
        //     Context({
        //         consideration: referenceConsideration,
        //         numOriginalAdditional: 0,
        //         numTips: 0
        //     })
        // );
    }

    function execFulfillAvailableAdvancedAscending(
        Context memory context
    ) external stateless {
        addErc20OfferItem(1, 101);
        addErc721ConsiderationItem(alice, 42);
        test721_1.mint(address(this), 42);

        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
        _configureOrderParameters({
            offerer: alice,
            zone: address(statefulZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: false
        });
        baseOrderParameters.startTime = 1;
        baseOrderParameters.endTime = 101;
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        configureOrderComponents(0);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: "extradata"
        });
        CriteriaResolver[] memory criteriaResolvers;

        offerComponents.push(
            FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
        );
        offerComponentsArray.push(offerComponents);

        considerationComponents.push(
            FulfillmentComponent({ orderIndex: 0, itemIndex: 0 })
        );
        considerationComponentsArray.push(considerationComponents);
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = order;

        vm.warp(50);
        context.consideration.fulfillAvailableAdvancedOrders({
            advancedOrders: orders,
            criteriaResolvers: criteriaResolvers,
            offerFulfillments: offerComponentsArray,
            considerationFulfillments: considerationComponentsArray,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0),
            maximumFulfilled: 1
        });
        assertTrue(statefulZone.called());
    }

    function testExecMatchAdvancedOrdersWithConduit() public {
        test(
            this.execMatchAdvancedOrdersWithConduit,
            Context({
                consideration: consideration,
                numOriginalAdditional: 0,
                numTips: 0
            })
        );
    }

    function execMatchAdvancedOrdersWithConduit(
        Context memory context
    ) external stateless {
        TestTransferValidationZoneOfferer transferValidationZone = new TestTransferValidationZoneOfferer();

        addErc20OfferItem(50);
        addErc721ConsiderationItem(alice, 42);

        _configureOrderParameters({
            offerer: alice,
            zone: address(transferValidationZone),
            zoneHash: bytes32(0),
            salt: 0,
            useConduit: true
        });
        baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;

        configureOrderComponents(0);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: signature,
            extraData: "context"
        });

        AdvancedOrder memory mirror = createMirrorOrder(
            context,
            "mirroroooor",
            order,
            true
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

        context.consideration.matchAdvancedOrders({
            orders: orders,
            criteriaResolvers: criteriaResolvers,
            fulfillments: fulfillments,
            recipient: alice
        });
    }

    // function testMatchAdvancedOrders() external {
    //     test(
    //         this.execMatchAdvancedOrders,
    //         Context({
    //             consideration: consideration,
    //             numOriginalAdditional: 0,
    //             numTips: 0
    //         })
    //     );
    //     test(
    //         this.execMatchAdvancedOrders,
    //         Context({
    //             consideration: referenceConsideration,
    //             numOriginalAdditional: 0,
    //             numTips: 0
    //         })
    //     );
    // }

    // function execMatchAdvancedOrders(Context memory context) external {
    //     addErc20OfferItem(1);
    //     addErc721ConsiderationItem(payable(address(offerer)), 42);
    //     addErc721ConsiderationItem(payable(address(offerer)), 43);
    //     addErc721ConsiderationItem(payable(address(offerer)), 44);

    //     _configureOrderParameters({
    //         offerer: address(this),
    //         zone: address(0),
    //         zoneHash: bytes32(0),
    //         salt: 0,
    //         useConduit: false
    //     });
    //     baseOrderParameters.orderType = OrderType.CONTRACT;

    //     configureOrderComponents(0);

    //     AdvancedOrder memory order = AdvancedOrder({
    //         parameters: baseOrderParameters,
    //         numerator: 1,
    //         denominator: 1,
    //         signature: "",
    //         extraData: "context"
    //     });

    //     AdvancedOrder memory mirror = createMirrorContractOffererOrder(
    //         context,
    //         "mirroroooor",
    //         order
    //     );

    //     CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](0);
    //     AdvancedOrder[] memory orders = new AdvancedOrder[](2);
    //     orders[0] = order;
    //     orders[1] = mirror;

    //     //match first order offer to second order consideration
    //     createFulfillmentFromComponentsAndAddToFulfillments({
    //         _offer: FulfillmentComponent({ orderIndex: 0, itemIndex: 0 }),
    //         _consideration: FulfillmentComponent({
    //             orderIndex: 1,
    //             itemIndex: 0
    //         })
    //     });
    //     // match second order first offer to first order first consideration
    //     createFulfillmentFromComponentsAndAddToFulfillments({
    //         _offer: FulfillmentComponent({ orderIndex: 1, itemIndex: 0 }),
    //         _consideration: FulfillmentComponent({
    //             orderIndex: 0,
    //             itemIndex: 0
    //         })
    //     });
    //     // match second order second offer to first order second consideration
    //     createFulfillmentFromComponentsAndAddToFulfillments({
    //         _offer: FulfillmentComponent({ orderIndex: 1, itemIndex: 1 }),
    //         _consideration: FulfillmentComponent({
    //             orderIndex: 0,
    //             itemIndex: 1
    //         })
    //     });
    //     // match second order third offer to first order third consideration
    //     createFulfillmentFromComponentsAndAddToFulfillments({
    //         _offer: FulfillmentComponent({ orderIndex: 1, itemIndex: 2 }),
    //         _consideration: FulfillmentComponent({
    //             orderIndex: 0,
    //             itemIndex: 2
    //         })
    //     });

    //     context.consideration.matchAdvancedOrders({
    //         orders: orders,
    //         criteriaResolvers: criteriaResolvers,
    //         fulfillments: fulfillments
    //     });
    //     assertTrue(zone.called());
    // }

    function createMirrorOrder(
        Context memory context,
        string memory _offerer,
        AdvancedOrder memory advancedOrder,
        bool _useConduit
    ) internal returns (AdvancedOrder memory) {
        delete offerItems;
        delete considerationItems;

        (address _offererAddr, uint256 pkey) = makeAddrAndKey(_offerer);
        test721_1.mint(address(_offererAddr), 42);

        vm.startPrank(_offererAddr);
        test721_1.setApprovalForAll(address(conduit), true);
        test721_1.setApprovalForAll(address(referenceConduit), true);
        test721_1.setApprovalForAll(address(context.consideration), true);
        vm.stopPrank();

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
            useConduit: _useConduit
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

    function _sumConsiderationAmounts() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < considerationItems.length; i++) {
            sum += considerationItems[i].startAmount;
        }
    }

    function createMirrorContractOffererOrder(
        Context memory context,
        string memory _offerer,
        AdvancedOrder memory advancedOrder,
        bool _useConduit
    ) internal returns (AdvancedOrder memory) {
        delete offerItems;
        delete considerationItems;

        (address _offererAddr, uint256 pkey) = makeAddrAndKey(_offerer);
        test721_1.mint(address(_offererAddr), 42);
        test721_1.mint(address(_offererAddr), 43);
        test721_1.mint(address(_offererAddr), 44);

        vm.startPrank(_offererAddr);
        test721_1.setApprovalForAll(address(conduit), true);
        test721_1.setApprovalForAll(address(referenceConduit), true);
        test721_1.setApprovalForAll(address(context.consideration), true);
        vm.stopPrank();

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
            useConduit: _useConduit
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
