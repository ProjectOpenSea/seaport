const utils = require("./utils");
const constants = require("./constants");
const consideration = require("./consideration");
const helpers = require("./helpers");

const log = utils.log;
const wallets = constants.wallets;

/// /////////////////////////////////////
/// Wrapper Methods for easy testing

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
  await consideration.validate(orders, rando);
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
  log(`matchOrders tx hash: ${txHash}`);
};

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

module.exports = {
  validate,
  matchOrders,
  fulfillAvailableAdvancedOrders,
};
