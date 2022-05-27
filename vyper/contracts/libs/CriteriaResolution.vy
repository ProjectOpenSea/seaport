# @version 0.3.3

MAX_ITEM_COUNT: constant(uint8) = 100


# --- Side Enum ---

# Items that can be spent
SIDE_OFFER: constant(uint8) = 0

# Items that must be received
SIDE_CONSIDERATION: constant(uint8) = 1


# --- ItemType Enum ---

# ETH on mainnet, MATIC on polygon, etc.
ITEM_TYPE_NATIVE: constant(uint8) = 0

# ERC20 items (ERC777 and ERC20 analogues could also technically work)
ITEM_TYPE_ERC20: constant(uint8) = 1

# ERC721 items
ITEM_TYPE_ERC721: constant(uint8) = 2

# ERC1155 items
ITEM_TYPE_ERC1155: constant(uint8) = 3

# ERC721 items where a number of tokenIds are supported
ITEM_TYPE_ERC721_WITH_CRITERIA: constant(uint8) = 4

# ERC1155 items where a number of ids are supported
ITEM_TYPE_ERC1155_WITH_CRITERIA: constant(uint8) = 5


# @dev An offer item has five components: an item type (ETH or other native
#     tokens, ERC20, ERC721, and ERC1155, as well as criteria-based ERC721 and
#     ERC1155), a token address, a dual-purpose "identifierOrCriteria"
#     component that will either represent a tokenId or a merkle root
#     depending on the item type, and a start and end amount that support
#     increasing or decreasing amounts over the duration of the respective
#     order.
struct OfferItem:
    itemType: uint8
    token: address
    identifierOrCriteria: uint256
    startAmount: uint256
    endAmount: uint256


# @dev A consideration item has the same five components as an offer item and
#      an additional sixth component designating the required recipient of the
#      item.
struct ConsiderationItem:
    itemType: uint8
    token: address
    identifierOrCriteria: uint256
    startAmount: uint256
    endAmount: uint256
    recipient: address


# @dev The full set of order components, with the exception of the nonce, must
#      be supplied when fulfilling more sophisticated orders or groups of
#      orders. The total number of original consideration items must also be
#      supplied, as the caller may specify additional consideration items.
struct OrderParameters:
    offerer: address
    zone: address
    offer: DynArray[OfferItem, MAX_ITEM_COUNT]
    consideration: DynArray[ConsiderationItem, MAX_ITEM_COUNT]
    orderType: uint8
    startTime: uint256
    endTime: uint256
    zoneHash: bytes32
    salt: uint256
    conduitKey: bytes32
    totalOriginalConsiderationItems: uint256

# @dev Advanced orders include a numerator (i.e. a fraction to attempt to fill)
#      and a denominator (the total size of the order) in addition to the
#      signature and other order parameters. It also supports an optional field
#      for supplying extra data; this data will be included in a staticcall to
#      `isValidOrderIncludingExtraData` on the zone for the order if the order
#      type is restricted and the offerer or zone are not the caller.
struct AdvancedOrder:
    parameters: OrderParameters
    numerator: uint120
    denominator: uint120
    signature: Bytes[MAX_ITEM_COUNT]
    extraData: Bytes[MAX_ITEM_COUNT]

# @dev A criteria resolver specifies an order, side (offer vs. consideration),
#      and item index. It then provides a chosen identifier (i.e. tokenId)
#      alongside a merkle proof demonstrating the identifier meets the required
#      criteria.
struct CriteriaResolver:
    orderIndex: uint256
    side: uint8
    index: uint256
    identifier: uint256
    criteriaProof: DynArray[bytes32, MAX_ITEM_COUNT]


@internal
@pure
def _isItemWithCriteria(itemType: uint8) -> (bool):
    """
    @dev Internal pure function to check whether a given item type represents
         a criteria-based ERC721 or ERC1155 item (e.g. an item that can be
         resolved to one of a number of different identifiers at the time of
         order fulfillment).

    @param itemType The item type in question.

    @return withCriteria A boolean indicating that the item type in question
                         represents a criteria-based item.
    """

    # ERC721WithCriteria is ItemType 4. ERC1155WithCriteria is ItemType 5.
    return itemType > ITEM_TYPE_ERC1155


@internal
@pure
def _verifyProof(
    leaf: uint256, 
    root: uint256, 
    proof: DynArray[bytes32, MAX_ITEM_COUNT]
) -> (bool):
    """
    @dev Internal pure function to ensure that a given element is contained
         in a merkle root via a supplied proof.

    @param leaf  The element for which to prove inclusion.
    @param root  The merkle root that inclusion will be proved against.
    @param proof The merkle proof.
    """

    # Start the hash off as just the starting leaf.
    computedHash: uint256 = leaf

    # Iterate over proof elements to compute root hash.
    for data in proof:
        loadedData: uint256 = convert(data, uint256)

        if computedHash > loadedData:
            computedHash = convert(
                keccak256(_abi_encode(computedHash, loadedData)), uint256)
        else:
            computedHash = convert(
                keccak256(_abi_encode(loadedData, computedHash)), uint256)

    # Compare the final hash to the supplied root.
    isValid: bool = computedHash == root

    # Revert if computed hash does not equal supplied root.
    assert isValid, "Invalid Proof"

    return isValid


