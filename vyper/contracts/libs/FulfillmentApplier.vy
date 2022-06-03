# @version 0.3.3

"""
@title      FulfillmentApplier
@author     0age
@notice     FulfillmentApplier contains logic related to applying fulfillments,
            both as part of order matching (where offer items are matched to
            consideration items) as well as fulfilling available orders (where
            order items and consideration items are independently aggregated).
"""

# @dev A spent item is translated from a utilized offer item an has four
#       components: an item type (ETH or other native tokens, ERC20, ERC721, and
#       ERC1155), a token address, a tokenId, and an amount.
struct SpentItem:
    itemType: uint8
    token: address
    identifier: uint256
    amount: uint256

# @dev A received item is translated from a utilized consideration item and has
#      the same four components as a spent item, as well as an additional fifth
#      component designating the required recipient of the item.
struct ReceivedItem:
    itemType: uint8
    token: address
    identifier: uint256
    amount: uint256
    recipient: address

# @dev    A struct that is an explicit version of advancedOrders without
#         memory optimization, that provides an array of spentItems
#         and receivedItems for fulfillment and event emission.
struct OrderToExecute:
    offerer: address
    spentItems: DynArray[SpentItem, 10] # Offer
    receivedItems: DynArray[ReceivedItem, 10] # Consideration
    conduitKey: bytes32
    numerator: uint120

# @dev Each fulfillment component contains one index referencing a specific
#      order and another referencing a specific offer or consideration item.
struct FulfillmentComponent:
    orderIndex: uint256
    itemIndex: uint256

# @dev An execution is triggered once all consideration items have been zeroed
#      out. It sends the item in question from the offerer to the item's
#      recipient, optionally sourcing approvals from either this contract
#      directly or from the offerer's chosen conduit if one is specified. An
#      execution is not provided as an argument, but rather is derived via
#      orders, criteria resolvers, and fulfillments (where the total number of
#      executions will be less than or equal to the total number of indicated
#      fulfillments) and returned as part of `matchOrders`.
struct Execution:
    item: ReceivedItem
    offerer: address
    conduitKey: bytes32

# @dev A struct used to hold Consideration Indexes and Fulfillment validity.
struct ConsiderationItemIndicesAndValidity:
    orderIndex: uint256
    itemIndex: uint256
    validFulfillment: bool

# --- Side Enum ---

# Items that can be spent
SIDE_OFFER: constant(uint8) = 0

@internal
@pure
def _checkMatchingConsideration(
    consideration: ReceivedItem,
    receivedItem: ReceivedItem
) -> bool:
    """
    @dev Internal pure function to check the indicated consideration item matches original item.

    @param consideration  The consideration to compare
    @param receivedItem  The aggregated received item

    @return invalidFulfillment A boolean indicating whether the fulfillment is invalid.
    """
    return (
        receivedItem.recipient != consideration.recipient or
        receivedItem.itemType != consideration.itemType or
        receivedItem.token != consideration.token or
        receivedItem.identifier != consideration.identifier
    )


