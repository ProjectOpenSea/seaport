// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ConduitItemType
} from "../../../../contracts/conduit/lib/ConduitEnums.sol";

import {
    ConduitInterface
} from "../../../../contracts/interfaces/ConduitInterface.sol";

import {
    ConduitTransfer
} from "../../../../contracts/conduit/lib/ConduitStructs.sol";

import { ItemType } from "../../../../contracts/lib/ConsiderationEnums.sol";

import {
    ReceivedItem
} from "../../../../contracts/lib/ConsiderationStructs.sol";

import "./FuzzTestContextLib.sol";

struct AccumulatorStruct {
    bytes32 conduitKey;
    ConduitTransfer[] transfers;
}

contract ExecutionsAccumulator {
    /**
     * @dev Internal function to transfer a given item.
     *
     * @param item                  The item to transfer including an amount
     *                              and recipient.
     * @param offerer               The account offering the item, i.e. the
     *                              from address.
     * @param conduitKey            A bytes32 value indicating what
     *                              corresponding conduit, if any, to source
     *                              token approvals from. The zero hash
     *                              signifies that no conduit should be used
     *                              (and direct approvals set on Consideration)
     * @param accumulatorStruct     A struct containing conduit transfer data
     *                              and its corresponding conduitKey.
     * @param context               A fuzz test context
     */
    function _transfer(
        ReceivedItem memory item,
        address offerer,
        bytes32 conduitKey,
        AccumulatorStruct memory accumulatorStruct,
        FuzzTestContext memory context
    ) internal {
        // If the item type indicates Ether or a native token...
        if (item.itemType == ItemType.NATIVE) {
            // Transfer the native tokens to the recipient.
            _expectNativeTransfer(
                item.recipient,
                item.amount,
                context
            );
        } else if (item.itemType == ItemType.ERC20) {
            // Transfer ERC20 tokens from the offerer to the recipient.
            _transferERC20(
                item.token,
                offerer,
                item.recipient,
                item.amount,
                conduitKey,
                accumulatorStruct,
                context
            );
        } else if (item.itemType == ItemType.ERC721) {
            // Transfer ERC721 token from the offerer to the recipient.
            _transferERC721(
                item.token,
                offerer,
                item.recipient,
                item.identifier,
                item.amount,
                conduitKey,
                accumulatorStruct,
                context
            );
        } else {
            // Transfer ERC1155 token from the offerer to the recipient.
            _transferERC1155(
                item.token,
                offerer,
                item.recipient,
                item.identifier,
                item.amount,
                conduitKey,
                accumulatorStruct,
                context
            );
        }
    }

    function _expectNativeTransfer(
        address to,
        uint256 amount,
        FuzzTestContext memory context
    ) internal {}

    function _expectERC20Transfer(
        address token,
        address from,
        address to,
        uint256 amount,
        FuzzTestContext memory context
    ) internal {}

    function _expectERC721Transfer(
        address token,
        address from,
        address to,
        uint256 id,
        FuzzTestContext memory context
    ) internal {}

    function _expectERC1155Transfer(
        address token,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        FuzzTestContext memory context
    ) internal {}

    function _expectConduitTransfers(
        address conduit,
        ConduitTransfer[] memory transfers,
        FuzzTestContext memory context
    ) internal {}

    /**
     * @dev Internal function to transfer ERC20 tokens from a given originator
     *      to a given recipient using a given conduit if applicable. Sufficient
     *      approvals must be set on this contract, the conduit.
     *
     * @param token                 The ERC20 token to transfer.
     * @param from                  The originator of the transfer.
     * @param to                    The recipient of the transfer.
     * @param amount                The amount to transfer.
     * @param conduitKey            A bytes32 value indicating what
     *                              corresponding conduit, if any, to source
     *                              token approvals from. The zero hash
     *                              signifies that no conduit should be used
     *                              (and direct approvals set on Consideration)
     * @param accumulatorStruct     A struct containing conduit transfer data
     *                              and its corresponding conduitKey.
     * @param context               A fuzz test context
     */
    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount,
        bytes32 conduitKey,
        AccumulatorStruct memory accumulatorStruct,
        FuzzTestContext memory context
    ) internal {
        // Trigger accumulated transfers if the conduits differ.
        _triggerIfArmedAndNotAccumulatable(
            accumulatorStruct,
            conduitKey,
            context
        );

        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Perform the token transfer directly.
            _expectERC20Transfer(token, from, to, amount, context);
        } else {
            // Insert the call to the conduit into the accumulator.
            _insert(
                conduitKey,
                accumulatorStruct,
                ConduitItemType.ERC20,
                token,
                from,
                to,
                uint256(0),
                amount,
                context
            );
        }
    }

    /**
     * @dev Internal function to transfer a single ERC721 token from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective conduit or on this contract itself.
     *
     * @param token                 The ERC721 token to transfer.
     * @param from                  The originator of the transfer.
     * @param to                    The recipient of the transfer.
     * @param identifier            The tokenId to transfer.
     * @param amount                The "amount" (this value must be equal
     *                              to one).
     * @param conduitKey            A bytes32 value indicating what
     *                              corresponding conduit, if any, to source
     *                              token approvals from. The zero hash
     *                              signifies that no conduit should be used
     *                              (and direct approvals set on Consideration)
     * @param accumulatorStruct     A struct containing conduit transfer data
     *                              and its corresponding conduitKey.
     * @param context               A fuzz test context
     */
    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        bytes32 conduitKey,
        AccumulatorStruct memory accumulatorStruct,
        FuzzTestContext memory context
    ) internal {
        // Trigger accumulated transfers if the conduits differ.
        _triggerIfArmedAndNotAccumulatable(
            accumulatorStruct,
            conduitKey,
            context
        );

        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Ensure that exactly one 721 item is being transferred.
            if (amount != 1) {
                revert("FuzzExecutionsAccumulator: InvalidERC721TransferAmount");
            }

            // Perform transfer via the token contract directly.
            _expectERC721Transfer(token, from, to, identifier, context);
        } else {
            // Insert the call to the conduit into the accumulator.
            _insert(
                conduitKey,
                accumulatorStruct,
                ConduitItemType.ERC721,
                token,
                from,
                to,
                identifier,
                amount,
                context
            );
        }
    }

    /**
     * @dev Internal function to transfer ERC1155 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set, either on
     *      the respective conduit or on this contract itself.
     *
     * @param token                 The ERC1155 token to transfer.
     * @param from                  The originator of the transfer.
     * @param to                    The recipient of the transfer.
     * @param identifier            The tokenId to transfer.
     * @param amount                The amount to transfer.
     * @param conduitKey            A bytes32 value indicating what
     *                              corresponding conduit, if any, to source
     *                              token approvals from. The zero hash
     *                              signifies that no conduit should be used
     *                              (and direct approvals set on Consideration)
     * @param accumulatorStruct     A struct containing conduit transfer data
     *                              and its corresponding conduitKey.
     * @param context               A fuzz test context
     */
    function _transferERC1155(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        bytes32 conduitKey,
        AccumulatorStruct memory accumulatorStruct,
        FuzzTestContext memory context
    ) internal {
        // Ensure that the supplied amount is non-zero.
        // _assertNonZeroAmount(amount);

        // Trigger accumulated transfers if the conduits differ.
        _triggerIfArmedAndNotAccumulatable(
            accumulatorStruct,
            conduitKey,
            context
        );

        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Perform transfer via the token contract directly.
            _expectERC1155Transfer(
                token,
                from,
                to,
                identifier,
                amount,
                context
            );
        } else {
            // Insert the call to the conduit into the accumulator.
            _insert(
                conduitKey,
                accumulatorStruct,
                ConduitItemType.ERC1155,
                token,
                from,
                to,
                identifier,
                amount,
                context
            );
        }
    }

    /**
     * @dev Internal function to trigger a call to the conduit currently held by
     *      the accumulator if the accumulator contains item transfers (i.e. it
     *      is "armed") and the supplied conduit key does not match the key held
     *      by the accumulator.
     *
     * @param accumulatorStruct A struct containing conduit transfer data
     *                          and its corresponding conduitKey.
     * @param conduitKey        A bytes32 value indicating what corresponding
     *                          conduit, if any, to source token approvals
     *                          from. The zero hash signifies that no conduit
     *                          should be used (and direct approvals set on
     *                          Consideration)
     * @param context               A fuzz test context
     */
    function _triggerIfArmedAndNotAccumulatable(
        AccumulatorStruct memory accumulatorStruct,
        bytes32 conduitKey,
        FuzzTestContext memory context
    ) internal {
        // Perform conduit call if the set key does not match the supplied key.
        if (accumulatorStruct.conduitKey != conduitKey) {
            _triggerIfArmed(accumulatorStruct, context);
        }
    }

    /**
     * @dev Internal function to trigger a call to the conduit currently held by
     *      the accumulator if the accumulator contains item transfers (i.e. it
     *      is "armed").
     *
     * @param accumulatorStruct A struct containing conduit transfer data
     *                          and its corresponding conduitKey.
     * @param context               A fuzz test context
     */
    function _triggerIfArmed(
        AccumulatorStruct memory accumulatorStruct,
        FuzzTestContext memory context
    ) internal {
        // Exit if the accumulator is not "armed".
        if (accumulatorStruct.transfers.length == 0) {
            return;
        }

        // Perform conduit call.
        _trigger(accumulatorStruct, context);
    }

    /**
     * @dev Internal function to trigger a call to the conduit corresponding to
     *      a given conduit key, supplying all accumulated item transfers. The
     *      accumulator will be "disarmed" and reset in the process.
     *
     * @param accumulatorStruct A struct containing conduit transfer data
     *                          and its corresponding conduitKey.
     * @param context               A fuzz test context
     */
    function _trigger(
        AccumulatorStruct memory accumulatorStruct,
        FuzzTestContext memory context
    ) internal {
        _expectConduitTransfers(
            _getConduit(accumulatorStruct.conduitKey, context),
            accumulatorStruct.transfers,
            context
        );

        // Reset accumulator length to signal that it is now "disarmed".
        delete accumulatorStruct.transfers;
    }

    /**
     * @dev Internal pure function to place an item transfer into an accumulator
     *      that collects a series of transfers to execute against a given
     *      conduit in a single call.
     *
     * @param conduitKey        A bytes32 value indicating what
     *                          corresponding conduit, if any, to source
     *                          token approvals from. The zero hash
     *                          signifies that no conduit should be used
     *                          (and direct approvals set on Consideration)
     * @param accumulatorStruct A struct containing conduit transfer data
     *                          and its corresponding conduitKey.
     * @param itemType          The type of the item to transfer.
     * @param token             The token to transfer.
     * @param from              The originator of the transfer.
     * @param to                The recipient of the transfer.
     * @param identifier        The tokenId to transfer.
     * @param amount            The amount to transfer.
     * @param context               A fuzz test context
     */
    function _insert(
        bytes32 conduitKey,
        AccumulatorStruct memory accumulatorStruct,
        ConduitItemType itemType,
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        FuzzTestContext memory context
    ) internal pure {
        /**
         *   The following is highly inefficient, but written this way to
         *   simply demonstrate what is performed by the optimized contract.
         */

        // Get the current length of the accumulator's transfers.
        uint256 currentTransferLength = accumulatorStruct.transfers.length;

        // Create a new array to "insert" the new transfer.
        ConduitTransfer[] memory newTransfers = (
            new ConduitTransfer[](currentTransferLength + 1)
        );

        // Fill new array with old transfers.
        for (uint256 i = 0; i < currentTransferLength; ++i) {
            // Get the old transfer.
            ConduitTransfer memory oldTransfer = accumulatorStruct.transfers[i];

            // Add the old transfer into the new array.
            newTransfers[i] = ConduitTransfer(
                oldTransfer.itemType,
                oldTransfer.token,
                oldTransfer.from,
                oldTransfer.to,
                oldTransfer.identifier,
                oldTransfer.amount
            );
        }

        // Insert new transfer into array.
        newTransfers[currentTransferLength] = ConduitTransfer(
            itemType,
            token,
            from,
            to,
            identifier,
            amount
        );

        // Set accumulator struct transfers to new transfers.
        accumulatorStruct.transfers = newTransfers;

        // Set the conduitkey of the current transfers.
        accumulatorStruct.conduitKey = conduitKey;
    }

    /**
     * @dev Internal function get the conduit derived by the provided
     *      conduit key.
     *
     * @param conduitKey A bytes32 value indicating what corresponding conduit,
     *                   if any, to source token approvals from. This value is
     *                   the "salt" parameter supplied by the deployer (i.e. the
     *                   conduit controller) when deploying the given conduit.
     *
     * @return conduit   The address of the conduit associated with the given
     *                   conduit key.
     * @param context    A fuzz test context
     */
    function _getConduit(
        bytes32 conduitKey,
        FuzzTestContext memory context
    ) internal view returns (address) {
        (address conduit, bool exists) = context.conduitController.getConduit(
            conduitKey
        );
        if (exists) {
            return conduit;
        } else {
            revert("FuzzExecutionsAccumulator: Conduit not found");
        }
        return conduit;
    }
}
