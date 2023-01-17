# Order object signing

## Object structure

The Offerer needs to sign the Order object to initiate the Order creation off-chain. This is an example of an Order object for fixed-price sale order:

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

Each of the parameters included in the Order is explained in detail in [Seaport Documentation](/docs/SeaportDocumentation.md). Simply put, the object above describes the following:

-   Offerer (trade initiator) is `0x07765B25468f559d88AffE4fcCB2B386004BFd2e`
-   Offerer offers his ERC721 (`itemType` = 2 stands for ERC721) asset with token address `0xaa5730aBE335DAe51Dd4306357622Fc8527603b0` and token id 1 in amount 1
-   Offerer considers the following should happen so he gives his asset:
    -   Offerer receives 0,002775 ETH (`itemType` = 0 stands for the native token) to his address
    -   Marketplace fee of 0,000075 ETH is paid to the Marketplace fee collector address
    -   Royalty fee of 0,00015 ETH is paid to the Royalty receiver address
-   Anyone can execute the Order and Order must be completed fully (`orderType` = 0. Refer to [Seaport Documentation](/docs/SeaportDocumentation.md) for other order types)
-   Order becomes valid at Sun Dec 18 2022 12:08:23 GMT+0000 and expires at Tue Dec 20 2022 12:08:23 GMT+0000
-   No zone is necessary to additionally validate the order (`zone` and `zoneHash` are zero)
-   Assets are being approved to the Seaport contract directly (`conduitKey` is zero)
-   Current counter of Offerer is `0`. If the Offerer increases the counter, this Order will become invalid

## Signature

The Offer object needs to be signed by Offerer as typed data in the semi-off-chain Order process. The code below demonstrates a sample of such a signature with the Ethers.js library.

```js
let wallet; // ethers.Wallet, Offerer's wallet

// ...

// Forming the object to sign
const domain = {
  name: 'Seaport',
  version: '1.1', // update this to the relevant version
  chainId: 5, // change this to the needed chain
  verifyingContract: '0x00000000006c3852cbef3e08e8df289169ede581'
};

const orderType = {
  OrderComponents: [
    { name: "offerer", type: "address" },
    { name: "zone", type: "address" },
    { name: "offer", type: "OfferItem[]" },
    { name: "consideration", type: "ConsiderationItem[]" },
    { name: "orderType", type: "uint8" },
    { name: "startTime", type: "uint256" },
    { name: "endTime", type: "uint256" },
    { name: "zoneHash", type: "bytes32" },
    { name: "salt", type: "uint256" },
    { name: "conduitKey", type: "bytes32" },
    { name: "counter", type: "uint256" },
  ],
  OfferItem: [
    { name: "itemType", type: "uint8" },
    { name: "token", type: "address" },
    { name: "identifierOrCriteria", type: "uint256" },
    { name: "startAmount", type: "uint256" },
    { name: "endAmount", type: "uint256" },
  ],
  ConsiderationItem: [
    { name: "itemType", type: "uint8" },
    { name: "token", type: "address" },
    { name: "identifierOrCriteria", type: "uint256" },
    { name: "startAmount", type: "uint256" },
    { name: "endAmount", type: "uint256" },
    { name: "recipient", type: "address" },
  ],
};

let value = {
  // order object based on the particular type of trade
};

// Signing the data
let signature = await wallet._signTypedData(domain, orderType, value);
```

## Obtaining Order hash

Order hash can be obtained from created Order parameters through the Seaport contract `getOrderHash()` function. Order hash is used to further track the events of Order Fulfillment or Order Cancel. The order hash of particular orders is a parameter of the `OrderCancel` & `OrderFulfilled` contract events.

Function accepts a parameter with the following data structure:
```js
struct OrderComponents {
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
    uint256 counter;
}
```

Example of input parameters for `getOrderHash()` function for the object signed above:

```js
[
  "0x07765B25468f559d88AffE4fcCB2B386004BFd2e",
  "0x0000000000000000000000000000000000000000",
  [
    [
      2,
      "0xaa5730aBE335DAe51Dd4306357622Fc8527603b0",
      1,
      1,
      1
    ]
  ],
  [
    [
      0,
      "0x0000000000000000000000000000000000000000",
      0,
      "2775000000000000",
      "2775000000000000",
      "0x07765B25468f559d88AffE4fcCB2B386004BFd2e"
    ],
    [
      0,
      "0x0000000000000000000000000000000000000000",
      0,
      "75000000000000",
      "75000000000000",
      "0x0000a26b00c1F0DF003000390027140000fAa719"
    ],
    [
      0,
      "0x0000000000000000000000000000000000000000",
      0,
      "150000000000000",
      "150000000000000",
      "0x6aef41Be8d7325Ef6dFf18F481b16d9a2012C8cd"
    ]
  ],
  0,
  1671365303,
  1671538103,
  "0x0000000000000000000000000000000000000000000000000000000000000000",
  "765234765234",
  "0x0000000000000000000000000000000000000000000000000000000000000000",
  0
]
```

Output of `getOrderHash()`:

```js
0xd4c6d87f29004900c23f130abd9c0249cca416691e70b3a1adcba67c45c3f449
```