// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ItemType } from "./SeaportEnums.sol";

import {
    Amount,
    BroadOrderType,
    Criteria,
    EOASignature,
    Offerer,
    Recipient,
    SignatureMethod,
    Time,
    Tips,
    TokenIndex,
    Zone,
    ZoneHash,
    ConduitChoice
} from "./SpaceEnums.sol";

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
    ConduitChoice conduit;
    Tips tips;
    // TODO: zone may have to be per-test depending on the zone
}

struct AdvancedOrdersSpace {
    OrderComponentsSpace[] orders;
    bool isMatchable;
}
