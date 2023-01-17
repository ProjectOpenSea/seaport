# Order fulfillment

Seaport provides [several functions](/docs/SeaportDocumentation.md) that can be used to fulfill the order based on the complexity & the number of orders to fulfill at a time.

## Basic orders

For simple cases, the `fulfillBasicOrder()` can be used. Some examples of the sale types using this function are:

-   [Fixed-price sale](4_Fixed-price_sale.md);
-   [Offer-based sale](5_Offer-based_sale.md);
-   [English auction](6_English_auction.md).

[Seaport documentation](/docs/SeaportDocumentation.md) describes in detail when this function can be used and the cases when it is not applicable. Simply put, the trade of 1 specific asset (ERC721 or ERC1155) for ETH or ERC20 is a basic order and can be fulfilled via this function.

The function accepts the parameter of the following structure:

```js
struct BasicOrderParameters {
    address considerationToken; // the main asset to exchange the Offer for
    uint256 considerationIdentifier; // ID of the asset
    uint256 considerationAmount; // amount of the asset
    address payable offerer; // Offerer
    address zone; // zone address, if used
    address offerToken; // offered token address
    uint256 offerIdentifier; // offered token ID
    uint256 offerAmount; // offered token amount
    BasicOrderType basicOrderType; // type of order, depends on the orderType used when Order was created + assets traded
    uint256 startTime; // start time from initial order
    uint256 endTime; // end time from initial order
    bytes32 zoneHash; // zone hash from initial order
    uint256 salt; // salt from initial order
    bytes32 offererConduitKey; // conduit key the Offerer uses
    bytes32 fulfillerConduitKey; // condit key the Fulfiller uses
    uint256 totalOriginalAdditionalRecipients; // amount of recipients in consideration besides Offerer
    AdditionalRecipient[] additionalRecipients; // data on additional recipients
    bytes signature; // Order object signature
}
```

The nested data types and enums used in the `BasicOrderParameters` are:

```js
struct AdditionalRecipient {
    uint256 amount;
    address payable recipient;
}

enum BasicOrderType {
    // 0: no partial fills, anyone can execute
    ETH_TO_ERC721_FULL_OPEN,

    // 1: partial fills supported, anyone can execute
    ETH_TO_ERC721_PARTIAL_OPEN,

    // 2: no partial fills, only offerer or zone can execute
    ETH_TO_ERC721_FULL_RESTRICTED,

    // 3: partial fills supported, only offerer or zone can execute
    ETH_TO_ERC721_PARTIAL_RESTRICTED,

    // 4: no partial fills, anyone can execute
    ETH_TO_ERC1155_FULL_OPEN,

    // 5: partial fills supported, anyone can execute
    ETH_TO_ERC1155_PARTIAL_OPEN,

    // 6: no partial fills, only offerer or zone can execute
    ETH_TO_ERC1155_FULL_RESTRICTED,

    // 7: partial fills supported, only offerer or zone can execute
    ETH_TO_ERC1155_PARTIAL_RESTRICTED,

    // 8: no partial fills, anyone can execute
    ERC20_TO_ERC721_FULL_OPEN,

    // 9: partial fills supported, anyone can execute
    ERC20_TO_ERC721_PARTIAL_OPEN,

    // 10: no partial fills, only offerer or zone can execute
    ERC20_TO_ERC721_FULL_RESTRICTED,

    // 11: partial fills supported, only offerer or zone can execute
    ERC20_TO_ERC721_PARTIAL_RESTRICTED,

    // 12: no partial fills, anyone can execute
    ERC20_TO_ERC1155_FULL_OPEN,

    // 13: partial fills supported, anyone can execute
    ERC20_TO_ERC1155_PARTIAL_OPEN,

    // 14: no partial fills, only offerer or zone can execute
    ERC20_TO_ERC1155_FULL_RESTRICTED,

    // 15: partial fills supported, only offerer or zone can execute
    ERC20_TO_ERC1155_PARTIAL_RESTRICTED,

    // 16: no partial fills, anyone can execute
    ERC721_TO_ERC20_FULL_OPEN,

    // 17: partial fills supported, anyone can execute
    ERC721_TO_ERC20_PARTIAL_OPEN,

    // 18: no partial fills, only offerer or zone can execute
    ERC721_TO_ERC20_FULL_RESTRICTED,

    // 19: partial fills supported, only offerer or zone can execute
    ERC721_TO_ERC20_PARTIAL_RESTRICTED,

    // 20: no partial fills, anyone can execute
    ERC1155_TO_ERC20_FULL_OPEN,

    // 21: partial fills supported, anyone can execute
    ERC1155_TO_ERC20_PARTIAL_OPEN,

    // 22: no partial fills, only offerer or zone can execute
    ERC1155_TO_ERC20_FULL_RESTRICTED,

    // 23: partial fills supported, only offerer or zone can execute
    ERC1155_TO_ERC20_PARTIAL_RESTRICTED
}
```

