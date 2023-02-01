// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {
    OrderType,
    ItemType
} from "../../contracts/lib/ConsiderationEnums.sol";

import {
    ConsiderationInterface
} from "../../contracts/interfaces/ConsiderationInterface.sol";

import {
    Order,
    OfferItem,
    OrderParameters,
    ConsiderationItem,
    OrderComponents,
    FulfillmentComponent
} from "../../contracts/lib/ConsiderationStructs.sol";

import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

import { stdError } from "forge-std/Test.sol";

import { ArithmeticUtil } from "./utils/ArithmeticUtil.sol";

contract FulfillAvailableOrder is BaseOrderTest {
    using ArithmeticUtil for uint256;
    using ArithmeticUtil for uint240;
    using ArithmeticUtil for uint128;
    using ArithmeticUtil for uint120;

    FuzzInputs empty;
    struct FuzzInputs {
        address zone;
        uint256 id;
        bytes32 zoneHash;
        uint248 salt;
        uint128[3] paymentAmts;
        bool useConduit;
        uint240 amount;
    }

    struct Context {
        ConsiderationInterface consideration;
        FuzzInputs args;
        ItemType itemType;
    }

    modifier validateInputs(FuzzInputs memory inputs) {
        vm.assume(
            inputs.paymentAmts[0] > 0 &&
                inputs.paymentAmts[1] > 0 &&
                inputs.paymentAmts[2] > 0
        );
        vm.assume(
            inputs.paymentAmts[0].add(inputs.paymentAmts[1]).add(
                inputs.paymentAmts[2]
            ) <= 2 ** 128 - 1
        );
        _;
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testNoNativeOffersFulfillAvailable(
        uint8[8] memory itemTypes
    ) public {
        uint256 tokenId;
        for (uint256 i; i < 8; i++) {
            ItemType itemType = ItemType(itemTypes[i] % 4);
            if (itemType == ItemType.NATIVE) {
                addEthOfferItem(1);
            } else if (itemType == ItemType.ERC20) {
                addErc20OfferItem(1);
            } else if (itemType == ItemType.ERC1155) {
                test1155_1.mint(alice, tokenId, 1);
                addErc1155OfferItem(tokenId, 1);
            } else {
                test721_1.mint(alice, tokenId);
                addErc721OfferItem(tokenId);
            }
            tokenId++;
            offerComponents.push(FulfillmentComponent(1, i));
        }
        addEthOfferItem(1);

        addEthConsiderationItem(alice, 1);
        considerationComponents.push(FulfillmentComponent(1, 0));

        test(
            this.noNativeOfferItemsFulfillAvailable,
            Context(consideration, empty, ItemType(0))
        );
        test(
            this.noNativeOfferItemsFulfillAvailable,
            Context(referenceConsideration, empty, ItemType(0))
        );
    }

    function noNativeOfferItemsFulfillAvailable(
        Context memory context
    ) external stateless {
        configureOrderParameters(alice);
        uint256 counter = context.consideration.getCounter(alice);
        configureOrderComponents(counter);
        bytes32 orderHash = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            orderHash
        );

        Order[] memory orders = new Order[](2);
        orders[1] = Order(baseOrderParameters, signature);
        offerComponentsArray.push(offerComponents);
        considerationComponentsArray.push(considerationComponents);

        delete offerItems;
        delete considerationItems;
        delete offerComponents;
        delete considerationComponents;

        token1.mint(alice, 100);
        addErc20OfferItem(100);
        addEthConsiderationItem(alice, 1);
        configureOrderParameters(alice);
        counter = context.consideration.getCounter(alice);
        configureOrderComponents(counter);
        bytes32 orderHash2 = context.consideration.getOrderHash(
            baseOrderComponents
        );
        bytes memory signature2 = signOrder(
            context.consideration,
            alicePk,
            orderHash2
        );
        offerComponents.push(FulfillmentComponent(0, 0));
        considerationComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(offerComponents);
        considerationComponentsArray.push(considerationComponents);

        orders[0] = Order(baseOrderParameters, signature2);

        vm.expectRevert(abi.encodeWithSignature("InvalidNativeOfferItem()"));
        context.consideration.fulfillAvailableOrders{ value: 2 }(
            orders,
            offerComponentsArray,
            considerationComponentsArray,
            bytes32(0),
            2
        );
    }

    function testFulfillAvailableOrdersOverflowOfferSide() public {
        // skip eth
        for (uint256 i = 1; i < 4; ++i) {
            // skip 721s
            if (i == 2) {
                continue;
            }
            test(
                this.fulfillAvailableOrdersOverflowOfferSide,
                Context(consideration, empty, ItemType(i))
            );
            test(
                this.fulfillAvailableOrdersOverflowOfferSide,
                Context(referenceConsideration, empty, ItemType(i))
            );
        }
    }

    function testFulfillAvailableOrdersOverflowConsiderationSide() public {
        for (uint256 i; i < 4; ++i) {
            // skip 721s
            if (i == 2) {
                continue;
            }
            test(
                this.fulfillAvailableOrdersOverflowConsiderationSide,
                Context(consideration, empty, ItemType(i))
            );
            test(
                this.fulfillAvailableOrdersOverflowConsiderationSide,
                Context(referenceConsideration, empty, ItemType(i))
            );
        }
    }

    function testSingleOrderViaFulfillAvailableOrdersEthToSingleErc721(
        FuzzInputs memory args
    ) public validateInputs(args) onlyPayable(args.zone) {
        test(
            this.singleOrderViaFulfillAvailableOrdersEthToSingleErc721,
            Context(referenceConsideration, args, ItemType(0))
        );
        test(
            this.singleOrderViaFulfillAvailableOrdersEthToSingleErc721,
            Context(consideration, args, ItemType(0))
        );
    }

    function testFulfillAndAggregateTwoOrdersViaFulfillAvailableOrdersEthToErc1155(
        FuzzInputs memory args
    ) public onlyPayable(args.zone) {
        vm.assume(args.amount > 0);

        args.paymentAmts[0] = uint120(args.paymentAmts[0].mul(2));
        args.paymentAmts[1] = uint120(args.paymentAmts[1].mul(2));
        args.paymentAmts[2] = uint120(args.paymentAmts[2].mul(2));
        vm.assume(
            args.paymentAmts[0] > 0 &&
                args.paymentAmts[1] > 0 &&
                args.paymentAmts[2] > 0
        );
        test(
            this
                .fulfillAndAggregateTwoOrdersViaFulfillAvailableOrdersEthToErc1155,
            Context(referenceConsideration, args, ItemType(0))
        );
        test(
            this
                .fulfillAndAggregateTwoOrdersViaFulfillAvailableOrdersEthToErc1155,
            Context(consideration, args, ItemType(0))
        );
    }

    function fulfillAvailableOrdersOverflowOfferSide(
        Context memory context
    ) external stateless {
        // mint consideration nfts to the test contract
        test721_1.mint(address(this), 1);
        test721_1.mint(address(this), 2);

        addOfferItem(context.itemType, 1, 100);
        addConsiderationItem(alice, ItemType.ERC721, 1, 1);

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        OrderComponents memory firstOrderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getCounter(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(firstOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        // try to overflow the aggregated amount of tokens sent to alice
        addOfferItem(context.itemType, 1, MAX_INT);
        addConsiderationItem(bob, ItemType.ERC721, 2, 1);

        OrderParameters memory secondOrderParameters = OrderParameters(
            address(alice),
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        OrderComponents memory secondOrderComponents = getOrderComponents(
            secondOrderParameters,
            context.consideration.getCounter(alice)
        );
        bytes memory secondSignature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(secondOrderComponents)
        );

        Order[] memory orders = new Order[](2);
        orders[0] = Order(orderParameters, signature);
        orders[1] = Order(secondOrderParameters, secondSignature);

        // aggregate offers together
        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponents.push(FulfillmentComponent(1, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;

        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;
        considerationComponents.push(FulfillmentComponent(1, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        vm.expectRevert(stdError.arithmeticError);
        context.consideration.fulfillAvailableOrders(
            orders,
            offerComponentsArray,
            considerationComponentsArray,
            bytes32(0),
            100
        );
    }

    function fulfillAvailableOrdersOverflowConsiderationSide(
        Context memory context
    ) external stateless {
        test721_1.mint(alice, 1);
        addOfferItem(ItemType.ERC721, 1, 1);
        addConsiderationItem(alice, context.itemType, 1, 100);

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        OrderComponents memory firstOrderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getCounter(alice)
        );
        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(firstOrderComponents)
        );

        delete offerItems;
        delete considerationItems;

        test721_1.mint(bob, 2);
        addOfferItem(ItemType.ERC721, 2, 1);
        // try to overflow the aggregated amount of tokens sent to alice
        addConsiderationItem(alice, context.itemType, 1, MAX_INT);

        OrderParameters memory secondOrderParameters = OrderParameters(
            address(bob),
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            considerationItems.length
        );

        OrderComponents memory secondOrderComponents = getOrderComponents(
            secondOrderParameters,
            context.consideration.getCounter(bob)
        );
        bytes memory secondSignature = signOrder(
            context.consideration,
            bobPk,
            context.consideration.getOrderHash(secondOrderComponents)
        );

        Order[] memory orders = new Order[](2);
        orders[0] = Order(orderParameters, signature);
        orders[1] = Order(secondOrderParameters, secondSignature);

        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;
        offerComponents.push(FulfillmentComponent(1, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;

        // aggregate considerations together
        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponents.push(FulfillmentComponent(1, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;
        vm.expectRevert(stdError.arithmeticError);
        context.consideration.fulfillAvailableOrders{ value: 99 }(
            orders,
            offerComponentsArray,
            considerationComponentsArray,
            bytes32(0),
            100
        );
    }

    function singleOrderViaFulfillAvailableOrdersEthToSingleErc721(
        Context memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test721_1.mint(alice, context.args.id);
        offerItems.push(
            OfferItem(
                ItemType.ERC721,
                address(test721_1),
                context.args.id,
                1,
                1
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[0]),
                uint256(context.args.paymentAmts[0]),
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[1]),
                uint256(context.args.paymentAmts[1]),
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[2]),
                uint256(context.args.paymentAmts[2]),
                payable(cal)
            )
        );

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getCounter(alice)
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        Order[] memory orders = new Order[](1);
        orders[0] = Order(orderParameters, signature);

        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;

        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        considerationComponents.push(FulfillmentComponent(0, 1));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        considerationComponents.push(FulfillmentComponent(0, 2));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        assertTrue(considerationComponentsArray.length == 3);

        context.consideration.fulfillAvailableOrders{
            value: context.args.paymentAmts[0] +
                context.args.paymentAmts[1] +
                context.args.paymentAmts[2]
        }(
            orders,
            offerComponentsArray,
            considerationComponentsArray,
            conduitKey,
            100
        );
    }

    function fulfillAndAggregateTwoOrdersViaFulfillAvailableOrdersEthToErc1155(
        Context memory context
    ) external stateless {
        bytes32 conduitKey = context.args.useConduit
            ? conduitKeyOne
            : bytes32(0);

        test1155_1.mint(alice, context.args.id, context.args.amount.mul(2));

        offerItems.push(
            OfferItem(
                ItemType.ERC1155,
                address(test1155_1),
                context.args.id,
                context.args.amount,
                context.args.amount
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[0]) / 2,
                uint256(context.args.paymentAmts[0]) / 2,
                payable(alice)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[1]) / 2,
                uint256(context.args.paymentAmts[1]) / 2,
                payable(context.args.zone)
            )
        );
        considerationItems.push(
            ConsiderationItem(
                ItemType.NATIVE,
                address(0),
                0,
                uint256(context.args.paymentAmts[2]) / 2,
                uint256(context.args.paymentAmts[2]) / 2,
                payable(cal)
            )
        );

        OrderParameters memory orderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            context.args.salt,
            conduitKey,
            considerationItems.length
        );
        OrderComponents memory orderComponents = getOrderComponents(
            orderParameters,
            context.consideration.getCounter(alice)
        );

        bytes memory signature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(orderComponents)
        );

        OrderParameters memory secondOrderParameters = OrderParameters(
            address(alice),
            context.args.zone,
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            context.args.zoneHash,
            uint256(context.args.salt) + 1,
            conduitKey,
            considerationItems.length
        );

        OrderComponents memory secondOrderComponents = getOrderComponents(
            secondOrderParameters,
            context.consideration.getCounter(alice)
        );

        bytes memory secondOrderSignature = signOrder(
            context.consideration,
            alicePk,
            context.consideration.getOrderHash(secondOrderComponents)
        );

        Order[] memory orders = new Order[](2);
        orders[0] = Order(orderParameters, signature);
        orders[1] = Order(secondOrderParameters, secondOrderSignature);

        offerComponents.push(FulfillmentComponent(0, 0));
        offerComponents.push(FulfillmentComponent(1, 0));
        offerComponentsArray.push(offerComponents);
        delete offerComponents;

        considerationComponents.push(FulfillmentComponent(0, 0));
        considerationComponents.push(FulfillmentComponent(1, 0));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        considerationComponents.push(FulfillmentComponent(0, 1));
        considerationComponents.push(FulfillmentComponent(1, 1));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;

        considerationComponents.push(FulfillmentComponent(0, 2));
        considerationComponents.push(FulfillmentComponent(1, 2));
        considerationComponentsArray.push(considerationComponents);
        delete considerationComponents;
        emit log_string("about to add");

        context.consideration.fulfillAvailableOrders{
            value: context.args.paymentAmts[0] +
                context.args.paymentAmts[1] +
                context.args.paymentAmts[2]
        }(
            orders,
            offerComponentsArray,
            considerationComponentsArray,
            conduitKey,
            100
        );
    }
}
