// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

import "seaport-sol/SeaportSol.sol";

import { FuzzHelpers } from "./FuzzHelpers.sol";

import { FuzzTestContext } from "./FuzzTestContextLib.sol";

/**
 * @notice Helpers for inscribing order status, contract nonce, and counter.
 */
library FuzzInscribers {
    using FuzzHelpers for AdvancedOrder;

    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 constant wipeDenominatorMask =
        0x000000000000000000000000000000ffffffffffffffffffffffffffffffffff;

    uint256 constant wipeNumeratorMask =
        0xffffffffffffffffffffffffffffff000000000000000000000000000000ffff;

    /**
     * @dev Inscribe an entire order status struct.
     *
     * @param order The order to inscribe.
     * @param orderStatus The order status to inscribe.
     * @param context The fuzz test context.
     *
     */
    function inscribeOrderStatusComprehensive(
        AdvancedOrder memory order,
        OrderStatus memory orderStatus,
        FuzzTestContext memory context
    ) internal {
        inscribeOrderStatusValidated(order, orderStatus.isValidated, context);
        inscribeOrderStatusCanceled(order, orderStatus.isCancelled, context);
        inscribeOrderStatusNumerator(order, orderStatus.numerator, context);
        inscribeOrderStatusDenominator(order, orderStatus.denominator, context);
    }

    /**
     * @dev Inscribe an entire order status struct, except for the numerator.
     *
     * @param order The order to inscribe.
     * @param numerator The numerator to inscribe.
     * @param denominator The denominator to inscribe.
     * @param context The fuzz test context.
     *
     */
    function inscribeOrderStatusNumeratorAndDenominator(
        AdvancedOrder memory order,
        uint120 numerator,
        uint120 denominator,
        FuzzTestContext memory context
    ) internal {
        inscribeOrderStatusNumerator(order, numerator, context);
        inscribeOrderStatusDenominator(order, denominator, context);
    }

    /**
     * @dev Inscribe just the `isValidated` field of an order status struct.
     *
     * @param order The order to inscribe.
     * @param isValidated The boolean value to set for the `isValidated` field.
     * @param context The fuzz test context.
     *
     */
    function inscribeOrderStatusValidated(
        AdvancedOrder memory order,
        bool isValidated,
        FuzzTestContext memory context
    ) internal {
        // Get the order hash.
        bytes32 orderHash = order.getTipNeutralizedOrderHash(context.seaport);

        bytes32 orderHashStorageSlot = _getStorageSlotForOrderHash(
            orderHash,
            context
        );
        bytes32 rawOrderStatus = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        // NOTE: This will permit putting an order in a 0x0...0101 state.
        //       In other words, it will allow you to inscribe an order as
        //       both validated and cancelled at the same time, which is not
        //       possible in actual Seaport.

        assembly {
            rawOrderStatus := and(
                sub(0, add(1, iszero(isValidated))),
                or(isValidated, rawOrderStatus)
            )
        }

        // Store the new raw order status.
        vm.store(
            address(context.seaport),
            orderHashStorageSlot,
            rawOrderStatus
        );
    }

    /**
     * @dev Inscribe just the `isCancelled` field of an order status struct.
     *
     * @param order The order to inscribe.
     * @param isCancelled The boolean value to set for the `isCancelled` field.
     * @param context The fuzz test context.
     *
     */
    function inscribeOrderStatusCanceled(
        AdvancedOrder memory order,
        bool isCancelled,
        FuzzTestContext memory context
    ) internal {
        // Get the order hash.
        bytes32 orderHash = order.getTipNeutralizedOrderHash(context.seaport);

        bytes32 orderHashStorageSlot = _getStorageSlotForOrderHash(
            orderHash,
            context
        );
        bytes32 rawOrderStatus = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        // NOTE: This will not permit putting an order in a 0x0...0101 state. If
        //       An order that's validated is inscribed as cancelled, it will
        //       be devalidated also.

        assembly {
            rawOrderStatus := and(
                sub(sub(0, 1), mul(iszero(isCancelled), 0x100)),
                or(
                    shl(8, isCancelled),
                    and(mul(sub(0, 0x102), isCancelled), rawOrderStatus)
                )
            )
        }

        // Store the new raw order status.
        vm.store(
            address(context.seaport),
            orderHashStorageSlot,
            rawOrderStatus
        );
    }

    /**
     * @dev Inscribe just the `numerator` field of an order status struct.
     *
     * @param order The order to inscribe.
     * @param numerator The numerator to inscribe.
     * @param context The fuzz test context.
     *
     */
    function inscribeOrderStatusNumerator(
        AdvancedOrder memory order,
        uint120 numerator,
        FuzzTestContext memory context
    ) internal {
        // Get the order hash, storage slot, and raw order status.
        bytes32 orderHash = order.getTipNeutralizedOrderHash(context.seaport);
        bytes32 orderHashStorageSlot = _getStorageSlotForOrderHash(
            orderHash,
            context
        );
        bytes32 rawOrderStatus = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        // Convert the numerator to bytes.
        bytes32 numeratorBytes = bytes32(uint256(numerator));

        assembly {
            // Shift the inputted numerator bytes to the left by 16 so they're
            // lined up in the right spot.
            numeratorBytes := shl(16, numeratorBytes)
            // Zero out the existing numerator bytes.
            rawOrderStatus := and(rawOrderStatus, wipeNumeratorMask)
            // Or the inputted numerator bytes into the raw order status.
            rawOrderStatus := or(rawOrderStatus, numeratorBytes)
        }

        // Store the new raw order status.
        vm.store(
            address(context.seaport),
            orderHashStorageSlot,
            rawOrderStatus
        );
    }

    /**
     * @dev Inscribe just the `denominator` field of an order status struct.
     *
     * @param order The order to inscribe.
     * @param denominator The denominator to inscribe.
     * @param context The fuzz test context.
     *
     */
    function inscribeOrderStatusDenominator(
        AdvancedOrder memory order,
        uint120 denominator,
        FuzzTestContext memory context
    ) internal {
        // Get the order hash, storage slot, and raw order status.
        bytes32 orderHash = order.getTipNeutralizedOrderHash(context.seaport);
        bytes32 orderHashStorageSlot = _getStorageSlotForOrderHash(
            orderHash,
            context
        );
        bytes32 rawOrderStatus = vm.load(
            address(context.seaport),
            orderHashStorageSlot
        );

        // Convert the denominator to bytes.
        bytes32 denominatorBytes = bytes32(uint256(denominator));

        assembly {
            // Shift the inputted denominator bytes to the left by 136 so
            // they're lined up in the right spot.
            denominatorBytes := shl(136, denominatorBytes)
            // Zero out the existing denominator bytes.
            rawOrderStatus := and(rawOrderStatus, wipeDenominatorMask)
            // Or the inputted denominator bytes into the raw order status.
            rawOrderStatus := or(rawOrderStatus, denominatorBytes)
        }

        // Store the new raw order status.
        vm.store(
            address(context.seaport),
            orderHashStorageSlot,
            rawOrderStatus
        );
    }

    /**
     * @dev Inscribe the contract offerer nonce.
     *
     * @param contractOfferer The contract offerer to inscribe the nonce for.
     * @param nonce The nonce to inscribe.
     * @param context The fuzz test context.
     *
     */
    function inscribeContractOffererNonce(
        address contractOfferer,
        uint256 nonce,
        FuzzTestContext memory context
    ) internal {
        // Get the storage slot for the contract offerer's nonce.
        bytes32 contractOffererNonceStorageSlot = _getStorageSlotForContractNonce(
                contractOfferer,
                context
            );

        // Store the new nonce.
        vm.store(
            address(context.seaport),
            contractOffererNonceStorageSlot,
            bytes32(nonce)
        );
    }

    /**
     * @dev Inscribe the counter for an offerer.
     *
     * @param offerer The offerer to inscribe the counter for.
     * @param counter The counter to inscribe.
     * @param context The fuzz test context.
     *
     */
    function inscribeCounter(
        address offerer,
        uint256 counter,
        FuzzTestContext memory context
    ) internal {
        // Get the storage slot for the counter.
        bytes32 contractOffererNonceStorageSlot = _getStorageSlotForContractNonce(
                offerer,
                context
            );

        // Store the new counter.
        vm.store(
            address(context.seaport),
            contractOffererNonceStorageSlot,
            bytes32(counter)
        );
    }

    function _getStorageSlotForOrderHash(
        bytes32 orderHash,
        FuzzTestContext memory context
    ) private returns (bytes32) {
        vm.record();
        context.seaport.getOrderStatus(orderHash);
        (bytes32[] memory readAccesses, ) = vm.accesses(
            address(context.seaport)
        );

        uint256 expectedReadAccessCount = 1;

        string memory profile = vm.envOr("MOAT_PROFILE", string("optimized"));

        if (
            keccak256(abi.encodePacked(profile)) ==
            keccak256(abi.encodePacked("optimized"))
        ) {
            expectedReadAccessCount = 4;
        }

        require(
            readAccesses.length == expectedReadAccessCount,
            "Expected 4 read accesses."
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
