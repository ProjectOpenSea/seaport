const eth = require("ethers");

const utils = require("./utils");
const constants = require("./constants");

const log = utils.log;
const wallets = constants.wallets;

const { contracts, txOpts, startTime, endTime, nftAddress } = constants;
const { Consideration, TestERC20, TestERC721 } = contracts;
const { AddressZero, HashZero } = eth.constants;

// NOTE: offer = what's being sold, consideration = what's being paid

/// /////////////////////////////////////
/// Helper Utility Methods

const yield = async () => {
  await new Promise((resolve) => setTimeout(resolve, 1));
  log("");
};

const stringify = (obj) => JSON.stringify(obj, null, 2);

const trace = (err) => {
  const txHash = err?.error?.data?.txHash || HashZero;
  if (txHash !== HashZero) {
    let realMessage = err.message;
    try {
      realMessage = JSON.parse(
        JSON.parse(
          err.message
            .replace(`\n`, "")
            .replace(`\r`, "")
            .replace("processing response error (body=", "")
            .replace(/, error=.*/, "")
        )
      ).error.message;
    } catch (e) {
      log(`Couldn't cleanly parse error message: ${e.message}`);
    }
    log(``);
    log(`!!!!! REVERT !!!!!`);
    log(realMessage);
    log(``);
    const file = "latest.trace.json";
    log(`Saving tx trace to ${file}`);
    utils.traceTx(txHash, file);
  }
  return txHash;
};

const mintERC20 = async (amount, signer = wallets[0]) => {
  log(`ERC20.mint(${signer.address}, ${amount})`);
  await TestERC20.connect(signer)
    .mint(signer.address, amount, txOpts)
    .catch(trace);
  log(`ERC20.approve(${Consideration.address}, ${amount})`);
  await TestERC20.connect(signer)
    .approve(Consideration.address, amount, txOpts)
    .catch(trace);
};

const mintERC721 = async (nftId, signer) => {
  const token = TestERC721.connect(signer);
  const owner = await token.ownerOf(nftId);
  if (owner === signer.address) {
    log(`${signer.address} already owns NFT #${nftId}, skipping mint..`);
    return;
  }
  log(`ERC721.mint(${signer.address}, ${nftId})`);
  await token.mint(signer.address, nftId, txOpts).catch(trace);
  log(`ERC721.approve(${Consideration.address}, ${nftId})`);
  await TestERC721.connect(signer)
    .approve(Consideration.address, nftId, txOpts)
    .catch(trace);
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
  itemType: overrides.itemType || 1, // ERC20
  token:
    overrides.token ||
    (overrides.itemType === 2 || overrides.itemType === 4
      ? TestERC721.address
      : TestERC20.address),
  identifierOrCriteria: overrides.identifierOrCriteria || 0,
  startAmount: overrides.startAmount || 1,
  endAmount: overrides.endAmount || 1,
  recipient: overrides.recipient || wallets[0].address || AddressZero,
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
  startTime,
  endTime,
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
  startTime,
  endTime,
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
  startTime,
  endTime,
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
  log(`getOrderHash(${stringify(order)})`);
  return await Consideration.connect(signer).getOrderHash(order).catch(trace);
};

const signOrder = async (overrides, signer = wallets[0]) => {
  const order = createOrderComponents(overrides.parameters || overrides);
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

const basicOrderToOrder = (basicOrder) =>
  createOrderComponents({
    offerer: basicOrder.offerer,
    zone: AddressZero,
    orderType: 0, // FULL_OPEN
    startTime,
    endTime,
    zoneHash: HashZero,
    salt: HashZero,
    conduit: AddressZero,
    nonce: 0,
    offer: [
      createOfferItem({
        itemType: basicOrder.offerToken === nftAddress ? 2 : 1,
        token: basicOrder.offerToken,
        identifierOrCriteria: basicOrder.offerIdentifier,
        startAmount: 1,
        endAmount: 1,
      }),
    ],
    consideration: [
      createConsiderationItem({
        itemType: basicOrder.considerationToken === nftAddress ? 2 : 1,
        token: basicOrder.considerationToken,
        identifierOrCriteria: basicOrder.considerationIdentifier,
        recipient: basicOrder.offerer,
        endAmount: 1,
        startAmount: 1,
      }),
    ],
  });

const orderToBasicOrder = (order) =>
  createBasicOrder({
    considerationToken: order.parameters.consideration[0].token,
    considerationIdentifier:
      order.parameters.consideration[0].identifierOrCriteria,
    considerationAmount: order.parameters.consideration[0].startAmount,
    offerer: order.parameters.offerer,
    offerToken: order.parameters.offer[0].token,
    offerIdentifier: order.parameters.offer[0].identifierOrCriteria,
    offerAmount: order.parameters.offer[0].startAmount,
    basicOrderType: order.parameters.offer[0].token === nftAddress ? 16 : 8,
    totalOriginalAdditionalRecipients: 1,
    signature: order.signature,
  });

const signBasicOrder = async (basicOrder, signer = wallets[0]) => {
  let order = basicOrderToOrder(basicOrder);
  order.offerer = signer.address;
  order = await signOrder(order);
  return orderToBasicOrder(order);
};

module.exports = {
  yield,
  trace,
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
  signBasicOrder,
};
