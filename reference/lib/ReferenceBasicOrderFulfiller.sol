// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    OrderType,
    BasicOrderType,
    ItemType,
    BasicOrderRouteType
} from "contracts/lib/ConsiderationEnums.sol";

import {
    AdditionalRecipient,
    BasicOrderParameters,
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem
} from "contracts/lib/ConsiderationStructs.sol";

import {
    AccumulatorStruct,
    BasicFulfillmentHashes,
    FulfillmentItemTypes
} from "./ReferenceConsiderationStructs.sol";

import { ReferenceOrderValidator } from "./ReferenceOrderValidator.sol";

import "contracts/lib/ConsiderationConstants.sol";

/**
 * @title BasicOrderFulfiller
 * @author 0age
 * @notice BasicOrderFulfiller contains functionality for fulfilling "basic"
 *         orders.
 */
contract ReferenceBasicOrderFulfiller is ReferenceOrderValidator {
    // Map BasicOrderType to BasicOrderRouteType
    mapping(BasicOrderType => BasicOrderRouteType) internal _OrderToRouteType;
    // Map BasicOrderType to OrderType
    mapping(BasicOrderType => OrderType) internal _BasicOrderToOrderType;

    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param conduitController A contract that deploys conduits, or proxies
     *                          that may optionally be used to transfer approved
     *                          ERC20/721/1155 tokens.
     */
    constructor(address conduitController)
        ReferenceOrderValidator(conduitController)
    {
        createMappings();
    }

    /**
     * @dev Creates a mapping of BasicOrderType Enums to BasicOrderRouteType
     *      Enums and BasicOrderType Enums to OrderType Enums. Note that this
     *      is wildly inefficient, but makes the logic easier to follow when
     *      performing the fulfillment.
     */
    function createMappings() internal {
        // BasicOrderType to BasicOrderRouteType

        // ETH TO ERC 721
        _OrderToRouteType[
            BasicOrderType.ETH_TO_ERC721_FULL_OPEN
        ] = BasicOrderRouteType.ETH_TO_ERC721;
        _OrderToRouteType[
            BasicOrderType.ETH_TO_ERC721_PARTIAL_OPEN
        ] = BasicOrderRouteType.ETH_TO_ERC721;
        _OrderToRouteType[
            BasicOrderType.ETH_TO_ERC721_FULL_RESTRICTED
        ] = BasicOrderRouteType.ETH_TO_ERC721;
        _OrderToRouteType[
            BasicOrderType.ETH_TO_ERC721_PARTIAL_RESTRICTED
        ] = BasicOrderRouteType.ETH_TO_ERC721;

        // ETH TO ERC 1155
        _OrderToRouteType[
            BasicOrderType.ETH_TO_ERC1155_FULL_OPEN
        ] = BasicOrderRouteType.ETH_TO_ERC1155;
        _OrderToRouteType[
            BasicOrderType.ETH_TO_ERC1155_PARTIAL_OPEN
        ] = BasicOrderRouteType.ETH_TO_ERC1155;
        _OrderToRouteType[
            BasicOrderType.ETH_TO_ERC1155_FULL_RESTRICTED
        ] = BasicOrderRouteType.ETH_TO_ERC1155;
        _OrderToRouteType[
            BasicOrderType.ETH_TO_ERC1155_PARTIAL_RESTRICTED
        ] = BasicOrderRouteType.ETH_TO_ERC1155;

        // ERC 20 TO ERC 721
        _OrderToRouteType[
            BasicOrderType.ERC20_TO_ERC721_FULL_OPEN
        ] = BasicOrderRouteType.ERC20_TO_ERC721;
        _OrderToRouteType[
            BasicOrderType.ERC20_TO_ERC721_PARTIAL_OPEN
        ] = BasicOrderRouteType.ERC20_TO_ERC721;
        _OrderToRouteType[
            BasicOrderType.ERC20_TO_ERC721_FULL_RESTRICTED
        ] = BasicOrderRouteType.ERC20_TO_ERC721;
        _OrderToRouteType[
            BasicOrderType.ERC20_TO_ERC721_PARTIAL_RESTRICTED
        ] = BasicOrderRouteType.ERC20_TO_ERC721;

        // ERC 20 TO ERC 1155
        _OrderToRouteType[
            BasicOrderType.ERC20_TO_ERC1155_FULL_OPEN
        ] = BasicOrderRouteType.ERC20_TO_ERC1155;
        _OrderToRouteType[
            BasicOrderType.ERC20_TO_ERC1155_PARTIAL_OPEN
        ] = BasicOrderRouteType.ERC20_TO_ERC1155;
        _OrderToRouteType[
            BasicOrderType.ERC20_TO_ERC1155_FULL_RESTRICTED
        ] = BasicOrderRouteType.ERC20_TO_ERC1155;
        _OrderToRouteType[
            BasicOrderType.ERC20_TO_ERC1155_PARTIAL_RESTRICTED
        ] = BasicOrderRouteType.ERC20_TO_ERC1155;

        // ERC 721 TO ERC 20
        _OrderToRouteType[
            BasicOrderType.ERC721_TO_ERC20_FULL_OPEN
        ] = BasicOrderRouteType.ERC721_TO_ERC20;
        _OrderToRouteType[
            BasicOrderType.ERC721_TO_ERC20_PARTIAL_OPEN
        ] = BasicOrderRouteType.ERC721_TO_ERC20;
        _OrderToRouteType[
            BasicOrderType.ERC721_TO_ERC20_FULL_RESTRICTED
        ] = BasicOrderRouteType.ERC721_TO_ERC20;
        _OrderToRouteType[
            BasicOrderType.ERC721_TO_ERC20_PARTIAL_RESTRICTED
        ] = BasicOrderRouteType.ERC721_TO_ERC20;

        // ERC 1155 TO ERC 20
        _OrderToRouteType[
            BasicOrderType.ERC1155_TO_ERC20_FULL_OPEN
        ] = BasicOrderRouteType.ERC1155_TO_ERC20;
        _OrderToRouteType[
            BasicOrderType.ERC1155_TO_ERC20_PARTIAL_OPEN
        ] = BasicOrderRouteType.ERC1155_TO_ERC20;
        _OrderToRouteType[
            BasicOrderType.ERC1155_TO_ERC20_FULL_RESTRICTED
        ] = BasicOrderRouteType.ERC1155_TO_ERC20;
        _OrderToRouteType[
            BasicOrderType.ERC1155_TO_ERC20_PARTIAL_RESTRICTED
        ] = BasicOrderRouteType.ERC1155_TO_ERC20;

        // Basic OrderType to OrderType

        // FULL OPEN
        _BasicOrderToOrderType[
            BasicOrderType.ETH_TO_ERC721_FULL_OPEN
        ] = OrderType.FULL_OPEN;
        _BasicOrderToOrderType[
            BasicOrderType.ETH_TO_ERC1155_FULL_OPEN
        ] = OrderType.FULL_OPEN;
        _BasicOrderToOrderType[
            BasicOrderType.ERC20_TO_ERC721_FULL_OPEN
        ] = OrderType.FULL_OPEN;
        _BasicOrderToOrderType[
            BasicOrderType.ERC20_TO_ERC1155_FULL_OPEN
        ] = OrderType.FULL_OPEN;
        _BasicOrderToOrderType[
            BasicOrderType.ERC721_TO_ERC20_FULL_OPEN
        ] = OrderType.FULL_OPEN;
        _BasicOrderToOrderType[
            BasicOrderType.ERC1155_TO_ERC20_FULL_OPEN
        ] = OrderType.FULL_OPEN;

        // PARTIAL OPEN
        _BasicOrderToOrderType[
            BasicOrderType.ETH_TO_ERC721_PARTIAL_OPEN
        ] = OrderType.PARTIAL_OPEN;
        _BasicOrderToOrderType[
            BasicOrderType.ETH_TO_ERC1155_PARTIAL_OPEN
        ] = OrderType.PARTIAL_OPEN;
        _BasicOrderToOrderType[
            BasicOrderType.ERC20_TO_ERC721_PARTIAL_OPEN
        ] = OrderType.PARTIAL_OPEN;
        _BasicOrderToOrderType[
            BasicOrderType.ERC20_TO_ERC1155_PARTIAL_OPEN
        ] = OrderType.PARTIAL_OPEN;
        _BasicOrderToOrderType[
            BasicOrderType.ERC721_TO_ERC20_PARTIAL_OPEN
        ] = OrderType.PARTIAL_OPEN;
        _BasicOrderToOrderType[
            BasicOrderType.ERC1155_TO_ERC20_PARTIAL_OPEN
        ] = OrderType.PARTIAL_OPEN;

        // FULL RESTRICTED
        _BasicOrderToOrderType[
            BasicOrderType.ETH_TO_ERC721_FULL_RESTRICTED
        ] = OrderType.FULL_RESTRICTED;
        _BasicOrderToOrderType[
            BasicOrderType.ETH_TO_ERC1155_FULL_RESTRICTED
        ] = OrderType.FULL_RESTRICTED;
        _BasicOrderToOrderType[
            BasicOrderType.ERC20_TO_ERC721_FULL_RESTRICTED
        ] = OrderType.FULL_RESTRICTED;
        _BasicOrderToOrderType[
            BasicOrderType.ERC20_TO_ERC1155_FULL_RESTRICTED
        ] = OrderType.FULL_RESTRICTED;
        _BasicOrderToOrderType[
            BasicOrderType.ERC721_TO_ERC20_FULL_RESTRICTED
        ] = OrderType.FULL_RESTRICTED;
        _BasicOrderToOrderType[
            BasicOrderType.ERC1155_TO_ERC20_FULL_RESTRICTED
        ] = OrderType.FULL_RESTRICTED;

        // PARTIAL RESTRICTED
        _BasicOrderToOrderType[
            BasicOrderType.ETH_TO_ERC721_PARTIAL_RESTRICTED
        ] = OrderType.PARTIAL_RESTRICTED;
        _BasicOrderToOrderType[
            BasicOrderType.ETH_TO_ERC1155_PARTIAL_RESTRICTED
        ] = OrderType.PARTIAL_RESTRICTED;
        _BasicOrderToOrderType[
            BasicOrderType.ERC20_TO_ERC721_PARTIAL_RESTRICTED
        ] = OrderType.PARTIAL_RESTRICTED;
        _BasicOrderToOrderType[
            BasicOrderType.ERC20_TO_ERC1155_PARTIAL_RESTRICTED
        ] = OrderType.PARTIAL_RESTRICTED;
        _BasicOrderToOrderType[
            BasicOrderType.ERC721_TO_ERC20_PARTIAL_RESTRICTED
        ] = OrderType.PARTIAL_RESTRICTED;
        _BasicOrderToOrderType[
            BasicOrderType.ERC1155_TO_ERC20_PARTIAL_RESTRICTED
        ] = OrderType.PARTIAL_RESTRICTED;
    }

    /**
     * @dev Internal function to fulfill an order offering an ERC20, ERC721, or
     *      ERC1155 item by supplying Ether (or other native tokens), ERC20
     *      tokens, an ERC721 item, or an ERC1155 item as consideration. Six
     *      permutations are supported: Native token to ERC721, Native token to
     *      ERC1155, ERC20 to ERC721, ERC20 to ERC1155, ERC721 to ERC20, and
     *      ERC1155 to ERC20 (with native tokens supplied as msg.value). For an
     *      order to be eligible for fulfillment via this method, it must
     *      contain a single offer item (though that item may have a greater
     *      amount if the item is not an ERC721). An arbitrary number of
     *      "additional recipients" may also be supplied which will each receive
     *      native tokens or ERC20 items from the fulfiller as consideration.
     *      Refer to the documentation for a more comprehensive summary of how
     *      to utilize with this method and what orders are compatible with it.
     *
     * @param parameters Additional information on the fulfilled order. Note
     *                   that the offerer and the fulfiller must first approve
     *                   this contract (or their chosen conduit if indicated)
     *                   before any tokens can be transferred. Also note that
     *                   contract recipients of ERC1155 consideration items must
     *                   implement `onERC1155Received` in order to receive those
     *                   items.
     *
     * @return A boolean indicating whether the order has been fulfilled.
     */
    function _validateAndFulfillBasicOrder(
        BasicOrderParameters calldata parameters
    ) internal returns (bool) {
        // Determine the basic order route type from the basic order type.
        BasicOrderRouteType route;
        {
            BasicOrderType basicType = parameters.basicOrderType;
            route = _OrderToRouteType[basicType];
        }

        // Determine the order type from the basic order type.
        OrderType orderType;
        {
            BasicOrderType basicType = parameters.basicOrderType;
            orderType = _BasicOrderToOrderType[basicType];
        }

        // Declare additional recipient item type to derive from the route type.
        ItemType additionalRecipientsItemType;
        if (
            route == BasicOrderRouteType.ETH_TO_ERC721 ||
            route == BasicOrderRouteType.ETH_TO_ERC1155
        ) {
            additionalRecipientsItemType = ItemType.NATIVE;
        } else {
            additionalRecipientsItemType = ItemType.ERC20;
        }

        // Revert if msg.value was not supplied as part of a payable route.
        if (msg.value == 0 && additionalRecipientsItemType == ItemType.NATIVE) {
            revert InvalidMsgValue(msg.value);
        }

        // Revert if msg.value was supplied as part of a non-payable route.
        if (msg.value != 0 && additionalRecipientsItemType == ItemType.ERC20) {
            revert InvalidMsgValue(msg.value);
        }

        // Determine the token that additional recipients should have set.
        address additionalRecipientsToken;
        if (
            route == BasicOrderRouteType.ERC721_TO_ERC20 ||
            route == BasicOrderRouteType.ERC1155_TO_ERC20
        ) {
            additionalRecipientsToken = parameters.offerToken;
        } else {
            additionalRecipientsToken = parameters.considerationToken;
        }

        // Determine the item type for received items.
        ItemType receivedItemType;
        if (
            route == BasicOrderRouteType.ETH_TO_ERC721 ||
            route == BasicOrderRouteType.ETH_TO_ERC1155
        ) {
            receivedItemType = ItemType.NATIVE;
        } else if (
            route == BasicOrderRouteType.ERC20_TO_ERC721 ||
            route == BasicOrderRouteType.ERC20_TO_ERC1155
        ) {
            receivedItemType = ItemType.ERC20;
        } else if (route == BasicOrderRouteType.ERC721_TO_ERC20) {
            receivedItemType = ItemType.ERC721;
        } else {
            receivedItemType = ItemType.ERC1155;
        }

        // Determine the item type for the offered item.
        ItemType offeredItemType;
        if (
            route == BasicOrderRouteType.ERC721_TO_ERC20 ||
            route == BasicOrderRouteType.ERC1155_TO_ERC20
        ) {
            offeredItemType = ItemType.ERC20;
        } else if (
            route == BasicOrderRouteType.ETH_TO_ERC721 ||
            route == BasicOrderRouteType.ERC20_TO_ERC721
        ) {
            offeredItemType = ItemType.ERC721;
        } else {
            offeredItemType = ItemType.ERC1155;
        }

        // Derive & validate order using parameters and update order status.
        bytes32 orderHash = _prepareBasicFulfillment(
            parameters,
            orderType,
            receivedItemType,
            additionalRecipientsItemType,
            additionalRecipientsToken,
            offeredItemType
        );

        // Determine conduitKey argument used by transfer functions.
        bytes32 conduitKey;
        if (
            route == BasicOrderRouteType.ERC721_TO_ERC20 ||
            route == BasicOrderRouteType.ERC1155_TO_ERC20
        ) {
            conduitKey = parameters.fulfillerConduitKey;
        } else {
            conduitKey = parameters.offererConduitKey;
        }

        // Check for dirtied unused parameters.
        if (
            ((route == BasicOrderRouteType.ETH_TO_ERC721 ||
                route == BasicOrderRouteType.ETH_TO_ERC1155) &&
                (uint160(parameters.considerationToken) |
                    parameters.considerationIdentifier) !=
                0) ||
            ((route == BasicOrderRouteType.ERC20_TO_ERC721 ||
                route == BasicOrderRouteType.ERC20_TO_ERC1155) &&
                parameters.considerationIdentifier != 0) ||
            ((route == BasicOrderRouteType.ERC721_TO_ERC20 ||
                route == BasicOrderRouteType.ERC1155_TO_ERC20) &&
                parameters.offerIdentifier != 0)
        ) {
            revert UnusedItemParameters();
        }

        // Declare transfer accumulator that will collect transfers that can be
        // bundled into a single call to their associated conduit.
        AccumulatorStruct memory accumulatorStruct;

        // Transfer tokens based on the route.
        if (route == BasicOrderRouteType.ETH_TO_ERC721) {
            // Transfer ERC721 to caller using offerer's conduit if applicable.
            _transferERC721(
                parameters.offerToken,
                parameters.offerer,
                msg.sender,
                parameters.offerIdentifier,
                parameters.offerAmount,
                conduitKey,
                accumulatorStruct
            );

            // Transfer native to recipients, return excess to caller & wrap up.
            _transferEthAndFinalize(parameters.considerationAmount, parameters);
        } else if (route == BasicOrderRouteType.ETH_TO_ERC1155) {
            // Transfer ERC1155 to caller using offerer's conduit if applicable.
            _transferERC1155(
                parameters.offerToken,
                parameters.offerer,
                msg.sender,
                parameters.offerIdentifier,
                parameters.offerAmount,
                conduitKey,
                accumulatorStruct
            );

            // Transfer native to recipients, return excess to caller & wrap up.
            _transferEthAndFinalize(parameters.considerationAmount, parameters);
        } else if (route == BasicOrderRouteType.ERC20_TO_ERC721) {
            // Transfer ERC721 to caller using offerer's conduit if applicable.
            _transferERC721(
                parameters.offerToken,
                parameters.offerer,
                msg.sender,
                parameters.offerIdentifier,
                parameters.offerAmount,
                conduitKey,
                accumulatorStruct
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                msg.sender,
                parameters.offerer,
                parameters.considerationToken,
                parameters.considerationAmount,
                parameters,
                false, // Send full amount indicated by all consideration items.
                accumulatorStruct
            );
        } else if (route == BasicOrderRouteType.ERC20_TO_ERC1155) {
            // Transfer ERC1155 to caller using offerer's conduit if applicable.
            _transferERC1155(
                parameters.offerToken,
                parameters.offerer,
                msg.sender,
                parameters.offerIdentifier,
                parameters.offerAmount,
                conduitKey,
                accumulatorStruct
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                msg.sender,
                parameters.offerer,
                parameters.considerationToken,
                parameters.considerationAmount,
                parameters,
                false, // Send full amount indicated by all consideration items.
                accumulatorStruct
            );
        } else if (route == BasicOrderRouteType.ERC721_TO_ERC20) {
            // Transfer ERC721 to offerer using caller's conduit if applicable.
            _transferERC721(
                parameters.considerationToken,
                msg.sender,
                parameters.offerer,
                parameters.considerationIdentifier,
                parameters.considerationAmount,
                conduitKey,
                accumulatorStruct
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                parameters.offerer,
                msg.sender,
                parameters.offerToken,
                parameters.offerAmount,
                parameters,
                true, // Reduce amount sent to fulfiller by additional amounts.
                accumulatorStruct
            );
        } else {
            // route == BasicOrderRouteType.ERC1155_TO_ERC20

            // Transfer ERC1155 to offerer using caller's conduit if applicable.
            _transferERC1155(
                parameters.considerationToken,
                msg.sender,
                parameters.offerer,
                parameters.considerationIdentifier,
                parameters.considerationAmount,
                conduitKey,
                accumulatorStruct
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                parameters.offerer,
                msg.sender,
                parameters.offerToken,
                parameters.offerAmount,
                parameters,
                true, // Reduce amount sent to fulfiller by additional amounts.
                accumulatorStruct
            );
        }

        // Trigger any remaining accumulated transfers via call to the conduit.
        _triggerIfArmed(accumulatorStruct);

        // Determine whether order is restricted and, if so, that it is valid.
        _assertRestrictedBasicOrderValidity(
            orderHash,
            orderType,
            parameters,
            offeredItemType,
            receivedItemType
        );

        return true;
    }

    /**
     * @dev Internal function to calculate the order hash.
     *
     * @param hashes               The array of offerItems and receivedItems
     *                             hashes.
     * @param parameters           The parameters of the basic order.
     * @param fulfillmentItemTypes The fulfillment's item type.
     *
     * @return orderHash           The order hash.
     */
    function _hashOrder(
        BasicFulfillmentHashes memory hashes,
        BasicOrderParameters calldata parameters,
        FulfillmentItemTypes memory fulfillmentItemTypes
    ) internal view returns (bytes32 orderHash) {
        // Read offerer's current counter from storage and place on the stack.
        uint256 counter = _getCounter(parameters.offerer);

        // Hash the contents to get the orderHash
        orderHash = keccak256(
            abi.encode(
                hashes.typeHash,
                parameters.offerer,
                parameters.zone,
                hashes.offerItemsHash,
                hashes.receivedItemsHash,
                fulfillmentItemTypes.orderType,
                parameters.startTime,
                parameters.endTime,
                parameters.zoneHash,
                parameters.salt,
                parameters.offererConduitKey,
                counter
            )
        );
    }

    /**
     * @dev Internal function to prepare fulfillment of a basic order. This
     *      calculates the order hash, emits an OrderFulfilled event, and
     *      asserts basic order validity.
     *
     * @param parameters                   The parameters of the basic order.
     * @param orderType                    The order type.
     * @param receivedItemType             The item type of the initial
     *                                     consideration item on the order.
     * @param additionalRecipientsItemType The item type of any additional
     *                                     consideration item on the order.
     * @param additionalRecipientsToken    The ERC20 token contract address (if
     *                                     applicable) for any additional
     *                                     consideration item on the order.
     * @param offeredItemType              The item type of the offered item on
     *                                     the order.
     * @return orderHash The calculated order hash.
     */
    function _prepareBasicFulfillment(
        BasicOrderParameters calldata parameters,
        OrderType orderType,
        ItemType receivedItemType,
        ItemType additionalRecipientsItemType,
        address additionalRecipientsToken,
        ItemType offeredItemType
    ) internal returns (bytes32 orderHash) {
        // Ensure current timestamp falls between order start time and end time.
        _verifyTime(parameters.startTime, parameters.endTime, true);

        // Verify that calldata offsets for all dynamic types were produced by
        // default encoding. This is only required on the optimized contract,
        // but is included here to maintain parity.
        _assertValidBasicOrderParameters();

        // Ensure supplied consideration array length is not less than original.
        _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
            parameters.additionalRecipients.length,
            parameters.totalOriginalAdditionalRecipients
        );

        // Memory to store hashes.
        BasicFulfillmentHashes memory hashes;

        // Store ItemType/Token parameters in a struct in memory to avoid stack
        // issues.
        FulfillmentItemTypes memory fulfillmentItemTypes = FulfillmentItemTypes(
            orderType,
            receivedItemType,
            additionalRecipientsItemType,
            additionalRecipientsToken,
            offeredItemType
        );

        // Array of Received Items for use with OrderFulfilled event.
        ReceivedItem[] memory consideration = new ReceivedItem[](
            parameters.additionalRecipients.length + 1
        );

        {
            // Load consideration item typehash from runtime and place on stack.
            hashes.typeHash = _CONSIDERATION_ITEM_TYPEHASH;

            // Create Consideration item.
            ConsiderationItem memory primaryConsiderationItem = (
                ConsiderationItem(
                    fulfillmentItemTypes.receivedItemType,
                    parameters.considerationToken,
                    parameters.considerationIdentifier,
                    parameters.considerationAmount,
                    parameters.considerationAmount,
                    parameters.offerer
                )
            );

            // Array of all consideration item hashes.
            hashes.considerationHashes = new bytes32[](
                parameters.totalOriginalAdditionalRecipients + 1
            );

            // Hash contents.
            hashes.considerationHashes[0] = keccak256(
                abi.encode(
                    hashes.typeHash,
                    primaryConsiderationItem.itemType,
                    primaryConsiderationItem.token,
                    primaryConsiderationItem.identifierOrCriteria,
                    primaryConsiderationItem.startAmount,
                    primaryConsiderationItem.endAmount,
                    primaryConsiderationItem.recipient
                )
            );

            // Declare memory for additionalReceivedItem and
            // additionalRecipientItem.
            ReceivedItem memory additionalReceivedItem;
            ConsiderationItem memory additionalRecipientItem;

            // Create Received item.
            ReceivedItem memory primaryReceivedItem = ReceivedItem(
                fulfillmentItemTypes.receivedItemType,
                primaryConsiderationItem.token,
                primaryConsiderationItem.identifierOrCriteria,
                primaryConsiderationItem.endAmount,
                primaryConsiderationItem.recipient
            );
            // Add the Received item to the
            // OrderFulfilled ReceivedItem[].
            consideration[0] = primaryReceivedItem;

            /**  Loop through all additionalRecipients, to generate
             *    ReceivedItems for OrderFulfilled Event and
             *    ConsiderationItems for hashing.
             */
            for (
                uint256 recipientCount = 0;
                recipientCount < parameters.totalOriginalAdditionalRecipients;
                ++recipientCount
            ) {
                // Get the next additionalRecipient.
                AdditionalRecipient memory additionalRecipient = (
                    parameters.additionalRecipients[recipientCount]
                );

                // Create a Received item for each additional recipients.
                additionalReceivedItem = ReceivedItem(
                    fulfillmentItemTypes.additionalRecipientsItemType,
                    fulfillmentItemTypes.additionalRecipientsToken,
                    0,
                    additionalRecipient.amount,
                    additionalRecipient.recipient
                );
                // Add additional Received items to the
                // OrderFulfilled ReceivedItem[].
                consideration[recipientCount + 1] = additionalReceivedItem;

                // Create a new consideration item for each additional
                // recipient.
                additionalRecipientItem = ConsiderationItem(
                    fulfillmentItemTypes.additionalRecipientsItemType,
                    fulfillmentItemTypes.additionalRecipientsToken,
                    0,
                    additionalRecipient.amount,
                    additionalRecipient.amount,
                    additionalRecipient.recipient
                );

                // Calculate the EIP712 ConsiderationItem hash for
                // each additional recipients.
                hashes.considerationHashes[recipientCount + 1] = keccak256(
                    abi.encode(
                        hashes.typeHash,
                        additionalRecipientItem.itemType,
                        additionalRecipientItem.token,
                        additionalRecipientItem.identifierOrCriteria,
                        additionalRecipientItem.startAmount,
                        additionalRecipientItem.endAmount,
                        additionalRecipientItem.recipient
                    )
                );
            }

            /**
             *  The considerationHashes array now contains
             *  all consideration Item hashes.
             *
             *  The consideration array now contains all received
             *  items excluding tips for OrderFulfilled Event.
             */

            // Get hash of all consideration items.
            hashes.receivedItemsHash = keccak256(
                abi.encodePacked(hashes.considerationHashes)
            );

            // Get remainder of additionalRecipients for tips.
            for (
                uint256 additionalTips = parameters
                    .totalOriginalAdditionalRecipients;
                additionalTips < parameters.additionalRecipients.length;
                ++additionalTips
            ) {
                // Get the next additionalRecipient.
                AdditionalRecipient memory additionalRecipient = (
                    parameters.additionalRecipients[additionalTips]
                );

                // Create the ReceivedItem.
                additionalReceivedItem = ReceivedItem(
                    fulfillmentItemTypes.additionalRecipientsItemType,
                    fulfillmentItemTypes.additionalRecipientsToken,
                    0,
                    additionalRecipient.amount,
                    additionalRecipient.recipient
                );
                // Add additional received items to the
                // OrderFulfilled ReceivedItem[].
                consideration[additionalTips + 1] = additionalReceivedItem;
            }
        }
        // Now let's handle the offer side.

        // Write the offer to the Event SpentItem array.
        SpentItem[] memory offer = new SpentItem[](1);

        {
            // Place offer item typehash on the stack.
            hashes.typeHash = _OFFER_ITEM_TYPEHASH;

            // Create Spent item.
            SpentItem memory offerItem = SpentItem(
                fulfillmentItemTypes.offeredItemType,
                parameters.offerToken,
                parameters.offerIdentifier,
                parameters.offerAmount
            );
            // Add the offer item to the SpentItem array.
            offer[0] = offerItem;

            // Get the hash of the Spent item, treated as an Offer item.
            bytes32[1] memory offerItemHashes = [
                keccak256(
                    abi.encode(
                        hashes.typeHash,
                        offerItem.itemType,
                        offerItem.token,
                        offerItem.identifier,
                        offerItem.amount,
                        // Assembly uses OfferItem instead of SpentItem.
                        offerItem.amount
                    )
                )
            ];

            // Get hash of all Spent items.
            hashes.offerItemsHash = keccak256(
                abi.encodePacked(offerItemHashes)
            );
        }

        {
            // Create the OrderComponent in order to derive
            // the orderHash.

            // Load order typehash from runtime code and place on stack.
            hashes.typeHash = _ORDER_TYPEHASH;

            // Derive the order hash.
            hashes.orderHash = _hashOrder(
                hashes,
                parameters,
                fulfillmentItemTypes
            );

            // Emit an event signifying that the order has been fulfilled.
            emit OrderFulfilled(
                hashes.orderHash,
                parameters.offerer,
                parameters.zone,
                msg.sender,
                offer,
                consideration
            );
        }

        // Verify and update the status of the derived order.
        _validateBasicOrderAndUpdateStatus(
            hashes.orderHash,
            parameters.offerer,
            parameters.signature
        );

        // Return the derived order hash.
        return hashes.orderHash;
    }

    /**
     * @dev Internal function to transfer Ether (or other native tokens) to a
     *      given recipient as part of basic order fulfillment. Note that
     *      proxies are not utilized for native tokens as the transferred amount
     *      must be provided as msg.value.
     *
     * @param amount      The amount to transfer.
     * @param parameters  The parameters of the basic order in question.
     */
    function _transferEthAndFinalize(
        uint256 amount,
        BasicOrderParameters calldata parameters
    ) internal {
        // Put ether value supplied by the caller on the stack.
        uint256 etherRemaining = msg.value;

        // Iterate over each additional recipient.
        for (uint256 i = 0; i < parameters.additionalRecipients.length; ++i) {
            // Retrieve the additional recipient.
            AdditionalRecipient calldata additionalRecipient = (
                parameters.additionalRecipients[i]
            );

            // Read ether amount to transfer to recipient and place on stack.
            uint256 additionalRecipientAmount = additionalRecipient.amount;

            // Ensure that sufficient Ether is available.
            if (additionalRecipientAmount > etherRemaining) {
                revert InsufficientEtherSupplied();
            }

            // Transfer Ether to the additional recipient.
            _transferEth(
                additionalRecipient.recipient,
                additionalRecipientAmount
            );

            // Reduce ether value available.
            etherRemaining -= additionalRecipientAmount;
        }

        // Ensure that sufficient Ether is still available.
        if (amount > etherRemaining) {
            revert InsufficientEtherSupplied();
        }

        // Transfer Ether to the offerer.
        _transferEth(parameters.offerer, amount);

        // If any Ether remains after transfers, return it to the caller.
        if (etherRemaining > amount) {
            // Transfer remaining Ether to the caller.
            _transferEth(payable(msg.sender), etherRemaining - amount);
        }
    }

    /**
     * @dev Internal function to transfer ERC20 tokens to a given recipient as
     *      part of basic order fulfillment. Note that proxies are not utilized
     *      for ERC20 tokens.
     *
     * @param from                  The originator of the ERC20 token transfer.
     * @param to                    The recipient of the ERC20 token transfer.
     * @param erc20Token            The ERC20 token to transfer.
     * @param amount                The amount of ERC20 tokens to transfer.
     * @param parameters            The parameters of the order.
     * @param fromOfferer           Whether to decrement amount from the
     *                              offered amount.
     * @param accumulatorStruct     A struct containing conduit transfer data
     *                              and its corresponding conduitKey.
     */
    function _transferERC20AndFinalize(
        address from,
        address to,
        address erc20Token,
        uint256 amount,
        BasicOrderParameters calldata parameters,
        bool fromOfferer,
        AccumulatorStruct memory accumulatorStruct
    ) internal {
        // Determine the appropriate conduit to utilize.
        bytes32 conduitKey;
        if (fromOfferer) {
            conduitKey = parameters.offererConduitKey;
        } else {
            conduitKey = parameters.fulfillerConduitKey;
        }

        // Iterate over each additional recipient.
        for (uint256 i = 0; i < parameters.additionalRecipients.length; ++i) {
            // Retrieve the additional recipient.
            AdditionalRecipient calldata additionalRecipient = (
                parameters.additionalRecipients[i]
            );

            // Decrement the amount to transfer to fulfiller if indicated.
            if (fromOfferer) {
                amount -= additionalRecipient.amount;
            }

            // Transfer ERC20 tokens to additional recipient given approval.
            _transferERC20(
                erc20Token,
                from,
                additionalRecipient.recipient,
                additionalRecipient.amount,
                conduitKey,
                accumulatorStruct
            );
        }

        // Transfer ERC20 token amount (from account must have proper approval).
        _transferERC20(
            erc20Token,
            from,
            to,
            amount,
            conduitKey,
            accumulatorStruct
        );
    }
}
