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

/**
 * @dev Context struct for OrderHelperLib. Includes context information
 *      necessary for fulfillment, like the caller and recipient addresses,
 *      and Seaport and SeaportValidator interfaces.
 */
struct OrderHelperContext {
    ConsiderationInterface seaport;
    SeaportValidatorInterface validator;
    address caller;
    address recipient;
    uint256 nativeTokensSupplied;
    uint256 maximumFulfilled;
    bytes32 fulfillerConduitKey;
    Response response;
}

struct Response {
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
    MatchComponent[] remainders;
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

struct CriteriaConstraint {
    /**
     * @dev Apply constraint to the order at this index in the orders array.
     */
    uint256 orderIndex;
    /**
     * @dev Apply constraint to this side of the order, either Side.OFFER or
     *      Side.CONSIDERATION.
     */
    Side side;
    /**
     * @dev Apply constraint to this item in the offer/consideration array.
     */
    uint256 index;
    /**
     * @dev Generate a criteria resolver for this token identifier. The helper
     *      will calculate a merkle proof that this token ID is in the set of
     *      eligible token IDs for the item with critera at the specified
     *      order index/side/item index.
     */
    uint256 identifier;
    /**
     * @dev Array of eligible token IDs. The helper will calculate a merkle
     *      root from this array and apply it to the item at the specified
     *      order index/side/item index as its `identifierOrCriteria`.
     */
    uint256[] tokenIds;
}
