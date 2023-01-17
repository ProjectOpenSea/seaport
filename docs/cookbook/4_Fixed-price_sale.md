# Fixed-price sale

The fixed-price sale is what happens when you list the NFT on the marketplace via a fixed-price option. In this case, the Offerer is the seller of the item.

To fulfill the fixed-price sale order, the `fulfillBasicOrder()` function is sufficient and is used on Opensea.

## Process steps:

1.  Offerer approves his NFT collection to Conduit.
2.  Offerer signs an order object.
3.  The marketplace back-office stores the order hash based on the order parameters. This hash can be composed via the `getOrderHash()` Seaport contract function.
4.  If the item is listed in ERC20, the buyer approves the necessary amount of ERC20 to the Conduit.
5.  Buyer confirms `fulfillBasicOrder()` transaction.
6.  Post-transaction, the marketplace back-office tracks the transaction via order hash and changes the item status to "sold".

## Sale of ERC721 for ETH

### Order details

Seller: `0x07765B25468f559d88AffE4fcCB2B386004BFd2e`

Offer:

-   ERC721 NFT:
    -   Token contract: `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0`
    -   Token id: `1`

Consideration:
Total value: `0.003 ETH`

-   ETH to the Offerer: `0.002775 ETH`
-   Fee to the marketplace: `0.000075 ETH`
-   Royalty to the collection creator: `0.00015 ETH`

### Order object

In this example, Seaport is used directly as a conduit. Therefore the `conduitKey` is `0`. Zone is not necessary to use in this example, so the `zone` is also `0`.

Order object to sign:

```js
{
  offerer: "0x07765B25468f559d88AffE4fcCB2B386004BFd2e",
  zone: "0x0000000000000000000000000000000000000000",
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
      itemType: 0,
      token: "0x0000000000000000000000000000000000000000",
      identifierOrCriteria: 0,
      startAmount: "2775000000000000",
      endAmount: "2775000000000000",
      recipient: "0x07765B25468f559d88AffE4fcCB2B386004BFd2e"
    },
    {
      itemType: 0,
      token: "0x0000000000000000000000000000000000000000",
      identifierOrCriteria: 0,
      startAmount: "75000000000000",
      endAmount: "75000000000000",
      recipient: "0x0000a26b00c1F0DF003000390027140000fAa719"
    },
    {
      itemType: 0,
      token: "0x0000000000000000000000000000000000000000",
      identifierOrCriteria: 0,
      startAmount: "150000000000000",
      endAmount: "150000000000000",
      recipient: "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"
    }
  ],
  orderType: 0,
  startTime: 1671365303,
  endTime: 1671538103,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "765234765234",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
}
```

### Fulfillment parameters breakdown

The `fulfillBasicOrder()` function can be used to fulfill the fixed-price sale order. The order parameters to pass to the function input:

| Parameter                         | Comments                                                                  | Value                                                                                                                                  |
| --------------------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| considerationToken                | ETH                                                                       | `0x0000000000000000000000000000000000000000`                                                                                           |
| considerationIdentifier           | Consideration token id. Since it's fungible, it's 0                       | `0`                                                                                                                                    |
| considerationAmount               | Amount of ETH to send to seller                                           | `2775000000000000`                                                                                                                     |
| offerer                           | Seller address                                                            | `0x07765B25468f559d88AffE4fcCB2B386004BFd2e`                                                                                           |
| zone                              | Zone address                                                              | `0x0000000000000000000000000000000000000000`                                                                                           |
| offerToken                        | ERC721 token address                                                      | `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0`                                                                                           |
| offerIdentifier                   | ERC721 token id                                                           | `1`                                                                                                                                    |
| offerAmount                       | ERC721 token quantity. Equals 1                                           | `1`                                                                                                                                    |
| basicOrderType                    | Basic order type matching the orderType in order object and assets traded | `0`                                                                                                                                    |
| startTime                         | Start time from order object                                              | `1671365303`                                                                                                                           |
| endTime                           | End time from order object                                                | `1671538103`                                                                                                                           |
| zoneHash                          | Zone hash                                                                 | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                   |
| salt                              | Salt from order object                                                    | `765234765234`                                                                                                                         |
| offererConduitKey                 | Offerer conduit key (0 since Seaport is used as Conduit)                  | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                   |
| fulfillerConduitKey               | Fulfiller conduit key (0 since Seaport is used as Conduit)                | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                   |
| totalOriginalAdditionalRecipients | Amount of recipients other than seller in consideration                   | `2`                                                                                                                                    |
| additionalRecipients              | Tuples with pairs [value, receiver] for each recipient                    | `[["75000000000000","0x0000a26b00c1F0DF003000390027140000fAa719"],["150000000000000","0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"]]`   |
| signature                         | Offerer's signature of the order object                                   | `0x9b07e084e2e3834bd10f097eeef621c5f00b7da962c1af49b1c8f70ae30fda5c551c89f310d31d8ee3ea0a4a8718b53ec75fdf547612dd1c4a550b95244f74251b` |

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0xb7de9c060039eb8dd32ef2d8200589659b887271139e8da53cdff5cc2efee12d  