@internal
@view # convert to pure with next Vyper release
def _aggregateValidFulfillmentConsiderationItems(
    ordersToExecute: DynArray[OrderToExecute, 10],
    considerationComponents: DynArray[FulfillmentComponent, 10],
    startIndex: uint256
) -> ReceivedItem:
    """
    @dev Internal pure function to aggregate a group of consideration items
         using supplied directives on which component items are candidates
         for aggregation, skipping items on orders that are not available.

    @param ordersToExecute         The orders to aggregate consideration
                                   items from.
    @param considerationComponents An array of FulfillmentComponent structs
                                   indicating the order index and item index
                                   of each candidate consideration item for
                                   aggregation.
    @param startIndex              The initial order index to begin iteration
                                   on when searching for consideration items
                                   to aggregate.

    @return receivedItem The aggregated consideration items.
    """
    # Declare struct into avoid declaring multiple local variables
    potentialCandidate: ConsiderationItemIndicesAndValidity = (
        ConsiderationItemIndicesAndValidity({
            orderIndex: considerationComponents[startIndex].orderIndex,
            itemIndex: considerationComponents[startIndex].itemIndex,
            # Ensure that order index is in range.
            validFulfillment: considerationComponents[startIndex].orderIndex < len(ordersToExecute)
        })
    )

    assert potentialCandidate.validFulfillment, "invalid fulfillment component data"

    receivedItem: ReceivedItem = empty(ReceivedItem)

    # Retrieve relevant item using order index.
    orderToExecute: OrderToExecute = ordersToExecute[potentialCandidate.orderIndex]

    # Retrieve relevant item using item index.
    consideration: ReceivedItem = orderToExecute.receivedItems[potentialCandidate.itemIndex]

    # Create the received item.
    receivedItem = ReceivedItem({
        itemType: consideration.itemType,
        token: consideration.token,
        identifier: consideration.identifier,
        amount: consideration.amount,
        recipient: consideration.recipient
    })

    # Zero out amount on original offerItem to indicate it is spent
    consideration.amount = 0

    # Loop through the consideration components and validate
    # their fulfillment.
    for component in considerationComponents:
        # Get the order index and item index of the consideration component.
        potentialCandidate.orderIndex = component.orderIndex
        potentialCandidate.itemIndex = component.itemIndex

        # Get the order based on consideration components order index.
        orderToExecute = ordersToExecute[potentialCandidate.orderIndex]
        # Confirm this is a fulfilled order.
        if orderToExecute.numerator != 0:
            # Retrieve relevant item using item index.
            consideration = orderToExecute.receivedItems[potentialCandidate.itemIndex]
            # Updating Received Item Amount
            receivedItem.amount = receivedItem.amount + consideration.amount
            # Zero out amount on original consideration item to indicate it is spent
            consideration.amount = 0
            # Ensure the indicated consideration item matches original item.
            potentialCandidate.validFulfillment = self._checkMatchingConsideration(
                consideration,
                receivedItem
            )

            # Revert if an order/item was not aggregatable.
            assert potentialCandidate.validFulfillment, "invalid fulfillment component data"

    return receivedItem

@internal
@pure
def _checkMatchingOffer(
    orderToExecute: OrderToExecute,
    offer: SpentItem,
    execution: Execution
) -> bool:
    """
    @dev Internal pure function to check the indicated offer item matches original item.

    @param orderToExecute  The order to compare.
    @param offer The offer to compare
    @param execution  The aggregated offer item

    @return invalidFulfillment A boolean indicating whether the fulfillment is invalid.
    """
    return (
        execution.item.identifier == offer.identifier and
        execution.offerer == orderToExecute.offerer and
        execution.conduitKey == orderToExecute.conduitKey and
        execution.item.itemType == offer.itemType and
        execution.item.token == offer.token
    )

