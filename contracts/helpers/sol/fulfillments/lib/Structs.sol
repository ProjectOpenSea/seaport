// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    MatchComponent,
    MatchComponentType
} from "../../lib/types/MatchComponentType.sol";
import { FulfillmentComponent } from "../../SeaportStructs.sol";

struct FulfillmentHelperCounterLayout {
    uint256 fulfillmentCounter;
}

// TODO: won't work for partial fulfills of criteria resolved
// TODO: won't work for hybrid tokens that implement multiple token interfaces
struct MatchFulfillmentStorageLayout {
    mapping(
        address /*tokenContract*/
            => mapping(
                uint256 /*identifier*/
                    => mapping(
                        address /*offerer*/
                            => mapping(
                                bytes32 /*conduitKey*/ => MatchComponent[] /*components*/
                            )
                    )
            )
        ) offerMap;
    mapping(
        address /*recipient*/
            => mapping(
                address /*tokenContract*/
                    => mapping(
                        uint256 /*identifier*/ => MatchComponent[] /*components*/
                    )
            )
        ) considerationMap;
    // a given aggregatable consideration component will have its own set of aggregatable offer components
    mapping(
        address /*token*/
            => mapping(
                uint256 /*tokenId*/ => AggregatableOfferer[] /*offererEnumeration*/
            )
        ) tokenToOffererEnumeration;
    // aggregatable consideration components can be enumerated normally
    AggregatableConsideration[] considerationEnumeration;
}

struct FulfillAvailableHelperStorageLayout {
    mapping(
        address /*tokenContract*/
            => mapping(
                uint256 /*identifier*/
                    => mapping(
                        address /*offerer*/
                            => mapping(
                                bytes32 /*conduitKey*/ => FulfillmentComponent[] /*components*/
                            )
                    )
            )
        ) offerMap;
    mapping(
        address /*recipient*/
            => mapping(
                address /*tokenContract*/
                    => mapping(
                        uint256 /*identifier*/ => FulfillmentComponent[] /*components*/
                    )
            )
        ) considerationMap;
    // a given aggregatable consideration component will have its own set of aggregatable offer components
    AggregatableOffer[] offerEnumeration;
    // aggregatable consideration components can be enumerated normally
    AggregatableConsideration[] considerationEnumeration;
}

/**
 * @notice Offers can only be aggregated if they share an offerer *and* conduitKey
 */
struct AggregatableOfferer {
    address offerer;
    bytes32 conduitKey;
}

struct AggregatableOffer {
    address offerer;
    bytes32 conduitKey;
    address contractAddress;
    uint256 tokenId;
}
/**
 *
 * @notice Considerations can only be aggregated if they share a token address, id, and recipient (and itemType, but in the vast majority of cases, a token is only one type)
 */

struct AggregatableConsideration {
    address recipient;
    address contractAddress;
    uint256 tokenId;
}

struct ProcessComponentParams {
    FulfillmentComponent[] offerFulfillmentComponents;
    FulfillmentComponent[] considerationFulfillmentComponents;
    uint256 offerItemIndex;
    uint256 considerationItemIndex;
    bool midCredit;
}
