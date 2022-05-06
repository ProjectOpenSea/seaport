const eth = require("ethers");

const utils = require("./utils");
const constants = require("./constants");
const helpers = require("./helpers");

const log = utils.log;
const logEvents = utils.logEvents;
const wallets = constants.wallets;

const { contracts, deployments } = constants;
const { Consideration } = contracts;
const { AddressZero } = eth.constants;

const txOpts = { gasLimit: "5000000" };
const { stringify, trace } = helpers;

// NOTE: offer = what's being sold, consideration = what's being paid

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
  const basicOrder = helpers.createBasicOrder(overrides);
  log(`fulfillBasicOrder(${stringify(basicOrder)})`);
  return await Consideration.connect(signer)
    .fulfillBasicOrder(basicOrder, txOpts)
    .then(async (tx) => {
      await logEvents(tx.hash, deployments.Consideration.abi);
      return tx.hash;
    })
    .catch(trace);
};

const fulfillOrder = async (overrides, signer = wallets[0]) => {
  const order = helpers.createOrder(overrides);
  log(`fulfillOrder(${stringify(order)})`);
  return await Consideration.connect(signer)
    .fulfillOrder(order, AddressZero)
    .then(async (tx) => {
      await logEvents(tx.hash, deployments.Consideration.abi);
      return tx.hash;
    })
    .catch(trace);
};

// eg for: let nftId = 1337; run the following:
// validate({ parameters: { offer: [{ itemType: 4, identifierOrCriteria: nftId }] } })
// fulfillAdvancedOrder({ advancedOrder: { parameters: { offer: [{ itemType: 4, identifierOrCriteria: nftId }] } }, criteriaResolvers: [{ identifier: nftId }] })
const fulfillAdvancedOrder = async (overrides, signer = wallets[0]) => {
  const advancedOrder = helpers.createAdvancedOrder(overrides.advancedOrder);
  const criteriaResolvers = [
    helpers.createCriteriaResolver(overrides?.criteriaResolvers?.[0]),
  ];
  const fulfillerConduit = overrides?.fulfillerConduit || AddressZero;
  log(
    `fulfillAdvancedOrder(${stringify(advancedOrder)}, ${stringify(
      criteriaResolvers
    )}, ${stringify(fulfillerConduit)})`
  );
  return await Consideration.connect(signer)
    .fulfillAdvancedOrder(advancedOrder, criteriaResolvers, fulfillerConduit)
    .then(async (tx) => {
      await logEvents(tx.hash, deployments.Consideration.abi);
      return tx.hash;
    })
    .catch(trace);
};

// TODO
const fulfillAvailableOrders = async (overrides, signer = wallets[0]) => {};

// eg for: let nftId = 1337; run the following:
// validate({ parameters: { offer: [{ itemType: 4, identifierOrCriteria: nftId }] } })
// fulfillAvailableAdvancedOrders({ advancedOrders: [{ parameters: { offer: [{ itemType: 4, identifierOrCriteria: nftId }] } }], criteriaResolvers: [{ identifier: nftId }] })
const fulfillAvailableAdvancedOrders = async (
  overrides,
  signer = wallets[0]
) => {
  const advancedOrders = (overrides?.advancedOrders || [{}]).map(
    helpers.createAdvancedOrder
  );
  const criteriaResolvers = (overrides?.criteriaResolvers || [{}]).map(
    helpers.createCriteriaResolver
  );
  const offerFulfillments = overrides?.offerFulfillments || [];
  const considerationFulfillments = overrides?.considerationFulfillments || [];
  const fulfillerConduit = overrides?.fulfillerConduit || AddressZero;
  log(
    `Fulfilling Available Advanced Orders: ${stringify({
      advancedOrders,
      criteriaResolvers,
      offerFulfillments,
      considerationFulfillments,
      fulfillerConduit,
    })}`
  );
  return await Consideration.connect(signer)
    .fulfillAvailableAdvancedOrders(
      advancedOrders,
      criteriaResolvers,
      offerFulfillments,
      considerationFulfillments,
      fulfillerConduit
    )
    .then(async (tx) => {
      await logEvents(tx.hash, deployments.Consideration.abi);
      return tx.hash;
    })
    .catch((e) => {
      log(e);
      log(`Failure`);
    });
};

const matchOrders = async (overrides, signer = wallets[0]) => {
  const orders = (overrides?.orders || [{}]).map(helpers.createOrder);
  const fulfillments = (overrides?.fulfillments || [{}]).map(
    helpers.createFulfillment
  );
  log(`matchOrders(${stringify(orders)}, ${stringify(fulfillments)})`);
  return await Consideration.connect(signer)
    .matchOrders(orders, fulfillments)
    .then(async (tx) => {
      await logEvents(tx.hash, deployments.Consideration.abi);
      return tx.hash;
    })
    .catch(trace);
};

// TODO
const matchAdvancedOrders = async (overrides, signer = wallets[0]) => {
  const orders = (overrides?.advancedOrders || [{}]).map(helpers.createOrder);
  const fulfillments = (overrides?.fulfillments || [{}]).map(
    helpers.createFulfillment
  );
  const resolvers = (overrides?.criteriaResolvers || [{}]).map(
    helpers.createCriteriaResolver
  );
  log(`matchAdvancedOrders(${orders}, ${resolvers}, ${fulfillments})`);
  await Consideration.connect(signer)
    .matchAdvancedOrders(orders, resolvers, fulfillments)
    .then(async (tx) => {
      await logEvents(tx.hash, deployments.Consideration.abi);
      return tx.hash;
    })
    .catch(trace);
};

const cancel = async (overrides, signer = wallets[0]) => {
  const order = helpers.createOrderComponents(overrides);
  log(`cancel(${stringify([order])})`);
  return await Consideration.connect(signer)
    .cancel([order])
    .then(async (tx) => {
      await logEvents(tx.hash, deployments.Consideration.abi);
      return tx.hash;
    })
    .catch(trace);
};

const validate = async (overrides, signer = wallets[0]) => {
  const orders = (overrides || [{}]).map(helpers.createOrder);
  log(`validate(${stringify(orders)})`);
  return await Consideration.connect(signer)
    .validate(orders)
    .then(async (tx) => {
      await logEvents(tx.hash, deployments.Consideration.abi);
      return tx.hash;
    })
    .catch(trace);
};

const incrementNonce = async (signer = wallets[0]) => {
  return await Consideration.connect(signer)
    .incrementNonce()
    .then(async (tx) => {
      await logEvents(tx.hash, deployments.Consideration.abi);
      return tx.hash;
    })
    .catch(trace);
};

module.exports = {
  fulfillBasicOrder: fulfillBasicOrder,
  fulfillOrder: fulfillOrder,
  fulfillAdvancedOrder: fulfillAdvancedOrder,
  fulfillAvailableOrders: fulfillAvailableOrders,
  fulfillAvailableAdvancedOrders: fulfillAvailableAdvancedOrders,
  matchOrders: matchOrders,
  matchAdvancedOrders: matchAdvancedOrders,
  cancel: cancel,
  validate: validate,
  incrementNonce: incrementNonce,
};