@internal
@view
def _aggregateValidFulfillmentOfferItems(
    ordersToExecute: DynArray[OrderToExecute, 10],
    offerComponents: DynArray[FulfillmentComponent, 10],
    startIndex: uint256
) -> Execution:
    """
    @dev Internal pure function to aggregate a group of offer items using
         supplied directives on which component items are candidates for
         aggregation, skipping items on orders that are not available.

    @param ordersToExecute The orders to aggregate offer items from.
    @param offerComponents An array of FulfillmentComponent structs
                           indicating the order index and item index of each
                           candidate offer item for aggregation.
    @param startIndex      The initial order index to begin iteration on when
                           searching for offer items to aggregate.

    @return execution The aggregated offer items.
    """
    # Get the order index and item index of the offer component.
    orderIndex: uint256 = offerComponents[startIndex].orderIndex
    itemIndex: uint256 = offerComponents[startIndex].itemIndex

    execution: Execution = empty(Execution)

    # Get the order based on offer components order index.
    orderToExecute: OrderToExecute = ordersToExecute[orderIndex]
    # Get the spent item based on the offer components item index.
    offer: SpentItem = orderToExecute.spentItems[itemIndex]

    # Create the Execution.
    execution = Execution({
        item: ReceivedItem({
            itemType: offer.itemType,
            token: offer.token,
            identifier: offer.identifier,
            amount: offer.amount,
            recipient: msg.sender
        }),
        offerer: orderToExecute.offerer,
        conduitKey: orderToExecute.conduitKey
    })

    # Zero out amount on original offerItem to indicate it is spent
    offer.amount = 0

    # Loop through the offer components, checking for validity.
    for component in offerComponents:
        # Get the order index and item index of the offer component.
        orderIndex = component.orderIndex
        itemIndex = component.itemIndex

        # Get the order based on offer components order index.
        orderToExecute = ordersToExecute[orderIndex]
        if orderToExecute.numerator != 0:
            # Get the spent item based on the offer components item index.
            offer = orderToExecute.spentItems[itemIndex]
            # Update the Received Item Amount.
            execution.item.amount = execution.item.amount + offer.amount
            # Zero out amount on original offerItem to indicate it is spent,
            offer.amount = 0
            # Ensure the indicated offer item matches original item.
            validFulfillment: bool = self._checkMatchingOffer(
                orderToExecute,
                offer,
                execution
            )

            # Revert if an order/item was not aggregatable.
            assert validFulfillment, "InvalidFulfillmentComponentData"

    return execution

@internal
@view
def _applyFulfillment(
    ordersToExecute: DynArray[OrderToExecute, 10],
    offerComponents: DynArray[FulfillmentComponent, 10],
    considerationComponents: DynArray[FulfillmentComponent, 10]
) -> Execution:
    """
    @dev    Internal view function to match offer items to consideration items
            on a group of orders via a supplied fulfillment.
    @param ordersToExecute  The orders to match.
    @param offerComponents  An array designating offer components to
                            match to consideration components.
    @param considerationComponents  An array designating consideration
                                    components to match to offer components.
                                    Note that each consideration amount must
                                    be zero in order for the match operation
                                    to be valid.

    @return execution The transfer performed as a result of the fulfillment.
    """
    # Ensure 1+ of both offer and consideration components are supplied.
    assert len(offerComponents) != 0 and len(considerationComponents) != 0,\
        "offer and consideration required on fulfillment"

    # Validate and aggregate consideration items and store the result as a
    # ReceivedItem.
    considerationItem: ReceivedItem = self._aggregateValidFulfillmentConsiderationItems(
        ordersToExecute,
        considerationComponents,
        0
    )


    # Validate & aggregate offer items and store result as an Execution.
    execution: Execution = self._aggregateValidFulfillmentOfferItems(
        ordersToExecute,
        offerComponents,
        0
    )

    # Ensure offer and consideration share types, tokens and identifiers.
    assert (execution.item.itemType == considerationItem.itemType
        and execution.item.token == considerationItem.token
        and execution.item.identifier == considerationItem.identifier),\
        "mismatched fulfillment offer and consideration components"

    # If total consideration amount exceeds the offer amount...
    if considerationItem.amount > execution.item.amount:
        # Retrieve the first consideration component from the fulfillment.
        targetComponent: FulfillmentComponent = considerationComponents[0]

        # Add excess consideration item amount to original array of orders.
        (
            ordersToExecute[targetComponent.orderIndex]
                .receivedItems[targetComponent.itemIndex]
                .amount
        ) = considerationItem.amount - execution.item.amount

        # Reduce total consideration amount to equal the offer amount.
        considerationItem.amount = execution.item.amount
    else:
        # Retrieve the first offer component from the fulfillment.
        targetComponent: FulfillmentComponent = offerComponents[0]

        # Add excess offer item amount to the original array of orders.
        (
            ordersToExecute[targetComponent.orderIndex]
                .spentItems[targetComponent.itemIndex]
                .amount
        ) = execution.item.amount - considerationItem.amount

    # Reuse execution struct with consideration amount and recipient.
    execution.item.amount = considerationItem.amount
    execution.item.recipient = considerationItem.recipient

    # Return the final execution that will be triggered for relevant items.
    return execution # Execution(considerationItem, offerer, conduitKey)


