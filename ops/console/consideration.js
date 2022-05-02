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
/// Helper Methods

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
  offer: [createOfferItem(overrides?.offer?.[0])],
  consideration: [createConsiderationItem(overrides?.consideration?.[0])],
});

const createCriteriaResolver = (overrides) => ({
  orderIndex: 0,
  side: 0, // Offer
  index: 0,
  identifier: 0,
  criteriaProof: [],
  ...(overrides || {}),
});

const helpers = {
  mintERC20,
  mintERC721,
  createOfferItem,
  createConsiderationItem,
  createOrderParameters,
  createCriteriaResolver,
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
  // If no orders are available, create one before fulfilling anything?
  await new Promise((resolve) => setTimeout(resolve, 10));
  log(``);
  const tokenAmount = 1;
  await mintERC20(tokenAmount, signer);
  const nftId = overrides?.considerationIdentifier || 1337;
  const basicOrder = {
    ...overrides,
    considerationToken: TestERC20.address,
    considerationIdentifier: 0,
    considerationAmount: 1,
    offerer: signer.address,
    zone: AddressZero,
    offerToken: TestERC721.address,
    offerIdentifier: nftId,
    offerAmount: tokenAmount,
    basicOrderType: 16, // ERC721_TO_ERC20_FULL_OPEN
    startTime: Math.round(Date.now() / 1000), // seconds from epoch until now
    endTime: Math.round(Date.now() / 1000) + 60 * 60, // 1 hour from now
    zoneHash: HashZero,
    salt: HashZero,
    offererConduit: AddressZero,
    fulfillerConduit: AddressZero,
    totalOriginalAdditionalRecipients: 1,
    additionalRecipients: [],
    signature: HashZero,
  };
  log(`Fulfilling basic order: ${JSON.stringify(basicOrder, null, 2)}`);
  Consideration.connect(signer)
    .fulfillBasicOrder(basicOrder)
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
    });
  log(`Success`);
};

const fulfillOrder = async (order, signer = wallets[0]) => {
  const params = order?.parameters || {};
  await new Promise((resolve) => setTimeout(resolve, 10));
  log(``);
  const tokenAmount = 1;
  await mintERC20(tokenAmount, signer);
  const fullOrder = {
    parameters: createOrderParameters(params),
    signature: order?.signature || HashZero,
  };
  log(`Fulfilling order: ${JSON.stringify(fullOrder, null, 2)}`);
  Consideration.connect(signer)
    .fulfillOrder(fullOrder, AddressZero)
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
    });
  log(`Success`);
};

// nftId = 26;
// validate({ parameters: { offer: [{ itemType: 4, identifierOrCriteria: nftId }] } })
// fulfillAdvancedOrder({ advOrder: { parameters: { offer: [{ itemType: 4, identifierOrCriteria: nftId }] } }, criteriaResolvers: [{ identifier: nftId }] })
const fulfillAdvancedOrder = async (overrides, signer = wallets[0]) => {
  const params = overrides?.advOrder?.parameters || {};
  const tokenAmount = 1;
  await mintERC20(tokenAmount, signer);
  const advOrder = {
    numerator: 1,
    denominator: 1,
    signature: HashZero,
    extraData: HashZero,
    ...(overrides?.advOrder || {}),
    parameters: createOrderParameters(params),
  };
  const criteriaResolvers = [
    createCriteriaResolver(overrides?.criteriaResolvers?.[0]),
  ];
  const fulfillerConduit = overrides?.fulfillerConduit || AddressZero;
  log(
    `Fulfilling advanced order: ${JSON.stringify(
      { advOrder, criteriaResolvers, fulfillerConduit },
      null,
      2
    )}`
  );
  await Consideration.connect(signer)
    .fulfillAdvancedOrder(advOrder, criteriaResolvers, fulfillerConduit)
    .then((tx) => {
      global.hash = tx.hash;
      return logEvents(tx.hash, deployments.Consideration.abi);
    });
  log(`Success`);
};

const fulfillAvailableAdvancedOrders = () => {};
const matchOrders = () => {};
const matchAdvancedOrders = () => {};
const cancel = () => {};

// Only one offer & consideration supported (for now)
// Validates the sale of an NFT in exchange for some tokens by default
// to validate an advanced order: use keccak256(nftId) for the identifierOrCriteria
const validate = async (order, signer = wallets[0]) => {
  const parameters = order?.parameters || {};
  const nftId = parameters.offer?.[0]?.identifierOrCriteria || 1337;
  await new Promise((resolve) => setTimeout(resolve, 10));
  log(``);
  await mintERC721(nftId, signer);
  const fullOrder = {
    parameters: {
      offerer: signer.address,
      zone: AddressZero,
      orderType: 1,
      startTime: Math.round(Date.now() / 1000), // seconds from epoch until now
      endTime: Math.round(Date.now() / 1000) + 60 * 60, // 1 hour from now
      zoneHash: HashZero,
      salt: HashZero,
      conduit: AddressZero,
      totalOriginalConsiderationItems: 1,
      ...parameters,
      offer: [createOfferItem(parameters?.offer?.[0])],
      consideration: [createConsiderationItem(parameters?.consideration?.[0])],
    },
    signature: order?.signature || HashZero,
  };
  log(`Validating order: ${JSON.stringify(fullOrder, null, 2)}`);
  await Consideration.connect(signer)
    .validate([fullOrder])
    .then((tx) => {
      global.hash = tx.hash;
      return logEvents(tx.hash, deployments.Consideration.abi);
    });
  log(`Success`);
};

const incrementNonce = (signer = wallets[0]) => {
  deployments.Consideration.connect(signer)
    .incrementNonce()
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
    });
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
  helpers: helpers,
};
