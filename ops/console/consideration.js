const eth = require("ethers");

const utils = require("./utils");
const constants = require("./constants");

const log = utils.log;
const logEvents = utils.logEvents;
const wallets = constants.wallets;

const { contracts, deployments } = constants;
const { Consideration, TestERC20, TestERC721 } = contracts;
const { AddressZero, HashZero } = eth.constants;

const day = 60 * 60 * 24; // seconds in a day

// NOTE: offer = what's being sold, consideration = what's being paid

/// /////////////////////////////////////
/// Helper Utility Methods

const mintERC20 = async (amount, signer = wallets[0]) => {
  log(`Minting ${amount} tokens..`);
  await TestERC20.connect(signer)
    .mint(signer.address, amount)
    .then((tx) => {
      return logEvents(tx.hash, deployments.TestERC20.abi);
    });
  log(`Approving ${amount} tokens..`);
  await TestERC20.connect(signer)
    .approve(Consideration.address, amount)
    .then((tx) => {
      return logEvents(tx.hash, deployments.TestERC20.abi);
    });
};

const mintERC721 = async (nftId, signer = wallets[0]) => {
  log(`Minting NFT #${nftId}`);
  await TestERC721.connect(signer)
    .mint(signer.address, nftId)
    .then((tx) => {
      return logEvents(tx.hash, deployments.TestERC721.abi);
    });
  log(`Approving NFT #${nftId}`);
  await TestERC721.connect(signer)
    .approve(Consideration.address, nftId)
    .then((tx) => {
      return logEvents(tx.hash, deployments.TestERC721.abi);
    });
};

// By default, offer 1 NFT up for sale
const createOfferItem = (overrides) => ({
  itemType: 2, // ERC721
  token: TestERC721.address,
  identifierOrCriteria: 0,
  startAmount: 1,
  endAmount: 1,
  ...(overrides || {}),
});

// By default, consider a payment of one ERC20 token
const createConsiderationItem = (overrides) => ({
  itemType: 1, // ERC20
  token: TestERC20.address,
  identifierOrCriteria: 0,
  startAmount: 1,
  endAmount: 1,
  recipient: wallets[0].address,
  ...(overrides || {}),
});

const createCriteriaResolver = (overrides) => ({
  orderIndex: 0,
  side: 0, // Offer
  index: 0,
  identifier: 0,
  criteriaProof: [],
  ...(overrides || {}),
});

// By default, consider a payment of one ERC20 token
const createOrderParameters = (overrides) => ({
  offerer: wallets[0].address,
  zone: AddressZero,
  orderType: 0, // FULL_OPEN
  startTime: Math.round(Date.now() / 1000) - day, // 1 day ago
  endTime: Math.round(Date.now() / 1000) + day, // 1 day from now
  zoneHash: HashZero,
  salt: HashZero,
  conduit: AddressZero,
  totalOriginalConsiderationItems: 1,
  ...(overrides || {}),
  offer: (overrides?.offer || [{}]).map(createOfferItem),
  consideration: (overrides?.consideration || [{}]).map(
    createConsiderationItem
  ),
});

// By default, consider a payment of one ERC20 token
const createOrderComponents = (overrides) => ({
  offerer: wallets[0].address,
  zone: AddressZero,
  orderType: 0, // FULL_OPEN
  startTime: Math.round(Date.now() / 1000) - day, // 1 day ago
  endTime: Math.round(Date.now() / 1000) + day, // 1 day from now
  zoneHash: HashZero,
  salt: HashZero,
  conduit: AddressZero,
  nonce: 0,
  ...(overrides || {}),
  offer: (overrides?.offer || [{}]).map(createOfferItem),
  consideration: (overrides?.consideration || [{}]).map(
    createConsiderationItem
  ),
});

// By default, consider a payment of one ERC20 token
const createOrder = (overrides) => ({
  parameters: createOrderParameters(overrides?.parameters),
  signature: overrides?.signature || HashZero,
});

const createBasicOrder = (overrides) => ({
  considerationToken: TestERC20.address,
  considerationIdentifier: 0,
  considerationAmount: 1,
  offerer: wallets[0].address,
  zone: AddressZero,
  offerToken: TestERC721.address,
  offerIdentifier: 0,
  offerAmount: 1,
  basicOrderType: 16, // ERC721_TO_ERC20_FULL_OPEN
  startTime: Math.round(Date.now() / 1000) - day, // 1 day ago
  endTime: Math.round(Date.now() / 1000) + day, // 1 day from now
  zoneHash: HashZero,
  salt: HashZero,
  offererConduit: AddressZero,
  fulfillerConduit: AddressZero,
  totalOriginalAdditionalRecipients: 1,
  additionalRecipients: [],
  signature: HashZero,
  ...(overrides || {}),
});

