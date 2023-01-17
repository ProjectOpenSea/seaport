# Collection offer

The collection offer sale is what happens when you create an offer for any NFT in a certain collection on the marketplace. In this case, the Offerer is the buyer of the item.

These offers can include absolutely any NFTs in the collection, or subsets of NFTs in the collection.

Seaport advanced offer mechanics lets you build pretty much any kind of criteria when picking a subset of specific NFTs. Some examples of offers that can be built like this:

-   Trait-based offers
-   Rarity-based offers
-   User favorite-based offers

The criteria like the ones described above are built using Merkle Tree mechanics. The ids of NFTs that match the criteria can be calculated off-chain. Then the Merkle Tree is composed of these ids and the Merkle Root is included in the Order object. When the order is fulfilled, the Merkle Proof is provided as a part of fulfillment function parameters and the id of NFT is checked against the Merkle Root using proof. The example of this offer is described in Subset NFTs offer section.

The `fulfillAdvancedOrder()` function can be used to fulfill the collection offer-based sale order.

## Process steps:

1.  Offerer approves his ERC20 offer amount to Conduit.
2.  Offerer signs an order object.
3.  The marketplace back-office stores the order hash based on the order parameters. This hash can be composed via the `getOrderHash()` Seaport contract function.
4.  Seller approves his NFT collection to Conduit. The seller also approves ERC20 to the conduit so that fees can be paid to the marketplace and the royalty receiver.
5.  Seller confirms `fulfillAdvancedOrder()` transaction.
6.  Post-transaction, the marketplace back-office tracks the transaction via order hash and changes the item status to "sold".

## All NFTs collection offer (ERC721)

### Order details

Buyer: `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`

Offer:

-   TEST to cover seller payment & fees: `1 TEST`

Consideration:

-   ERC721 NFT:
    -   Any NFT from token contract: `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0`
-   Fee to the marketplace: `0.025 TEST`
-   Royalty to the collection creator: `0.05 TEST`

Seller receives the remaining TEST amount.

### Order object

In this example, Seaport is used directly as a conduit. Therefore the `conduitKey` is `0`. Zone is not necessary to use in this example, so the `zone` is also `0`.

The item type of NFT in consideration is `4` standing for the type "ERC721 with criteria, and `identifierOrCriteria` is `0`, meaning any ERC721 NFT of this contract is eligible.

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
      itemType: 4,
      token: "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0",
      identifierOrCriteria: 0,
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
  startTime: 1673473359,
  endTime: 1673905359,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "98243783478934797887978",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
}
```

### Fulfillment parameters breakdown

The `fulfillAdvancedOrder()` function can be used to fulfill the collection offer-based sale order.

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
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address
        0, // 0 for ERC20 since it is fungible
        "1000000000000000000", // start amount
        "1000000000000000000" // end amount
      ]
    ],
    [ // consideration items
      [ // any NFT from the collection 
        4, // ERC721 with criteria item type
        "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0", // ERC721 token address
        0, // criteria = 0 since any NFT based on the composed offer is acceptable
        1, // start amount
        1, // end amount
        "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5" // recipient - offerer
      ],
      [ // fee to the marketplace
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address 
        0, // 0 for ERC20 since it is fungible
        "25000000000000000", // start amount
        "25000000000000000", // end amount
        "0x0000a26b00c1F0DF003000390027140000fAa719" // recipient - marketplace fee collector
      ],
      [ // royalty fee
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address 
        0, // 0 for ERC20 since it is fungible
        "50000000000000000", // start amount
        "50000000000000000", // end amount
        "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd" // recipient - royalty address
      ]
    ],
    0, // order type
    1673473359, // start time
    1673905359, // end time
    "0x0000000000000000000000000000000000000000000000000000000000000000", // zone hash
    "98243783478934797887978", // salt
    "0x0000000000000000000000000000000000000000000000000000000000000000", // conduit key
    3 // total original consideration items in consideration array
  ],
  1, // numerator
  1, // denominator
  "0xef422046aa9c7f99e5efe55b1625452ac64eabb0ff297a4ee946c2413a34c1dd2afe9f677e59bcd4ee638801cce3c536441b516113ff43971c311112f73570fd1b", // order signature
  "0x0000000000000000000000000000000000000000000000000000000000000000" // extra data
] 
```

