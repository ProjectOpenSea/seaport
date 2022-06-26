# @version 0.3.4

#pragma once
#include "ConsiderationEnums.vy"

MAX_DYN_ARRAY_LENGTH: constant(uint256) = 100

#
# @dev An offer item has five components: an item type (ETH or other native
#      tokens, ERC20, ERC721, and ERC1155, as well as criteria-based ERC721 and
#      ERC1155), a token address, a dual-purpose "identifierOrCriteria"
#      component that will either represent a tokenId or a merkle root
#      depending on the item type, and a start and end amount that support
#      increasing or decreasing amounts over the duration of the respective
#      order.
#
struct OfferItem:
    itemType: ItemType
    token: address
    identifierOrCriteria: uint256
    startAmount: uint256
    endAmount: uint256

#
# @dev A consideration item has the same five components as an offer item and
#      an additional sixth component designating the required recipient of the
#      item.
#
struct ConsiderationItem:
    itemType: ItemType
    token: address
    identifierOrCriteria: uint256
    startAmount: uint256
    endAmount: uint256
    recipient: address

#
# @dev An order contains eleven components: an offerer, a zone (or account that
#      can cancel the order or restrict who can fulfill the order depending on
#      the type), the order type (specifying partial fill support as well as
#      restricted order status), the start and end time, a hash that will be
#      provided to the zone when validating restricted orders, a salt, a key
#      corresponding to a given conduit, a counter, and an arbitrary number of
#      offer items that can be spent along with consideration items that must
#      be received by their respective recipient.
#
struct OrderComponents:
    offerer: address
    zone: address
    offer: DynArray[OfferItem, MAX_DYN_ARRAY_LENGTH]
    consideration: DynArray[ConsiderationItem, MAX_DYN_ARRAY_LENGTH]
    orderType: OrderType 
    startTime: uint256
    endTime: uint256
    zoneHash: bytes32
    salt: uint256
    conduitKey: bytes32
    counter: uint256

#
# @dev A spent item is translated from a utilized offer item and has four
#      components: an item type (ETH or other native tokens, ERC20, ERC721, and
#      ERC1155), a token address, a tokenId, and an amount.
#
struct SpentItem:
    itemType: ItemType
    token: address
    identifier: uint256
    amount: uint256

#
# @dev A received item is translated from a utilized consideration item and has
#      the same four components as a spent item, as well as an additional fifth
#      component designating the required recipient of the item.
#
struct ReceivedItem:
    itemType: ItemType
    token: address
    identifier: uint256
    amount: uint256
    recipient: address

#
# @dev Basic orders can supply any number of additional recipients, with the
#      implied assumption that they are supplied from the offered ETH (or other
#      native token) or ERC20 token for the order.
#
struct AdditionalRecipient:
    amount: uint256
    recipient: address

#
# @dev For basic orders involving ETH / native / ERC20 <=> ERC721 / ERC1155
#      matching, a group of six functions may be called that only requires a
#      subset of the usual order arguments. Note the use of a "basicOrderType"
#      enum; this represents both the usual order type as well as the "route"
#      of the basic order (a simple derivation function for the basic order
#      type is `basicOrderType = orderType + (4 * basicOrderRoute)`.)
#
struct BasicOrderParameters:
    # calldata offset
    considerationToken: address # 0x24
    considerationIdentifier: uint256 # 0x44
    considerationAmount: uint256 # 0x64
    offerer: address # 0x84
    zone: address # 0xa4
    offerToken: address # 0xc4
    offerIdentifier: uint256 # 0xe4
    offerAmount: uint256 # 0x104
    basicOrderType: BasicOrderType # 0x124
    startTime: uint256 # 0x144
    endTime: uint256 # 0x164
    zoneHash: bytes32 # 0x184
    salt: uint256 # 0x1a4
    offererConduitKey: bytes32 # 0x1c4
    fulfillerConduitKey: bytes32 # 0x1e4
    totalOriginalAdditionalRecipients: uint256 # 0x204
    additionalRecipients: DynArray[AdditionalRecipient, MAX_DYN_ARRAY_LENGTH] # 0x224
    signature: DynArray[bytes1, MAX_DYN_ARRAY_LENGTH] # 0x244
    # Total length, excluding dynamic array data: 0x264 (580)

