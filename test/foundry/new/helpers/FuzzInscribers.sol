// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { vm } from "./VmUtils.sol";

import { AdvancedOrder, OrderStatus } from "seaport-sol/src/SeaportStructs.sol";

import { SeaportInterface } from "seaport-sol/src/SeaportInterface.sol";

import { AdvancedOrderLib } from "seaport-sol/src/SeaportSol.sol";

/**
 * @notice "Inscribers" are helpers that set Seaport state directly by modifying
 *         contract storage. For example, changing order status, setting
 *         contract nonces, and setting counters.
 */
library FuzzInscribers {
    using AdvancedOrderLib for AdvancedOrder;

    uint256 constant wipeDenominatorMask =
        0x000000000000000000000000000000ffffffffffffffffffffffffffffffffff;

    uint256 constant wipeNumeratorMask =
        0xffffffffffffffffffffffffffffff000000000000000000000000000000ffff;

    /**
     * @dev Inscribe an entire order status struct.
     *
     * @param order The order to inscribe.
     * @param orderStatus The order status to inscribe.
     * @param seaport The Seaport instance.
     *
     */
    function inscribeOrderStatusComprehensive(
        AdvancedOrder memory order,
        OrderStatus memory orderStatus,
        SeaportInterface seaport
    ) internal {
        inscribeOrderStatusValidated(order, orderStatus.isValidated, seaport);
        inscribeOrderStatusCancelled(order, orderStatus.isCancelled, seaport);
        inscribeOrderStatusNumerator(order, orderStatus.numerator, seaport);
        inscribeOrderStatusDenominator(order, orderStatus.denominator, seaport);
    }

    /**
     * @dev Inscribe an entire order status struct, except for the numerator.
     *
     * @param order The order to inscribe.
     * @param numerator The numerator to inscribe.
     * @param denominator The denominator to inscribe.
     * @param seaport The Seaport instance.
     *
     */
    function inscribeOrderStatusNumeratorAndDenominator(
        AdvancedOrder memory order,
        uint120 numerator,
        uint120 denominator,
        SeaportInterface seaport
    ) internal {
        inscribeOrderStatusNumerator(order, numerator, seaport);
        inscribeOrderStatusDenominator(order, denominator, seaport);
    }

    /**
     * @dev Inscribe just the `isValidated` field of an order status struct.
     *
     * @param order The order to inscribe.
     * @param isValidated The boolean value to set for the `isValidated` field.
     * @param seaport The Seaport instance.
     *
     */
    function inscribeOrderStatusValidated(
        AdvancedOrder memory order,
        bool isValidated,
        SeaportInterface seaport
    ) internal {
        // Get the order hash.
        bytes32 orderHash = order.getTipNeutralizedOrderHash(seaport);

        bytes32 orderHashStorageSlot = _getStorageSlotForOrderHash(
            orderHash,
            seaport
        );
        bytes32 rawOrderStatus = vm.load(
            address(seaport),
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
        vm.store(address(seaport), orderHashStorageSlot, rawOrderStatus);

        // Get the fresh baked order status straight from Seaport.
        (bool isValidatedOrganicValue, , , ) = seaport.getOrderStatus(
            orderHash
        );

        if (isValidated != isValidatedOrganicValue) {
            revert("FuzzInscribers/inscribeOrderStatusValidated: Mismatch");
        }
    }

    /**
     * @dev Inscribe just the `isCancelled` field of an order status struct.
     *
     * @param order The order to inscribe.
     * @param isCancelled The boolean value to set for the `isCancelled` field.
     * @param seaport The Seaport instance.
     *
     */
    function inscribeOrderStatusCancelled(
        AdvancedOrder memory order,
        bool isCancelled,
        SeaportInterface seaport
    ) internal {
        // Get the order hash.
        bytes32 orderHash = order.getTipNeutralizedOrderHash(seaport);
        inscribeOrderStatusCancelled(orderHash, isCancelled, seaport);
    }

    function inscribeOrderStatusCancelled(
        bytes32 orderHash,
        bool isCancelled,
        SeaportInterface seaport
    ) internal {
        bytes32 orderHashStorageSlot = _getStorageSlotForOrderHash(
            orderHash,
            seaport
        );
        bytes32 rawOrderStatus = vm.load(
            address(seaport),
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
        vm.store(address(seaport), orderHashStorageSlot, rawOrderStatus);

        // Get the fresh baked order status straight from Seaport.
        (
            bool isValidatedOrganicValue,
            bool isCancelledOrganicValue,
            ,

        ) = seaport.getOrderStatus(orderHash);

        if (isCancelled != isCancelledOrganicValue) {
            revert("FuzzInscribers/inscribeOrderStatusCancelled: Mismatch");
        }

        if (isCancelledOrganicValue && isValidatedOrganicValue) {
            revert(
                "FuzzInscribers/inscribeOrderStatusCancelled: Invalid state"
            );
        }
    }

    /**
     * @dev Inscribe just the `numerator` field of an order status struct.
     *
     * @param order The order to inscribe.
     * @param numerator The numerator to inscribe.
     * @param seaport The Seaport instance.
     *
     */
    function inscribeOrderStatusNumerator(
        AdvancedOrder memory order,
        uint120 numerator,
        SeaportInterface seaport
    ) internal {
        // Get the order hash, storage slot, and raw order status.
        bytes32 orderHash = order.getTipNeutralizedOrderHash(seaport);
        bytes32 orderHashStorageSlot = _getStorageSlotForOrderHash(
            orderHash,
            seaport
        );
        bytes32 rawOrderStatus = vm.load(
            address(seaport),
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
        vm.store(address(seaport), orderHashStorageSlot, rawOrderStatus);
    }

    /**
     * @dev Inscribe just the `denominator` field of an order status struct.
     *
     * @param order The order to inscribe.
     * @param denominator The denominator to inscribe.
     * @param seaport The Seaport instance.
     *
     */
    function inscribeOrderStatusDenominator(
        AdvancedOrder memory order,
        uint120 denominator,
        SeaportInterface seaport
    ) internal {
        // Get the order hash, storage slot, and raw order status.
        bytes32 orderHash = order.getTipNeutralizedOrderHash(seaport);
        bytes32 orderHashStorageSlot = _getStorageSlotForOrderHash(
            orderHash,
            seaport
        );
        bytes32 rawOrderStatus = vm.load(
            address(seaport),
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
        vm.store(address(seaport), orderHashStorageSlot, rawOrderStatus);
    }

    /**
     * @dev Inscribe the contract offerer nonce.
     *
     * @param contractOfferer The contract offerer to inscribe the nonce for.
     * @param nonce The nonce to inscribe.
     * @param seaport The Seaport instance.
     *
     */
    function inscribeContractOffererNonce(
        address contractOfferer,
        uint256 nonce,
        SeaportInterface seaport
    ) internal {
        // Get the storage slot for the contract offerer's nonce.
        bytes32 contractOffererNonceStorageSlot = _getStorageSlotForContractNonce(
                contractOfferer,
                seaport
            );

        // Store the new nonce.
        vm.store(
            address(seaport),
            contractOffererNonceStorageSlot,
            bytes32(nonce)
        );
    }

    /**
     * @dev Inscribe the counter for an offerer.
     *
     * @param offerer The offerer to inscribe the counter for.
     * @param counter The counter to inscribe.
     * @param seaport The Seaport instance.
     *
     */
    function inscribeCounter(
        address offerer,
        uint256 counter,
        SeaportInterface seaport
    ) internal {
        // Get the storage slot for the counter.
        bytes32 counterStorageSlot = _getStorageSlotForCounter(
            offerer,
            seaport
        );

        // Store the new counter.
        vm.store(address(seaport), counterStorageSlot, bytes32(counter));
    }

    function _getStorageSlotForOrderHash(
        bytes32 orderHash,
        SeaportInterface seaport
    ) private returns (bytes32) {
        vm.record();
        seaport.getOrderStatus(orderHash);
        (bytes32[] memory readAccesses, ) = vm.accesses(address(seaport));

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
        SeaportInterface seaport
    ) private returns (bytes32) {
        vm.record();
        seaport.getContractOffererNonce(contractOfferer);
        (bytes32[] memory readAccesses, ) = vm.accesses(address(seaport));

        require(readAccesses.length == 1, "Expected 1 read access.");

        return readAccesses[0];
    }

    function _getStorageSlotForCounter(
        address offerer,
        SeaportInterface seaport
    ) private returns (bytes32) {
        vm.record();
        seaport.getCounter(offerer);
        (bytes32[] memory readAccesses, ) = vm.accesses(address(seaport));

        require(readAccesses.length == 1, "Expected 1 read access.");

        return readAccesses[0];
    }
}