## Sale of ERC721 for ERC20

### Order details

Seller: `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`

Offer:

-   ERC721 NFT:
    -   Token contract: `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0`
    -   Token id: `1`

Consideration:
Total value: `5 TEST`

-   TEST to the Offerer: `4.625 TEST`
-   Fee to the marketplace: `0.125 TEST`
-   Royalty to the collection creator: `0.25 TEST`

### Order object

In this example, Seaport is used directly as a conduit. Therefore the `conduitKey` is `0`. Zone is not necessary to use in this example, so the `zone` is also `0`.

Order object to sign:

```js
const value = {
  offerer: "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5",
  zone: "0x0000000000000000000000000000000000000000",
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
      startAmount: "4625000000000000000",
      endAmount: "4625000000000000000",
      recipient: "0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "125000000000000000",
      endAmount: "125000000000000000",
      recipient: "0x0000a26b00c1F0DF003000390027140000fAa719"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "250000000000000000",
      endAmount: "250000000000000000",
      recipient: "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"
    }
  ],
  orderType: 0,
  startTime: 1671365303,
  endTime: 1671538103,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "87623487623487623487",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
};
```

### Fulfillment parameters breakdown

The `fulfillBasicOrder()` function can be used to fulfill the fixed-price sale order. The order parameters to pass to the function input:

| Parameter                         | Comments                                                                  | Value                                                                                                                                         |
| --------------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| considerationToken                | ERC20 token address                                                       | `0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23`                                                                                                  |
| considerationIdentifier           | Consideration token id. Since it's fungible, it's 0                       | `0`                                                                                                                                           |
| considerationAmount               | Amount of ERC20                                                           | `4625000000000000000`                                                                                                                         |
| offerer                           | Seller address                                                            | `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`                                                                                                  |
| zone                              | Zone address                                                              | `0x0000000000000000000000000000000000000000`                                                                                                  |
| offerToken                        | ERC721 token address                                                      | `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0`                                                                                                  |
| offerIdentifier                   | ERC721 token id                                                           | `1`                                                                                                                                           |
| offerAmount                       | ERC721 token quantity                                                     | `1`                                                                                                                                           |
| basicOrderType                    | Basic order type matching the orderType in order object and assets traded | `8`                                                                                                                                           |
| startTime                         | Start time from order object                                              | `1671365303`                                                                                                                                  |
| endTime                           | End time from order object                                                | `1671538103`                                                                                                                                  |
| zoneHash                          | Zone hash                                                                 | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                          |
| salt                              | Salt from order object                                                    | `87623487623487623487`                                                                                                                        |
| offererConduitKey                 | Offerer conduit key (0 since Seaport is used as a Conduit)                | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                          |
| fulfillerConduitKey               | Fulfiller conduit key (0 since Seaport is used as a Conduit)              | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                          |
| totalOriginalAdditionalRecipients | Amount of recipients other than seller in consideration                   | `2`                                                                                                                                           |
| additionalRecipients              | Tuples with pairs [value, receiver] for each  recipient                   | `[["125000000000000000", "0x0000a26b00c1F0DF003000390027140000fAa719"],["250000000000000000", "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"]]` |
| signature                         | Offerer's signature of the order object                                   | `0xa39595210df558a5668e06ff0cb701c2afe64d8f0b0c7714947bd25090d97a794effec9fd8fe47d2fff510f98dc49e159319a8bdfcedb87952f1ab54e92c4d4d1c`        |

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0xf5160ce133d427fc056d43b999a98c63acf9919ba85e89c9c7a05f5f03f371ea

## Sale of ERC1155 for ETH

Seller: `0x24b35e781c20d2fe7b06d4bf985eb954d41abcc5`

Offer:

