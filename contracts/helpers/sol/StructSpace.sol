// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ItemType } from "./SeaportEnums.sol";

import {
    Amount,
    BroadOrderType,
    Caller,
    ConduitChoice,
    ContractOrderRebate,
    Criteria,
    EOASignature,
    ExtraData,
    FulfillmentRecipient,
    Offerer,
    Recipient,
    SignatureMethod,
    Time,
    Tips,
    TokenIndex,
    UnavailableReason,
    Zone,
    ZoneHash
} from "./SpaceEnums.sol";

import {
    FulfillmentStrategy
} from "./fulfillments/lib/FulfillmentLib.sol";

struct OfferItemSpace {
    ItemType itemType;
    TokenIndex tokenIndex;
    Criteria criteria;
    Amount amount;
}

struct ConsiderationItemSpace {
    ItemType itemType;
    TokenIndex tokenIndex;
    Criteria criteria;
    Amount amount;
    Recipient recipient;
}

struct SpentItemSpace {
    ItemType itemType;
    TokenIndex tokenIndex;
}

struct ReceivedItemSpace {
    ItemType itemType;
    TokenIndex tokenIndex;
    Recipient recipient;
}

struct OrderComponentsSpace {
    Offerer offerer;
    Zone zone;
    OfferItemSpace[] offer;
    ConsiderationItemSpace[] consideration;
    BroadOrderType orderType;
    Time time;
    ZoneHash zoneHash;
    SignatureMethod signatureMethod;
    EOASignature eoaSignatureType;
    uint256 bulkSigHeight;
    uint256 bulkSigIndex;
    ConduitChoice conduit;
    Tips tips;
    UnavailableReason unavailableReason; // ignored unless unavailable
    ExtraData extraData;
    ContractOrderRebate rebate;
}

struct AdvancedOrdersSpace {
    OrderComponentsSpace[] orders;
    bool isMatchable;
    uint256 maximumFulfilled;
    FulfillmentRecipient recipient;
    ConduitChoice conduit;
    Caller caller;
    FulfillmentStrategy strategy;
}
