# Multiple assets trade

The multiple assets trade is what happens when you trade any amount of ERC20s, ERC721s, and ERC1155s you have for the assets that another marketplace user owns. In this case, the Offerer is the trade initiator.

A trade like this can be executed through the Seaport `fulfillAdvancedOrder()` function.

## Process steps:

1.  Offerer approves his ERC20, ERC721 and/or ERC1155 tokens to Conduit.
2.  Offerer signs an order object.
3.  The marketplace back-office stores the order hash based on the order parameters. This hash can composed via `getOrderHash()` Seaport contract function
4.  Trade counterpart approves his ERC20, ERC721 and/or ERC1155 to Conduit. Trade counterpart also approves the necessary assets to the Conduit so that fees can be paid to the marketplace, if necessary.
5.  Trade counterpart confirms the `fulfillAdvancedOrder()` transaction.
6.  Post-transaction, the marketplace back-office tracks the transaction via order hash and changes the item status to "sold".

## Example

### Order details

Initiator: `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`
Counterpart: `0x07765B25468f559d88AffE4fcCB2B386004BFd2e`

| Initiator assets                                                                                         | Counterpart assets                                                                       |
| -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| ERC20 TEST token, amount `5.05 TEST`                                                                     | ERC721 NFT from token contract `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0` with id `10` |
| ERC721 NFT from token contract `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0` with id `8`                  |                                                                                          |
| ERC1155 NFT from token contract `0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B` with id `2` in quantity `5` |                                                                                          |

Offer:

-   ERC20 TEST token, amount `5.05 TEST`
-   ERC721 NFT from token contract `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0` with id `1`
-   ERC1155 NFT from token contract `0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B` with id `2` in quantity `5`

Consideration:

-   ERC721 NFT from token contract `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0` with id `10` to the initiator
-   Fee to the marketplace: `0.025 TEST`

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
      startAmount: "5050000000000000000",
      endAmount: "5050000000000000000"
    },
    {
      itemType: 2,
      token: "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0",
      identifierOrCriteria: 1,
      startAmount: 1,
      endAmount: 1
    },
    {
      itemType: 3,
      token: "0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B",
      identifierOrCriteria: 2,
      startAmount: 5,
      endAmount: 5
    }
  ],
  consideration: [
    {
      itemType: 2,
      token: "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0",
      identifierOrCriteria: 10,
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
    }
  ],
  orderType: 0,
  startTime: 1673473359,
  endTime: 1673905359,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "4761762672675276523675423765432",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
}
```

### Fulfillment parameters breakdown

The `fulfillAdvancedOrder()` function can be used to fulfill the collection offer-based sale order

Refer to the [Order fulfillment](3_Order_fulfillment.md) description of each parameter structure for more details. The particular values for the described case are provided below.

#### Advanced Order

Detailed structure of the Advanced order is described in [Order fulfillment](3_Order_fulfillment.md).

Value for the described case:

```js
[
  [
    "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5", // offerer
    "0x0000000000000000000000000000000000000000", // zone
    [ // offer items
      [ 
        1, // ERC20 item type
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address
        0, // 0 for ERC20 since it is fungible
        "5050000000000000000", // start amount
        "5050000000000000000" // end amount
      ],
      [
        2, // ERC721 item type
        "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0", // ERC721 token address
        1, // Token id
        1, // start amount
        1 // end amount
      ],
      [
        3, // ERC1155 item type
        "0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B", // ERC1155 token address
        2, // Token id
        5, // start amount
        5 // end amount
      ]
    ],
    [ // consideration items
      [
        2, // ERC721 item type
        "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0",// ERC721 token address
        "10", // Token id
        1, // start amount
        1, // end amount
        "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5" // recipient - offerer
      ],
      [ 
        1, // ERC20 item type
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address
        0, // 0 for ERC20 since it is fungible
        "25000000000000000", // start amount
        "25000000000000000", // end amount
        "0x0000a26b00c1F0DF003000390027140000fAa719" // recipient - marketplace fee collector
      ]
    ],
    0, // order type
    1673473359, // start time
    1673905359, // end time
    "0x0000000000000000000000000000000000000000000000000000000000000000", // zone hash
    "4761762672675276523675423765432", // salt
    "0x0000000000000000000000000000000000000000000000000000000000000000", // conduit key
    2 // total original consideration items in consideration array
  ],
  1, // numerator
  1, // denominator
  "0x83dc961bb6932635eb5e26d544ff75f7189636f3b59205999482ab65e1a9dccf4e9313b79eff1ea2af3ada9048bbdd1df56174e9012f20c0cd59862d215c81531b", // order signature
  "0x0000000000000000000000000000000000000000000000000000000000000000" // extra data
]
```

#### Criteria resolvers

In the described case, there are no assets with criteria traded, so there are no criteria resolvers needed and value to use in the function call is the empty array.

Value example:

```js
[]
```

#### Fulfiller Conduit Key

In the described case, both offerer and fulfiller have approved their items to the Seaport contract directly and the parameter value to pass is:

```js
0x0000000000000000000000000000000000000000000000000000000000000000
```

#### Recipient

In the described case, the intended recipient is the caller himself, so the value is:

```js
0x0000000000000000000000000000000000000000
```

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0x212a063d79e9d278ce7b5a353ef0bff8dbdd1aa79300b212b3b72c1428343302