-   ERC1155 NFT:
    -   Token contract: `0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B`
    -   Token id: `2`
    -   Token quantity: `5`

Consideration:
Total value: `0.004 ETH`

-   ETH to the Offerer: `0.00038 ETH`
-   Fee to the marketplace: `0.00002 ETH`

### Order object

In this example, Seaport is used directly as a conduit. Therefore the `conduitKey` is `0`. Zone is not necessary to use in this example, so the `zone` is also `0`.

Order object to sign:

```js
const value = {
  offerer: "0x24b35e781c20d2fe7b06d4bf985eb954d41abcc5",
  zone: "0x0000000000000000000000000000000000000000",
  offer: [
    {
      itemType: 3,
      token: "0xf29f3b6a60c95d8f7659fc5b0c98c64d35633d4b",
      identifierOrCriteria: 2,
      startAmount: 5,
      endAmount: 5
    }
  ],
  consideration: [
    {
      itemType: 0,
      token: "0x0000000000000000000000000000000000000000",
      identifierOrCriteria: 0,
      startAmount: "380000000000000",
      endAmount: "380000000000000",
      recipient: "0x24b35e781c20d2fe7b06d4bf985eb954d41abcc5"
    },
    {
      itemType: 0,
      token: "0x0000000000000000000000000000000000000000",
      identifierOrCriteria: 0,
      startAmount: "20000000000000",
      endAmount: "20000000000000",
      recipient: "0x0000a26b00c1F0DF003000390027140000fAa719"
    }
  ],
  orderType: 0,
  startTime: 1671432920,
  endTime: 1671605720,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "63366406355630714",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
};
```

### Fulfillment parameters breakdown

The `fulfillBasicOrder()` function can be used to fulfill the fixed-price sale order. The order parameters to pass to the function input:

| Parameter                         | Comments                                                                      | Value                                                                                                                                  |
| --------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| considerationToken                | ETH                                                                           | `0x0000000000000000000000000000000000000000`                                                                                           |
| considerationIdentifier           | Consideration token id. Since it's fungible, it's 0                           | `0`                                                                                                                                    |
| considerationAmount               | Amount of ETH to send to seller                                               | `380000000000000`                                                                                                                      |
| offerer                           | Seller address                                                                | `0x24B35E781c20D2fe7b06d4BF985eB954D41ABCC5`                                                                                           |
| zone                              | Zone address                                                                  | `0x0000000000000000000000000000000000000000`                                                                                           |
| offerToken                        | ERC1155 token address                                                         | `0xf29f3b6a60c95d8f7659fc5b0c98c64d35633d4b`                                                                                           |
| offerIdentifier                   | ERC1155 token id                                                              | `2`                                                                                                                                    |
| offerAmount                       | ERC1155 token quantity                                                        | `5`                                                                                                                                    |
| basicOrderType                    | Basic order type matching the orderType in order object and the assets traded | `4`                                                                                                                                    |
| startTime                         | Start time from order object                                                  | `1671432920`                                                                                                                           |
| endTime                           | End time from order object                                                    | `1671605720`                                                                                                                           |
| zoneHash                          | Zone hash                                                                     | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                   |
| salt                              | Salt from order object                                                        | `63366406355630714`                                                                                                                    |
| offererConduitKey                 | Offerer conduit key (0 since Seaport is used as a Conduit)                    | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                   |
| fulfillerConduitKey               | Fulfiller conduit key (0 since Seaport is used as a Conduit)                  | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                   |
| totalOriginalAdditionalRecipients | Amount of recipients other than seller in consideration                       | `1`                                                                                                                                    |
| additionalRecipients              | Tuples with pairs [value, receiver] for each recipient                        | `[["20000000000000", "0x0000a26b00c1F0DF003000390027140000fAa719"]]`                                                                   |
| signature                         | Offerer's signature of the order object                                       | `0x79d8d19921ebc7d19987fa917f4dbff47b173fa8dbc5927917bab9239e536c536452217524c26570483aa48f84e9947903118edecb6a3f0fb838262fb57982b91b` |

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0xab8836d30d74784c4a527fe4c25d7e55b1e6437a51e2e118aef937b60b7a43cc

## Sale of ERC1155 for ERC20

### Offer and Consideration

Seller: `0x07765B25468f559d88AffE4fcCB2B386004BFd2e`

Offer:

-   ERC721 NFT:
    -   Token contract: `0xF29f3B6A60C95D8F7659Fc5b0C98C64d35633D4B`
    -   Token id: `2`
    -   Token quantity: `3`