#### Criteria resolvers

In the described case, the array with 1 criteria resolver for "any collection item" is provided.

Value for the described case:

```js
[
  [
    0, // order index
    1, // side. 1 is Consideration
    0, // index
    4, // actual sold NFT id
    [] // proof. empty for this case
  ]
]
```

#### Fulfiller Conduit Key

In the described case, both the Offerer and Fulfiller have approved their items to the Seaport contract directly, and the parameter value to pass is:

```js
0x0000000000000000000000000000000000000000000000000000000000000000
```

#### Recipient

In the described case, the intended recipient is the caller himself, so the value is:

```js
0x0000000000000000000000000000000000000000
```

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0x116f3314b1cc7f33e7c680a3606930854fe3d54ad1f6b767bad3dd7c8492e73b

## All NFTs collection offer (ERC1155)

### Order details

Buyer: `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`

Offer:

-   TEST to cover seller payment & fees: `1 TEST`

Consideration:

-   ERC1155 NFT:
    -   Any NFT from token contract: `0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B`
    -   Token quantity: `1`
-   Fee to the marketplace: `0.025 TEST`
-   Royalty to the collection creator: `0.05 TEST`

Seller receives the remaining TEST amount.

### Order object

In this example, Seaport is used directly as a conduit. Therefore the `conduitKey` is `0`. Zone is not necessary to use in this example, so the `zone` is also `0`.

The item type of NFT in consideration is `5` standing for the type "ERC1155 with criteria", and `identifierOrCriteria` is `0`, meaning any ERC1155 NFT of this contract is eligible.

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
      itemType: 5,
      token: "0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B",
      identifierOrCriteria: 0,
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
  startTime: 1673779816,
  endTime: 1674125416,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "12376523876534984304",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
}
```

### Fulfillment parameters breakdown

The `fulfillAdvancedOrder()` function can be used to fulfill the collection offer-based sale order.

Refer to [Order fulfillment](3_Order_fulfillment.md) description of each parameter structure for more details, the particular values for the described case are provided below.

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
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address
        0, // 0 for ERC20 since it is fungible
        "1000000000000000000", // start amount
        "1000000000000000000" // end amount
      ]
    ],
    [ // consideration items
      [ // any NFT from the collection 
        5, // ERC1155 with criteria item type
        "0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B", // ERC1155 token address
        0, // criteria = 0 since any NFT based on the composed offer is acceptable
        1, // start amount
        1, // end amount
        "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5" // recipient - offerer
      ],
      [ // fee to the marketplace
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address 
        0, // 0 for ERC20 since it is fungible
        "25000000000000000", // start amount
        "25000000000000000", // end amount
        "0x0000a26b00c1F0DF003000390027140000fAa719" // recipient - marketplace fee collector
      ],
      [ // royalty fee
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address 
        0, // 0 for ERC20 since it is fungible
        "50000000000000000", // start amount
        "50000000000000000", // end amount
        "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd" // recipient - royalty address
      ]
    ],
    0, // order type
    1673779816, // start time
    1674125416, // end time
    "0x0000000000000000000000000000000000000000000000000000000000000000", // zone hash
    "12376523876534984304", // salt
    "0x0000000000000000000000000000000000000000000000000000000000000000", // conduit key
    3 // total original consideration items in consideration array
  ],
  1, // numerator
  1, // denominator
  "0xc360a3399c0f14b0896fff68211ed29ae19d4fb8be57bb7be14f33a07edbcc3d26e6bf238f44baf4d91e33e1836392e488ac047705afb666c4fc78a486c641b61c", // order signature
  "0x0000000000000000000000000000000000000000000000000000000000000000" // extra data
] 
```

