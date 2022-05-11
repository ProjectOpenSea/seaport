// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

// prettier-ignore
import {
    OrderType,
    ItemType,
    BasicOrderRouteType
} from "contracts/lib/ConsiderationEnums.sol";

// prettier-ignore
import {
    AdditionalRecipient,
    BasicOrderParameters,
    OfferItem,
    ConsiderationItem,
    SpentItem,
    ReceivedItem
} from "contracts/lib/ConsiderationStructs.sol";

import { AccumulatorStruct, BasicFulfillmentHashes, FulfillmentItemTypes } from "./ReferenceConsiderationStructs.sol";

import { ReferenceOrderValidator } from "./ReferenceOrderValidator.sol";

import "./ReferenceConsiderationConstants.sol";

/**
 * @title BasicOrderFulfiller
 * @author 0age
 * @notice BasicOrderFulfiller contains functionality for fulfilling "basic"
 *         orders.
 */
contract ReferenceBasicOrderFulfiller is ReferenceOrderValidator {
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
    {}

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
        // Declare enums for order type & route to extract from basicOrderType.
        BasicOrderRouteType route = BasicOrderRouteType(
            uint8(parameters.basicOrderType) / 4
        );

        OrderType orderType = OrderType(uint8(parameters.basicOrderType) % 4);

        // Declare additional recipient item type to derive from the route type.
        ItemType additionalRecipientsItemType = ItemType(
            uint8(route) > 1 ? 1 : 0
        );

        {
            // Declare temporary variable for enforcing payable status.
            bool correctPayableStatus = (msg.value != 0 &&
                additionalRecipientsItemType == ItemType.NATIVE) ||
                (msg.value == 0 &&
                    additionalRecipientsItemType == ItemType.ERC20);

            // Revert if msg.value has not been supplied as part of payable
            // routes or has been supplied as part of non-payable routes.
            if (!correctPayableStatus) {
                revert InvalidMsgValue(msg.value);
            }
        }

        // Declare more arguments that will be derived from route and calldata.
        address additionalRecipientsToken = uint8(route) > 3
            ? parameters.offerToken
            : parameters.considerationToken;

        ItemType receivedItemType = uint8(route) > 2
            ? ItemType(uint8(route) - 2)
            : (
                route == BasicOrderRouteType.ERC20_TO_ERC721
                    ? ItemType.ERC20
                    : ItemType.NATIVE
            );

        ItemType offeredItemType = uint8(route) > 3
            ? ItemType.ERC20
            : (
                uint8(route) > 1
                    ? ItemType(uint8(route))
                    : ItemType(uint8(route) + 2)
            );

        // Derive & validate order using parameters and update order status.
        _prepareBasicFulfillmentFromCalldata(
            parameters,
            orderType,
            receivedItemType,
            additionalRecipientsItemType,
            additionalRecipientsToken,
            offeredItemType
        );

        // Read offerer from calldata and place on the stack.
        address payable offerer = parameters.offerer;

        // Declare conduitKey argument used by transfer functions.
        bytes32 conduitKey = uint8(route) > 3
            ? parameters.fulfillerConduitKey
            : parameters.offererConduitKey;

        // Declare transfer accumulator — it will extend memory where needed.
        //bytes memory accumulator = new bytes(32);
        AccumulatorStruct memory accumulatorStruct;

        // Transfer tokens based on the route.
        if (route == BasicOrderRouteType.ETH_TO_ERC721) {
            // Transfer ERC721 to caller using offerer's conduit if applicable.
            _transferERC721(
                parameters.offerToken,
                offerer,
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
                offerer,
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
                offerer,
                msg.sender,
                parameters.offerIdentifier,
                parameters.offerAmount,
                conduitKey,
                accumulatorStruct
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                msg.sender,
                offerer,
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
                offerer,
                msg.sender,
                parameters.offerIdentifier,
                parameters.offerAmount,
                conduitKey,
                accumulatorStruct
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                msg.sender,
                offerer,
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
                offerer,
                parameters.considerationIdentifier,
                parameters.considerationAmount,
                conduitKey,
                accumulatorStruct
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                offerer,
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
                offerer,
                parameters.considerationIdentifier,
                parameters.considerationAmount,
                conduitKey,
                accumulatorStruct
            );

            // Transfer ERC20 tokens to all recipients and wrap up.
            _transferERC20AndFinalize(
                offerer,
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

        return true;
    }

    /**
     * @dev Internal function to calculate the order hash
     *
     * @param hashes                       The array of offerItems and
     *                                     receivedItems hashes.
     * @param parameters                   The parameters of the basic order.
     * @param fulfillmentItemTypes         The fulfillment's item type.
     */
    function _hashOrder(
        BasicFulfillmentHashes memory hashes,
        BasicOrderParameters calldata parameters,
        FulfillmentItemTypes memory fulfillmentItemTypes
    ) internal view returns (bytes32 orderHash) {
        // Read offerer's current nonce from storage and place on the stack.
        uint256 nonce = _getNonce(parameters.offerer);

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
                nonce
            )
        );
    }

    /**
     * @dev Internal function to prepare fulfillment of a basic order with
     *      manual calldata and memory access. This calculates the order hash,
     *      emits an OrderFulfilled event, and asserts basic order validity.
     *      Note that calldata offsets must be validated as this function
     *      accesses constant calldata pointers for dynamic types that match
     *      default ABI encoding, but valid ABI encoding can use arbitrary
     *      offsets. Checking that the offsets were produced by default encoding
     *      will ensure that other functions using Solidity's calldata accessors
     *      (which calculate pointers from the stored offsets) are reading the
     *      same data as the order hash is derived from. Also note that This
     *      function accesses memory directly. It does not clear the expanded
     *      memory regions used, nor does it update the free memory pointer, so
     *      other direct memory access must not assume that unused memory is
     *      empty.
     *
     * @param parameters                   The parameters of the basic order.
     * @param orderType                    The order type.
     * @param receivedItemType             The item type of the initial
     *                                     consideration item on the order.
     * @param additionalRecipientsItemType The item type of any additional
     *                                     consideration item on the order.
     * @param additionalRecipientsToken    The ERC20 token contract adddress (if
     *                                     applicable) for any additional
     *                                     consideration item on the order.
     * @param offeredItemType              The item type of the offered item on
     *                                     the order.
     */
    function _prepareBasicFulfillmentFromCalldata(
        BasicOrderParameters calldata parameters,
        OrderType orderType,
        ItemType receivedItemType,
        ItemType additionalRecipientsItemType,
        address additionalRecipientsToken,
        ItemType offeredItemType
    ) internal {
        // Ensure current timestamp falls between order start time and end time.
        _verifyTime(parameters.startTime, parameters.endTime, true);

        // Verify that calldata offsets for all dynamic types were produced by
        // default encoding. This ensures that the constants we use for calldata
        // pointers to dynamic types are the same as those calculated by
        // Solidity using their offsets.
        _assertValidBasicOrderParameterOffsets();

        // Ensure supplied consideration array length is not less than original.
        _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
            parameters.additionalRecipients.length + 1,
            parameters.totalOriginalAdditionalRecipients
        );

        // Memory to store hashes.
        BasicFulfillmentHashes memory hashes;

        // Store ItemType/Token parameters in a struct in memory to avoid stack issues.
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

            // Declare memory for additionalReceivedItem, additionalRecipientItem.
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
                recipientCount < parameters.additionalRecipients.length;
                recipientCount++
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
                // Add additonal Received items to the
                // OrderFulfilled ReceivedItem[].
                consideration[recipientCount + 1] = additionalReceivedItem;

                // Skip hashing items not contained in the
                // Original Recipients.
                if (
                    recipientCount >=
                    parameters.totalOriginalAdditionalRecipients
                ) {
                    continue;
                }

                // Create a new consideration item for each qdditional recipient.
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
             *  The consideration array now contains all receieved
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
                additionalTips++
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
                // Add additonal received items to the
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
                        offerItem.amount //Assembly uses OfferItem instead of SpentItem.
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
        // Determine whether order is restricted and, if so, that it is valid.
        _assertRestrictedBasicOrderValidity(
            hashes.orderHash,
            parameters.zoneHash,
            orderType,
            parameters.offerer,
            parameters.zone
        );

        // Verify and update the status of the derived order.
        _validateBasicOrderAndUpdateStatus(
            hashes.orderHash,
            parameters.offerer,
            parameters.signature
        );
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
     * @param fromOfferer           Whether to decrement amount from the offered amount.
     * @param accumulatorStruct     A struct containing conduit transfer data and its
     *                              corresponding conduitKey.
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
        bytes32 conduitKey = fromOfferer
            ? parameters.offererConduitKey
            : parameters.fulfillerConduitKey;

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