## Advanced orders

For the trade types like collection offers and trait-based offers the `fulfillAdvancedOrder()` can be used. It is a more complex but also more robust function in terms of what kinds of sale types it can support.

Comparing to basic orders `fulfillBasicOrder()`, this function input requires more info:

| Parameter name      | Parameter description                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| advancedOrder       | This parameter describes the order to fulfill and the fraction of the order that is attempted to fill. It is possible to fulfill orders fractionally with Seaport, and advanced order structure contain numerator and denominator parameters that are used in the cases of fractional fulfillment to calculate the resulting amounts.                                                  |
| criteriaResolvers   | An array where each element contains a  reference to a specific offer or consideration, a token identifier, and a proof that the supplied token identifier is contained in the merkle root held by the item in question's criteria element. This parameter can be used for the trade types like Collection offer for Any NFT from collection, or an offer for NFT with specifit trait. |
| fulfillerConduitKey | A bytes32 value indicating what conduit, if any, to source the fulfiller's token approvals from. The zero hash signifies that no conduit should be used (and direct approvals set on Consideration).                                                                                                                                                                                   |
| recipient           | The intended recipient for all received items, with `address(0)` indicating that the caller should receive the items. In most common marketplace cases the caller is the receipient.                                                                                                                                                                                                   |

### Advanced Order parameter

The structure of the advanced order parameter is as follows:

```js
struct AdvancedOrder {
    OrderParameters parameters;
    uint120 numerator;
    uint120 denominator;
    bytes signature;
    bytes extraData;
}
```

-   `parameters` is the order description.
-   `numerator` and `denominator` are used for fractional orders fulfillment.
-   `signature` is the order object signature.
-   `extraData` is used for additional validation for some trade cases.

The nested structs used:

```js
struct OrderParameters {
    address offerer;
    address zone;
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    bytes32 zoneHash;
    uint256 salt;
    bytes32 conduitKey;
    uint256 totalOriginalConsiderationItems;
}

struct OfferItem {
    ItemType itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
}

struct ConsiderationItem {
    ItemType itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
    address payable recipient;
}
```

The Item types accepted are matching the item types used in order object:

```js
enum ItemType {
    // 0: ETH on mainnet, MATIC on polygon, etc.
    NATIVE,

    // 1: ERC20 items (ERC777 and ERC20 analogues could also technically work)
    ERC20,

    // 2: ERC721 items
    ERC721,

    // 3: ERC1155 items
    ERC1155,

    // 4: ERC721 items where a number of tokenIds are supported
    ERC721_WITH_CRITERIA,

    // 5: ERC1155 items where a number of ids are supported
    ERC1155_WITH_CRITERIA
}
```

#### Criteria resolvers

Criteria resolver has a following structure: 

```js
struct CriteriaResolver {
    uint256 orderIndex;
    Side side;
    uint256 index;
    uint256 identifier;
    bytes32[] criteriaProof;
}
```

`identifier` corresponds to the actual token id that is considered. 

Seaport protocol supports setting a criteria and its validation using Merkle Tree mechanics. The ids of tokens that need to be valid based on the Order criteria are used to compose a Merkle Root. The Root is passed to the particular item criteria when the Order is created. When the order is fulfilled, Merkle proof for a particular `identifier` is passed as `criteriaProof` in this parameter and is used for validation against the Merkle root from Order.

Criteria can also be empty, meaning any kind of token can be considered. In this case, `criteriaProof` can be an empty array. This case is described in the [Collection offer](7_Collection_offer.md) for Any NFT.