const createAdvancedOrder = (overrides) => ({
  numerator: 1,
  denominator: 1,
  signature: HashZero,
  extraData: HashZero,
  ...(overrides || {}),
  parameters: createOrderParameters(overrides?.parameters),
});

// By default, consider a payment of one ERC20 token
const createFulfillment = (overrides) => ({
  offerComponents: [{ orderIndex: 0, itemIndex: 0 }],
  considerationComponents: [{ orderIndex: 0, itemIndex: 0 }],
});

const signOrder = async (overrides, signer = wallets[0]) => {
  const order = createOrderComponents(overrides.parameters);
  order.offerer = signer.address;
  const domain = await Consideration.DOMAIN_SEPARATOR();
  const hash = await getOrderHash(order);
  const digest = eth.utils.keccak256(
    eth.utils.hexConcat(["0x1901", domain, hash])
  );
  const trueDigest = await Consideration.getOrderDigest(order);
  if (digest !== trueDigest) {
    throw new Error(`Error: digests don't match. ${digest} !== ${trueDigest}`);
  }
  // UNSAFE SIGNATURE, we should prob use _signTypedData here instead..
  const sig = new eth.utils.SigningKey(signer.privateKey).signDigest(digest);
  const signature = eth.utils.hexConcat([sig.r, sig.s, sig.v]);
  log(`Signature is ${eth.utils.hexDataLength(signature)} bytes long`);
  return { parameters: order, signature };
};

const helpers = {
  mintERC20,
  mintERC721,
  createOfferItem,
  createConsiderationItem,
  createOrderParameters,
  createOrderComponents,
  createCriteriaResolver,
  createOrder,
  createBasicOrder,
  createAdvancedOrder,
};

/// /////////////////////////////////////
/// Consideration External Methods:
/// - fulfillBasicOrder
/// - fulfillOrder
/// - fulfillAdvancedOrder
/// - fulfillAvailableAdvancedOrders
/// - matchOrders
/// - matchAdvancedOrders
/// - cancel
/// - validate
/// - incrementNonce

const fulfillBasicOrder = async (overrides, signer = wallets[0]) => {
  const basicOrder = createBasicOrder(overrides);
  await mintERC20(basicOrder.considerationAmount, signer);
  log(`Fulfilling basic order: ${JSON.stringify(basicOrder, null, 2)}`);
  Consideration.connect(signer)
    .fulfillBasicOrder(basicOrder)
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
    });
};

const fulfillOrder = async (overrides, signer = wallets[0]) => {
  const order = createOrder(overrides);
  await mintERC20(order.parameters.consideration[0].startAmount, signer);
  log(`Fulfilling order: ${JSON.stringify(order, null, 2)}`);
  Consideration.connect(signer)
    .fulfillOrder(order, AddressZero)
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
    });
};

// eg for: let nftId = 1337; run the following:
// validate({ parameters: { offer: [{ itemType: 4, identifierOrCriteria: nftId }] } })
// fulfillAdvancedOrder({ advancedOrder: { parameters: { offer: [{ itemType: 4, identifierOrCriteria: nftId }] } }, criteriaResolvers: [{ identifier: nftId }] })
const fulfillAdvancedOrder = async (overrides, signer = wallets[0]) => {
  const advancedOrder = createAdvancedOrder(overrides.advancedOrder);
  const criteriaResolvers = [
    createCriteriaResolver(overrides?.criteriaResolvers?.[0]),
  ];
  const fulfillerConduit = overrides?.fulfillerConduit || AddressZero;
  await mintERC20(
    advancedOrder.parameters.consideration[0].startAmount,
    signer
  );
  log(
    `Fulfilling advanced order: ${JSON.stringify(
      { advancedOrder, criteriaResolvers, fulfillerConduit },
      null,
      2
    )}`
  );
  await Consideration.connect(signer)
    .fulfillAdvancedOrder(advancedOrder, criteriaResolvers, fulfillerConduit)
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
    });
};

