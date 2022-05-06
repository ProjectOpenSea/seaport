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
const { getDumpTrace, stringify } = helpers;

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
  log(`Fulfilling basic order: ${stringify(basicOrder)}`);
  return await Consideration.connect(signer)
    .fulfillBasicOrder(basicOrder, txOpts)
    .then(async (tx) => {
      global.hash = tx.hash;
      await logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
      return tx.hash;
    })
    .catch(helpers.getDumpTrace(`fulfillBasicOrder(${stringify(basicOrder)})`));
};

const fulfillOrder = async (overrides, signer = wallets[0]) => {
  const order = helpers.createOrder(overrides);
  await helpers.mintERC20(
    order.parameters.consideration[0].startAmount,
    signer.address
  );
  log(`Fulfilling order: ${stringify(order)}`);
  return await Consideration.connect(signer)
    .fulfillOrder(order, AddressZero)
    .then(async (tx) => {
      global.hash = tx.hash;
      await logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
      return tx.hash;
    })
    .catch(helpers.getDumpTrace(`fulfillOrder(${stringify(order)})`));
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
  await helpers.mintERC20(
    advancedOrder.parameters.consideration[0].startAmount,
    signer.address
  );
  log(
    `Fulfilling advanced order: ${stringify({
      advancedOrder,
      criteriaResolvers,
      fulfillerConduit,
    })}`
  );
  return await Consideration.connect(signer)
    .fulfillAdvancedOrder(advancedOrder, criteriaResolvers, fulfillerConduit)
    .then(async (tx) => {
      global.hash = tx.hash;
      await logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
      return tx.hash;
    })
    .catch(
      helpers.getDumpTrace(
        `fulfillAdvancedOrder(${stringify(advancedOrder)}, ${stringify(
          criteriaResolvers
        )}, ${stringify(fulfillerConduit)})`
      )
    );
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
      global.hash = tx.hash;
      await logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
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
  log(`Matching orders: ${stringify({ orders, fulfillments })}`);
  return await Consideration.connect(signer)
    .matchOrders(orders, fulfillments)
    .then(async (tx) => {
      global.hash = tx.hash;
      await logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
      return tx.hash;
    })
    .catch(
      getDumpTrace(
        `matchOrders(${stringify(orders)}, ${stringify(fulfillments)})`
      )
    );
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
  log(
    `Matching orders: ${stringify({
      orders,
      fulfillments,
      resolvers,
    })}`
  );
  await Consideration.connect(signer)
    .matchAdvancedOrders(orders, resolvers, fulfillments)
    .then(async (tx) => {
      global.hash = tx.hash;
      await logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
    })
    .catch(
      getDumpTrace(
        `(matchAdvancedOrders(${orders}, ${resolvers}, ${fulfillments}))`
      )
    );
};

const cancel = async (overrides, signer = wallets[0]) => {
  const order = helpers.createOrderComponents(overrides);
  log(`Cancelling order: ${stringify(order)}`);
  return await Consideration.connect(signer)
    .cancel([order])
    .then(async (tx) => {
      global.hash = tx.hash;
      await logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
      return tx.hash;
    })
    .catch(getDumpTrace(`cancel(${stringify([order])})`));
};

// Only one offer & consideration supported (for now)
// Validates the sale of an NFT in exchange for some tokens by default
// to validate an advanced order: use keccak256(nftId) for the identifierOrCriteria
const validate = async (overrides, signer = wallets[0]) => {
  const orders = (overrides || [{}]).map(helpers.createOrder);
  for (let i = 0; i < orders.length; i++) {
    const order = orders[i];
    for (let i = 0; i < order.parameters.offer.length; i++) {
      const offer = order.parameters.offer[i];
      const owner = order.parameters.offerer || signer.address;
      if (offer.itemType === 2 || offer.itemType === 4) {
        await helpers.mintERC721(offer.identifierOrCriteria, owner);
      } else if (offer.itemType === 1) {
        await helpers.mintERC20(offer.startAmount, owner);
      }
    }
    for (let i = 0; i < order.parameters.consideration.length; i++) {
      const consideration = order.parameters.consideration[i];
      if (consideration.itemType === 2 || consideration.itemType === 4) {
        await helpers.mintERC721(
          consideration.identifierOrCriteria,
          signer.address
        );
      } else if (consideration.itemType === 1) {
        await helpers.mintERC20(consideration.startAmount, signer.address);
      }
    }
  }
  log(`Validating order: ${stringify(orders)}`);
  return await Consideration.connect(signer)
    .validate(orders)
    .then(async (tx) => {
      global.hash = tx.hash;
      await logEvents(tx.hash, deployments.Consideration.abi);
      log(`Success`);
      return tx.hash;
    })
    .catch(getDumpTrace(`validate(${stringify(orders)})`));
};

const incrementNonce = async (signer = wallets[0]) => {
  return await Consideration.connect(signer)
    .incrementNonce()
    .then(async (tx) => {
      global.hash = tx.hash;
      await logEvents(tx.hash, deployments.Consideration.abi);
      return tx.hash;
    })
    .catch(getDumpTrace(`incrementNonce()`));
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
