# Offer-based sale

The offer-based sale is what happens when you create an offer for a particular NFT on the marketplace. In this case, the Offerer is the buyer of the item.

To fulfill the offer-based sale order, the `fulfillBasicOrder()` function is sufficient and is used on Opensea.

## Process steps:

1.  Offerer approves his ERC20 offer amount to Conduit
2.  Offerer signs an order object.
3.  The marketplace back-office stores the order hash based on the order parameters. This hash can be composed via the `getOrderHash()` Seaport contract function.
4.  Seller approves his NFT collection to Conduit.
5.  Seller confirms `fulfillBasicOrder()` transaction.
6.  Post-transaction, the marketplace back-office tracks the transaction via order hash and changes the item status to "sold".

## Offer for ERC721 in ERC20

### Order details

Buyer: `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`

Offer:

-   TEST to cover seller payment & fees: `1 TEST`

Consideration:

-   ERC721 NFT:
    -   Token contract: `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0`
    -   Token id: `1`
-   Fee to the marketplace: `0.025 TEST`
-   Royalty to the collection creator: `0.05 TEST`

Seller receives the remaining TEST amount.

### Order object

In this example, Seaport is used directly as a conduit. Therefore the `conduitKey` is `0`. Zone is not necessary to use in this example, so the `zone` is also `0`.

Order object to sign:

```js
{
  offerer: "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5",
  zone: "0x0000000000000000000000000000000000000000",
  offer: [
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "1000000000000000000",
      endAmount: "1000000000000000000"
    },
  ],
  consideration: [
    {
      itemType: 2,
      token: "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0",
      identifierOrCriteria: 1,
      startAmount: 1,
      endAmount: 1,
      recipient: "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "25000000000000000",
      endAmount: "25000000000000000",
      recipient: "0x0000a26b00c1F0DF003000390027140000fAa719"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "50000000000000000",
      endAmount: "50000000000000000",
      recipient: "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"
    }
  ],
  orderType: 0,
  startTime: 1671623590,
  endTime: 1674301990,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "723487372347652349",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
}
```

### Fulfillment parameters breakdown

The `fulfillBasicOrder()` function can be used to fulfill the fixed-price sale order. The order parameters to pass to the function input:

| Parameter                         | Comments                                                                      | Value                                                                                                                                     |
| --------------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| considerationToken                | ERC721 token address                                                          | `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0`                                                                                              |
| considerationIdentifier           | Consideration token id                                                        | `1`                                                                                                                                       |
| considerationAmount               | ERC721 token amount                                                           | `1`                                                                                                                                       |
| offerer                           | Buyer address                                                                 | `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`                                                                                              |
| zone                              | Zone address                                                                  | `0x0000000000000000000000000000000000000000`                                                                                              |
| offerToken                        | ERC20 token address                                                           | `0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23`                                                                                              |
| offerIdentifier                   | Offer token id. Since it's fungible, it's 0                                   | `0`                                                                                                                                       |
| offerAmount                       | Amount of ERC20 to distribute                                                 | `1000000000000000000`                                                                                                                     |
| basicOrderType                    | Basic order type matching the orderType in order object and the assets traded | `16`                                                                                                                                      |
| startTime                         | Start time from order object                                                  | `1671623590`                                                                                                                              |
| endTime                           | End time from order object                                                    | `1674301990`                                                                                                                              |
| zoneHash                          | Zone hash                                                                     | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                      |
| salt                              | Salt from order object                                                        | `723487372347652349`                                                                                                                      |
| offererConduitKey                 | Offerer conduit key (0 since Seaport is used as a conduit)                    | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                      |
| fulfillerConduitKey               | Fulfiller conduit key (0 since Seaport is used as a conduit)                  | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                      |
| totalOriginalAdditionalRecipients | Amount of recipients other than buyer in consideration                        | `2`                                                                                                                                       |
| additionalRecipients              | Tuples with pairs [value, receiver] for each recipient                        | `[["25000000000000000","0x0000a26b00c1F0DF003000390027140000fAa719"],["50000000000000000","0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"]]` |
| signature                         | Offerer's signature of the order object                                       | `0x501529cd5a9c27dbfd322491d95f7b1b6fe04f65651f3eb195e55a4bafe226a57a8ab9502deffd39b015f645d43dfc926125ffb28b2a806ce9be0dbfc562add51b`    |

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0x9dcf519fff6028fa732a254727f156a904642ddc48aab31b7b1407d6eada8968

