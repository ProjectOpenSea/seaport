const utils = require("./utils").module;
const constants = require("./constants").module;

const log = utils.log;
const logEvents = utils.logEvents;
const eth = utils.eth;
const wallets = constants.wallets;

const { deployments } = constants;
const { AddressZero, HashZero } = eth.constants;

/// /////////////////////////////////////
/// Consideration External Methods

global.fulfillBasicOrder = async (overrides, signer = wallets[0]) => {
  await new Promise((resolve) => setTimeout(resolve, 10));
  log(``);
  const tokenAmount = 100;
  log(`Minting ${tokenAmount} tokens..`);
  await global.TestERC20.connect(signer)
    .mint(signer.address, tokenAmount)
    .then((tx) => {
      return logEvents(tx.hash, deployments.TestERC20.abi);
    });
  log(`Approving ${tokenAmount} tokens..`);
  await global.TestERC20.connect(signer)
    .approve(global.Consideration.address, tokenAmount)
    .then((tx) => {
      return logEvents(tx.hash, deployments.TestERC20.abi);
    });
  const nftId = overrides?.considerationIdentifier || 1337;
  const basicOrder = {
    ...overrides,
    considerationToken: global.TestERC721.address,
    considerationIdentifier: nftId,
    considerationAmount: 1,
    offerer: signer.address,
    zone: AddressZero,
    offerToken: global.TestERC20.address,
    offerIdentifier: 0,
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
  global.Consideration.connect(signer)
    .fulfillBasicOrder(basicOrder)
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
    });
  log(`Success`);
};

global.fulfillOrder = async (order, signer = wallets[0]) => {
  const parameters = order?.parameters || {};
  const nftId = parameters.offer?.[0]?.identifierOrCriteria || 1337;
  await new Promise((resolve) => setTimeout(resolve, 10));
  log(``);
  const tokenAmount = eth.utils.parseEther("2");
  log(`Minting ${tokenAmount} tokens..`);
  await global.TestERC20.connect(signer)
    .mint(signer.address, tokenAmount)
    .then((tx) => {
      return logEvents(tx.hash, deployments.TestERC20.abi);
    });
  log(`Approving ${tokenAmount} tokens..`);
  await global.TestERC20.connect(signer)
    .approve(global.Consideration.address, tokenAmount)
    .then((tx) => {
      return logEvents(tx.hash, deployments.TestERC20.abi);
    });
  const offer = {
    itemType: 2, // ERC271
    token: global.TestERC721.address,
    identifierOrCriteria: 0,
    startAmount: 1,
    endAmount: 1,
    ...(parameters.offer?.[0] || {}),
  };
  const consideration = {
    itemType: 1, // ERC20
    token: global.TestERC20.address,
    identifierOrCriteria: nftId,
    startAmount: eth.utils.parseEther("2"), // start the sale at 2 eth
    endAmount: eth.utils.parseEther("1"), // finish the sale at 1 eth
    recipient: signer.address,
    ...(parameters.consideration?.[0] || {}),
  };
  const fullOrder = {
    parameters: {
      offerer: signer.address,
      zone: eth.constants.AddressZero,
      orderType: 1,
      startTime: Math.round(Date.now() / 1000), // seconds from epoch until now
      endTime: Math.round(Date.now() / 1000) + 60 * 60, // 1 hour from now
      zoneHash: eth.constants.HashZero,
      salt: eth.constants.HashZero,
      conduit: eth.constants.AddressZero,
      totalOriginalConsiderationItems: 1,
      ...parameters,
      offer: [offer],
      consideration: [consideration],
    },
    signature: order?.signature || eth.constants.HashZero,
  };
  log(`Fulfilling order: ${JSON.stringify(fullOrder, null, 2)}`);
  global.Consideration.connect(signer)
    .fulfillOrder(fullOrder, eth.constants.AddressZero)
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
    });
  log(`Success`);
};

global.fulfillAdvancedOrder = () => {};
global.fulfillAvailableAdvancedOrders = () => {};
global.matchOrders = () => {};
global.matchAdvancedOrders = () => {};
global.cancel = () => {};

// Only one offer & consideration supported (for now)
global.validateOrder = async (order, signer = wallets[0]) => {
  const parameters = order?.parameters || {};
  const nftId = parameters.offer?.[0]?.identifierOrCriteria || 1337;
  await new Promise((resolve) => setTimeout(resolve, 10));
  log(``);
  log(`Minting NFT #${nftId}`);
  await global.TestERC721.connect(signer)
    .mint(signer.address, nftId)
    .then((tx) => {
      return logEvents(tx.hash, deployments.TestERC721.abi);
    });
  log(`Approving NFT #${nftId}`);
  await global.TestERC721.connect(signer)
    .approve(global.Consideration.address, nftId)
    .then((tx) => {
      return logEvents(tx.hash, deployments.TestERC721.abi);
    });
  const offer = {
    itemType: 2, // ERC271
    token: global.TestERC721.address,
    identifierOrCriteria: 0,
    startAmount: 1,
    endAmount: 1,
    ...(parameters.offer?.[0] || {}),
  };
  const consideration = {
    itemType: 1, // ERC20
    token: global.TestERC20.address,
    identifierOrCriteria: nftId,
    startAmount: eth.utils.parseEther("2"), // start the sale at 2 eth
    endAmount: eth.utils.parseEther("1"), // finish the sale at 1 eth
    recipient: signer.address,
    ...(parameters.consideration?.[0] || {}),
  };
  const fullOrder = {
    parameters: {
      offerer: signer.address,
      zone: eth.constants.AddressZero,
      orderType: 1,
      startTime: Math.round(Date.now() / 1000), // seconds from epoch until now
      endTime: Math.round(Date.now() / 1000) + 60 * 60, // 1 hour from now
      zoneHash: eth.constants.HashZero,
      salt: eth.constants.HashZero,
      conduit: eth.constants.AddressZero,
      totalOriginalConsiderationItems: 1,
      ...parameters,
      offer: [offer],
      consideration: [consideration],
    },
    signature: order?.signature || eth.constants.HashZero,
  };
  log(`Validating order: ${JSON.stringify(fullOrder, null, 2)}`);
  await global.Consideration.connect(signer)
    .validate([fullOrder])
    .then((tx) => {
      // Save the hash to the global scope to make it easier to investigate after
      global.hash = tx.hash;
      // Print formatted events
      return logEvents(tx.hash, deployments.Consideration.abi);
    });
  log(`Success`);
};

global.incrementNonce = (signer = wallets[0]) => {
  global.Consideration.connect(signer)
    .incrementNonce()
    .then((tx) => {
      global.hash = tx.hash;
      logEvents(tx.hash, deployments.Consideration.abi);
    });
};
