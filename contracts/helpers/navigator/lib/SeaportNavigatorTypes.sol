// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    SeaportValidatorInterface,
    ErrorsAndWarnings
} from "../../order-validator/SeaportValidator.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    Execution,
    Order,
    OrderComponents,
    OrderParameters,
    ConsiderationItem,
    OfferItem,
    ReceivedItem,
    SpentItem,
    Fulfillment,
    FulfillmentComponent
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ItemType,
    Side,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    MatchComponent
} from "seaport-sol/src/lib/types/MatchComponentType.sol";

import {
    FulfillmentDetails,
    OrderDetails
} from "seaport-sol/src/fulfillments/lib/Structs.sol";

import {
    FulfillmentStrategy
} from "seaport-sol/src/fulfillments/lib/FulfillmentLib.sol";

struct NavigatorAdvancedOrder {
    NavigatorOrderParameters parameters;
    uint120 numerator;
    uint120 denominator;
    bytes signature;
    bytes extraData;
}

struct NavigatorOrderParameters {
    address offerer;
    address zone;
    NavigatorOfferItem[] offer;
    NavigatorConsiderationItem[] consideration;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    bytes32 zoneHash;
    uint256 salt;
    bytes32 conduitKey;
    uint256 totalOriginalConsiderationItems;
}

struct NavigatorOfferItem {
    ItemType itemType;
    address token;
    uint256 identifier;
    uint256 startAmount;
    uint256 endAmount;
    uint256[] candidateIdentifiers;
}

struct NavigatorConsiderationItem {
    ItemType itemType;
    address token;
    uint256 identifier;
    uint256 startAmount;
    uint256 endAmount;
    address payable recipient;
    uint256[] candidateIdentifiers;
}

/**
 * @dev Context struct for NavigatorContextLib. Includes context information
 *      necessary for fulfillment, like the caller and recipient addresses,
 *      and Seaport and SeaportValidator interfaces.
 */
struct NavigatorContext {
    NavigatorRequest request;
    NavigatorResponse response;
}

struct NavigatorRequest {
    /**
     * @dev Seaport interface.
     */
    ConsiderationInterface seaport;
    /**
     * @dev SeaportValidator interface.
     */
    SeaportValidatorInterface validator;
    /**
     * @dev An array of `NavigatorAdvancedOrder` structs.
     */
    NavigatorAdvancedOrder[] orders;
    /**
     * @dev Address of the account calling seaport.
     */
    address caller;
    /**
     * @dev Recipient address.
     */
    address recipient;
    /**
     * @dev Quantity of native tokens the caller will provide to Seaport as
     *      `msg.value`.
     */
    uint256 nativeTokensSupplied;
    /**
     * @dev Optional maximum fulfilled amount.
     */
    uint256 maximumFulfilled;
    /**
     * @dev Optional fulfiller conduit key.
     */
    bytes32 fulfillerConduitKey;
    /**
     * @dev A PRNG seed, used by fulfillment strategies.
     */
    uint256 seed;
    /**
     * @dev A struct that describes a strategy for calculating fulfillments. A
     *      FulfillmentStrategy consists of three sub-strategies: aggregation,
     *      fulfill available, and match.
     *
     *      Aggregation:
     *     - MINIMUM: Aggregate as few items as possible
     *     - MAXIMUM: Aggregate as many items as possible
     *     - RANDOM:  Randomize aggregation quantity

     *     Fulfill Available:
     *     - KEEP_ALL:                  Persist default aggregation strategy
     *     - DROP_SINGLE_OFFER:         Exclude aggregations for single offer
     *                                  items
     *     - DROP_ALL_OFFER:            Exclude offer aggregations (keep one if
     *                                  no consideration)
     *     - DROP_RANDOM_OFFER:         Exclude random offer aggregations
     *     - DROP_SINGLE_KEEP_FILTERED: Exclude single unless it would be
     *                                  filtered
     *     - DROP_ALL_KEEP_FILTERED:    Exclude all unfilterable offer
     *                                  aggregations
     *     - DROP_RANDOM_KEEP_FILTERED: Exclude random, unfilterable offer
     *                                  aggregations
     *
     *     Match:
     *     - MAX_FILTERS:                Prioritize locating filterable
     *                                   executions
     *     - MIN_FILTERS:                Prioritize avoiding filterable
     *                                   executions where possible
     *     - MAX_INCLUSION:              Try not to leave any unspent offer
     *                                   items
     *     - MIN_INCLUSION:              Leave as many unspent offer items as
     *                                   possible
     *     - MIN_INCLUSION_MAX_FILTERS:  Leave unspent items if not filterable
     *     - MAX_EXECUTIONS:             Use as many fulfillments as possible
     *                                   given aggregations
     *     - MIN_EXECUTIONS:             Use as few fulfillments as possible
     *                                   given aggregations
     *     - MIN_EXECUTIONS_MAX_FILTERS: Minimize fulfillments and prioritize
     *                                   filters
     *
     */
    FulfillmentStrategy fulfillmentStrategy;
    /**
     * @dev An optional array of explicit criteria resolvers. If provided, these
     *      will override any derived criteria resolvers.
     */
    CriteriaResolver[] criteriaResolvers;
    /**
     * @dev A boolean flag specifying whether to prefer match/matchAdvanced over
     *      fullfillAvailable/fulfillAvailableAdvanced.
     */
    bool preferMatch;
}

struct NavigatorResponse {
    /**
     * @dev The provided orders. If the caller provides explicit criteria
     *      resolvers, the orders will not be modified. If the caller provides
     *      criteria constraints, the returned offer/consideration items will be
     *      updated with calculated merkle roots as their `identifierOrCriteria`
     */
    AdvancedOrder[] orders;
    /**
     * @dev The provided or calculated criteria resolvers. If the caller
     *      provides criteria constraints rather than explicit criteria
     *      resolvers, criteria resolvers and merkle proofs will be calculated
     *      based on provided criteria constraints.
     */
    CriteriaResolver[] criteriaResolvers;
    /**
     * @dev Selector of the suggested Seaport fulfillment method for the
     *      provided orders.
     */
    bytes4 suggestedAction;
    /**
     * @dev Human-readable name of the suggested Seaport fulfillment method for
     *      the provided orders.
     */
    string suggestedActionName;
    /**
     * @dev Array of errors and warnings returned by SeaportValidator for the
     *      provided orders, by order index in the orders array.
     */
    ErrorsAndWarnings[] validationErrors;
    /**
     * @dev Calculated OrderDetails structs for the provided orders, by order
     *      index. Includes offerer, conduit key, spent and received items,
     *      order hash, and unavailable reason.
     */
    OrderDetails[] orderDetails;
    /**
     * @dev Calculated fulfillment components and combined Fullfiilments.
     */
    FulfillmentComponent[][] offerFulfillments;
    FulfillmentComponent[][] considerationFulfillments;
    Fulfillment[] fulfillments;
    /**
     * @dev Calculated match components for matchable orders.
     */
    MatchComponent[] unspentOfferComponents;
    MatchComponent[] unmetConsiderationComponents;
    /**
     * @dev Calculated explicit and implicit executions.
     */
    Execution[] explicitExecutions;
    Execution[] implicitExecutions;
    Execution[] implicitExecutionsPre;
    Execution[] implicitExecutionsPost;
    /**
     * @dev Quantity of native tokens returned to caller.
     */
    uint256 nativeTokensReturned;
}