Consideration:
Total value: `4 TEST`

-   TEST to the Offerer: `3.7 TEST`
-   Fee to the marketplace: `0.1 TEST`
-   Royalty to the collection creator: `0.2 TEST`

### Order object

In this example, Seaport is used directly as a conduit. Therefore the `conduitKey` is `0`. Zone is not necessary to use in this example, so the `zone` is also `0`.

Order object to sign:

```js
const value = {
  offerer: "0x07765B25468f559d88AffE4fcCB2B386004BFd2e",
  zone: "0x0000000000000000000000000000000000000000",
  offer: [
    {
      itemType: 3,
      token: "0xf29f3b6a60c95d8f7659fc5b0c98c64d35633d4b",
      identifierOrCriteria: 2,
      startAmount: 3,
      endAmount: 3
    }
  ],
  consideration: [
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "3700000000000000000",
      endAmount: "3700000000000000000",
      recipient: "0x07765B25468f559d88AffE4fcCB2B386004BFd2e"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "100000000000000000",
      endAmount: "100000000000000000",
      recipient: "0x0000a26b00c1F0DF003000390027140000fAa719"
    },
    {
      itemType: 1,
      token: "0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23",
      identifierOrCriteria: 0,
      startAmount: "200000000000000000",
      endAmount: "200000000000000000",
      recipient: "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"
    }
  ],
  orderType: 0,
  startTime: 1671432920,
  endTime: 1671605720,
  zoneHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  salt: "128376123876218376348",
  conduitKey: "0x0000000000000000000000000000000000000000000000000000000000000000",
  counter: 0
};
```

### Fulfillment parameters breakdown

The `fulfillBasicOrder()` function can be used to fulfill the fixed-price sale order. The order parameters to pass to the function input:

| Parameter                         | Comments                                                                      | Value                                                                                                                                          |
| --------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| considerationToken                | ERC20 token                                                                   | `0xE7E9d7B8AEDf038012caEe8F22dCf30c01631D23`                                                                                                   |
| considerationIdentifier           | Consideration token id. Since it's fungible, it's 0                           | `0`                                                                                                                                            |
| considerationAmount               | Amount of ERC20 to send to seller                                             | `3700000000000000000`                                                                                                                          |
| offerer                           | Seller address                                                                | `0x07765B25468f559d88AffE4fcCB2B386004BFd2e`                                                                                                   |
| zone                              | Zone address                                                                  | `0x0000000000000000000000000000000000000000`                                                                                                   |
| offerToken                        | ERC1155 token address                                                         | `0xf29f3b6a60c95d8f7659fc5b0c98c64d35633d4b`                                                                                                   |
| offerIdentifier                   | ERC1155 token id                                                              | `2`                                                                                                                                            |
| offerAmount                       | ERC1155 token quantity                                                        | `3`                                                                                                                                            |
| basicOrderType                    | Basic order type matching the orderType in order object and the assets traded | `12`                                                                                                                                           |
| startTime                         | Start time from order object                                                  | `1671432920`                                                                                                                                   |
| endTime                           | End time from order object                                                    | `1671605720`                                                                                                                                   |
| zoneHash                          | Zone hash                                                                     | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                           |
| salt                              | Salt from order object                                                        | `128376123876218376348`                                                                                                                        |
| offererConduitKey                 | Offerer conduit key (0 since Seaport is used as a conduit)                    | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                           |
| fulfillerConduitKey               | Fulfiller conduit key (0 since Seaport is used as a conduit)                  | `0x0000000000000000000000000000000000000000000000000000000000000000`                                                                           |
| totalOriginalAdditionalRecipients | Amount of recipients other than seller in consideration                       | `2`                                                                                                                                            |
| additionalRecipients              | Tuples with pairs [value, receiver] for each recipient                        | `[["100000000000000000", "0x0000a26b00c1F0DF003000390027140000fAa719"], ["200000000000000000", "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"]]` |
| signature                         | Offerer's signature of the order object                                       | `0xe02c19b30f6283f78650307f9eef678266b7123a226f12d547da6514aff1182f468e9a1716e349182142728e0d830da6ac6d40fbd1179230683514681ecd12861b`         |

### Fulfillment transaction example

https://goerli.etherscan.io/tx/0x0e5e9b2a9e3c6700fb0e0851eed78061471bc72eb438d1ac2736c74090b97985