// eg for: let nftId = 1337; run the following:
// validate({ parameters: { offer: [{ itemType: 4, identifierOrCriteria: nftId }] } })
// fulfillAvailableAdvancedOrders({ advancedOrders: [{ parameters: { offer: [{ itemType: 4, identifierOrCriteria: nftId }] } }], criteriaResolvers: [{ identifier: nftId }] })
const fulfillAvailableAdvancedOrders = async (
  overrides,
  signer = wallets[0]
) => {
  const advancedOrders = (overrides?.advancedOrders || [{}]).map(
    createAdvancedOrder
  );
  const criteriaResolvers = (overrides?.criteriaResolvers || [{}]).map(
    createCriteriaResolver
  );
  const offerFulfillments = overrides?.offerFulfillments || [];
  const considerationFulfillments = overrides?.considerationFulfillments || [];
  const fulfillerConduit = overrides?.fulfillerConduit || AddressZero;
  log(
    `Fulfilling Available Advanced Orders: ${JSON.stringify(
      {
        advancedOrders,
        criteriaResolvers,
        offerFulfillments,
        considerationFulfillments,
        fulfillerConduit,
      },
      null,
      2
    )}`
  );
  return await Consideration.connect(signer)
    .fulfillAvailableAdvancedOrders(
      advancedOrders,
      criteriaResolvers,
      offerFulfillments,
      considerationFulfillments,
      fulfillerConduit
    )
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
      return tx.hash;
    })
    .catch((e) => {
      log(e.message);
      log(`Failure`);
    });
};

// TODO
const matchOrders = async (overrides, signer = wallets[0]) => {
  const orders = (overrides?.orders || [{}]).map(createOrder);
  const fulfillments = (overrides?.fulfillments || [{}]).map(createFulfillment);
  log(`Matching orders: ${JSON.stringify({ orders, fulfillments }, null, 2)}`);
  await Consideration.connect(signer)
    .matchOrders(orders, fulfillments)
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
    });
};

// TODO
const matchAdvancedOrders = async () => {};

const cancel = async (overrides, signer = wallets[0]) => {
  const order = createOrderComponents(overrides);
  log(`Cancelling order: ${JSON.stringify(order, null, 2)}`);
  await Consideration.connect(signer)
    .cancel([order])
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
    });
};

// Only one offer & consideration supported (for now)
// Validates the sale of an NFT in exchange for some tokens by default
// to validate an advanced order: use keccak256(nftId) for the identifierOrCriteria
const validate = async (overrides, signer = wallets[0]) => {
  const orders = (overrides || [{}]).map(createOrder);
  log(`Minting NFTs for orders: ${JSON.stringify(orders, null, 2)}`);
  for (let i = 0; i < orders.length; i++) {
    const order = orders[i];
    for (let i = 0; i < order.parameters.offer.length; i++) {
      const offer = order.parameters.offer[i];
      await mintERC721(offer.identifierOrCriteria, signer);
    }
  }
  log(`Validating order: ${JSON.stringify(orders, null, 2)}`);
  await Consideration.connect(signer)
    .validate(orders)
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
    });
};

const incrementNonce = async (signer = wallets[0]) => {
  await Consideration.connect(signer)
    .incrementNonce()
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
    });
};

const getOrderHash = async (overrides, signer = wallets[0]) => {
  const order = createOrderComponents(overrides);
  log(`Getting order hash for: ${JSON.stringify(order, null, 2)}`);
  return await Consideration.connect(signer)
    .getOrderHash(order)
    .then((hash) => {
      log(`Order Hash: ${hash}`);
      return hash;
    });
};

/// /////////////////////////////////////
/// Wrapper Methods for easy testing

const test = {};

// Test that signature generation is good by submitting an order via 3rd party
test.validate = async () => {
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
  ].map(createOrder);
  orders[0] = await signOrder(orders[0], seller);
  await validate(orders, rando);
};

test.matchOrders = async () => {
  const nftId1 = Math.round(Math.random() * 1000000);
  const nftId2 = Math.round(Math.random() * 1000000);
  const seller = wallets[1];
  const orders = [
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
  ];
  await validate({ orders }, seller);
  await matchOrders({ orders });
};

test.fulfillAvailableAdvancedOrders = async () => {
  const nftId1 = Math.round(Math.random() * 1000000);
  const nftId2 = Math.round(Math.random() * 1000000);
  const buyer = wallets[0];
  const seller = wallets[1];
  // Register two offers to sell 2 different NFTs for 1 token each
  await validate(
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
  return await fulfillAvailableAdvancedOrders(
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
  fulfillBasicOrder: fulfillBasicOrder,
  fulfillOrder: fulfillOrder,
  fulfillAdvancedOrder: fulfillAdvancedOrder,
  fulfillAvailableAdvancedOrders: fulfillAvailableAdvancedOrders,
  matchOrders: matchOrders,
  matchAdvancedOrders: matchAdvancedOrders,
  cancel: cancel,
  validate: validate,
  incrementNonce: incrementNonce,
  getOrderHash: getOrderHash,
  helpers: helpers,
  test: test,
};
