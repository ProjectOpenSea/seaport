// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ItemType, OrderType } from "./SeaportEnums.sol";
import {
    TokenIndex,
    Criteria,
    Amount,
    Recipient,
    Offerer,
    Zone,
    Time,
    Zone,
    BroadOrderType,
    ZoneHash
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

    // TODO: zone may have to be per-test depending on the zone
}

struct AdvancedOrdersSpace {
    OrderComponentsSpace[] orders;
}