@internal
@view
def _applyCriteriaResolvers(
    advancedOrders: DynArray[AdvancedOrder, MAX_ITEM_COUNT], 
    criteriaResolvers: DynArray[CriteriaResolver, MAX_ITEM_COUNT]
):
    """
    @dev Internal view function to apply criteria resolvers containing
         specific token identifiers and associated proofs to order items.

    @param advancedOrders     The orders to apply criteria resolvers to.
    @param criteriaResolvers  An array where each element contains a
                              reference to a specific order as well as that
                              order's offer or consideration, a token
                              identifier, and a proof that the supplied token
                              identifier is contained in the order's merkle
                              root. Note that a root of zero indicates that
                              any transferrable token identifier is valid and
                              that no proof needs to be supplied.
    """
    # Retrieve length of orders array and place on stack.
    totalAdvancedOrders: uint256 = len(advancedOrders)

    # Iterate over each criteria resolver.
    for criteriaResolver in criteriaResolvers:
        orderIndex: uint256 = criteriaResolver.orderIndex

        # Ensure that the order index is in range.
        assert orderIndex >= totalAdvancedOrders, "Order Criteria Resolver Out of Range"

        # Skip criteria resolution for order if not fulfilled.
        if advancedOrders[orderIndex].numerator == 0:
            continue

        # Retrieve the parameters for the order.
        orderParameters: OrderParameters = advancedOrders[orderIndex].parameters

        # Read component index from memory and place it on the stack.
        componentIndex: uint256 = criteriaResolver.index

        # Declare values for item's type and criteria.
        itemType: uint8 = 0
        identifierOrCriteria: uint256 = 0

        if criteriaResolver.side == SIDE_OFFER:
            # Retrieve the offer.
            offer: DynArray[OfferItem, MAX_ITEM_COUNT] = orderParameters.offer

            # Ensure that the component index is in range.
            if componentIndex >= len(offer):
                raise "Offer Criteria Resolver Out of Range"

            # Retrieve relevant item using the component index.
            offerItem: OfferItem = offer[componentIndex]

            # Read item type and criteria from memory & place on stack.
            itemType = offerItem.itemType
            identifierOrCriteria = offerItem.identifierOrCriteria

            # Optimistically update item type to remove criteria usage.
            if itemType == ITEM_TYPE_ERC721_WITH_CRITERIA:
                offerItem.itemType = ITEM_TYPE_ERC721
            else:
                offerItem.itemType = ITEM_TYPE_ERC1155

            # Optimistically update identifier w/ supplied identifier.
            offerItem.identifierOrCriteria = criteriaResolver.identifier
        else:
            # Otherwise, the resolver refers to a consideration item.
            consideration: DynArray[ConsiderationItem,
                                    MAX_ITEM_COUNT] = orderParameters.consideration

            # Ensure that the component index is in range.
            if componentIndex >= len(consideration):
                raise "Consideration Criteria Resolver Out of Range"

            # Retrieve relevant item using order and component index.
            considerationItem: ConsiderationItem = consideration[componentIndex]

            # Read item type and criteria from memory & place on stack.
            itemType = considerationItem.itemType
            identifierOrCriteria = considerationItem.identifierOrCriteria

            # Optimistically update item type to remove criteria usage.
            if itemType == ITEM_TYPE_ERC721_WITH_CRITERIA:
                considerationItem.itemType = ITEM_TYPE_ERC721
            else:
                considerationItem.itemType = ITEM_TYPE_ERC1155

            # Optimistically update identifier w/ supplied identifier.
            considerationItem.identifierOrCriteria = criteriaResolver.identifier

        # Ensure the specified item type indicates criteria usage.

        if not self._isItemWithCriteria(itemType):
            raise "Criteria Not Enabled For Item"

        if identifierOrCriteria != 0:
            self._verifyProof(criteriaResolver.identifier,
                              identifierOrCriteria, criteriaResolver.criteriaProof)

    # Iterate over each advanced order.
    for advancedOrder in advancedOrders:
        # Skip criteria resolution for order if not fulfilled.
        if advancedOrder.numerator == 0:
            continue

        # Retrieve the parameters for the order.
        orderParameters: OrderParameters = advancedOrder.parameters

        # Iterate over each consideration item on the order.
        for considerationItem in orderParameters.consideration:
            # Ensure item type no longer indicates criteria usage.
            if self._isItemWithCriteria(considerationItem.itemType):
                raise "Unresolved Consideration Criteria"

        # Iterate over each offer item on the order.
        for offerItem in orderParameters.offer:
            # Ensure item type no longer indicates criteria usage.
            if self._isItemWithCriteria(offerItem.itemType):
                raise "Unresolved Offer Criteria"
