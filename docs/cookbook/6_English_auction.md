# English auction

The English auction-based sale is what happens when you want to sell the NFT to the highest bidder.

Opensea English auction mechanics doesn't oblige the seller to sell the item to the highest bidder. The English auction is implemented as a mix of the [Fixed-price sale](4_Fixed-price_sale.md) and [Offer-based sale](5_Offer-based_sale.md) mechanics. Users of the marketplace can place bids for the item, and the seller can choose any bidder to sell to. The auction process logic parts such as minimal bid validations, displaying the highest bid, and bid expiration date settings are the off-chain solution parts.

In terms of the Seaport part of the solution, the English auction consists of:

-   Listing the item on [Fixed-price sale](4_Fixed-price_sale.md) in ERC20 by the seller. This listing has its specifics:
    -   The type of order created when listing on an English auction is Full Restricted, meaning only the Offerer and zone can execute it.
    -   The zone used in this listing is an Externally-Owned Address (EOA)
-   Regular [Offer-based sale](5_Offer-based_sale.md) process initiated by bidders. Bidders place the bids just like the regular offers.

To accept the bid, the `fulfillBasicOrder()` function is sufficient and is used on Opensea.

## Process steps:

Listing:

1.  Seller approves his NFT collection to Conduit.
2.  Seller signs an order object.
3.  The marketplace back-office lists the item on auction sale and processes the offers as bids from the user perspective.

Bid:

1.  Bidder approves his ERC20 offer amount to Conduit.
2.  Bidder signs an order object.
3.  The marketplace back-office stores the order hash based on the order parameters. This hash can be composed via the `getOrderHash()` Seaport contract function.
4.  Seller confirms `fulfillBasicOrder()` transaction.
5.  Post-transaction, the marketplace back-office tracks the transaction via order hash and changes the item status to "sold".

## Listing on Auction sale

Listing should happen in ERC20 since the bids for the item can not be placed in ETH.

When listing the item on an Auction sale, an order object is composed so that it can not be executed by buyers and is created mainly to list the item on the marketplace. The type of order created when listing on an English auction is Full Restricted, meaning only the offerer and zone can execute it. Offerer (seller) will likely not execute his listing in terms of marketplace UX. The zone used in this listing is an Externally-owned address.

## Listing ERC721 on Auction sale

### Order details

Seller: `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`
Zone address: `0x9B814233894Cd227f561B78Cc65891AA55C62Ad2`

Offer:

-   ERC721 NFT:
    -   Token contract: `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0`
    -   Token id: `1`

Consideration:
Total value: `3 TEST`

-   TEST to the Offerer: `2.775 TEST`
-   Fee to the marketplace: `0.075 TEST`
-   Royalty to the collection creator: `0.15 TEST`

### Order object

Order type needs to be set to full restricted (`2`). Zone is set to the EOA.

Order object to sign:

```js
{
  offerer: "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5",
  zone: "0x9B814233894Cd227f561B78Cc65891AA55C62Ad2",
  offer: [
    {
      itemType: 2,
      token: "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0",
      identifierOrCriteria: 1,
      startAmount: 1,
      endAmount: 1
    }
  ],
  consideration: [
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "2775000000000000000",
      endAmount: "2775000000000000000",
      recipient: "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "75000000000000000",
      endAmount: "75000000000000000",
      recipient: "0x0000a26b00c1F0DF003000390027140000fAa719"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "150000000000000000",
      endAmount: "150000000000000000",
      recipient: "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"
    }
  ],
  orderType: 2,
  startTime: 1672316929,
  endTime: 1672403329,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "897387121293129312939",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
}
```

### Post-signature

Marketplace back-office handles the setting of the item on sale in the auction mode. Bidders can place bids on the item, which in terms of the protocol are handled exactly as an [Offer-based sale](5_Offer-based_sale.md).

The consideration elements in the offers, such as fee distribution, should match the signed order by the seller when he lists the item on the Auction sale.

## Listing ERC1155

### Order details

Seller: `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`

Offer:

-   ERC1155 NFT:
    -   Token contract: `0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B`
    -   Token id: `2`
    -   Token quantity: `1`

Consideration:
Total value: `3 TEST`

-   TEST to the Offerer: `2.775 TEST`
-   Fee to the marketplace: `0.075 TEST`
-   Royalty to the collection creator: `0.15 TEST`

### Order object

Order type needs to be set to full restricted (`2`). Zone is set to the EOA.

Order object to sign:

```js
{
  offerer: "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5",
  zone: "0x9B814233894Cd227f561B78Cc65891AA55C62Ad2",
  offer: [
    {
      itemType: 3,
      token: "0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B",
      identifierOrCriteria: 2,
      startAmount: 1,
      endAmount: 1
    }
  ],
  consideration: [
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "2775000000000000000",
      endAmount: "2775000000000000000",
      recipient: "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "75000000000000000",
      endAmount: "75000000000000000",
      recipient: "0x0000a26b00c1F0DF003000390027140000fAa719"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "150000000000000000",
      endAmount: "150000000000000000",
      recipient: "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"
    }
  ],
  orderType: 2,
  startTime: 1672316929,
  endTime: 1672403329,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "7861287361283761234",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
}
```

### Post-signature

Marketplace back-office handles the setting of the item on sale in the auction mode. Bidders can place bids on the item, which in terms of the protocol are handled exactly as an [Offer-based sale](5_Offer-based_sale.md).

The consideration elements in the offers, such as fee distribution, should match the signed order by the seller when he lists the item on the Auction sale.