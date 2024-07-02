// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

import {
    ConsiderationItemLib,
    OfferItemLib,
    OrderComponentsLib,
    OrderLib
} from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    OfferItem,
    OrderComponents
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType, OrderType } from "seaport-sol/src/SeaportEnums.sol";

import { BaseOrderTest } from "./BaseOrderTest.sol";

import { FuzzHelpers } from "./helpers/FuzzHelpers.sol";

import { FuzzInscribers } from "./helpers/FuzzInscribers.sol";

import {
    FuzzTestContext,
    FuzzTestContextLib
} from "./helpers/FuzzTestContextLib.sol";

contract FuzzHelpersTest is BaseOrderTest {
    using ConsiderationItemLib for ConsiderationItem;
    using OfferItemLib for OfferItem;
    using OrderComponentsLib for OrderComponents;
    using FuzzHelpers for AdvancedOrder;
    using FuzzInscribers for AdvancedOrder;

    struct RawStorageValues {
        bytes32 rawOrganicOrderStatusBeforeCalls;
        bytes32 rawOrganicOrderStatusAfterValidation;
        bytes32 rawOrganicOrderStatusAfterPartialFulfillment;
        bytes32 rawOrganicOrderStatusAfterFullFulfillment;
        bytes32 rawOrganicOrderStatusAfterCancellation;
        bytes32 rawSyntheticOrderStatusBeforeCalls;
        bytes32 rawSyntheticOrderStatusAfterValidation;
        bytes32 rawSyntheticOrderStatusAfterPartialFulfillment;
        bytes32 rawSyntheticOrderStatusAfterFullFulfillment;
        bytes32 rawSyntheticOrderStatusAfterCancellation;
    }

    function test_inscribeOrderStatus() public {
        RawStorageValues memory rawStorageValues = RawStorageValues({
            rawOrganicOrderStatusBeforeCalls: 0,
            rawOrganicOrderStatusAfterValidation: 0,
            rawOrganicOrderStatusAfterPartialFulfillment: 0,
            rawOrganicOrderStatusAfterFullFulfillment: 0,
            rawOrganicOrderStatusAfterCancellation: 0,
            rawSyntheticOrderStatusBeforeCalls: 0,
            rawSyntheticOrderStatusAfterValidation: 0,
            rawSyntheticOrderStatusAfterPartialFulfillment: 0,
            rawSyntheticOrderStatusAfterFullFulfillment: 0,
            rawSyntheticOrderStatusAfterCancellation: 0
        });

        (
            bytes32 orderHash,
            FuzzTestContext memory context,
            AdvancedOrder memory advancedOrder,
            OrderComponents[] memory orderComponentsArray
        ) = _setUpOrderAndContext();

        _setRawOrganicStorageValues(
            orderHash,
            context,
            advancedOrder,
            orderComponentsArray,
            rawStorageValues
        );

        // Wipe the slot.
        advancedOrder.inscribeOrderStatusDenominator(0, context.seaport);
        advancedOrder.inscribeOrderStatusNumerator(0, context.seaport);
        advancedOrder.inscribeOrderStatusCancelled(false, context.seaport);
        advancedOrder.inscribeOrderStatusValidated(false, context.seaport);

        // Populate the raw synthetic storage values.  These are the storage
        // values produced by using the inscription helpers.
        _setRawSyntheticStorageValues(
            orderHash,
            context,
            advancedOrder,
            rawStorageValues
        );

        _compareOrganicAndSyntheticRawStorageValues(rawStorageValues);
    }

    function test_inscribeContractOffererNonce() public {
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](0);
        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: advancedOrders,
            seaport: seaport,
            caller: address(this)
        });

        bytes32 contractNonceStorageSlot = _getStorageSlotForContractNonce(
            address(this),
            context
        );
        bytes32 rawContractOffererNonceValue = vm.load(
            address(context.seaport),
            contractNonceStorageSlot
        );

        assertEq(rawContractOffererNonceValue, bytes32(0));

        FuzzInscribers.inscribeContractOffererNonce(
            address(this),
            1,
            context.seaport
        );

        bytes32 newContractOffererNonceValue = vm.load(
            address(context.seaport),
            contractNonceStorageSlot
        );

        assertEq(newContractOffererNonceValue, bytes32(uint256(1)));
    }

    function test_inscribeCounter() public {
        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: new AdvancedOrder[](0),
            seaport: seaport,
            caller: address(this)
        });

        bytes32 counterStorageSlot = _getStorageSlotForCounter(
            address(this),
            context
        );
        bytes32 rawCounterValue = vm.load(
            address(context.seaport),
            counterStorageSlot
        );

        assertEq(rawCounterValue, bytes32(0));

        FuzzInscribers.inscribeCounter(address(this), 1, context.seaport);

        bytes32 newCounterValue = vm.load(
            address(context.seaport),
            counterStorageSlot
        );

        assertEq(newCounterValue, bytes32(uint256(1)));
    }

    function _setUpOrderAndContext()
        internal
        returns (
            bytes32 _orderHash,
            FuzzTestContext memory _context,
            AdvancedOrder memory _advancedOrder,
            OrderComponents[] memory _orderComponentsArray
        )
    {
        // Set up the order.
        OfferItem[] memory offerItems = new OfferItem[](1);
        OfferItem memory offerItem = OfferItemLib
            .empty()
            .withItemType(ItemType.ERC20)
            .withToken(address(erc20s[0]))
            .withAmount(10e34);

        offerItems[0] = offerItem;

        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            1
        );
        ConsiderationItem memory considerationItem = ConsiderationItemLib
            .empty()
            .withItemType(ItemType.NATIVE)
            .withAmount(10e34);

        considerationItems[0] = considerationItem;

        OrderComponents memory orderComponents = OrderComponentsLib
            .empty()
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 100)
            .withOrderType(OrderType.PARTIAL_OPEN)
            .withOfferer(offerer1.addr)
            .withOffer(offerItems)
            .withConsideration(considerationItems);

        // Set this up to use later for canceling.
        OrderComponents[] memory orderComponentsArray = new OrderComponents[](
            1
        );

        orderComponentsArray[0] = orderComponents;

        bytes memory signature = signOrder(
            getSeaport(),
            offerer1.key,
            getSeaport().getOrderHash(orderComponents)
        );

        AdvancedOrder memory advancedOrder = AdvancedOrder({
            parameters: orderComponents.toOrderParameters(),
            signature: signature,
            numerator: 10e34 / 2,
            denominator: 10e34,
            extraData: bytes("")
        });

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](1);
        advancedOrders[0] = advancedOrder;

        FuzzTestContext memory context = FuzzTestContextLib.from({
            orders: advancedOrders,
            seaport: seaport,
            caller: address(this)
        });

        bytes32 orderHash = context.seaport.getOrderHash(orderComponents);

        return (orderHash, context, advancedOrder, orderComponentsArray);
    }

    function _setRawOrganicStorageValues(
        bytes32 orderHash,
        FuzzTestContext memory context,
        AdvancedOrder memory advancedOrder,
        OrderComponents[] memory orderComponentsArray,
        RawStorageValues memory rawStorageValues
    ) internal {
        // Populate the raw organic storage values.  These are the storage
        // values produced by actualy calling Seaport.
        bytes32 orderHashStorageSlot = _getStorageSlotForOrderHash(
            orderHash,
            context
        );
        rawStorageValues.rawOrganicOrderStatusBeforeCalls = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        advancedOrder.validateTipNeutralizedOrder(context);

        rawStorageValues.rawOrganicOrderStatusAfterValidation = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        context.seaport.fulfillAdvancedOrder{ value: 10e34 / 2 }({
            advancedOrder: advancedOrder,
            criteriaResolvers: new CriteriaResolver[](0),
            fulfillerConduitKey: bytes32(0),
            recipient: address(this)
        });

        rawStorageValues.rawOrganicOrderStatusAfterPartialFulfillment = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        context.seaport.fulfillAdvancedOrder{ value: 10e34 / 2 }({
            advancedOrder: advancedOrder,
            criteriaResolvers: new CriteriaResolver[](0),
            fulfillerConduitKey: bytes32(0),
            recipient: address(this)
        });

        rawStorageValues.rawOrganicOrderStatusAfterFullFulfillment = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        vm.prank(address(offerer1.addr));
        context.seaport.cancel(orderComponentsArray);

        rawStorageValues.rawOrganicOrderStatusAfterCancellation = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );
    }

    function _setRawSyntheticStorageValues(
        bytes32 orderHash,
        FuzzTestContext memory context,
        AdvancedOrder memory advancedOrder,
        RawStorageValues memory rawStorageValues
    ) internal {
        // Populate the raw organic storage values.  These are the storage
        // values produced by actualy calling Seaport.
        bytes32 orderHashStorageSlot = _getStorageSlotForOrderHash(
            orderHash,
            context
        );
        rawStorageValues.rawSyntheticOrderStatusBeforeCalls = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        advancedOrder.inscribeOrderStatusValidated(true, context.seaport);

        rawStorageValues.rawSyntheticOrderStatusAfterValidation = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        advancedOrder.inscribeOrderStatusNumerator(10e34 / 2, context.seaport);
        advancedOrder.inscribeOrderStatusDenominator(10e34, context.seaport);

        rawStorageValues.rawSyntheticOrderStatusAfterPartialFulfillment = vm
            .load(address(context.seaport), orderHashStorageSlot);

        advancedOrder.inscribeOrderStatusNumerator(10e34, context.seaport);
        advancedOrder.inscribeOrderStatusDenominator(10e34, context.seaport);

        rawStorageValues.rawSyntheticOrderStatusAfterFullFulfillment = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        advancedOrder.inscribeOrderStatusCancelled(true, context.seaport);

        rawStorageValues.rawSyntheticOrderStatusAfterCancellation = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );
    }

    function _compareOrganicAndSyntheticRawStorageValues(
        RawStorageValues memory rawStorageValues
    ) internal {
        assertEq(rawStorageValues.rawOrganicOrderStatusBeforeCalls, 0);

        assertEq(
            rawStorageValues.rawOrganicOrderStatusBeforeCalls,
            rawStorageValues.rawSyntheticOrderStatusBeforeCalls
        );

        assertEq(
            rawStorageValues.rawOrganicOrderStatusAfterValidation,
            rawStorageValues.rawSyntheticOrderStatusAfterValidation
        );

        assertEq(
            rawStorageValues.rawOrganicOrderStatusAfterPartialFulfillment,
            rawStorageValues.rawSyntheticOrderStatusAfterPartialFulfillment
        );

        assertEq(
            rawStorageValues.rawOrganicOrderStatusAfterFullFulfillment,
            rawStorageValues.rawSyntheticOrderStatusAfterFullFulfillment
        );

        assertEq(
            rawStorageValues.rawOrganicOrderStatusAfterCancellation,
            rawStorageValues.rawSyntheticOrderStatusAfterCancellation
        );
    }

    function _getStorageSlotForOrderHash(
        bytes32 orderHash,
        FuzzTestContext memory context
    ) internal returns (bytes32) {
        vm.record();
        context.seaport.getOrderStatus(orderHash);
        (bytes32[] memory readAccesses, ) = vm.accesses(
            address(context.seaport)
        );

        uint256 expectedReadAccessCount = 4;

        string memory profile = vm.envOr(
            "FOUNDRY_PROFILE",
            string("optimized")
        );

        if (
            keccak256(abi.encodePacked(profile)) ==
            keccak256(abi.encodePacked("optimized")) ||
            keccak256(abi.encodePacked(profile)) ==
            keccak256(abi.encodePacked("test")) ||
            keccak256(abi.encodePacked(profile)) ==
            keccak256(abi.encodePacked("lite")) ||
            keccak256(abi.encodePacked(profile)) ==
            keccak256(abi.encodePacked("reference"))
        ) {
            expectedReadAccessCount = 1;
        }

        require(
            readAccesses.length == expectedReadAccessCount,
            "Expected a different number of read accesses."
        );

        return readAccesses[0];
    }

    function _getStorageSlotForContractNonce(
        address contractOfferer,
        FuzzTestContext memory context
    ) private returns (bytes32) {
        vm.record();
        context.seaport.getContractOffererNonce(contractOfferer);
        (bytes32[] memory readAccesses, ) = vm.accesses(
            address(context.seaport)
        );

        require(readAccesses.length == 1, "Expected 1 read access.");

        return readAccesses[0];
    }

    function _getStorageSlotForCounter(
        address offerer,
        FuzzTestContext memory context
    ) private returns (bytes32) {
        vm.record();
        context.seaport.getCounter(offerer);
        (bytes32[] memory readAccesses, ) = vm.accesses(
            address(context.seaport)
        );

        require(readAccesses.length == 1, "Expected 1 read access.");

        return readAccesses[0];
    }
}