#### Criteria resolvers

In the described case, the array with 1 criteria resolver for "any collection item" is provided:

Value for the described case:

```js
[
  [
    0, // order index
    1, // side. 1 is Consideration
    0, // index
    2, // actual sold NFT id
    [] // proof. empty for this case
  ]
]
```

#### Fulfiller Conduit Key

In the described case, both the Offerer and Fulfiller have approved their items to the Seaport contract directly, and the parameter value to pass is:

```js
0x0000000000000000000000000000000000000000000000000000000000000000
```

#### Recipient

In the described case, the intended recipient is the caller himself, so the value is:

```js
0x0000000000000000000000000000000000000000
```

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0x2458e8231193401686b058d96c9b2684a3b88bd0c8bf308955fa1e741796ffed

## Subset NFTs collection offer (ERC721)

### Order details

Buyer: `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`

Offer:

-   TEST to cover seller payment & fees: `1 TEST`

Consideration:

-   ERC721 NFT:
    -   NFT from token contract `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0` that has one of the following ids: `1, 2, 3, 4`
-   Fee to the marketplace: `0.025 TEST`
-   Royalty to the collection creator: `0.05 TEST`

Seller receives the remaining TEST amount.

### Merkle Proof and Merkle Root

To compose an order object and for further validation of considered NFT having the id matching the subset, the Merkle Tree is created out of the following ids: `[1, 2, 3, 4]`.

The resulting Merkle root looks as follows:

```js
0x9cb86f87624f55e4956a62a87acdd72769cdb21f746c27d345ef90343a9b2316
```

And the Merkle proof for each id looks as follows:

Id 1:

```js
[
  "0x405787fa12a823e0f2b7631cc41b3ba8828b3321ca811111fa75cd3aa3bb5ace",
  "0x58dedfa8c8510aa7a44a262de0df204bc81f3b437741b6b63212d1173a876672"
]
```

Id 2:

```js
[
  "0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6",
  "0x58dedfa8c8510aa7a44a262de0df204bc81f3b437741b6b63212d1173a876672"
]
```

Id 3:

```js
[
  "0x8a35acfbc15ff81a39ae7d344fd709f28e8600b4aa8c65c6b64bfe7fe36bd19b",
  "0x2a171b5bcd1449348c3e09a5424946b5e6d6f5471221941d585131d673952ee4"
]
```

Id 4:

```js
[
  "0xc2575a0e9e593c00f959f8c92f12db2869c3395a3b0502d05e2516446f71f85b",
  "0x2a171b5bcd1449348c3e09a5424946b5e6d6f5471221941d585131d673952ee4"
]
```

### Order object

In this example, Seaport is used directly as a conduit. Therefore the `conduitKey` is `0`. Zone is not necessary to use in this example, so the `zone` is also `0`.