@internal
@view
def _aggregateConsiderationItems(
    ordersToExecute: DynArray[OrderToExecute, 10],
    considerationComponents: DynArray[FulfillmentComponent, 10],
    nextComponentIndex: uint256,
    fulfillerConduitKey: bytes32
) -> Execution:
    """
    @dev Internal view function to aggregate consideration items from a group
         of orders into a single execution via a supplied components array.
         Consideration items that are not available to aggregate will not be
         included in the aggregated execution.

    @param ordersToExecute         The orders to aggregate.
    @param considerationComponents An array designating consideration
                                   components to aggregate if part of an
                                   available order.
    @param nextComponentIndex      The index of the next potential
                                   consideration component.
    @param fulfillerConduitKey     A bytes32 value indicating what conduit,
                                   if any, to source the fulfiller's token
                                   approvals from. The zero hash signifies
                                   that no conduit should be used (and direct
                                   approvals set on Consideration)

    @return execution The transfer performed as a result of the fulfillment.
    """
    # Validate and aggregate consideration items on available orders and
    # store result as a ReceivedItem.
    receiveConsiderationItem: ReceivedItem = self._aggregateValidFulfillmentConsiderationItems(
        ordersToExecute,
        considerationComponents,
        nextComponentIndex)


    # Return execution for aggregated items provided by the fulfiller.
    execution: Execution  = Execution({
        item: receiveConsiderationItem,
        offerer: msg.sender,
        conduitKey: fulfillerConduitKey
    })
    return execution

@internal
@view
def _aggregateAvailable(
    ordersToExecute: DynArray[OrderToExecute, 10],
    side: uint8,
    fulfillmentComponents: DynArray[FulfillmentComponent, 10],
    fulfillerConduitKey: bytes32
) -> Execution:
    """
    @dev Internal view function to aggregate offer or consideration items
         from a group of orders into a single execution via a supplied array
         of fulfillment components. Items that are not available to aggregate
         will not be included in the aggregated execution.

    @param ordersToExecute       The orders to aggregate.
    @param side                  The side (i.e. offer or consideration).
    @param fulfillmentComponents An array designating item components to
                                 aggregate if part of an available order.
    @param fulfillerConduitKey   A bytes32 value indicating what conduit, if
                                 any, to source the fulfiller's token
                                 approvals from. The zero hash signifies that
                                 no conduit should be used (and direct
                                 approvals set on Consideration)

    @return execution The transfer performed as a result of the fulfillment.
    """
    # Retrieve fulfillment components array length and place on stack.
    totalFulfillmentComponents: uint256 = len(fulfillmentComponents)

    # Ensure at least one fulfillment component has been supplied.
    assert totalFulfillmentComponents != 0, "missing fulfillment component on aggregation"

    # Determine component index after first available (0 implies none).
    nextComponentIndex: uint256 = 0

    # Iterate over components until finding one with a fulfilled order.
    index: uint256 = 0
    for component in fulfillmentComponents:
        # Retrieve the fulfillment component index.
        orderIndex: uint256 = component.orderIndex

        # If order is being fulfilled (i.e. it is still available)...
        if ordersToExecute[orderIndex].numerator != 0:
            # Update the next potential component index.
            nextComponentIndex = index

            # Exit the loop.
            break

        index += 1

    # If no available order was located...
    if index == len(fulfillmentComponents):
        # Return with an empty execution element that will be filtered.
        return empty(Execution)

    # If the fulfillment components are offer components...
    if side == SIDE_OFFER:
        # Return execution for aggregated items provided by offerer.
        return self._aggregateValidFulfillmentOfferItems(
            ordersToExecute,
            fulfillmentComponents,
            nextComponentIndex
        )
    else:
        # Otherwise, fulfillment components are consideration
        # components. Return execution for aggregated items provided by
        # the fulfiller.
        return self._aggregateConsiderationItems(
            ordersToExecute,
            fulfillmentComponents,
            nextComponentIndex,
            fulfillerConduitKey
        )
