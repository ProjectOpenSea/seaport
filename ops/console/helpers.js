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

const txOpts = { gasLimit: "5000000" };

// NOTE: offer = what's being sold, consideration = what's being paid

/// /////////////////////////////////////
/// Helper Utility Methods

const stringify = (obj) => JSON.stringify(obj, null, 2);

const getDumpTrace = (fnCall) => (err) => {
  const txHash = err.error.data.txHash || HashZero;
  if (txHash !== HashZero) {
    log(err.message);
    log(``);
    log(`!!!!! REVERT !!!!!`);
    log(``);
    const file = "latest.trace.json";
    log(`Saving tx trace to ${file} for fn call:`);
    log(fnCall);
    utils.traceTx(txHash, file);
  }
  return txHash;
};

const getWallet = (address) => {
  return wallets.find((w) => w.address === address);
};

const mintERC20 = async (amount, address) => {
  log(`Minting ${amount} tokens for ${address}`);
  const signer = getWallet(address);
  const token = TestERC20.connect(signer);
  await token.mint(signer.address, amount, txOpts).then(async (tx) => {
    return await logEvents(tx.hash, deployments.TestERC20.abi);
  });
  log(`Approving ${amount} tokens..`);
  await TestERC20.connect(signer)
    .approve(Consideration.address, amount, txOpts)
    .then(async (tx) => {
      return await logEvents(tx.hash, deployments.TestERC20.abi);
    })
    .catch(getDumpTrace(`approve(${Consideration.address}, ${amount})`));
};

const mintERC721 = async (nftId, address) => {
  log(`Minting NFT #${nftId} for ${address}`);
  const signer = getWallet(address);
  const token = TestERC721.connect(signer);
  const owner = await token.ownerOf(nftId);
  if (owner >= address) {
    log(`${address} already owns NFT #${nftId}, skipping mint..`);
    return;
  }
  await token
    .mint(signer.address, nftId, txOpts)
    .then(async (tx) => {
      return await logEvents(tx.hash, deployments.TestERC721.abi);
    })
    .catch(getDumpTrace(`mint(${signer.address}, ${nftId})`));
  log(`Approving NFT #${nftId}`);
  await TestERC721.connect(signer)
    .approve(Consideration.address, nftId, txOpts)
    .then(async (tx) => {
      return await logEvents(tx.hash, deployments.TestERC721.abi);
    })
    .catch(getDumpTrace(`approve(${Consideration.address}, ${nftId})`));
};

// By default, offer 1 NFT up for sale
const createOfferItem = (overrides) => ({
  itemType: 2, // ERC721
  token:
    overrides.itemType === 2 || overrides.itemType === 4
      ? TestERC721.address
      : TestERC20.address,
  identifierOrCriteria: 0,
  startAmount: 1,
  endAmount: 1,
  ...(overrides || {}),
});

// By default, consider a payment of one ERC20 token
const createConsiderationItem = (overrides) => ({
  itemType: 1, // ERC20
  token:
    overrides.itemType === 2 || overrides.itemType === 4
      ? TestERC721.address
      : TestERC20.address,
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
  offerComponents: overrides.offerComponents || [
    { orderIndex: 0, itemIndex: 0 },
  ],
  considerationComponents: overrides.considerationComponents || [
    { orderIndex: 0, itemIndex: 0 },
  ],
});

const getOrderHash = async (overrides, signer = wallets[0]) => {
  const order = createOrderComponents(overrides);
  return await Consideration.connect(signer)
    .getOrderHash(order)
    .then((hash) => {
      log(`Order Hash: ${hash}`);
      return hash;
    })
    .catch(getDumpTrace(`getOrderHash(${stringify(order)})`));
};

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
  return { parameters: order, signature };
};

module.exports = {
  getDumpTrace,
  mintERC20,
  stringify,
  mintERC721,
  createOfferItem,
  createConsiderationItem,
  createOrderParameters,
  createOrderComponents,
  createCriteriaResolver,
  createOrder,
  createBasicOrder,
  createAdvancedOrder,
  createFulfillment,
  getOrderHash,
  signOrder,
};