#
# @dev The full set of order components, with the exception of the counter,
#      must be supplied when fulfilling more sophisticated orders or groups of
#      orders. The total number of original consideration items must also be
#      supplied, as the caller may specify additional consideration items.
#
struct OrderParameters:
    offerer: address # 0x00
    zone: address # 0x20
    offer: DynArray[OfferItem, MAX_DYN_ARRAY_LENGTH] # 0x40
    consideration: DynArray[ConsiderationItem, MAX_DYN_ARRAY_LENGTH] # 0x60
    orderType: OrderType # 0x80
    startTime: uint256 # 0xa0
    endTime: uint256 # 0xc0
    zoneHash: bytes32 # 0xe0
    salt: uint256 # 0x100
    conduitKey: bytes32 # 0x120
    totalOriginalConsiderationItems: uint256 # 0x140
    # offer.length                          # 0x160

#
# @dev Orders require a signature in addition to the other order parameters.
#
struct Order:
    parameters: OrderParameters
    signature: DynArray[bytes1, MAX_DYN_ARRAY_LENGTH]

#
# @dev Advanced orders include a numerator (i.e. a fraction to attempt to fill)
#      and a denominator (the total size of the order) in addition to the
#      signature and other order parameters. It also supports an optional field
#      for supplying extra data; this data will be included in a staticcall to
#      `isValidOrderIncludingExtraData` on the zone for the order if the order
#      type is restricted and the offerer or zone are not the caller.
#
struct AdvancedOrder:
    parameters: OrderParameters
    numerator: uint120
    denominator: uint120
    signature: DynArray[bytes1, MAX_DYN_ARRAY_LENGTH]
    extraData: DynArray[bytes1, MAX_DYN_ARRAY_LENGTH]

#
# @dev Orders can be validated (either explicitly via `validate`, or as a
#      consequence of a full or partial fill), specifically cancelled (they can
#      also be cancelled in bulk via incrementing a per-zone counter), and
#      partially or fully filled (with the fraction filled represented by a
#      numerator and denominator).
#
struct OrderStatus:
    isValidated: bool
    isCancelled: bool
    numerator: uint120
    denominator: uint120

#
# @dev A criteria resolver specifies an order, side (offer vs. consideration),
#      and item index. It then provides a chosen identifier (i.e. tokenId)
#      alongside a merkle proof demonstrating the identifier meets the required
#      criteria.
#
struct CriteriaResolver:
    orderIndex: uint256
    side: Side
    index: uint256
    identifier: uint256
    criteriaProof: DynArray[bytes32, MAX_DYN_ARRAY_LENGTH]


#
# @dev Each fulfillment component contains one index referencing a specific
#      order and another referencing a specific offer or consideration item.
#
struct FulfillmentComponent:
    orderIndex: uint256
    itemIndex: uint256

#
# @dev A fulfillment is applied to a group of orders. It decrements a series of
#      offer and consideration items, then generates a single execution
#      element. A given fulfillment can be applied to as many offer and
#      consideration items as desired, but must contain at least one offer and
#      at least one consideration that match. The fulfillment must also remain
#      consistent on all key parameters across all offer items (same offerer,
#      token, type, tokenId, and conduit preference) as well as across all
#      consideration items (token, type, tokenId, and recipient).
#
struct Fulfillment:
    offerComponents: DynArray[FulfillmentComponent, MAX_DYN_ARRAY_LENGTH]
    considerationComponents: DynArray[FulfillmentComponent, MAX_DYN_ARRAY_LENGTH]

#
# @dev An execution is triggered once all consideration items have been zeroed
#      out. It sends the item in question from the offerer to the item's
#      recipient, optionally sourcing approvals from either this contract
#      directly or from the offerer's chosen conduit if one is specified. An
#      execution is not provided as an argument, but rather is derived via
#      orders, criteria resolvers, and fulfillments (where the total number of
#      executions will be less than or equal to the total number of indicated
#      fulfillments) and returned as part of `matchOrders`.
#
struct Execution:
    item: ReceivedItem
    offerer: address
    conduitKey: bytes32