The item type of NFT in consideration is `4` standing for the type "ERC721 with criteria, and `identifierOrCriteria` is the root of the Merkle Tree, formed from the ids `[1, 2, 3, 4]`.

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
      itemType: 4,
      token: "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0",
      identifierOrCriteria: "0x9cb86f87624f55e4956a62a87acdd72769cdb21f746c27d345ef90343a9b2316",
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
  startTime: 1673473359,
  endTime: 1673905359,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "87612387628761238723727377",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
}
```

### Fulfillment parameters breakdown

The `fulfillAdvancedOrder()` function can be used to fulfill the collection offer-based sale order.

Refer to [Order fulfillment](3_Order_fulfillment.md) description of each parameter structure for more details, the particular values for the described case are provided below.

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
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address
        0, // 0 for ERC20 since it is fungible
        "1000000000000000000", // start amount
        "1000000000000000000" // end amount
      ]
    ],
    [ // consideration items
      [ // any NFT from the collection 
        4, // ERC721 with criteria item type
        "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0", // ERC721 token address
        "0x9cb86f87624f55e4956a62a87acdd72769cdb21f746c27d345ef90343a9b2316", // criteria = merkle root for ids 1, 2, 3, 4
        1, // start amount
        1, // end amount
        "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5" // recipient - offerer
      ],
      [ // fee to the marketplace
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address 
        0, // 0 for ERC20 since it is fungible
        "25000000000000000", // start amount
        "25000000000000000", // end amount
        "0x0000a26b00c1F0DF003000390027140000fAa719" // recipient - marketplace fee collector
      ],
      [ // royalty fee
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address 
        0, // 0 for ERC20 since it is fungible
        "50000000000000000", // start amount
        "50000000000000000", // end amount
        "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd" // recipient - royalty address
      ]
    ],
    0, // order type
    1673473359, // start time
    1673905359, // end time
    "0x0000000000000000000000000000000000000000000000000000000000000000", // zone hash
    "87612387628761238723727377", // salt
    "0x0000000000000000000000000000000000000000000000000000000000000000", // conduit key
    3 // total original consideration items in consideration array
  ],
  1, // numerator
  1, // denominator
  "0x075c07821eb5a3f03f99f4c6e56ecb4bce52a49b8bcb3072642d5bb05d1fbd2f6f09a249c45397eca6993aff70c2cbbe24df643c897c13c8eb424bcf9940549a1b", // order signature
  "0x0000000000000000000000000000000000000000000000000000000000000000" // extra data
] 
```

#### Criteria resolvers

In the described case, the array with 1 criteria resolver for the item with id 3 is provided:

Value for the described case:

```js
[
  [
    0, // order index
    1, // side. 1 is Consideration
    0, // index
    3, // actual sold NFT id
    [ // proof for id 3
      "0x8a35acfbc15ff81a39ae7d344fd709f28e8600b4aa8c65c6b64bfe7fe36bd19b",
      "0x2a171b5bcd1449348c3e09a5424946b5e6d6f5471221941d585131d673952ee4"
    ]
  ]
]
```

#### Fulfiller Conduit Key

In the described case, both the Offerer and Fulfiller have approved their items to the Seaport contract directly, and the parameter value to pass is:

```js
0x0000000000000000000000000000000000000000000000000000000000000000
```

#### Recipient

In the described case, the intended recipient is the caller himself, so the value is:

```js
0x0000000000000000000000000000000000000000
```

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0xf17d5a80ce926ceed8a1b99c92197ea65944d361204d627b41d9b519d7636aa6

## Subset NFTs collection offer (ERC1155)

### Order details

Buyer: `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`

Offer:

-   TEST to cover seller payment & fees: `1 TEST`

Consideration:

-   ERC1155 NFT:
    -   Any NFT from token contract: `0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B` that has one of the following ids: `2, 5, 6`
    -   Token quantity: `2`
-   Fee to the marketplace: `0.025 TEST`
-   Royalty to the collection creator: `0.05 TEST`

Seller receives the remaining TEST amount.

### Merkle Proof and Merkle Root

To compose an order object and for further validation of considered NFT having the id matching the subset, the Merkle Tree is created out of the following ids: `[2, 5, 6]`.

The resulting Merkle root looks as follows:

```js
0x7e5d06e94050d228c85b4fc55229be36d1ab545ab56335ee4129b8c91a27a01b
```

And the Merkle proof for each id looks as follows:

Id 2:

```js
[
  "0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db0",
  "0xf652222313e28459528d920b65115c16c04f3efc82aaedc97be59f3f377c0d3f"
]
```

Id 5:

```js
[
  "0x405787fa12a823e0f2b7631cc41b3ba8828b3321ca811111fa75cd3aa3bb5ace",
  "0xf652222313e28459528d920b65115c16c04f3efc82aaedc97be59f3f377c0d3f"
]
```

