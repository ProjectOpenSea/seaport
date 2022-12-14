// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ZoneInterface } from "../interfaces/ZoneInterface.sol";

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";

import { ItemType, OrderType } from "./ConsiderationEnums.sol";

import {
    AdvancedOrder,
    OrderParameters,
    BasicOrderParameters,
    AdditionalRecipient,
    ZoneParameters,
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem
} from "./ConsiderationStructs.sol";

import { ZoneInteractionErrors } from "../interfaces/ZoneInteractionErrors.sol";

import { LowLevelHelpers } from "./LowLevelHelpers.sol";

import "./ConsiderationConstants.sol";

import "./ConsiderationErrors.sol";
import "./PointerLibraries.sol";
import "./ConsiderationEncoder.sol";

/**
 * @title ZoneInteraction
 * @author 0age
 * @notice ZoneInteraction contains logic related to interacting with zones.
 */
contract ZoneInteraction is
    ConsiderationEncoder,
    ZoneInteractionErrors,
    LowLevelHelpers
{
    /**
     * @dev Internal view function to determine if an order has a restricted
     *      order type and, if so, to ensure that either the offerer or the zone
     *      are the fulfiller or that a staticcall to `isValidOrder` on the zone
     *      returns a magic value indicating that the order is currently valid.
     *      Note that contract orders are not accessible via basic fulfillments.
     *
     * @param orderHash   The hash of the order.
     * @param orderType   The order type.
     * @param parameters  The parameters of the basic order.
     */
    function _assertRestrictedBasicOrderValidity(
        bytes32 orderHash,
        OrderType orderType,
        BasicOrderParameters calldata parameters
    ) internal {
        // Order type 2-3 require zone be caller or zone to approve.
        if (_isRestrictedAndCallerNotZone(orderType, parameters.zone)) {
            (MemoryPointer callData, uint256 size) = abi_encode_validateOrder(
                orderHash,
                parameters
            );

            _callAndCheckStatus(
                parameters.zone,
                orderHash,
                callData,
                size,
                InvalidRestrictedOrder_error_selector
            );
        }
    }

    /**
     * @dev Internal view function to determine whether an order is a restricted
     *      order and, if so, to ensure that it was either submitted by the
     *      offerer or the zone for the order, or that the zone returns the
     *      expected magic value upon performing a staticcall to `isValidOrder`
     *      or `isValidOrderIncludingExtraData` depending on whether the order
     *      fulfillment specifies extra data or criteria resolvers.
     *
     * @param advancedOrder     The advanced order in question.
     * @param orderHashes       The order hashes of each order supplied prior to
     *                          the current order as part of a "match" variety
     *                          of order fulfillment (e.g. this array will be
     *                          empty for single or "fulfill available").
     * @param orderHash         The hash of the order.
     */
    function _assertRestrictedAdvancedOrderValidity(
        AdvancedOrder memory advancedOrder,
        bytes32[] memory orderHashes,
        bytes32 orderHash
    ) internal {
        // bytes memory callData;
        address target;
        uint256 errorSelector;
        // function(bytes32) internal view errorHandler;
        MemoryPointer callData;
        uint256 size;

        OrderParameters memory parameters = advancedOrder.parameters;

        // OrderType 2-3 require zone to be caller or approve via validateOrder.
        if (
            _isRestrictedAndCallerNotZone(parameters.orderType, parameters.zone)
        ) {
            (callData, size) = abi_encode_validateOrder(
                orderHash,
                parameters,
                advancedOrder.extraData,
                orderHashes
            );
            target = parameters.zone;
            errorSelector = InvalidRestrictedOrder_error_selector;
        } else if (parameters.orderType == OrderType.CONTRACT) {
            (callData, size) = abi_encode_ratifyOrder(
                orderHash,
                parameters,
                advancedOrder.extraData,
                orderHashes
            );

            target = parameters.offerer;
            errorSelector = InvalidContractOrder_error_selector;
        } else {
            return;
        }

        _callAndCheckStatus(target, orderHash, callData, size, errorSelector);
    }

    /**
     * @dev Determines whether the specified order type is restricted and the
     *      caller is not the specified zone.
     *
     * @param orderType     The type of the order to check.
     * @param zone          The address of the zone to check against.
     *
     * @return mustValidate True if the order type is restricted and the caller
     *                      is not the specified zone, false otherwise.
     */
    function _isRestrictedAndCallerNotZone(
        OrderType orderType,
        address zone
    ) internal view returns (bool mustValidate) {
        assembly {
            mustValidate := and(
                or(eq(orderType, 2), eq(orderType, 3)),
                iszero(eq(caller(), zone))
            )
        }
    }

    /**
     * @dev Calls the specified target with the given data and checks the status
     *      of the call. Revert reasons will be "bubbled up" if one is returned,
     *      otherwise reverting calls will throw a generic error based on the
     *      supplied error handler.
     *
     * @param target       The address of the contract to call.
     * @param orderHash    The hash of the order associated with the call.
     * @param callData     The data to pass to the contract call.
     * @param size          The size of calldata
     * @param errorSelector The error handling function to call if the call fails
     *                     or the magic value does not match.
     */
    function _callAndCheckStatus(
        address target,
        bytes32 orderHash,
        MemoryPointer callData,
        uint256 size,
        uint256 errorSelector
    ) internal {
        bool success;
        bool magicMatch;
        assembly {
            // Clear the start of scratch space.
            mstore(0, 0)
            // let magicValue := shr(224, mload(callData))
            // Perform call, placing result in the first word of scratch space.
            success := call(gas(), target, 0, callData, size, 0, OneWord)
            let magic := shr(224, mload(callData))
            magicMatch := eq(magic, shr(224, mload(0)))
        }
        if (!success) {
            // Revert and pass reason along if one was returned.
            _revertWithReasonIfOneIsReturned();
            assembly {
                mstore(0, errorSelector)
                mstore(0x20, orderHash)
                revert(Error_selector_offset, 0x24)
            }
        }

        if (!magicMatch) {
            // Otherwise, revert with a generic error message.
            assembly {
                mstore(0, errorSelector)
                mstore(0x20, orderHash)
                revert(Error_selector_offset, 0x24)
            }
        }
    }
}
