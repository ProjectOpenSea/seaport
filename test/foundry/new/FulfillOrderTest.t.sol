// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./BaseOrderTest.sol";
import "seaport-sol/SeaportSol.sol";

contract FulfillOrderTest is BaseOrderTest {
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using OrderLib for Order;
    using OrderComponentsLib for OrderComponents;
    using OrderParametersLib for OrderParameters;

    struct FuzzParams {
        uint120 startAmount;
        uint120 endAmount;
        uint256 amount;
        uint16 warpAmount;
    }

    struct ContextOverride {
        SeaportInterface seaport;
        bytes32 conduitKey;
        FuzzParams fuzzParams;
    }

    function setUp() public virtual override {
        super.setUp();
    }

    function test(
        function(ContextOverride memory) external fn,
        ContextOverride memory context
    ) internal {
        try fn(context) {
            fail("Differential tests should revert with failure status");
        } catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    /**
     * @dev fulfillOrder should fill valid orders with ascending and descending
     *      offer item amounts
     *
     *      Setup:  Create a FULL_OPEN order with an ERC20 offer item and a
     *              fuzzed ascending/descending amount. Consider 1000 wei of
     *              native ETH.
     *
     *      Exec:   Warp forward a fuzzed warpAmount. Fill the order with
     *              fulfillOrder.
     *
     *      Expect: Should succeed and emit a Transfer event with the expected
     *              offer amount.
     */
    function testFulfillAscendingDescendingOffer(
        FuzzParams memory fuzzParams
    ) public {
        fuzzParams.startAmount = uint120(
            bound(fuzzParams.startAmount, 1, type(uint120).max)
        );
        fuzzParams.endAmount = uint120(
            bound(fuzzParams.endAmount, 1, type(uint120).max)
        );
        fuzzParams.warpAmount = uint16(bound(fuzzParams.warpAmount, 0, 1000));

        test(
            this.execFulfillAscendingDescendingOffer,
            ContextOverride({
                seaport: seaport,
                conduitKey: bytes32(0),
                fuzzParams: fuzzParams
            })
        );
        test(
            this.execFulfillAscendingDescendingOffer,
            ContextOverride({
                seaport: referenceSeaport,
                conduitKey: bytes32(0),
                fuzzParams: fuzzParams
            })
        );
    }

    function setUpFulfillAscendingDescendingOffer(
        ContextOverride memory context
    ) internal view returns (Order memory order) {
        // Create single-item offer and consideration arrays.
        OfferItem[] memory offers = new OfferItem[](1);
        ConsiderationItem[] memory considerations = new ConsiderationItem[](1);

        // New scope to set up order/consideration
        {
            // Offer an ERC20 with fuzzed startAmount and EndAmount.
            // offerer1 will already have a sufficient ERC20 balance.
            offers[0] = OfferItemLib
                .empty()
                .withItemType(ItemType.ERC20)
                .withToken(address(erc20s[0]))
                .withIdentifierOrCriteria(0)
                .withStartAmount(context.fuzzParams.startAmount)
                .withEndAmount(context.fuzzParams.endAmount);

            // Consider 1000 wei of native ETH
            considerations[0] = ConsiderationItemLib
                .empty()
                .withRecipient(offerer1.addr)
                .withItemType(ItemType.NATIVE)
                .withStartAmount(1000)
                .withEndAmount(1000);
        }

        // Construct the order
        OrderComponents memory orderComponents = OrderComponentsLib
            .empty()
            .withOfferer(offerer1.addr)
            .withOffer(offers)
            .withConsideration(considerations)
            .withOrderType(OrderType.FULL_OPEN)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1000)
            .withConduitKey(context.conduitKey)
            .withCounter(context.seaport.getCounter(offerer1.addr));

        return
            OrderLib
                .empty()
                .withParameters(orderComponents.toOrderParameters())
                .withSignature(
                    signOrder(
                        context.seaport,
                        offerer1.key,
                        context.seaport.getOrderHash(orderComponents)
                    )
                );
    }

    function execFulfillAscendingDescendingOffer(
        ContextOverride memory context
    ) external stateless {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 1000;

        // Warp forward by fuzzed amount warpAmount
        vm.warp(startTime + context.fuzzParams.warpAmount);

        // Calculate expected offer amount
        uint256 expectedAmount = _locateCurrentAmount(
            context.fuzzParams.startAmount,
            context.fuzzParams.endAmount,
            startTime,
            endTime,
            false // don't round up offers
        );

        vm.expectEmit(true, true, true, false, address(erc20s[0]));
        emit Transfer(offerer1.addr, address(this), expectedAmount);

        context.seaport.fulfillOrder{ value: 1000 }(
            setUpFulfillAscendingDescendingOffer(context),
            context.conduitKey
        );
    }

    /**
     * @dev fulfillOrder should fill valid orders with ascending and descending
     *      consideration item amounts
     *
     *      Setup:  Create a FULL_OPEN order with an ERC1155 offer item.
     *              Consider a fuzzed ascending/descending amount of ERC20.
     *
     *      Exec:   Warp forward a fuzzed warpAmount. Fill the order with
     *              fulfillOrder.
     *
     *      Expect: Should succeed and emit a Transfer event with the expected
     *              consideration amount.
     */
    function testFulfillAscendingDescendingConsideration(
        FuzzParams memory fuzzParams
    ) public {
        fuzzParams.startAmount = uint120(
            bound(fuzzParams.startAmount, 1, type(uint120).max)
        );
        fuzzParams.endAmount = uint120(
            bound(fuzzParams.endAmount, 1, type(uint120).max)
        );
        fuzzParams.warpAmount = uint16(bound(fuzzParams.warpAmount, 0, 1000));
        fuzzParams.amount = bound(fuzzParams.amount, 1, type(uint256).max);

        test(
            this.execFulfillAscendingDescendingConsideration,
            ContextOverride({
                seaport: seaport,
                conduitKey: bytes32(0),
                fuzzParams: fuzzParams
            })
        );
        test(
            this.execFulfillAscendingDescendingConsideration,
            ContextOverride({
                seaport: referenceSeaport,
                conduitKey: bytes32(0),
                fuzzParams: fuzzParams
            })
        );
    }

    function setUpFulfillAscendingDescendingConsideration(
        ContextOverride memory context
    ) internal returns (Order memory order) {
        // Create single-item offer and consideration arrays.
        OfferItem[] memory offers = new OfferItem[](1);
        ConsiderationItem[] memory considerations = new ConsiderationItem[](1);

        // New scope to setup order/consideration
        {
            // Mint sufficient ERC1155 balance to offerer1 for this order.
            erc1155s[0].mint(offerer1.addr, 1, context.fuzzParams.amount);

            // Offer an ERC1155 with fuzzed amount
            offers[0] = OfferItemLib
                .empty()
                .withItemType(ItemType.ERC1155)
                .withToken(address(erc1155s[0]))
                .withIdentifierOrCriteria(1)
                .withStartAmount(context.fuzzParams.amount)
                .withEndAmount(context.fuzzParams.amount);

            // Consider ERC20 with fuzzed startAmount/endAmount
            considerations[0] = ConsiderationItemLib
                .empty()
                .withRecipient(offerer1.addr)
                .withItemType(ItemType.ERC20)
                .withToken(address(erc20s[0]))
                .withStartAmount(context.fuzzParams.startAmount)
                .withEndAmount(context.fuzzParams.endAmount);
        }

        // Construct the order
        OrderComponents memory orderComponents = OrderComponentsLib
            .empty()
            .withOfferer(offerer1.addr)
            .withOffer(offers)
            .withConsideration(considerations)
            .withOrderType(OrderType.FULL_OPEN)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 1000)
            .withConduitKey(context.conduitKey)
            .withCounter(context.seaport.getCounter(offerer1.addr));

        return
            OrderLib
                .empty()
                .withParameters(orderComponents.toOrderParameters())
                .withSignature(
                    signOrder(
                        context.seaport,
                        offerer1.key,
                        context.seaport.getOrderHash(orderComponents)
                    )
                );
    }

    function execFulfillAscendingDescendingConsideration(
        ContextOverride memory context
    ) external stateless {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 1000;

        // Warp forward by fuzzed amount warpAmount
        vm.warp(startTime + context.fuzzParams.warpAmount);

        // Calculate expected consideration amount
        uint256 expectedAmount = _locateCurrentAmount(
            context.fuzzParams.startAmount,
            context.fuzzParams.endAmount,
            startTime,
            endTime,
            true // round up considerations
        );

        vm.expectEmit(true, true, true, false, address(erc20s[0]));
        emit Transfer(address(this), offerer1.addr, expectedAmount);

        context.seaport.fulfillOrder(
            setUpFulfillAscendingDescendingConsideration(context),
            context.conduitKey
        );
    }
}