Id 6:

```js
[
  "0x7b7da98f67ab775ab79cf3e36984e2490fb6897ba0fc1ef566df8d39adedd92f"
]
```

### Order object

In this example, Seaport is used directly as a conduit. Therefore the `conduitKey` is `0`. Zone is not necessary to use in this example, so the `zone` is also `0`.

The item type of NFT in consideration is `5` standing for the type "ERC1155 with criteria, and `identifierOrCriteria` is the root of the Merkle Tree, formed from the ids `[2, 5, 6]`.

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
      itemType: 5,
      token: "0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B",
      identifierOrCriteria: "0x7e5d06e94050d228c85b4fc55229be36d1ab545ab56335ee4129b8c91a27a01b",
      startAmount: 2,
      endAmount: 2,
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
  startTime: 1673779816,
  endTime: 1674125416,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "65238734723478623487",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
}
```

### Fulfillment parameters breakdown

The `fulfillAdvancedOrder()` function can be used to fulfill the collection offer-based sale order.

Refer to [Order fulfillment](3_Order_fulfillment.md) description of each parameter structure for more details, the particular values for the described case are provided below.

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
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address
        0, // 0 for ERC20 since it is fungible
        "1000000000000000000", // start amount
        "1000000000000000000" // end amount
      ]
    ],
    [ // consideration items
      [ // any NFT from the collection 
        5, // ERC1155 with criteria item type
        "0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B", // ERC1155 token address
        "0x7e5d06e94050d228c85b4fc55229be36d1ab545ab56335ee4129b8c91a27a01b", // criteria = merkle root for ids 2, 5, 6
        2, // start amount
        2, // end amount
        "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5" // recipient - offerer
      ],
      [ // fee to the marketplace
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address 
        0, // 0 for ERC20 since it is fungible
        "25000000000000000", // start amount
        "25000000000000000", // end amount
        "0x0000a26b00c1F0DF003000390027140000fAa719" // recipient - marketplace fee collector
      ],
      [ // royalty fee
        1, // ERC20 token
        "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23", // ERC20 token address 
        0, // 0 for ERC20 since it is fungible
        "50000000000000000", // start amount
        "50000000000000000", // end amount
        "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd" // recipient - royalty address
      ]
    ],
    0, // order type
    1673779816, // start time
    1674125416, // end time
    "0x0000000000000000000000000000000000000000000000000000000000000000", // zone hash
    "65238734723478623487", // salt
    "0x0000000000000000000000000000000000000000000000000000000000000000", // conduit key
    3 // total original consideration items in consideration array
  ],
  1, // numerator
  1, // denominator
  "0xde94abcae8f2b07da926b1b2243304cba767dee8f4e77d72fb322bb493771de62fb506b4cd386ea6ffda7f7e8b7a82ea0a661361f202352ea5d432d585ab35921c", // order signature
  "0x0000000000000000000000000000000000000000000000000000000000000000" // extra data
]
```

#### Criteria resolvers

In the described case, the array with 1 criteria resolver for the item with id `3` is provided.

Value for the described case:

```js
[
  [
    0, // order index
    1, // side. 1 is Consideration
    0, // index
    2, // actual sold NFT id
    [ // proof. empty for this case
      "0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db0",
      "0xf652222313e28459528d920b65115c16c04f3efc82aaedc97be59f3f377c0d3f"
    ]
  ]
]
```

#### Fulfiller Conduit Key

In the described case, both the Offerer and Fulfiller have approved their items to the Seaport contract directly, and the parameter value to pass is:

```js
0x0000000000000000000000000000000000000000000000000000000000000000
```

#### Recipient

In the described case, the intended recipient is the caller himself, so the value is:

```js
0x0000000000000000000000000000000000000000
```

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0x2f83282601b1947c92311d6ace23a4fb79f40c2b3dacc097c607c25e438dbd9c