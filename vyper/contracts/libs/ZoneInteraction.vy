# @version ^0.3.3


interface ZoneInteraction:
    def isValidOrder(
        orderHash: bytes32,
        caller: address,
        offerer: address,
        zoneHash: bytes32
    ) -> bytes4: view

    def isValidOrderIncludingExtraData(
        orderHash: bytes32,
        caller: address,
        order: AdvancedOrder,
        priorOrderHashes: DynArray[bytes32, 10],
        criteriaResolvers: DynArray[CriteriaResolver, 10]
    ) -> bytes4: view


struct OfferItem:
    itemType: uint256
    token: address
    identifierOrCriteria: uint256
    startAmount: uint256
    endAmount: uint256


struct ConsiderationItem:
    itemType: uint256
    token: address
    identifierOrCriteria: uint256
    startAmount: uint256
    endAmount: uint256
    recipient: address


struct OrderParameters:
    offerer: address
    zone: address
    offer: DynArray[OfferItem, 10]
    consideration: DynArray[ConsiderationItem, 10]
    orderType: uint256
    startTime: uint256
    endTime: uint256
    zoneHash: bytes32
    salt: uint256
    conduitKey: bytes32
    totalOriginalConsiderationItems: uint256


struct AdvancedOrder:
    parameters: OrderParameters
    numerator: uint120
    denominator: uint120
    signature: Bytes[1024]
    extraData: Bytes[1024]


struct CriteriaResolver:
    orderIndex: uint256
    side: uint256
    index: uint256
    identifier: uint256
    criteriaProof: DynArray[bytes32, 10]


IS_VALID_ORDER_MAGIC_VALUE: constant(bytes4) = 0x0e1d31dc


@internal
@view
def _callIsValidOrder(
    zone: address,
    orderHash: bytes32,
    offerer: address,
    zoneHash: bytes32
):

    res: bytes4 = ZoneInteraction(zone).isValidOrder(orderHash, msg.sender, offerer, zoneHash)
    assert res == IS_VALID_ORDER_MAGIC_VALUE, "Invalid order"


@internal
@view
def _assertRestrictedBasicOrderValidity(
    orderHash: bytes32,
    zoneHash: bytes32,
    orderType: uint256,
    offerer: address,
    zone: address
):
    """
    @dev Internal view function to determine if an order has a restricted order
         type and, if so, to ensure that either the offerer or the zone are the
         fulfiller or that a call to `isValidOrder` on the zone returns a
         magic value indicating that the order is currently valid.

    @param orderHash The hash of the order.
    @param zoneHash  The hash to provide upon calling the zone.
    @param orderType The type of the order.
    @param offerer   The offerer in question.
    @param zone      The zone in question.
    """

    if orderType > 1 and msg.sender != zone and msg.sender != offerer:
        self._callIsValidOrder(zone, orderHash, offerer, zoneHash)


@internal
@view
def _assertRestrictAdvancedOrderValidity(
    advancedOrder: AdvancedOrder,
    criteriaResolvers: DynArray[CriteriaResolver, 10],
    priorOrderHashes: DynArray[bytes32, 10],
    orderHash: bytes32,
    zoneHash: bytes32,
    orderType: uint256,
    offerer: address,
    zone: address
):
    """
    @dev Internal view function to determine whether an order is a restricted
         order and, if so, to ensure that it was either submitted by the
         offerer or the zone for the order, or that the zone returns the
         expected magic value upon performing a call to `isValidOrder`
         or `isValidOrderIncludingExtraData` depending on whether the order
         fulfillment specifies extra data or criteria resolvers.

    @param advancedOrder     The advanced order in question.
    @param criteriaResolvers An array where each element contains a reference
                             to a specific offer or consideration, a token
                             identifier, and a proof that the supplied token
                             identifier is contained in the order's merkle
                             root. Note that a criteria of zero indicates
                             that any (transferrable) token identifier is
                             valid and that no proof needs to be supplied.
    @param priorOrderHashes  The order hashes of each order supplied prior to
                             the current order as part of a "match" variety
                             of order fulfillment (e.g. this array will be
                             empty for single or "fulfill available").
    @param orderHash         The hash of the order.
    @param zoneHash          The hash to provide upon calling the zone.
    @param orderType         The type of the order.
    @param offerer           The offerer in question.
    @param zone              The zone in question.
    """
    if orderType > 1 and msg.sender != zone and msg.sender != offerer:
        if len(advancedOrder.extraData) == 0 and len(criteriaResolvers) == 0:
            self._callIsValidOrder(zone, orderHash, offerer, zoneHash)

        else:
            res: bytes4 = ZoneInteraction(zone).isValidOrderIncludingExtraData(
                orderHash,
                msg.sender,
                advancedOrder,
                priorOrderHashes,
                criteriaResolvers
            )

            assert res == IS_VALID_ORDER_MAGIC_VALUE, "Invalid order"
