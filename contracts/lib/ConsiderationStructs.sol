// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {
    OrderType,
    ItemType,
    Side
} from "./ConsiderationEnums.sol";

/*
 * @dev An order contains nine components: an offerer, a zone (or account that
 * can cancel the order or restrict who can fulfill the order depending on the
 * type), the order type (specifing partial fill support, restricted fulfillers,
 * and the offerer's proxy usage preference), the start and end time, a salt,
 * a nonce, and an arbitrary number of offer items that can be spent along with
 * consideration items that must be received by their respective recipient.
 */
struct OrderComponents {
    address offerer;
    address zone;
    OfferedItem[] offer;
    ReceivedItem[] consideration;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    uint256 salt;
    uint256 nonce;
}

/*
 * @dev An offered item has five components: an item type (ETH, ERC20, ERC721,
 * and ERC1155, as well as criteria-based ERC721 and ERC1155), a token address,
 * a dual-purpose "identifierOrCriteria" component that will either represent a
 * tokenId or a merkle root depending on the item type, and a start and end
 * amount that support increasing or decreasing amounts over the duration of the
 * respective order.
 */
struct OfferedItem {
    ItemType itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
}

/*
 * @dev A received item has the same five components as an offered item and an
 * additional sixth component designating the required recipient of the item.
 */
struct ReceivedItem {
    ItemType itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
    address payable recipient;
}

/*
 * @dev For basic orders involving ETH / ERC20 <=> ERC721 / ERC1155 matching, a
 * group of six functions may be called that only requires a subset of the usual
 * order arguments.
 */
struct BasicOrderParameters {
    address payable offerer;
    address zone;
    OrderType orderType;
    address token;
    uint256 identifier;
    uint256 startTime;
    uint256 endTime;
    uint256 salt;
    bool useFulfillerProxy;
    bytes signature;
    AdditionalRecipient[] additionalRecipients;
}

/*
 * @dev Basic orders can supply any number of additional recipients, with the
 * implied assumption that they are supplied from the offered ETH or ERC20
 * token for the order.
 */
struct AdditionalRecipient {
    address payable recipient;
    uint256 amount;
}

/*
 * @dev The full set of order components, with the exception of the nonce, must
 * be supplied when fulfilling more sophisticated orders or groups of orders.
 */
struct OrderParameters {
    address offerer;
    address zone;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    uint256 salt;
    OfferedItem[] offer;
    ReceivedItem[] consideration;
}

/*
 * @dev Orders require a signature in addition to the other order parameters.
 */
struct Order {
    OrderParameters parameters;
    bytes signature;
}

/*
 * @dev Partial orders include a numerator (i.e. the fraction to attempt to fill)
 * and a denominator (the total size of the order) in additon to the signature
 * and other order parameters.
 */
struct PartialOrder {
    OrderParameters parameters;
    uint120 numerator;
    uint120 denominator;
    bytes signature;
}

/*
 * @dev Orders can be validated (either explicitly via `validate`, or as a
 * consequence of a full or partial fill), specifically cancelled (they can also
 * be cancelled in bulk via incrementing a per-zone nonce), and partially or
 * fully filled (with the fraction filled represented by a numerator and
 * denominator).
 */
struct OrderStatus {
    bool isValidated;
    bool isCancelled;
    uint120 numerator;
    uint120 denominator;
}

/*
 * @dev A criteria resolver specifies an order, side (offer vs. consideration),
 * and item index. It then provides a chosen identifier (i.e. tokenId) alongside
 * a merkle proof demonstrating that the identifier meets the required criteria.
 */
struct CriteriaResolver {
    uint256 orderIndex;
    Side side;
    uint256 index;
    uint256 identifier;
    bytes32[] criteriaProof;
}

/*
 * @dev A fulfillment is applied to a group of orders. It decrements a series of
 * offer and consideration items, then generates a single execution element. A
 * given fulfillment can be applied to as many offer and consideration items as
 * desired, but must contain at least one offer and at least one consideration
 * that match. The fulfillment must also remain consistent on all key parameters
 * across all offer items (same offerer, token, type, tokenId, and proxy
 * preference) as well as across all consideration items (token, type, tokenId,
 * and recipient).
 */
struct Fulfillment {
    FulfillmentComponent[] offerComponents;
    FulfillmentComponent[] considerationComponents;
}

/*
 * @dev Each fulfullment component contains an index referencing a specific
 * order as well as an index referencing a specific offer or consideration item.
 */
struct FulfillmentComponent {
    uint256 orderIndex;
    uint256 itemIndex;
}

/*
 * @dev An execution is triggered once all consideration items have been zeroed
 * out. It sends the item in question from the offerer to the item's recipient,
 * optionally sourcing approvals from either this contract directly or from the
 * offerer's proxy contract if one is available. An execution is not provided as
 * an argument, but rather is derived via orders, criteria resolvers, and
 * fulfillments and returned as part of `matchOrders`.
 */
struct Execution {
    ReceivedItem item;
    address offerer;
    bool useProxy;
}

/*
 * @dev A batch execution operates in a similar fashion to a standard execution,
 * but instead will transfer a number of ERC1155 tokenIds on the same token
 * contract in a single batch transaction.
 */
struct BatchExecution {
    address token;
    address from;
    address to;
    uint256[] tokenIds;
    uint256[] amounts;
    bool useProxy;
}

/*
 * @dev A purely internal struct for facilitating batch execution construction.
 */
struct Batch {
    bytes32 hash;
    uint256[] executionIndices;
}
