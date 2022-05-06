const utils = require("./utils");
const constants = require("./constants");
const consideration = require("./consideration");
const helpers = require("./helpers");

const log = utils.log;
const wallets = constants.wallets;

/// /////////////////////////////////////
/// Wrapper Methods for easy testing

const fulfillBasicOrder = async () => {
  const buyer = wallets[0];
  const seller = wallets[1];
  const nftId = Math.round(Math.random() * 1000000);
  log(
    `Testing fulfillBasicOrder with buyer=${buyer.address} seller=${seller.address} nftId=${nftId}`
  );
  await consideration.validate(
    [
      {
        parameters: {
          offerer: seller.address,
          offer: [{ itemType: 2, identifierOrCriteria: nftId }],
        },
      },
    ],
    seller
  );
  const txHash = await consideration.fulfillBasicOrder(
    { offerer: seller.address, offerIdentifier: nftId },
    seller
  );
  log(`fulfillBasicOrder tx hash: ${txHash}`);
};

const fulfillOrder = async () => {};

const fulfillAdvancedOrder = async () => {};

const fulfillAvailableOrders = async () => {};

const fulfillAvailableAdvancedOrders = async () => {
  const nftId1 = Math.round(Math.random() * 1000000);
  const nftId2 = Math.round(Math.random() * 1000000);
  const buyer = wallets[0];
  const seller = wallets[1];
  // Register two offers to sell 2 different NFTs for 1 token each
  await consideration.validate(
    {
      orders: [
        {
          parameters: {
            offerer: seller.address,
            offer: [
              { itemType: 4, identifierOrCriteria: nftId1 },
              { itemType: 4, identifierOrCriteria: nftId2 },
            ],
            consideration: [{ startAmount: 2, endAmount: 2 }],
          },
        },
      ],
    },
    seller
  );
  // Fulfill both offers..?
  return await consideration.fulfillAvailableAdvancedOrders(
    {
      advancedOrders: [
        {
          parameters: {
            offer: [
              { itemType: 4, identifierOrCriteria: nftId1 },
              { itemType: 4, identifierOrCriteria: nftId2 },
            ],
            consideration: [{ startAmount: 2, endAmount: 2 }],
          },
        },
      ],
      criteriaResolvers: [
        { identifier: nftId1 },
        { identifier: nftId2, index: 1 },
      ],
      offerFulfillments: [[{ orderIndex: 0, itemIndex: 0 }]],
      considerationFulfillments: [[{ orderIndex: 0, itemIndex: 0 }]],
    },
    buyer
  );
};

const matchOrders = async () => {
  // Validate an order to sell 1 NFT
  const buyer = wallets[0];
  const seller = wallets[1];
  const nftId = Math.round(Math.random() * 1000000);
  const sellOrder = await helpers.signOrder(
    {
      parameters: {
        offer: [{ itemType: 2, identifierOrCriteria: nftId }],
        consideration: [
          {
            startAmount: 1,
            endAmount: 1,
            recipient: seller.address,
          },
        ],
      },
    },
    seller
  );
  await consideration.validate([sellOrder]);
  // Validate an order to buy the 2 NFTs for sale
  const buyOrder = await helpers.signOrder(
    {
      parameters: {
        offerer: buyer.address,
        offer: [{ itemType: 1, startAmount: 2, endAmount: 2 }],
        consideration: [{ itemType: 2, identifierOrCriteria: nftId }],
      },
    },
    buyer
  );
  await consideration.validate([buyOrder]);
  // Match the validated orders
  const fulfillments = [
    // 1st fulfillment: NFT #1
    {
      offerComponents: [
        {
          orderIndex: 0,
          itemIndex: 0,
        },
      ],
      considerationComponents: [
        {
          orderIndex: 1,
          itemIndex: 0,
        },
      ],
    },
    // 2nd fulfillment: ERC20s
    {
      offerComponents: [
        {
          orderIndex: 1,
          itemIndex: 0,
        },
      ],
      considerationComponents: [
        {
          orderIndex: 0,
          itemIndex: 0,
        },
      ],
    },
  ];
  const txHash = await consideration.matchOrders({
    orders: [sellOrder, buyOrder],
    fulfillments,
  });
  if (txHash) {
    log(`matchOrders tx hash: ${txHash}`);
  }
};

const matchAdvancedOrders = async () => {};

const cancel = async () => {
  // Validate an order to sell 1 NFT
  const seller = wallets[1];
  const nftId = Math.round(Math.random() * 1000000);
  const sellOrder = await helpers.signOrder(
    {
      parameters: {
        offer: [{ itemType: 2, identifierOrCriteria: nftId }],
        consideration: [
          {
            startAmount: 1,
            endAmount: 1,
            recipient: seller.address,
          },
        ],
      },
    },
    seller
  );
  await consideration.validate([sellOrder]);
  const txHash = await consideration.cancel([sellOrder]);
  log(`cancel tx hash: ${txHash}`);
};

// Test that signature generation is good by submitting an order via 3rd party
const validate = async () => {
  const nftId1 = Math.round(Math.random() * 1000000);
  const nftId2 = Math.round(Math.random() * 1000000);
  const seller = wallets[1];
  const rando = wallets[3];
  const orders = [
    {
      parameters: {
        offer: [
          { itemType: 4, identifierOrCriteria: nftId1 },
          { itemType: 4, identifierOrCriteria: nftId2 },
        ],
        consideration: [{ startAmount: 2, endAmount: 2 }],
      },
    },
  ].map(helpers.createOrder);
  orders[0] = await helpers.signOrder(orders[0], seller);
  const txHash = await consideration.validate(orders, rando);
  log(`validate tx hash: ${txHash}`);
};

const incrementNonce = async () => {
  const txHash = await consideration.incrementNonce();
  log(`incrementNonce tx hash: ${txHash}`);
};

// TODO: 6
module.exports = {
  fulfillBasicOrder: fulfillBasicOrder, // TODO
  fulfillOrder: fulfillOrder, // TODO
  fulfillAdvancedOrder: fulfillAdvancedOrder, // TODO
  fulfillAvailableOrders: fulfillAvailableOrders, // TODO
  fulfillAvailableAdvancedOrders: fulfillAvailableAdvancedOrders, // TODO
  matchOrders: matchOrders,
  matchAdvancedOrders: matchAdvancedOrders, // TODO
  cancel: cancel,
  validate: validate,
  incrementNonce: incrementNonce,
};