## Offer for ERC1155 in ERC20

### Order details

Buyer: `0x07765B25468f559d88AffE4fcCB2B386004BFd2e`

Offer:

-   TEST to cover seller payment & fees: `1 TEST`

Consideration:

-   ERC721 NFT:
    -   Token contract: `0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B`
    -   Token id: `2`
    -   Token quantity: `2`
-   Fee to the marketplace: `0.025 TEST`
-   Royalty to the collection creator: `0.05 TEST`

Seller receives the remaining TEST amount.

### Order object

In this example, Seaport is used directly as a conduit. Therefore the `conduitKey` is `0`. Zone is not necessary to use in this example, so the `zone` is also `0`.

Order object to sign:

```js
{
  offerer: "0x07765B25468f559d88AffE4fcCB2B386004BFd2e",
  zone: "0x0000000000000000000000000000000000000000",
  offer: [
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "1000000000000000000",
      endAmount: "1000000000000000000"
    },
  ],
  consideration: [
    {
      itemType: 3,
      token: "0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B",
      identifierOrCriteria: 2,
      startAmount: 2,
      endAmount: 2,
      recipient: "0x07765B25468f559d88AffE4fcCB2B386004BFd2e"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "25000000000000000",
      endAmount: "25000000000000000",
      recipient: "0x0000a26b00c1F0DF003000390027140000fAa719"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "50000000000000000",
      endAmount: "50000000000000000",
      recipient: "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"
    }
  ],
  orderType: 0,
  startTime: 1671623590,
  endTime: 1674301990,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "762537462347609898",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
}
```

### Fulfillment parameters breakdown

The `fulfillBasicOrder()` function can be used to fulfill the fixed-price sale order. The order parameters to pass to the function input:

| Parameter                         | Comments                                                                      | Value                                                                                                                                     |
| --------------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| considerationToken                | ERC1155 token address                                                         | `0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B`                                                                                              |
| considerationIdentifier           | Consideration token id                                                        | `2`                                                                                                                                       |
| considerationAmount               | ERC1155 token amount                                                          | `2`                                                                                                                                       |
| offerer                           | Buyer address                                                                 | `0x07765B25468f559d88AffE4fcCB2B386004BFd2e`                                                                                              |
| zone                              | Zone address                                                                  | `0x0000000000000000000000000000000000000000`                                                                                              |
| offerToken                        | ERC20 token address                                                           | `0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23`                                                                                              |
| offerIdentifier                   | Offer token id. Since it's fungible, it's 0                                   | `0`                                                                                                                                       |
| offerAmount                       | Amount of ERC20 to distribute                                                 | `1000000000000000000`                                                                                                                     |
| basicOrderType                    | Basic order type matching the orderType in order object and the assets traded | `20`                                                                                                                                      |
| startTime                         | Start time from order object                                                  | `1671623590`                                                                                                                              |
| endTime                           | End time from order object                                                    | `1674301990`                                                                                                                              |
| zoneHash                          | Zone hash                                                                     | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                      |
| salt                              | Salt from order object                                                        | `762537462347609898`                                                                                                                      |
| offererConduitKey                 | Offerer conduit key (0 since Seaport is used as a Conduit)                    | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                      |
| fulfillerConduitKey               | Fulfiller conduit key (0 since Seaport is used as a Conduit)                  | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                      |
| totalOriginalAdditionalRecipients | Amount of recipients other than buyer in consideration                        | `2`                                                                                                                                       |
| additionalRecipients              | Tuples with pairs [value, receiver] for each recipient                        | `[["25000000000000000","0x0000a26b00c1F0DF003000390027140000fAa719"],["50000000000000000","0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"]]` |
| signature                         | Offerer's signature of the order object                                       | `0xfb4f610b073002b07aaa11761f1ebc9afcaac9a357cec19b05553e34fb9aca3f17d4f85ada2653c81c22ab466db4254c266fea0b0dc111c05acdcf794a33d1b01c`    |

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0x6d3131896a71ae74978febba42e9f83eaaf3911ffbf49bec436ff155890b422e 