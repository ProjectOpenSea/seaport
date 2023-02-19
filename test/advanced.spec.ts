import { PANIC_CODES } from "@nomicfoundation/hardhat-chai-matchers/panic";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { constants } from "ethers";
import { ethers, network } from "hardhat";

import { deployContract } from "./utils/contracts";
import { merkleTree } from "./utils/criteria";
import {
  buildOrderStatus,
  buildResolver,
  defaultAcceptOfferMirrorFulfillment,
  defaultBuyNowMirrorFulfillment,
  getItemETH,
  random128,
  randomBN,
  randomHex,
  toBN,
  toFulfillment,
  toFulfillmentComponents,
  toKey,
} from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { seaportFixture } from "./utils/fixtures";
import {
  VERSION,
  minRandom,
  simulateAdvancedMatchOrders,
  simulateMatchOrders,
} from "./utils/helpers";

import type {
  ConduitInterface,
  ConsiderationInterface,
  TestERC1155,
  TestERC20,
  TestERC721,
  TestZone,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { AdvancedOrder, ConsiderationItem } from "./utils/types";
import type { Wallet } from "ethers";

const { parseEther } = ethers.utils;

describe(`Advanced orders (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let conduitKeyOne: string;
  let conduitOne: ConduitInterface;
  let marketplaceContract: ConsiderationInterface;
  let testERC1155: TestERC1155;
  let testERC1155Two: TestERC1155;
  let testERC20: TestERC20;
  let testERC721: TestERC721;
  let stubZone: TestZone;

  let checkExpectedEvents: SeaportFixtures["checkExpectedEvents"];
  let createMirrorAcceptOfferOrder: SeaportFixtures["createMirrorAcceptOfferOrder"];
  let createMirrorBuyNowOrder: SeaportFixtures["createMirrorBuyNowOrder"];
  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem1155: SeaportFixtures["getTestItem1155"];
  let getTestItem1155WithCriteria: SeaportFixtures["getTestItem1155WithCriteria"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let getTestItem721WithCriteria: SeaportFixtures["getTestItem721WithCriteria"];
  let mint1155: SeaportFixtures["mint1155"];
  let mint721: SeaportFixtures["mint721"];
  let mint721s: SeaportFixtures["mint721s"];
  let mintAndApprove1155: SeaportFixtures["mintAndApprove1155"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];
  let set1155ApprovalForAll: SeaportFixtures["set1155ApprovalForAll"];
  let set721ApprovalForAll: SeaportFixtures["set721ApprovalForAll"];
  let signOrder: SeaportFixtures["signOrder"];
  let withBalanceChecks: SeaportFixtures["withBalanceChecks"];
  let invalidContractOfferer: SeaportFixtures["invalidContractOfferer"];
  let invalidContractOffererRatifyOrder: SeaportFixtures["invalidContractOffererRatifyOrder"];

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await faucet(owner.address, provider);

    ({
      checkExpectedEvents,
      conduitKeyOne,
      conduitOne,
      createMirrorAcceptOfferOrder,
      createMirrorBuyNowOrder,
      createOrder,
      getTestItem1155,
      getTestItem1155WithCriteria,
      getTestItem20,
      getTestItem721,
      getTestItem721WithCriteria,
      marketplaceContract,
      mint1155,
      mint721,
      mint721s,
      mintAndApprove1155,
      mintAndApprove721,
      mintAndApproveERC20,
      set1155ApprovalForAll,
      set721ApprovalForAll,
      signOrder,
      testERC1155,
      testERC1155Two,
      testERC20,
      testERC721,
      withBalanceChecks,
      invalidContractOfferer,
      invalidContractOffererRatifyOrder,
      stubZone,
    } = await seaportFixture(owner));
  });

  let seller: Wallet;
  let buyer: Wallet;
  let zone: Wallet;

  async function setupFixture() {
    // Setup basic buyer/seller wallets with ETH
    const seller = new ethers.Wallet(randomHex(32), provider);
    const buyer = new ethers.Wallet(randomHex(32), provider);
    const zone = new ethers.Wallet(randomHex(32), provider);
    for (const wallet of [seller, buyer, zone]) {
      await faucet(wallet.address, provider);
    }

    return { seller, buyer, zone };
  }

  beforeEach(async () => {
    ({ seller, buyer, zone } = await loadFixture(setupFixture));
  });

  describe("Contract Orders", async () => {
    it("Contract Orders (standard)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });
    it("Contract Orders (offer extended)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithoutOffer = JSON.parse(JSON.stringify(order));
      orderWithoutOffer.parameters.offer = [];

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithoutOffer,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });
    it("Contract Orders (offer amount increased)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithSmallerOfferAmount = JSON.parse(JSON.stringify(order));
      orderWithSmallerOfferAmount.parameters.offer[0].startAmount =
        order.parameters.offer[0].startAmount.sub(1);
      orderWithSmallerOfferAmount.parameters.offer[0].endAmount =
        order.parameters.offer[0].endAmount.sub(1);

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithSmallerOfferAmount,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });
    it("Contract Orders (criteria-based offer item: ERC1155 wildcard)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithCriteriaOffer = JSON.parse(JSON.stringify(order));
      orderWithCriteriaOffer.parameters.offer[0].itemType = 5; // Criteria-1155
      orderWithCriteriaOffer.parameters.offer[0].identifierOrCriteria = 0;

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithCriteriaOffer,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });
    it("Contract Orders (criteria-based offer item: ERC1155 non-wildcard)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1
      );

      const { root, proofs } = merkleTree([nftId, toBN(0xdead)]);

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155WithCriteria(root, toBN(1), toBN(1)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      // ERC1155 criteria based item
      offer[0].itemType = 5;
      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activateWithCriteria(offer[0], consideration[0], nftId);

      const criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
      ];
      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4, // CONTRACT
        criteriaResolvers
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // Change from Seller to offererContract
      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      order.parameters.offer[0].identifier = nftId;
      const orderWithCriteriaOffer = JSON.parse(JSON.stringify(order));

      await withBalanceChecks([order], 0, criteriaResolvers, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithCriteriaOffer,
            criteriaResolvers,
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        const orderStatus1 = await marketplaceContract.getOrderStatus(
          orderHash
        );

        expect({ ...orderStatus1 }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          criteriaResolvers
        );

        return receipt;
      });
    });
    it("Contract Orders (offer extended with supplied offer)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithSmallerOffer = JSON.parse(JSON.stringify(order));
      orderWithSmallerOffer.parameters.offer[0].startAmount =
        order.parameters.offer[0].startAmount.div(2);
      orderWithSmallerOffer.parameters.offer[0].endAmount =
        order.parameters.offer[0].endAmount.div(2);

      order.parameters.offer[0].startAmount =
        order.parameters.offer[0].startAmount.div(2);
      order.parameters.offer[0].endAmount =
        order.parameters.offer[0].endAmount.div(2);
      order.parameters.offer.push(order.parameters.offer[0]);

      await offererContract.connect(seller).extendAvailable();

      // TODO: include balance checks
      const tx = marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          orderWithSmallerOffer,
          [],
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: buyer.address,
            fulfillerConduitKey: toKey(0),
          },
        ],
        undefined,
        []
      );
    });
    it("Contract Orders (consideration reduced)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithExtraConsideration = JSON.parse(JSON.stringify(order));
      orderWithExtraConsideration.parameters.consideration.push(
        JSON.parse(
          JSON.stringify(
            orderWithExtraConsideration.parameters.consideration[0]
          )
        )
      );
      orderWithExtraConsideration.parameters.consideration[1].itemType = 1;
      orderWithExtraConsideration.parameters.consideration[1].token =
        "0x".padEnd(42, "1");
      orderWithExtraConsideration.parameters.totalOriginalConsiderationItems++;

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithExtraConsideration,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });
    it("Contract Orders (consideration amount reduced)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithIncreasedConsideration = JSON.parse(JSON.stringify(order));
      orderWithIncreasedConsideration.parameters.consideration[0].startAmount =
        order.parameters.consideration[0].startAmount.add(1);
      orderWithIncreasedConsideration.parameters.consideration[0].endAmount =
        order.parameters.consideration[0].endAmount.add(1);

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithIncreasedConsideration,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });
    it("Contract Orders (criteria-based consideration item)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      // Buyer mints nft
      const { nftId: buyerNftId, amount: buyerAmount } =
        await mintAndApprove1155(buyer, marketplaceContract.address, 10000);

      const consideration = [
        getTestItem1155(
          buyerNftId,
          buyerAmount.mul(10),
          buyerAmount.mul(10),
          undefined,
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithCriteriaConsideration = JSON.parse(JSON.stringify(order));
      orderWithCriteriaConsideration.parameters.consideration[0].itemType = 5; // Criteria-1155
      orderWithCriteriaConsideration.parameters.consideration[0].identifierOrCriteria = 0;

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithCriteriaConsideration,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });
    it("Contract Orders (native token offer items)", async () => {
      // Buyer deploys offererContract
      const offererContract = await deployContract(
        "TestContractOffererNativeToken",
        owner,
        marketplaceContract.address
      );

      await faucet(offererContract.address, provider);

      // Buyer mints nft
      // Buyer will call fulfillAdvancedOrder and receive 10 eth offer item.
      const nftId = await mintAndApprove721(buyer, marketplaceContract.address);

      const offer = [getItemETH(parseEther("10"), parseEther("10")) as any];

      const consideration = [
        getTestItem721(
          nftId,
          toBN(1),
          toBN(1),
          offererContract.address,
          testERC721.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });
    it("Reverts on contract orders where offer startAmount doesn't equal offer endAmount", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;
      offer[0].startAmount = offer[0].endAmount.add(1);

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where offer endAmount is greater than offer amount (branch 2)", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;
      // endAmount should exceed amount to throw on branch 2
      offer[0].endAmount = offer[0].amount.add(1);
      // startAmount and endAmount should be equal in order to reach branch 2
      offer[0].startAmount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where offer itemType is different from generated itemType", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      order.parameters.offer[0].itemType = 1;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where offer token address is different from generated token address", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      order.parameters.offer[0].token = testERC1155Two.address;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where offer identifier is different from generated identifier", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      order.parameters.offer[0].identifierOrCriteria =
        offer[0].identifier.add(1);

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where consideration startAmount doesn't equal consideration endAmount", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;
      consideration[0].startAmount = consideration[0].endAmount.add(1);

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where consideration itemType is different from generated itemType", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      order.parameters.consideration[0].itemType = 1;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where consideration token address is different from generated token address", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      order.parameters.consideration[0].token = testERC1155Two.address;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where consideration identifier is different from generated identifier", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      order.parameters.consideration[0].identifierOrCriteria =
        consideration[0].identifier.add(1);

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where consideration recipient is different from generated recipient", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      order.parameters.consideration[0].recipient = owner.address;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where consideration is omitted", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithNoConsideration = JSON.parse(JSON.stringify(order));
      orderWithNoConsideration.parameters.consideration = [];
      orderWithNoConsideration.parameters.totalOriginalConsiderationItems = 0;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithNoConsideration,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where offer and consideration omitted", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithoutOfferOrConsideration = JSON.parse(
        JSON.stringify(order)
      );
      orderWithoutOfferOrConsideration.parameters.offer = [];
      orderWithoutOfferOrConsideration.parameters.consideration = [];
      orderWithoutOfferOrConsideration.parameters.totalOriginalConsiderationItems = 0;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithoutOfferOrConsideration,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where offer is reduced by contract offerer", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // Seller mints second nft
      const secondNftId = toBN(randomBN(4));
      const secondAmount = toBN(randomBN(4));
      await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

      await expect(
        testERC1155Two
          .connect(seller)
          .setApprovalForAll(marketplaceContract.address, true)
      )
        .to.emit(testERC1155Two, "ApprovalForAll")
        .withArgs(seller.address, marketplaceContract.address, true);

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithExtraOffer = JSON.parse(JSON.stringify(order));
      orderWithExtraOffer.parameters.offer.push(
        JSON.parse(JSON.stringify(orderWithExtraOffer.parameters.offer[0]))
      );
      orderWithExtraOffer.parameters.offer[1].token = testERC1155Two.address;
      orderWithExtraOffer.parameters.offer[1].identifierOrCriteria =
        secondNftId;
      orderWithExtraOffer.parameters.offer[1].amount = secondAmount;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithExtraOffer,
            [],
            toKey(0),
            buyer.address,
            {
              value,
            }
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where consideration is extended by contract offerer", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      await offererContract.connect(seller).extendRequired();

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where offer amount is reduced by contract offerer", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // Seller mints second nft
      const secondNftId = toBN(randomBN(4));
      const secondAmount = toBN(randomBN(4));
      await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

      await expect(
        testERC1155Two
          .connect(seller)
          .setApprovalForAll(marketplaceContract.address, true)
      )
        .to.emit(testERC1155Two, "ApprovalForAll")
        .withArgs(seller.address, marketplaceContract.address, true);

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      order.parameters.offer[0].startAmount =
        order.parameters.offer[0].startAmount.add(1);
      order.parameters.offer[0].endAmount =
        order.parameters.offer[0].startAmount.add(1);

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where consideration amount is increased by contract offerer", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      consideration[0].startAmount = consideration[0].startAmount.sub(1);
      consideration[0].endAmount = consideration[0].endAmount.sub(1);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders that supply a bad fraction", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 2;
      order.signature = "0x";

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      ).to.be.revertedWithCustomError(marketplaceContract, "BadFraction");
    });
    it("Reverts on contract orders that supply a bad fraction (numerator != 1)", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 2;
      order.denominator = 2;
      order.signature = "0x";

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      ).to.be.revertedWithCustomError(marketplaceContract, "BadFraction");
    });
    it("Reverts on contract orders where call to generateOrders throws and reverts aren't skipped", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      await set1155ApprovalForAll(seller, invalidContractOfferer.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          invalidContractOfferer.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await invalidContractOfferer
        .connect(seller)
        .activate(offer[0], consideration[0]);

      consideration[0].startAmount = consideration[0].startAmount.sub(1);
      consideration[0].endAmount = consideration[0].endAmount.sub(1);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          invalidContractOfferer.address
        );

      const orderHash =
        invalidContractOfferer.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = invalidContractOfferer.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where call to generateOrders throws and reverts are skipped", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract with invalid generateOrders function
      // and approves it for 1155 token
      const offererContract = await deployContract(
        "TestInvalidContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      consideration[0].startAmount = consideration[0].startAmount.sub(1);
      consideration[0].endAmount = consideration[0].endAmount.sub(1);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orders = [order, mirrorOrder];

      const offerComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 1, itemIndex: 0 }],
      ];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 1, itemIndex: 0 }],
      ];

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAvailableOrders(
            orders,
            offerComponents,
            considerationComponents,
            toKey(0),
            100,
            {
              value,
            }
          )
      ).to.be.reverted; // TODO: look into this
    });
    it("Reverts on contract orders where call to ratifyOrders returns incorrect magic value", async () => {
      // Seller mints nfts
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      await set1155ApprovalForAll(
        seller,
        invalidContractOffererRatifyOrder.address,
        true
      );

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          invalidContractOffererRatifyOrder.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await invalidContractOffererRatifyOrder
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          invalidContractOffererRatifyOrder.address
        );

      const orderHash =
        invalidContractOffererRatifyOrder.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = invalidContractOffererRatifyOrder.address;
      order.numerator = 1;
      order.denominator = 1;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Reverts on contract orders where consideration length does not match totalOriginalConsiderationItems", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const orderWithMismatchedTotalOriginal = JSON.parse(
        JSON.stringify(order)
      );
      orderWithMismatchedTotalOriginal.parameters
        .totalOriginalConsiderationItems++;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            orderWithMismatchedTotalOriginal,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "ConsiderationLengthNotEqualToTotalOriginal"
      );
    });
    it("Can fulfill and aggregate contract orders via fulfillAvailableAdvancedOrders with failing orders due to reverts", async () => {
      // Seller mints nfts
      const { nftId: nftIdOne, amount: amountOne } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );
      const { nftId: nftIdTwo, amount: amountTwo } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      await mintAndApprove1155(seller, marketplaceContract.address, 10000);

      await mintAndApprove1155(seller, marketplaceContract.address, 10000);

      // seller deploys offererContracts and approves them for 1155 token
      const offererContractOne = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContractOne.address, true);

      const offererContractTwo = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContractTwo.address, true);

      const offererContractThree = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContractThree.address, true);

      const offererContractFour = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContractFour.address, true);

      const offerOne = [
        getTestItem1155(nftIdOne, amountOne.mul(10), amountOne.mul(10)) as any,
      ];

      const considerationOne = [
        getItemETH(
          amountOne.mul(1000),
          amountOne.mul(1000),
          offererContractOne.address
        ) as any,
      ];

      offerOne[0].identifier = offerOne[0].identifierOrCriteria;
      offerOne[0].amount = offerOne[0].endAmount;

      considerationOne[0].identifier = considerationOne[0].identifierOrCriteria;
      considerationOne[0].amount = considerationOne[0].endAmount;

      await offererContractOne
        .connect(seller)
        .activate(offerOne[0], considerationOne[0]);

      const { order: orderOne, value } = await createOrder(
        seller,
        zone,
        offerOne,
        considerationOne,
        4 // CONTRACT
      );

      const contractOffererOneNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContractOne.address
        );

      const orderHashOne =
        offererContractOne.address.toLowerCase() +
        contractOffererOneNonce.toHexString().slice(2).padStart(24, "0");

      orderOne.parameters.offerer = offererContractOne.address;
      orderOne.numerator = 1;
      orderOne.denominator = 1;
      orderOne.signature = "0x";

      // test orderHashes
      orderOne.extraData = ethers.utils.defaultAbiCoder.encode(
        ["bytes32[]"],
        [[orderHashOne, ethers.constants.HashZero]]
      );

      expect((orderOne.extraData.length - 2) / 64).to.equal(4);

      // second order reverts when generating the order
      const offerTwo = [
        getTestItem1155(nftIdTwo, amountTwo.mul(10), amountTwo.mul(10)) as any,
      ];

      const considerationTwo = [
        getItemETH(
          amountTwo.mul(1000),
          amountTwo.mul(1000),
          offererContractTwo.address
        ) as any,
      ];

      offerTwo[0].identifier = offerTwo[0].identifierOrCriteria;
      offerTwo[0].amount = offerTwo[0].endAmount;

      considerationTwo[0].identifier = considerationTwo[0].identifierOrCriteria;
      considerationTwo[0].amount = considerationTwo[0].endAmount;

      await offererContractTwo
        .connect(seller)
        .activate(offerTwo[0], considerationTwo[0]);

      const { order: orderTwo, value: valueTwo } = await createOrder(
        seller,
        zone,
        offerTwo,
        considerationTwo,
        4 // CONTRACT
      );

      orderTwo.parameters.offerer = offererContractTwo.address;
      orderTwo.numerator = 1;
      orderTwo.denominator = 1;
      orderTwo.signature = "0x";
      orderTwo.extraData = "0x1234"; // causes call to revert

      const offerComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 1, itemIndex: 0 }],
      ];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 1, itemIndex: 0 }],
      ];

      await withBalanceChecks([orderOne], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAvailableAdvancedOrders(
            [orderOne, orderTwo],
            [],
            offerComponents,
            considerationComponents,
            toKey(0),
            ethers.constants.AddressZero,
            100,
            {
              value: value.add(valueTwo).mul(2),
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order: orderOne,
            orderHash: orderHashOne,
            fulfiller: buyer.address,
          },
        ]);

        return receipt;
      });
    });
    it("Cannot fulfill and aggregate contract orders via fulfillAvailableAdvancedOrders with failing orders due to bad data", async () => {
      // Seller mints nfts
      const { nftId: nftIdOne, amount: amountOne } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );
      const { nftId: nftIdTwo, amount: amountTwo } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );
      const { nftId: nftIdThree, amount: amountThree } =
        await mintAndApprove1155(seller, marketplaceContract.address, 10000);
      const { nftId: nftIdFour, amount: amountFour } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // seller deploys offererContracts and approves them for 1155 token
      const offererContractOne = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContractOne.address, true);

      const offererContractTwo = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContractTwo.address, true);

      const offererContractThree = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContractThree.address, true);

      const offererContractFour = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set1155ApprovalForAll(seller, offererContractFour.address, true);

      const offerOne = [
        getTestItem1155(nftIdOne, amountOne.mul(10), amountOne.mul(10)) as any,
      ];

      const considerationOne = [
        getItemETH(
          amountOne.mul(1000),
          amountOne.mul(1000),
          offererContractOne.address
        ) as any,
      ];

      offerOne[0].identifier = offerOne[0].identifierOrCriteria;
      offerOne[0].amount = offerOne[0].endAmount;

      considerationOne[0].identifier = considerationOne[0].identifierOrCriteria;
      considerationOne[0].amount = considerationOne[0].endAmount;

      await offererContractOne
        .connect(seller)
        .activate(offerOne[0], considerationOne[0]);

      const { order: orderOne, value } = await createOrder(
        seller,
        zone,
        offerOne,
        considerationOne,
        4 // CONTRACT
      );

      const contractOffererOneNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContractOne.address
        );

      const orderHashOne =
        offererContractOne.address.toLowerCase() +
        contractOffererOneNonce.toHexString().slice(2).padStart(24, "0");

      orderOne.parameters.offerer = offererContractOne.address;
      orderOne.numerator = 1;
      orderOne.denominator = 1;
      orderOne.signature = "0x";

      // test orderHashes
      orderOne.extraData = ethers.utils.defaultAbiCoder.encode(
        ["bytes32[]"],
        [
          [
            orderHashOne,
            ethers.constants.HashZero,
            ethers.constants.HashZero,
            ethers.constants.HashZero,
          ],
        ]
      );

      expect((orderOne.extraData.length - 2) / 64).to.equal(6);

      // second order reverts when generating the order
      const offerTwo = [
        getTestItem1155(nftIdTwo, amountTwo.mul(10), amountTwo.mul(10)) as any,
      ];

      const considerationTwo = [
        getItemETH(
          amountTwo.mul(1000),
          amountTwo.mul(1000),
          offererContractTwo.address
        ) as any,
      ];

      offerTwo[0].identifier = offerTwo[0].identifierOrCriteria;
      offerTwo[0].amount = offerTwo[0].endAmount;

      considerationTwo[0].identifier = considerationTwo[0].identifierOrCriteria;
      considerationTwo[0].amount = considerationTwo[0].endAmount;

      await offererContractTwo
        .connect(seller)
        .activate(offerTwo[0], considerationTwo[0]);

      const { order: orderTwo, value: valueTwo } = await createOrder(
        seller,
        zone,
        offerTwo,
        considerationTwo,
        4 // CONTRACT
      );

      orderTwo.parameters.offerer = offererContractTwo.address;
      orderTwo.numerator = 1;
      orderTwo.denominator = 1;
      orderTwo.signature = "0x";
      orderTwo.extraData = "0x1234"; // causes call to revert

      // third order: generated order is missing expected offer items
      const offerThree = [
        getTestItem1155(
          nftIdThree,
          amountThree.mul(10),
          amountThree.mul(10)
        ) as any,
        getTestItem1155(
          nftIdOne,
          amountOne.mul(10),
          amountThree.mul(10)
        ) as any,
      ];

      const considerationThree = [
        getItemETH(
          amountThree.mul(1000),
          amountThree.mul(1000),
          offererContractThree.address
        ) as any,
      ];

      offerThree[0].identifier = offerThree[0].identifierOrCriteria;
      offerThree[0].amount = offerThree[0].endAmount;

      offerThree[1].identifier = offerThree[1].identifierOrCriteria;
      offerThree[1].amount = offerThree[1].endAmount;

      considerationThree[0].identifier =
        considerationThree[0].identifierOrCriteria;
      considerationThree[0].amount = considerationThree[0].endAmount;

      await offererContractThree
        .connect(seller)
        .activate(offerThree[0], considerationThree[0]);

      const { order: orderThree, value: valueThree } = await createOrder(
        seller,
        zone,
        offerThree,
        considerationThree,
        4 // CONTRACT
      );

      orderThree.parameters.offerer = offererContractThree.address;
      orderThree.numerator = 1;
      orderThree.denominator = 1;
      orderThree.signature = "0x";

      const contractOffererThreeNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContractThree.address
        );

      const orderHashThree =
        offererContractThree.address.toLowerCase() +
        contractOffererThreeNonce.toHexString().slice(2).padStart(24, "0");

      // fourth order: generated order exceeds expected consideration items
      const offerFour = [
        getTestItem1155(
          nftIdFour,
          amountFour.mul(10),
          amountFour.mul(10)
        ) as any,
      ];

      const considerationFour = [
        getItemETH(
          amountFour.mul(1000),
          amountFour.mul(1000),
          offererContractFour.address
        ) as any,
      ];

      offerFour[0].identifier = offerFour[0].identifierOrCriteria;
      offerFour[0].amount = offerFour[0].endAmount;

      considerationFour[0].identifier =
        considerationFour[0].identifierOrCriteria;
      considerationFour[0].amount = considerationFour[0].endAmount;

      await offererContractFour
        .connect(seller)
        .activate(offerFour[0], considerationFour[0]);

      const { order: orderFour, value: valueFour } = await createOrder(
        seller,
        zone,
        offerFour,
        considerationFour,
        4 // CONTRACT
      );

      orderFour.parameters.offerer = offererContractFour.address;
      orderFour.numerator = 1;
      orderFour.denominator = 1;
      orderFour.signature = "0x";
      orderFour.parameters.consideration[0].startAmount =
        orderFour.parameters.consideration[0].startAmount.sub(1);
      orderFour.parameters.consideration[0].endAmount =
        orderFour.parameters.consideration[0].endAmount.sub(1);

      const offerComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 1, itemIndex: 0 }],
        [{ orderIndex: 2, itemIndex: 0 }],
        [{ orderIndex: 3, itemIndex: 0 }],
      ];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 1, itemIndex: 0 }],
        [{ orderIndex: 2, itemIndex: 0 }],
        [{ orderIndex: 3, itemIndex: 0 }],
      ];

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAvailableAdvancedOrders(
            [orderOne, orderTwo, orderThree, orderFour],
            [],
            offerComponents,
            considerationComponents,
            toKey(0),
            ethers.constants.AddressZero,
            100,
            {
              value: value.add(valueTwo).add(valueThree).add(valueFour).mul(2),
            }
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHashThree);
    });
  });

  describe("Partial fills", async () => {
    it("Partial fills (standard)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
        getItemETH(amount.mul(10), amount.mul(10), zone.address),
        getItemETH(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1 // PARTIAL_OPEN
      );

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 2; // fill two tenths or one fifth
      order.denominator = 10; // fill two tenths or one fifth

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 2, 10)
      );

      order.numerator = 1; // fill one half
      order.denominator = 2; // fill one half

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 14, 20)
      );

      // Fill remaining; only 3/10ths will be fillable
      order.numerator = 1; // fill one half
      order.denominator = 2; // fill one half

      const ordersClone = [{ ...order }] as AdvancedOrder[];
      for (const [, clonedOrder] of Object.entries(ordersClone)) {
        clonedOrder.parameters.startTime = order.parameters.startTime;
        clonedOrder.parameters.endTime = order.parameters.endTime;

        for (const [j, offerItem] of Object.entries(
          clonedOrder.parameters.offer
        )) {
          offerItem.startAmount = order.parameters.offer[+j].startAmount;
          offerItem.endAmount = order.parameters.offer[+j].endAmount;
        }

        for (const [j, considerationItem] of Object.entries(
          clonedOrder.parameters.consideration
        )) {
          considerationItem.startAmount =
            order.parameters.consideration[+j].startAmount;
          considerationItem.endAmount =
            order.parameters.consideration[+j].endAmount;
        }
      }

      ordersClone[0].numerator = 3;
      ordersClone[0].denominator = 10;

      await withBalanceChecks(ordersClone, 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order: ordersClone[0],
              orderHash,
              fulfiller: buyer.address,
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 40, 40)
      );
    });
    it("Partial fills (standard, additional permutations)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
        getItemETH(amount.mul(10), amount.mul(10), zone.address),
        getItemETH(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1 // PARTIAL_OPEN
      );

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 2; // fill two tenths or one fifth
      order.denominator = 10; // fill two tenths or one fifth

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 2, 10)
      );

      order.numerator = 1; // fill one tenth
      order.denominator = 10; // fill one tenth

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 3, 10)
      );

      // Fill all available; only 7/10ths will be fillable
      order.numerator = 1; // fill all available
      order.denominator = 1; // fill all available

      const ordersClone = [{ ...order }] as AdvancedOrder[];
      for (const [, clonedOrder] of Object.entries(ordersClone)) {
        clonedOrder.parameters.startTime = order.parameters.startTime;
        clonedOrder.parameters.endTime = order.parameters.endTime;

        for (const [j, offerItem] of Object.entries(
          clonedOrder.parameters.offer
        )) {
          offerItem.startAmount = order.parameters.offer[+j].startAmount;
          offerItem.endAmount = order.parameters.offer[+j].endAmount;
        }

        for (const [j, considerationItem] of Object.entries(
          clonedOrder.parameters.consideration
        )) {
          considerationItem.startAmount =
            order.parameters.consideration[+j].startAmount;
          considerationItem.endAmount =
            order.parameters.consideration[+j].endAmount;
        }
      }

      ordersClone[0].numerator = 7;
      ordersClone[0].denominator = 10;

      await withBalanceChecks(ordersClone, 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order: ordersClone[0],
              orderHash,
              fulfiller: buyer.address,
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 10, 10)
      );
    });
    it("Partial fills (match)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
        getItemETH(amount.mul(10), amount.mul(10), zone.address),
        getItemETH(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1 // PARTIAL_OPEN
      );

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 2; // fill two tenths or one fifth
      order.denominator = 10; // fill two tenths or one fifth

      let mirrorObject;
      mirrorObject = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = defaultBuyNowMirrorFulfillment;

      let executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [order, mirrorObject.mirrorOrder],
        [], // no criteria resolvers
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(4);

      const tx = marketplaceContract.connect(owner).matchAdvancedOrders(
        [order, mirrorObject.mirrorOrder],
        [], // no criteria resolvers
        fulfillments,
        ethers.constants.AddressZero,
        {
          value,
        }
      );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorObject.mirrorOrder,
            orderHash: mirrorObject.mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 2, 10)
      );

      order.numerator = 1; // fill one tenth
      order.denominator = 10; // fill one tenth

      mirrorObject = await createMirrorBuyNowOrder(buyer, zone, order);

      executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [order, mirrorObject.mirrorOrder],
        [], // no criteria resolvers
        fulfillments,
        owner,
        value
      );

      const tx2 = marketplaceContract.connect(owner).matchAdvancedOrders(
        [order, mirrorObject.mirrorOrder],
        [], // no criteria resolvers
        fulfillments,
        ethers.constants.AddressZero,
        {
          value,
        }
      );
      const receipt2 = await (await tx2).wait();
      await checkExpectedEvents(
        tx2,
        receipt2,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorObject.mirrorOrder,
            orderHash: mirrorObject.mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 3, 10)
      );

      // Fill all available; only 7/10ths will be fillable
      order.numerator = 7; // fill all available
      order.denominator = 10; // fill all available

      mirrorObject = await createMirrorBuyNowOrder(buyer, zone, order);

      executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [order, mirrorObject.mirrorOrder],
        [], // no criteria resolvers
        fulfillments,
        owner,
        value
      );

      const tx3 = await marketplaceContract.connect(owner).matchAdvancedOrders(
        [order, mirrorObject.mirrorOrder],
        [], // no criteria resolvers
        fulfillments,
        ethers.constants.AddressZero,
        {
          value,
        }
      );
      const receipt3 = await tx3.wait();
      await checkExpectedEvents(
        tx3,
        receipt3,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorObject.mirrorOrder,
            orderHash: mirrorObject.mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 10, 10)
      );
    });

    it("Simplifies fraction when numerator/denominator would overflow", async () => {
      const numer1 = toBN(2).pow(100);
      const denom1 = toBN(2).pow(101);
      const numer2 = toBN(2).pow(20);
      const denom2 = toBN(2).pow(22);
      const amt = 8;
      await mintAndApproveERC20(buyer, marketplaceContract.address, amt);
      // Seller mints nft
      const { nftId } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000,
        undefined,
        amt
      );

      const offer = [getTestItem1155(nftId, amt, amt)];

      const consideration = [getTestItem20(amt, amt, seller.address)];
      const { order, orderHash, value } = await createOrder(
        seller,
        undefined,
        offer,
        consideration,
        1, // PARTIAL_OPEN
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        true
      );
      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // 1/2
      order.numerator = numer1 as any; // would error here if cast to number (due to overflow)
      order.denominator = denom1 as any;

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, numer1, denom1)
      );

      order.numerator = +numer2;
      order.denominator = +denom2;

      await marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
          value,
        });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, toBN(3), toBN(4))
      );
    });

    it("Reverts when numerator/denominator overflow", async () => {
      const prime1 = toBN(2).pow(7).sub(1);
      const prime2 = toBN(2).pow(61).sub(1);
      const prime3 = toBN(2).pow(107).sub(1);
      const amt = prime1.mul(prime2).mul(prime3);
      await mintAndApproveERC20(buyer, marketplaceContract.address, amt);
      // Seller mints nft
      const { nftId } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000,
        undefined,
        amt
      );

      const offer = [getTestItem1155(nftId, amt, amt)];

      const consideration = [getTestItem20(amt, amt, seller.address)];
      const { order, orderHash, value } = await createOrder(
        seller,
        undefined,
        offer,
        consideration,
        1, // PARTIAL_OPEN
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        true
      );
      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // 1/2
      order.numerator = 1;
      order.denominator = prime2 as any; // would error here if cast to number (due to overflow)

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, toBN(1), prime2)
      );

      order.numerator = prime1 as any; // would error here if cast to number (due to overflow)
      order.denominator = prime3 as any;

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value,
          })
      ).to.be.revertedWithPanic(PANIC_CODES.ARITHMETIC_UNDER_OR_OVERFLOW);
    });
  });

  describe("Criteria-based orders", async () => {
    it("Criteria-based offer item ERC721 (standard)", async () => {
      // Seller mints nfts
      const [nftId, secondNFTId, thirdNFTId] = await mint721s(seller, 3);

      const tokenIds = [nftId, secondNFTId, thirdNFTId];

      // Seller approves marketplace contract to transfer NFTs
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const { root, proofs } = merkleTree(tokenIds);

      const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      await withBalanceChecks([order], 0, criteriaResolvers, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            criteriaResolvers,
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          criteriaResolvers
        );

        return receipt;
      });
    });
    it("Criteria-based offer item ERC1155 (standard)", async () => {
      // Seller mints nfts
      const { nftId } = await mint1155(seller);

      // Seller approves marketplace contract to transfer NFTs
      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      const { root, proofs } = merkleTree([nftId]);

      const offer = [getTestItem1155WithCriteria(root, toBN(1), toBN(1))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      await withBalanceChecks([order], 0, criteriaResolvers, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            criteriaResolvers,
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          criteriaResolvers
        );

        return receipt;
      });
    });
    it("Criteria-based offer item (standard, collection-level)", async () => {
      // Seller mints nfts
      const nftId = randomBN();
      const secondNFTId = randomBN();
      const thirdNFTId = randomBN();

      await testERC721.mint(seller.address, nftId);
      await testERC721.mint(seller.address, secondNFTId);
      await testERC721.mint(seller.address, thirdNFTId);

      // Seller approves marketplace contract to transfer NFTs
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        getTestItem721WithCriteria(ethers.constants.HashZero, toBN(1), toBN(1)),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const criteriaResolvers = [buildResolver(0, 0, 0, nftId, [])];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      await withBalanceChecks([order], 0, criteriaResolvers, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            criteriaResolvers,
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          criteriaResolvers
        );

        return receipt;
      });
    });
    it("Criteria-based offer item ERC721 (match)", async () => {
      // Seller mints nfts
      const nftId = randomBN();
      const secondNFTId = randomBN();
      const thirdNFTId = randomBN();

      await testERC721.mint(seller.address, nftId);
      await testERC721.mint(seller.address, secondNFTId);
      await testERC721.mint(seller.address, thirdNFTId);

      const tokenIds = [nftId, secondNFTId, thirdNFTId];

      // Seller approves marketplace contract to transfer NFTs
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const { root, proofs } = merkleTree(tokenIds);

      const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      const { mirrorOrder, mirrorOrderHash } =
        await createMirrorAcceptOfferOrder(
          buyer,
          zone,
          order,
          criteriaResolvers
        );

      const fulfillments = [
        [[[1, 0]], [[0, 0]]],
        [[[0, 0]], [[1, 0]]],
        [[[1, 1]], [[0, 1]]],
        [[[1, 2]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        criteriaResolvers,
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(4);

      const tx = marketplaceContract
        .connect(owner)
        .matchAdvancedOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          ethers.constants.AddressZero,
          {
            value,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions,
        criteriaResolvers
      );
      return receipt;
    });
    it("Criteria-based offer item ERC1155 (match)", async () => {
      // Seller mints nfts
      const { nftId } = await mint1155(seller);

      // Seller approves marketplace contract to transfer NFTs
      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      const { root, proofs } = merkleTree([nftId]);

      const offer = [getTestItem1155WithCriteria(root, toBN(1), toBN(1))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      const { mirrorOrder, mirrorOrderHash } =
        await createMirrorAcceptOfferOrder(
          buyer,
          zone,
          order,
          criteriaResolvers
        );

      const fulfillments = [
        [[[1, 0]], [[0, 0]]],
        [[[0, 0]], [[1, 0]]],
        [[[1, 1]], [[0, 1]]],
        [[[1, 2]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        criteriaResolvers,
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(4);

      const tx = marketplaceContract
        .connect(owner)
        .matchAdvancedOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          ethers.constants.AddressZero,
          {
            value,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions,
        criteriaResolvers
      );
      return receipt;
    });
    it("Criteria-based offer item (match, collection-level)", async () => {
      // Seller mints nfts
      const nftId = randomBN();
      const secondNFTId = randomBN();
      const thirdNFTId = randomBN();

      await testERC721.mint(seller.address, nftId);
      await testERC721.mint(seller.address, secondNFTId);
      await testERC721.mint(seller.address, thirdNFTId);

      // Seller approves marketplace contract to transfer NFTs
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        getTestItem721WithCriteria(ethers.constants.HashZero, toBN(1), toBN(1)),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const criteriaResolvers = [buildResolver(0, 0, 0, nftId, [])];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      const { mirrorOrder, mirrorOrderHash } =
        await createMirrorAcceptOfferOrder(
          buyer,
          zone,
          order,
          criteriaResolvers
        );

      const fulfillments = [
        [[[1, 0]], [[0, 0]]],
        [[[0, 0]], [[1, 0]]],
        [[[1, 1]], [[0, 1]]],
        [[[1, 2]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        criteriaResolvers,
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(4);

      const tx = marketplaceContract
        .connect(owner)
        .matchAdvancedOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          ethers.constants.AddressZero,
          {
            value,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions,
        criteriaResolvers
      );
      return receipt;
    });
    it("Criteria-based consideration item (standard)", async () => {
      // buyer mints nfts
      const nftId = randomBN();
      const secondNFTId = randomBN();
      const thirdNFTId = randomBN();

      await testERC721.mint(buyer.address, nftId);
      await testERC721.mint(buyer.address, secondNFTId);
      await testERC721.mint(buyer.address, thirdNFTId);

      const tokenIds = [nftId, secondNFTId, thirdNFTId];

      // Seller approves marketplace contract to transfer NFTs
      await set721ApprovalForAll(buyer, marketplaceContract.address, true);

      const { root, proofs } = merkleTree(tokenIds);
      const tokenAmount = minRandom(100);
      await mintAndApproveERC20(
        seller,
        marketplaceContract.address,
        tokenAmount
      );
      const offer = [getTestItem20(tokenAmount, tokenAmount)];

      const consideration = [
        getTestItem721WithCriteria(root, toBN(1), toBN(1), seller.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 1, 0, nftId, proofs[nftId.toString()]),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      await withBalanceChecks(
        [order],
        value.mul(-1),
        criteriaResolvers,
        async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(0),
              ethers.constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(0),
              },
            ],
            undefined,
            criteriaResolvers
          );

          return receipt;
        }
      );
    });
    it("Criteria-based consideration item ERC1155 (standard)", async () => {
      // buyer mints nfts
      const { nftId } = await mint1155(buyer);

      // Seller approves marketplace contract to transfer NFTs
      await set1155ApprovalForAll(buyer, marketplaceContract.address, true);

      const { root, proofs } = merkleTree([nftId]);
      const tokenAmount = minRandom(100);
      await mintAndApproveERC20(
        seller,
        marketplaceContract.address,
        tokenAmount
      );
      const offer = [getTestItem20(tokenAmount, tokenAmount)];

      const consideration = [
        getTestItem1155WithCriteria(root, toBN(1), toBN(1), seller.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 1, 0, nftId, proofs[nftId.toString()]),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      await withBalanceChecks(
        [order],
        value.mul(-1),
        criteriaResolvers,
        async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(0),
              ethers.constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(0),
              },
            ],
            undefined,
            criteriaResolvers
          );

          return receipt;
        }
      );
    });
    it("Criteria-based wildcard consideration item (standard)", async () => {
      // buyer mints nft
      const nftId = await mintAndApprove721(buyer, marketplaceContract.address);
      const tokenAmount = minRandom(100);
      await mintAndApproveERC20(
        seller,
        marketplaceContract.address,
        tokenAmount
      );
      const offer = [getTestItem20(tokenAmount, tokenAmount)];

      const consideration = [
        getTestItem721WithCriteria(
          ethers.constants.HashZero,
          toBN(1),
          toBN(1),
          seller.address
        ),
      ];

      const criteriaResolvers = [buildResolver(0, 1, 0, nftId, [])];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      await withBalanceChecks(
        [order],
        value.mul(-1),
        criteriaResolvers,
        async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(0),
              ethers.constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(0),
              },
            ],
            undefined,
            criteriaResolvers
          );

          return receipt;
        }
      );
    });
    it("Criteria-based consideration item ERC721 (match)", async () => {
      // Fulfiller mints nft
      const nftId = await mint721(buyer);
      const tokenAmount = minRandom(100);

      // Fulfiller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(buyer, marketplaceContract.address, true);

      // Offerer mints ERC20
      await mintAndApproveERC20(
        seller,
        marketplaceContract.address,
        tokenAmount
      );

      // Fulfiller mints ERC20
      await mintAndApproveERC20(
        buyer,
        marketplaceContract.address,
        tokenAmount
      );

      const { root, proofs } = merkleTree([nftId]);

      const offer = [
        // Offerer (Seller)
        getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
      ];

      const consideration = [
        // Fulfiller (Buyer)
        {
          itemType: 4, // ERC721WithCriteria
          token: testERC721.address,
          identifierOrCriteria: toBN(root),
          startAmount: toBN(1),
          endAmount: toBN(1),
          recipient: seller.address,
        },
        getTestItem20(50, 50, zone.address),
        getTestItem20(50, 50, owner.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 1, 0, nftId, proofs[nftId.toString()]),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      const { mirrorOrder, mirrorOrderHash } =
        await createMirrorAcceptOfferOrder(
          buyer,
          zone,
          order,
          criteriaResolvers
        );

      const fulfillments = defaultAcceptOfferMirrorFulfillment;

      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        criteriaResolvers,
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(4);

      const tx = marketplaceContract
        .connect(owner)
        .matchAdvancedOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          ethers.constants.AddressZero,
          {
            value,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions,
        criteriaResolvers
      );
      return receipt;
    });
    it("Criteria-based consideration item ERC1155 (match)", async () => {
      // Fulfiller mints nft
      const { nftId } = await mint1155(buyer);
      const tokenAmount = minRandom(100);

      // Fulfiller approves marketplace contract to transfer NFT
      await set1155ApprovalForAll(buyer, marketplaceContract.address, true);

      // Offerer mints ERC20
      await mintAndApproveERC20(
        seller,
        marketplaceContract.address,
        tokenAmount
      );

      // Fulfiller mints ERC20
      await mintAndApproveERC20(
        buyer,
        marketplaceContract.address,
        tokenAmount
      );

      const { root, proofs } = merkleTree([nftId]);

      const offer = [
        // Offerer (Seller)
        getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
      ];

      const consideration = [
        // Fulfiller (Buyer)
        {
          itemType: 5, // ERC1155_WITH_CRITERIA
          token: testERC1155.address,
          identifierOrCriteria: toBN(root),
          startAmount: toBN(1),
          endAmount: toBN(1),
          recipient: seller.address,
        },
        getTestItem20(50, 50, zone.address),
        getTestItem20(50, 50, owner.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 1, 0, nftId, proofs[nftId.toString()]),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      const { mirrorOrder, mirrorOrderHash } =
        await createMirrorAcceptOfferOrder(
          buyer,
          zone,
          order,
          criteriaResolvers
        );

      const fulfillments = defaultAcceptOfferMirrorFulfillment;

      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        criteriaResolvers,
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(4);

      const tx = marketplaceContract
        .connect(owner)
        .matchAdvancedOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          ethers.constants.AddressZero,
          {
            value,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions,
        criteriaResolvers
      );

      return receipt;
    });
    it("Criteria-based offer item with junk criteria proof", async () => {
      // Seller mints nfts
      const { nftId } = await mint1155(seller);

      // Seller approves marketplace contract to transfer NFTs
      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [getTestItem1155WithCriteria(toBN(0), toBN(1), toBN(1))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, [
          "0xDEAFBEEF00000000000000000000000000000000000000000000000000000000",
        ]),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            criteriaResolvers,
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          )
      ).to.be.revertedWithCustomError(marketplaceContract, "InvalidProof");
    });
  });

  describe("Bulk Signature", async () => {
    it("Can sign for a bulk signature", async () => {
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
        getItemETH(amount.mul(10), amount.mul(10), zone.address),
        getItemETH(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        true
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 2; // fill two tenths or one fifth
      order.denominator = 10; // fill two tenths or one fifth

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });

    it("Can sign for a bulk signature with index 9 in 32 node tree", async () => {
      // let n = x - 99

      // equal(n, and(n, mask))
      // n < 738 & (n & 31) < 2
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
        getItemETH(amount.mul(10), amount.mul(10), zone.address),
        getItemETH(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        true,
        9,
        5
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 2; // fill two tenths or one fifth
      order.denominator = 10; // fill two tenths or one fifth

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });

    it("Can sign for a compact bulk signature", async () => {
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
        getItemETH(amount.mul(10), amount.mul(10), zone.address),
        getItemETH(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        true,
        true
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 2; // fill two tenths or one fifth
      order.denominator = 10; // fill two tenths or one fifth

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });
  });

  describe("Ascending / Descending amounts", async () => {
    it("Ascending offer amount (standard)", async () => {
      // Seller mints nft
      const nftId = randomBN();
      const startAmount = toBN(randomBN(2));
      const endAmount = startAmount.mul(2);
      await testERC1155.mint(seller.address, nftId, endAmount.mul(10));

      // Seller approves marketplace contract to transfer NFTs

      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [getTestItem1155(nftId, startAmount, endAmount, undefined)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 1, 1)
      );
    });
    it("Ascending consideration amount (standard)", async () => {
      // Seller mints ERC20
      const tokenAmount = toBN(random128());
      await mintAndApproveERC20(
        seller,
        marketplaceContract.address,
        tokenAmount
      );

      // Buyer mints nft
      const nftId = randomBN();
      const startAmount = toBN(randomBN(2));
      const endAmount = startAmount.mul(2);
      await testERC1155.mint(buyer.address, nftId, endAmount.mul(10));

      // Buyer approves marketplace contract to transfer NFTs
      await set1155ApprovalForAll(buyer, marketplaceContract.address, true);

      // Buyer needs to approve marketplace to transfer ERC20 tokens too (as it's a standard fulfillment)
      await expect(
        testERC20
          .connect(buyer)
          .approve(marketplaceContract.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

      const offer = [getTestItem20(tokenAmount, tokenAmount)];

      const consideration = [
        getTestItem1155(
          nftId,
          startAmount,
          endAmount,
          undefined,
          seller.address
        ),
        getTestItem20(50, 50, zone.address),
        getTestItem20(50, 50, owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 1, 1)
      );
    });
    it("Ascending offer amount (match)", async () => {
      // Seller mints nft
      const nftId = randomBN();
      const startAmount = toBN(randomBN(2));
      const endAmount = startAmount.mul(2);
      await testERC1155.mint(seller.address, nftId, endAmount.mul(10));

      // Seller approves marketplace contract to transfer NFTs

      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [getTestItem1155(nftId, startAmount, endAmount, undefined)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      const fulfillments = defaultBuyNowMirrorFulfillment;

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(4);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 1, 1)
      );
    });
  });

  describe("Sequenced Orders", async () => {
    it("Match A => B => C => A", async () => {
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );
      const secondNFTId = await mintAndApprove721(
        buyer,
        marketplaceContract.address
      );
      const thirdNFTId = await mintAndApprove721(
        owner,
        marketplaceContract.address
      );

      const offerOne = [
        getTestItem721(nftId, toBN(1), toBN(1), undefined, testERC721.address),
      ];

      const considerationOne = [
        getTestItem721(
          secondNFTId,
          toBN(1),
          toBN(1),
          seller.address,
          testERC721.address
        ),
      ];

      const { order: orderOne, orderHash: orderHashOne } = await createOrder(
        seller,
        zone,
        offerOne,
        considerationOne,
        0 // FULL_OPEN
      );

      const offerTwo = [
        getTestItem721(
          secondNFTId,
          toBN(1),
          toBN(1),
          undefined,
          testERC721.address
        ),
      ];

      const considerationTwo = [
        getTestItem721(
          thirdNFTId,
          toBN(1),
          toBN(1),
          buyer.address,
          testERC721.address
        ),
      ];

      const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
        buyer,
        zone,
        offerTwo,
        considerationTwo,
        0 // FULL_OPEN
      );

      const offerThree = [
        getTestItem721(
          thirdNFTId,
          toBN(1),
          toBN(1),
          undefined,
          testERC721.address
        ),
      ];

      const considerationThree = [
        getTestItem721(
          nftId,
          toBN(1),
          toBN(1),
          owner.address,
          testERC721.address
        ),
      ];

      const { order: orderThree, orderHash: orderHashThree } =
        await createOrder(
          owner,
          zone,
          offerThree,
          considerationThree,
          0 // FULL_OPEN
        );

      const fulfillments = [
        [[[1, 0]], [[0, 0]]],
        [[[0, 0]], [[2, 0]]],
        [[[2, 0]], [[1, 0]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [orderOne, orderTwo, orderThree],
        [], // no criteria resolvers
        fulfillments,
        owner,
        0 // no value
      );

      expect(executions.length).to.equal(fulfillments.length);

      const tx = marketplaceContract
        .connect(owner)
        .matchAdvancedOrders(
          [orderOne, orderTwo, orderThree],
          [],
          fulfillments,
          ethers.constants.AddressZero,
          {
            value: 0,
          }
        );
      const receipt = await (await tx).wait();

      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order: orderOne,
            orderHash: orderHashOne,
            fulfiller: owner.address,
          },
          {
            order: orderTwo,
            orderHash: orderHashTwo,
            fulfiller: owner.address,
          },
          {
            order: orderThree,
            orderHash: orderHashThree,
            fulfiller: owner.address,
          },
        ],
        executions
      );
    });
    it("Match with fewer executions when one party has multiple orders that coincide", async () => {
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );
      const secondNFTId = await mintAndApprove721(
        buyer,
        marketplaceContract.address
      );

      const offerOne = [
        getTestItem721(nftId, toBN(1), toBN(1), undefined, testERC721.address),
      ];

      const considerationOne = [
        getTestItem20(parseEther("10"), parseEther("10"), seller.address),
      ];

      const { order: orderOne, orderHash: orderHashOne } = await createOrder(
        seller,
        zone,
        offerOne,
        considerationOne,
        0 // FULL_OPEN
      );

      const offerTwo = [getTestItem20(parseEther("10"), parseEther("10"))];

      const considerationTwo = [
        getTestItem721(
          secondNFTId,
          toBN(1),
          toBN(1),
          seller.address,
          testERC721.address
        ),
      ];

      const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
        seller,
        zone,
        offerTwo,
        considerationTwo,
        0 // FULL_OPEN
      );

      const offerThree = [
        getTestItem721(
          secondNFTId,
          toBN(1),
          toBN(1),
          undefined,
          testERC721.address
        ),
      ];

      const considerationThree = [
        getTestItem721(
          nftId,
          toBN(1),
          toBN(1),
          buyer.address,
          testERC721.address
        ),
      ];

      const { order: orderThree, orderHash: orderHashThree } =
        await createOrder(
          buyer,
          zone,
          offerThree,
          considerationThree,
          0 // FULL_OPEN
        );

      const fulfillments = [
        [[[1, 0]], [[0, 0]]],
        [[[0, 0]], [[2, 0]]],
        [[[2, 0]], [[1, 0]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [orderOne, orderTwo, orderThree],
        [], // no criteria resolvers
        fulfillments,
        owner,
        0 // no value
      );

      expect(executions.length).to.equal(fulfillments.length - 1);

      const tx = marketplaceContract
        .connect(owner)
        .matchAdvancedOrders(
          [orderOne, orderTwo, orderThree],
          [],
          fulfillments,
          ethers.constants.AddressZero,
          {
            value: 0,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order: orderOne,
            orderHash: orderHashOne,
            fulfiller: owner.address,
          },
          {
            order: orderTwo,
            orderHash: orderHashTwo,
            fulfiller: owner.address,
          },
          {
            order: orderThree,
            orderHash: orderHashThree,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      return receipt;
    });
    it("Does not filter native tokens", async () => {
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );
      const secondNFTId = await mintAndApprove721(
        buyer,
        marketplaceContract.address
      );

      const offerOne = [
        getTestItem721(nftId, toBN(1), toBN(1), undefined, testERC721.address),
      ];

      const considerationOne = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
      ];

      const { order: orderOne } = await createOrder(
        seller,
        zone,
        offerOne,
        considerationOne,
        0 // FULL_OPEN
      );

      const offerTwo = [getItemETH(parseEther("10"), parseEther("10"))];

      const considerationTwo = [
        getTestItem721(
          secondNFTId,
          toBN(1),
          toBN(1),
          seller.address,
          testERC721.address
        ),
      ];

      const { order: orderTwo } = await createOrder(
        seller,
        zone,
        offerTwo,
        considerationTwo,
        0 // FULL_OPEN
      );

      const offerThree = [
        getTestItem721(
          secondNFTId,
          toBN(1),
          toBN(1),
          undefined,
          testERC721.address
        ),
      ];

      const considerationThree = [
        getTestItem721(
          nftId,
          toBN(1),
          toBN(1),
          buyer.address,
          testERC721.address
        ),
      ];

      const { order: orderThree } = await createOrder(
        buyer,
        zone,
        offerThree,
        considerationThree,
        0 // FULL_OPEN
      );

      const fulfillments = [
        [[[1, 0]], [[0, 0]]],
        [[[0, 0]], [[2, 0]]],
        [[[2, 0]], [[1, 0]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchAdvancedOrders(
            [orderOne, orderTwo, orderThree],
            [],
            fulfillments,
            ethers.constants.AddressZero,
            {
              value: 0,
            }
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InsufficientNativeTokensSupplied"
      );
    });
  });

  describe("Order groups", async () => {
    it("Multiple offer components at once", async () => {
      // Seller mints NFTs
      const { nftId, amount } = await mint1155(seller, 2);

      // Seller approves marketplace contract to transfer NFT

      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      // Buyer mints ERC20s
      const tokenAmount = toBN(random128());
      await mintAndApproveERC20(
        buyer,
        marketplaceContract.address,
        tokenAmount.mul(2)
      );

      const offerOne = [getTestItem1155(nftId, amount, amount)];

      const considerationOne = [
        getTestItem20(tokenAmount, tokenAmount, seller.address),
      ];

      const { order: orderOne, orderHash: orderHashOne } = await createOrder(
        seller,
        zone,
        offerOne,
        considerationOne,
        0 // FULL_OPEN
      );

      const offerTwo = [getTestItem1155(nftId, amount, amount)];

      const considerationTwo = [
        getTestItem20(tokenAmount, tokenAmount, seller.address),
      ];

      const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
        seller,
        zone,
        offerTwo,
        considerationTwo,
        0 // FULL_OPEN
      );

      const offerThree = [
        getTestItem20(tokenAmount.mul(2), tokenAmount.mul(2)),
      ];

      const considerationThree = [
        getTestItem1155(
          nftId,
          amount.mul(2),
          amount.mul(2),
          undefined,
          buyer.address
        ),
      ];

      const { order: orderThree, orderHash: orderHashThree } =
        await createOrder(
          buyer,
          zone,
          offerThree,
          considerationThree,
          0 // FULL_OPEN
        );

      const fulfillments = [
        [
          [
            [0, 0],
            [1, 0],
          ],
          [[2, 0]],
        ],
        [[[2, 0]], [[0, 0]]],
        [[[2, 0]], [[1, 0]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [orderOne, orderTwo, orderThree],
        [], // no criteria resolvers
        fulfillments,
        owner,
        0 // no value
      );

      expect(executions.length).to.equal(fulfillments.length);

      const tx = marketplaceContract
        .connect(buyer)
        .matchAdvancedOrders(
          [orderOne, orderTwo, orderThree],
          [],
          fulfillments,
          ethers.constants.AddressZero,
          {
            value: 0,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order: orderOne,
            orderHash: orderHashOne,
            fulfiller: buyer.address,
          },
          {
            order: orderTwo,
            orderHash: orderHashTwo,
            fulfiller: buyer.address,
          },
          {
            order: orderThree,
            orderHash: orderHashThree,
            fulfiller: buyer.address,
          },
        ],
        executions,
        [],
        true
      );

      // Check ERC1155 event `TransferSingle` amount is amount.mul(2)
      expect(
        toBN(
          "0x" +
            receipt.events
              ?.find(
                (x) =>
                  x.topics[0] ===
                  testERC1155.interface.getEventTopic("TransferSingle")
              )
              ?.data.slice(66)
        ).toString()
      ).to.equal(amount.mul(2).toString());

      return receipt;
    });
    it("Multiple consideration components at once", async () => {
      // Seller mints NFTs
      const { nftId, amount } = await mint1155(seller, 2);

      // Seller approves marketplace contract to transfer NFT

      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      // Buyer mints ERC20s
      const tokenAmount = toBN(random128());
      await mintAndApproveERC20(
        buyer,
        marketplaceContract.address,
        tokenAmount.mul(2)
      );

      const offerOne = [
        getTestItem1155(nftId, amount.mul(2), amount.mul(2), undefined),
      ];

      const considerationOne = [
        getTestItem20(tokenAmount.mul(2), tokenAmount.mul(2), seller.address),
      ];

      const { order: orderOne, orderHash: orderHashOne } = await createOrder(
        seller,
        zone,
        offerOne,
        considerationOne,
        0 // FULL_OPEN
      );

      const offerTwo = [getTestItem20(tokenAmount, tokenAmount)];

      const considerationTwo = [
        getTestItem1155(nftId, amount, amount, undefined, buyer.address),
      ];

      const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
        buyer,
        zone,
        offerTwo,
        considerationTwo,
        0 // FULL_OPEN
      );

      const offerThree = [getTestItem20(tokenAmount, tokenAmount)];

      const considerationThree = [
        getTestItem1155(nftId, amount, amount, undefined, buyer.address),
      ];

      const { order: orderThree, orderHash: orderHashThree } =
        await createOrder(
          buyer,
          zone,
          offerThree,
          considerationThree,
          0 // FULL_OPEN
        );

      const fulfillments = [
        [
          [[0, 0]],
          [
            [1, 0],
            [2, 0],
          ],
        ],
        [[[1, 0]], [[0, 0]]],
        [[[2, 0]], [[0, 0]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [orderOne, orderTwo, orderThree],
        [], // no criteria resolvers
        fulfillments,
        owner,
        0 // no value
      );

      expect(executions.length).to.equal(fulfillments.length);

      const tx = marketplaceContract
        .connect(buyer)
        .matchAdvancedOrders(
          [orderOne, orderTwo, orderThree],
          [],
          fulfillments,
          ethers.constants.AddressZero,
          {
            value: 0,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order: orderOne,
            orderHash: orderHashOne,
            fulfiller: buyer.address,
          },
          {
            order: orderTwo,
            orderHash: orderHashTwo,
            fulfiller: buyer.address,
          },
          {
            order: orderThree,
            orderHash: orderHashThree,
            fulfiller: buyer.address,
          },
        ],
        executions,
        [],
        true
      );

      // TODO: include balance checks on the duplicate ERC20 transfers

      return receipt;
    });
    it("Multiple consideration components at once, various OOR offer/consideration items", async () => {
      // Seller mints NFTs
      const { nftId, amount } = await mint1155(seller, 2);

      // Seller approves marketplace contract to transfer NFT

      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      // Buyer mints ERC20s
      const tokenAmount = toBN(random128());
      await mintAndApproveERC20(
        buyer,
        marketplaceContract.address,
        tokenAmount.mul(2)
      );

      const offerOne = [
        getTestItem1155(nftId, amount.mul(2), amount.mul(2), undefined),
      ];

      const considerationOne = [
        getTestItem20(tokenAmount.mul(2), tokenAmount.mul(2), seller.address),
      ];

      const { order: orderOne, orderHash: orderHashOne } = await createOrder(
        seller,
        zone,
        offerOne,
        considerationOne,
        0 // FULL_OPEN
      );

      const offerTwo = [getTestItem20(tokenAmount, tokenAmount)];

      const considerationTwo = [
        getTestItem1155(nftId, amount, amount, undefined, buyer.address),
      ];

      const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
        buyer,
        zone,
        offerTwo,
        considerationTwo,
        0 // FULL_OPEN
      );

      const offerThree = [getTestItem20(tokenAmount, tokenAmount)];

      const considerationThree = [
        getTestItem1155(nftId, amount, amount, undefined, buyer.address),
      ];

      const { order: orderThree, orderHash: orderHashThree } =
        await createOrder(
          buyer,
          zone,
          offerThree,
          considerationThree,
          0 // FULL_OPEN
        );

      const fulfillments = [
        [
          [
            [0, 5], // OOR first offer item
            [0, 0],
          ],
          [
            [1, 0],
            [2, 0],
          ],
        ],
        [
          [[1, 0]],
          [
            [0, 5], // OOR first consideration item
            [0, 0],
          ],
        ],
        [
          [
            [2, 0],
            [0, 5], // OOR last offer item
          ],
          [
            [0, 0],
            [0, 5], // OOR last consideration item
          ],
        ],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [orderOne, orderTwo, orderThree],
        [], // no criteria resolvers
        fulfillments,
        owner,
        0 // no value
      );

      expect(executions.length).to.equal(fulfillments.length);

      const tx = marketplaceContract
        .connect(buyer)
        .matchAdvancedOrders(
          [orderOne, orderTwo, orderThree],
          [],
          fulfillments,
          ethers.constants.AddressZero,
          {
            value: 0,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order: orderOne,
            orderHash: orderHashOne,
            fulfiller: buyer.address,
          },
          {
            order: orderTwo,
            orderHash: orderHashTwo,
            fulfiller: buyer.address,
          },
          {
            order: orderThree,
            orderHash: orderHashThree,
            fulfiller: buyer.address,
          },
        ],
        executions,
        [],
        true
      );

      // TODO: include balance checks on the duplicate ERC20 transfers

      return receipt;
    });
  });

  describe("Complex ERC1155 transfers", async () => {
    it("ERC1155 <=> ETH (match)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } =
        await mintAndApprove1155(seller, marketplaceContract.address);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(secondNftId, secondAmount, secondAmount),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [[[0, 1]], [[1, 1]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(5);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      return receipt;
    });
    it("ERC1155 <=> ETH (match, three items)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        seller
      );

      // Seller mints third nft
      const { nftId: thirdNftId, amount: thirdAmount } =
        await mintAndApprove1155(seller, marketplaceContract.address);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(secondNftId, secondAmount, secondAmount),
        getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [[[0, 1]], [[1, 1]]],
        [[[0, 2]], [[1, 2]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(6);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      return receipt;
    });
    it("ERC1155 <=> ETH (match, initial OOR offer/consideration items skipped)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        seller
      );

      // Seller mints third nft
      const { nftId: thirdNftId, amount: thirdAmount } =
        await mintAndApprove1155(seller, marketplaceContract.address);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(secondNftId, secondAmount, secondAmount),
        getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      const fulfillments = [
        [
          [
            [0, 5], // OOR offer item
            [0, 0],
          ],
          [
            [0, 5], // OOR consideration itemx
            [1, 0],
          ],
        ],
        [[[0, 1]], [[1, 1]]],
        [[[0, 2]], [[1, 2]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(6);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      return receipt;
    });
    it("ERC1155 <=> ETH (match, subsequent OOR offer/consideration items skipped)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        seller
      );

      // Seller mints third nft
      const { nftId: thirdNftId, amount: thirdAmount } =
        await mintAndApprove1155(seller, marketplaceContract.address);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(secondNftId, secondAmount, secondAmount),
        getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      const fulfillments = [
        [
          [
            [0, 0],
            [0, 5],
          ],
          [
            [1, 0],
            [0, 5],
          ],
        ],
        [[[0, 0]], [[0, 5]]],
        [[[0, 1]], [[1, 1]]],
        [[[0, 2]], [[1, 2]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(6);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      return receipt;
    });
    it("ERC1155 <=> ETH (match, offer aggregation skipped if no available consideration items)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        seller
      );

      // Seller mints third nft
      const { nftId: thirdNftId, amount: thirdAmount } =
        await mintAndApprove1155(seller, marketplaceContract.address);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(secondNftId, secondAmount, secondAmount),
        getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      const fulfillments = [
        // Order index invalid for offer, but will be skipped because no available considerations
        [[[5, 5]], [[0, 5]]],
        [[[0, 0]], [[1, 0]]],
        [[[0, 0]], [[0, 5]]],
        [[[0, 1]], [[1, 1]]],
        [[[0, 2]], [[1, 2]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(6);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      return receipt;
    });
    it("ERC1155 <=> ETH (match via conduit)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } =
        await mintAndApprove1155(seller, conduitOne.address);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(secondNftId, secondAmount, secondAmount),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        null,
        seller,
        ethers.constants.HashZero,
        conduitKeyOne
      );

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [[[0, 1]], [[1, 1]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(5);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      return receipt;
    });
    it("ERC1155 <=> ETH (match, single item)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem1155(nftId, amount, amount, undefined)];

      const consideration: ConsiderationItem[] = [];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      const fulfillments = [toFulfillment([[0, 0]], [[1, 0]])];

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(1);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      return receipt;
    });
    it("ERC1155 <=> ETH (match, single 1155)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem1155(nftId, amount, amount, undefined)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(4);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      return receipt;
    });
    it("ERC1155 <=> ETH (match, two different 1155 contracts)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const secondNftId = toBN(randomBN(4));
      const secondAmount = toBN(randomBN(4));
      await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

      // Seller approves marketplace contract to transfer NFTs

      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      await expect(
        testERC1155Two
          .connect(seller)
          .setApprovalForAll(marketplaceContract.address, true)
      )
        .to.emit(testERC1155Two, "ApprovalForAll")
        .withArgs(seller.address, marketplaceContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(
          secondNftId,
          secondAmount,
          secondAmount,
          testERC1155Two.address
        ),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [[[0, 1]], [[1, 1]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(5);

      await marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
    });
    it("ERC1155 <=> ETH (match, one single and one with two 1155's)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address
      );

      // Seller mints second nft
      const secondNftId = toBN(randomBN(4));
      const secondAmount = toBN(randomBN(4));
      await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

      // Seller mints third nft
      const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(seller);

      // Seller approves marketplace contract to transfer NFTs

      await expect(
        testERC1155Two
          .connect(seller)
          .setApprovalForAll(marketplaceContract.address, true)
      )
        .to.emit(testERC1155Two, "ApprovalForAll")
        .withArgs(seller.address, marketplaceContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(
          secondNftId,
          secondAmount,
          secondAmount,
          testERC1155Two.address
        ),
        getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [[[0, 1]], [[1, 1]]],
        [[[0, 2]], [[1, 2]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(6);

      await marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
    });
    it("ERC1155 <=> ETH (match, two different groups of 1155's)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address
      );

      // Seller mints second nft
      const secondNftId = toBN(randomBN(4));
      const secondAmount = toBN(randomBN(4));
      await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

      // Seller mints third nft
      const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(seller);

      // Seller mints fourth nft
      const fourthNftId = toBN(randomBN(4));
      const fourthAmount = toBN(randomBN(4));
      await testERC1155Two.mint(seller.address, fourthNftId, fourthAmount);

      // Seller approves marketplace contract to transfer NFTs

      await expect(
        testERC1155Two
          .connect(seller)
          .setApprovalForAll(marketplaceContract.address, true)
      )
        .to.emit(testERC1155Two, "ApprovalForAll")
        .withArgs(seller.address, marketplaceContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(
          secondNftId,
          secondAmount,
          secondAmount,
          testERC1155Two.address
        ),
        getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
        getTestItem1155(
          fourthNftId,
          fourthAmount,
          fourthAmount,
          testERC1155Two.address
        ),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [[[0, 1]], [[1, 1]]],
        [[[0, 2]], [[1, 2]]],
        [[[0, 3]], [[1, 3]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(7);

      await marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
    });
  });

  describe("Fulfill Available Orders", async () => {
    it("Can fulfill a single order via fulfillAvailableOrders", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address,
        10
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [toFulfillmentComponents([[0, 0]])];

      const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]].map(
        toFulfillmentComponents
      );

      await withBalanceChecks([order], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAvailableOrders(
            [order],
            offerComponents,
            considerationComponents,
            toKey(0),
            100,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order,
            orderHash,
            fulfiller: buyer.address,
          },
        ]);

        return receipt;
      });
    });
    it("Can fulfill a single order via fulfillAvailableAdvancedOrders", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address,
        11
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [[{ orderIndex: 0, itemIndex: 0 }]];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
        [{ orderIndex: 0, itemIndex: 2 }],
      ];

      await withBalanceChecks([order], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAvailableAdvancedOrders(
            [order],
            [],
            offerComponents,
            considerationComponents,
            toKey(0),
            ethers.constants.AddressZero,
            100,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order,
            orderHash,
            fulfiller: buyer.address,
          },
        ]);

        return receipt;
      });
    });
    it("Can fulfill a single order via fulfillAvailableAdvancedOrders with recipient specified", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [[{ orderIndex: 0, itemIndex: 0 }]];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
      ];

      await withBalanceChecks([order], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAvailableAdvancedOrders(
            [order],
            [],
            offerComponents,
            considerationComponents,
            toKey(0),
            owner.address,
            100,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order,
            orderHash,
            fulfiller: buyer.address,
            recipient: owner.address,
          },
        ]);

        return receipt;
      });
    });
    it("Can fulfill and aggregate multiple orders via fulfillAvailableOrders", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1,
        1,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const {
        order: orderOne,
        orderHash: orderHashOne,
        value,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [
        toFulfillmentComponents([
          [0, 0],
          [1, 0],
        ]),
      ];

      const considerationComponents = [
        [
          [0, 0],
          [1, 0],
        ],
        [
          [0, 1],
          [1, 1],
        ],
        [
          [0, 2],
          [1, 2],
        ],
      ].map(toFulfillmentComponents);

      await withBalanceChecks(
        [orderOne, orderTwo],
        0,
        undefined,
        async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [orderOne, orderTwo],
              offerComponents,
              considerationComponents,
              toKey(0),
              100,
              {
                value: value.mul(2),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: buyer.address,
              },
              {
                order: orderTwo,
                orderHash: orderHashTwo,
                fulfiller: buyer.address,
              },
            ],
            [],
            [],
            false,
            2
          );
          return receipt;
        },
        2
      );
    });
    it("Can fulfill and aggregate multiple orders via fulfillAvailableAdvancedOrders including restricted orders", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1,
        1,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const {
        order: orderOne,
        orderHash: orderHashOne,
        value,
      } = await createOrder(
        seller,
        stubZone,
        offer,
        consideration,
        2 // FULL_RESTRICTED
      );

      const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // test orderHashes
      orderOne.extraData = ethers.utils.defaultAbiCoder.encode(
        ["bytes32[]"],
        [[orderHashOne, orderHashTwo]]
      );

      expect((orderOne.extraData.length - 2) / 64).to.equal(4);

      const offerComponents = [
        toFulfillmentComponents([
          [0, 0],
          [1, 0],
        ]),
      ];

      const considerationComponents = [
        [
          [0, 0],
          [1, 0],
        ],
        [
          [0, 1],
          [1, 1],
        ],
        [
          [0, 2],
          [1, 2],
        ],
      ].map(toFulfillmentComponents);

      await withBalanceChecks(
        [orderOne, orderTwo],
        0,
        undefined,
        async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [orderOne, orderTwo],
              [],
              offerComponents,
              considerationComponents,
              toKey(0),
              ethers.constants.AddressZero,
              100,
              {
                value: value.mul(2),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: buyer.address,
              },
              {
                order: orderTwo,
                orderHash: orderHashTwo,
                fulfiller: buyer.address,
              },
            ],
            [],
            [],
            false,
            2
          );
          return receipt;
        },
        2
      );
    });
    it("Can fulfill and aggregate multiple orders via fulfillAvailableOrders with OOR offer / consideration items", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1,
        1,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const {
        order: orderOne,
        orderHash: orderHashOne,
        value,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [
        toFulfillmentComponents([
          [0, 0],
          [1, 0],
          [1, 5],
        ]),
      ];

      const considerationComponents = [
        [
          [0, 0],
          [1, 0],
        ],
        [
          [0, 1],
          [1, 1],
        ],
        [
          [0, 2],
          [1, 2],
          [1, 5],
        ],
      ].map(toFulfillmentComponents);

      await withBalanceChecks(
        [orderOne, orderTwo],
        0,
        undefined,
        async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [orderOne, orderTwo],
              offerComponents,
              considerationComponents,
              toKey(0),
              100,
              {
                value: value.mul(2),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: buyer.address,
              },
              {
                order: orderTwo,
                orderHash: orderHashTwo,
                fulfiller: buyer.address,
              },
            ],
            [],
            [],
            false,
            2
          );
          return receipt;
        },
        2
      );
    });
    it("Can fulfill and aggregate multiple orders via fulfillAvailableOrders with OOR initial offer / consideration items", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1,
        1,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const {
        order: orderOne,
        orderHash: orderHashOne,
        value,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [
        toFulfillmentComponents([
          [1, 5],
          [0, 0],
          [1, 0],
        ]),
      ];

      const considerationComponents = [
        [
          [0, 0],
          [1, 0],
        ],
        [
          [0, 1],
          [1, 1],
        ],
        [
          [1, 5],
          [0, 2],
          [1, 2],
        ],
      ].map(toFulfillmentComponents);

      await withBalanceChecks(
        [orderOne, orderTwo],
        0,
        undefined,
        async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [orderOne, orderTwo],
              offerComponents,
              considerationComponents,
              toKey(0),
              100,
              {
                value: value.mul(2),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: buyer.address,
              },
              {
                order: orderTwo,
                orderHash: orderHashTwo,
                fulfiller: buyer.address,
              },
            ],
            [],
            [],
            false,
            2
          );
          return receipt;
        },
        2
      );
    });
    it("Can fulfill and aggregate multiple orders via fulfillAvailableAdvancedOrders", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1,
        2,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const {
        order: orderOne,
        orderHash: orderHashOne,
        value,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [
        toFulfillmentComponents([
          [0, 0],
          [1, 0],
        ]),
      ];

      const considerationComponents = [
        [
          [0, 0],
          [1, 0],
        ],
        [
          [0, 1],
          [1, 1],
        ],
        [
          [0, 2],
          [1, 2],
        ],
      ].map(toFulfillmentComponents);

      await withBalanceChecks(
        [orderOne, orderTwo],
        0,
        undefined,
        async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [orderOne, orderTwo],
              [],
              offerComponents,
              considerationComponents,
              toKey(0),
              ethers.constants.AddressZero,
              100,
              {
                value: value.mul(2),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: buyer.address,
              },
              {
                order: orderTwo,
                orderHash: orderHashTwo,
                fulfiller: buyer.address,
              },
            ],
            [],
            [],
            false,
            2
          );
          return receipt;
        },
        2
      );
    });
    it("Can fulfill and aggregate a max number of multiple orders via fulfillAvailableOrders", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1,
        3,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const {
        order: orderOne,
        orderHash: orderHashOne,
        value,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { order: orderTwo } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 1, itemIndex: 0 }],
      ];
      const considerationComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 1, itemIndex: 0 },
        ],
        [
          { orderIndex: 0, itemIndex: 1 },
          { orderIndex: 1, itemIndex: 1 },
        ],
        [
          { orderIndex: 0, itemIndex: 2 },
          { orderIndex: 1, itemIndex: 2 },
        ],
      ];

      await withBalanceChecks(
        [orderOne],
        0,
        undefined,
        async () => {
          const { executions } = await marketplaceContract
            .connect(buyer)
            .callStatic.fulfillAvailableOrders(
              [orderOne, orderTwo],
              offerComponents,
              considerationComponents,
              toKey(0),
              1,
              {
                value: value.mul(2),
              }
            );
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [orderOne, orderTwo],
              offerComponents,
              considerationComponents,
              toKey(0),
              1,
              {
                value: value.mul(2),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: buyer.address,
              },
            ],
            executions
          );

          return receipt;
        },
        1
      );
    });
    it("Can fulfill and aggregate a max number of multiple orders via fulfillAvailableAdvancedOrders", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1,
        4,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const {
        order: orderOne,
        orderHash: orderHashOne,
        value,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { order: orderTwo } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 1, itemIndex: 0 },
        ],
      ];
      const considerationComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 1, itemIndex: 0 },
        ],
        [
          { orderIndex: 0, itemIndex: 1 },
          { orderIndex: 1, itemIndex: 1 },
        ],
        [
          { orderIndex: 0, itemIndex: 2 },
          { orderIndex: 1, itemIndex: 2 },
        ],
      ];

      await withBalanceChecks(
        [orderOne],
        0,
        undefined,
        async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [orderOne, orderTwo],
              [],
              offerComponents,
              considerationComponents,
              toKey(0),
              ethers.constants.AddressZero,
              1,
              {
                value: value.mul(2),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: buyer.address,
              },
            ],
            [],
            [],
            false,
            1
          );

          return receipt;
        },
        1
      );
    });
    it("Can fulfill and aggregate multiple orders via fulfillAvailableOrders with failing orders", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1,
        5,
        100000
      );

      const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const {
        order: orderOne,
        orderHash: orderHashOne,
        value,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // second order is expired
      const { order: orderTwo } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        "EXPIRED"
      );

      // third order will be cancelled
      const {
        order: orderThree,
        orderHash: orderHashThree,
        orderComponents,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // can cancel it
      await expect(
        marketplaceContract.connect(seller).cancel([orderComponents])
      )
        .to.emit(marketplaceContract, "OrderCancelled")
        .withArgs(orderHashThree, seller.address, zone.address);

      // fourth order will be filled
      const { order: orderFour, orderHash: orderHashFour } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // can fill it
      await withBalanceChecks([orderFour], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillOrder(orderFour, toKey(0), {
            value,
          });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order: orderFour,
            orderHash: orderHashFour,
            fulfiller: buyer.address,
          },
        ]);

        return receipt;
      });

      const offerComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 1, itemIndex: 0 },
          { orderIndex: 2, itemIndex: 0 },
          { orderIndex: 3, itemIndex: 0 },
        ],
      ];
      const considerationComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 1, itemIndex: 0 },
          { orderIndex: 2, itemIndex: 0 },
          { orderIndex: 3, itemIndex: 0 },
        ],
        [
          { orderIndex: 0, itemIndex: 1 },
          { orderIndex: 1, itemIndex: 1 },
          { orderIndex: 2, itemIndex: 1 },
          { orderIndex: 3, itemIndex: 1 },
        ],
        [
          { orderIndex: 0, itemIndex: 2 },
          { orderIndex: 1, itemIndex: 2 },
          { orderIndex: 2, itemIndex: 2 },
          { orderIndex: 3, itemIndex: 2 },
        ],
      ];

      await withBalanceChecks([orderOne], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAvailableOrders(
            [orderOne, orderTwo, orderThree, orderFour],
            offerComponents,
            considerationComponents,
            toKey(0),
            100,
            {
              value: value.mul(4),
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order: orderOne,
            orderHash: orderHashOne,
            fulfiller: buyer.address,
          },
        ]);

        return receipt;
      });
    });
    it("Can fulfill and aggregate multiple orders via fulfillAvailableAdvancedOrders with failing orders", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1,
        6,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const {
        order: orderOne,
        orderHash: orderHashOne,
        value,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // second order is expired
      const { order: orderTwo } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        "EXPIRED"
      );

      // third order will be cancelled
      const {
        order: orderThree,
        orderHash: orderHashThree,
        orderComponents,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // can cancel it
      await expect(
        marketplaceContract.connect(seller).cancel([orderComponents])
      )
        .to.emit(marketplaceContract, "OrderCancelled")
        .withArgs(orderHashThree, seller.address, zone.address);

      // fourth order will be filled
      const { order: orderFour, orderHash: orderHashFour } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // can fill it
      await withBalanceChecks([orderFour], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillOrder(orderFour, toKey(0), {
            value,
          });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order: orderFour,
            orderHash: orderHashFour,
            fulfiller: buyer.address,
          },
        ]);

        return receipt;
      });

      const offerComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 1, itemIndex: 0 },
          { orderIndex: 2, itemIndex: 0 },
          { orderIndex: 3, itemIndex: 0 },
        ],
      ];
      const considerationComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 1, itemIndex: 0 },
          { orderIndex: 2, itemIndex: 0 },
          { orderIndex: 3, itemIndex: 0 },
        ],
        [
          { orderIndex: 0, itemIndex: 1 },
          { orderIndex: 1, itemIndex: 1 },
          { orderIndex: 2, itemIndex: 1 },
          { orderIndex: 3, itemIndex: 1 },
        ],
        [
          { orderIndex: 0, itemIndex: 2 },
          { orderIndex: 1, itemIndex: 2 },
          { orderIndex: 2, itemIndex: 2 },
          { orderIndex: 3, itemIndex: 2 },
        ],
      ];

      await withBalanceChecks([orderOne], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAvailableAdvancedOrders(
            [orderOne, orderTwo, orderThree, orderFour],
            [],
            offerComponents,
            considerationComponents,
            toKey(0),
            ethers.constants.AddressZero,
            100,
            {
              value: value.mul(4),
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order: orderOne,
            orderHash: orderHashOne,
            fulfiller: buyer.address,
          },
        ]);

        return receipt;
      });
    });
    it("Can fulfill and aggregate multiple orders via fulfillAvailableAdvancedOrders with failing components including criteria", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        1,
        7,
        10000
      );

      // Seller mints second nft

      // Seller mints nfts for criteria-based item
      const criteriaNftId = randomBN();
      const secondCriteriaNFTId = randomBN();
      const thirdCriteriaNFTId = randomBN();

      await testERC721.mint(seller.address, criteriaNftId);
      await testERC721.mint(seller.address, secondCriteriaNFTId);
      await testERC721.mint(seller.address, thirdCriteriaNFTId);

      const tokenIds = [criteriaNftId, secondCriteriaNFTId, thirdCriteriaNFTId];

      // Seller approves marketplace contract to transfer NFTs
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const { root, proofs } = merkleTree(tokenIds);

      const offer = [getTestItem1155(nftId, amount, amount, undefined)];

      const offerTwo = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const criteriaResolvers = [
        buildResolver(1, 0, 0, criteriaNftId, proofs[criteriaNftId.toString()]),
      ];

      const {
        order: orderOne,
        orderHash: orderHashOne,
        value,
      } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // second order is expired
      const { order: orderTwo } = await createOrder(
        seller,
        zone,
        offerTwo,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers,
        "EXPIRED"
      );

      const offerComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 1, itemIndex: 0 }],
      ];
      const considerationComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 1, itemIndex: 0 },
        ],
        [
          { orderIndex: 0, itemIndex: 1 },
          { orderIndex: 1, itemIndex: 1 },
        ],
        [
          { orderIndex: 0, itemIndex: 2 },
          { orderIndex: 1, itemIndex: 2 },
        ],
      ];

      await withBalanceChecks([orderOne], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAvailableAdvancedOrders(
            [orderOne, orderTwo],
            criteriaResolvers,
            offerComponents,
            considerationComponents,
            toKey(0),
            ethers.constants.AddressZero,
            100,
            {
              value: value.mul(2),
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order: orderOne,
            orderHash: orderHashOne,
            fulfiller: buyer.address,
          },
        ]);

        return receipt;
      });
    });
  });

  describe("Match Orders (send excess offer items to recipient)", async () => {
    it("Return unspent offer items to caller", async () => {
      // Mint 1155 tokens
      const { nftId, amount } = await mint1155(seller);

      // Generate random amount of tokens not to spend.
      const unspentAmount = toBN(randomBN(2));

      // Seller approves marketplace contract to transfer NFTs
      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [getTestItem1155(nftId, amount, amount, undefined)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const counter = await marketplaceContract.getCounter(buyer.address);

      const mirrorOrderParameters = {
        offerer: buyer.address,
        zone: zone.address,
        offer: [getItemETH(parseEther("12"), parseEther("12"))],
        consideration: [
          getTestItem1155(
            nftId,
            amount.sub(unspentAmount),
            amount.sub(unspentAmount),
            undefined,
            buyer.address
          ),
        ],
        totalOriginalConsiderationItems: 1,
        orderType: order.parameters.orderType, // FULL_OPEN
        zoneHash: "0x".padEnd(66, "0"),
        salt: randomHex(),
        conduitKey: constants.HashZero,
        startTime: order.parameters.startTime,
        endTime: order.parameters.endTime,
      };

      const mirrorOrderComponents = {
        ...mirrorOrderParameters,
        counter,
      };

      const flatSig = await signOrder(mirrorOrderComponents, buyer);

      const mirrorOrder = {
        parameters: mirrorOrderParameters,
        signature: flatSig,
        numerator: order.numerator, // only used for advanced orders
        denominator: order.denominator, // only used for advanced orders
        extraData: "0x", // only used for advanced orders
      };

      const fulfillments = defaultBuyNowMirrorFulfillment;

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );
      expect(executions.length).to.equal(4);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();

      // Check that unspent offer items are sent back to caller.
      expect(await testERC1155.balanceOf(owner.address, nftId)).to.equal(
        unspentAmount
      );

      return receipt;
    });

    it("Return unspent offer items to specified recipient", async () => {
      // Mint 1155 tokens
      const { nftId, amount } = await mint1155(seller);

      // Generate random amount of tokens not to spend.
      const unspentAmount = toBN(randomBN(2));

      // Seller approves marketplace contract to transfer NFTs
      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [getTestItem1155(nftId, amount, amount, undefined)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const counter = await marketplaceContract.getCounter(buyer.address);

      const mirrorOrderParameters = {
        offerer: buyer.address,
        zone: zone.address,
        offer: [getItemETH(parseEther("12"), parseEther("12"))],
        consideration: [
          getTestItem1155(
            nftId,
            amount.sub(unspentAmount),
            amount.sub(unspentAmount),
            undefined,
            buyer.address
          ),
        ],
        totalOriginalConsiderationItems: 1,
        orderType: order.parameters.orderType, // FULL_OPEN
        zoneHash: "0x".padEnd(66, "0"),
        salt: randomHex(),
        conduitKey: constants.HashZero,
        startTime: order.parameters.startTime,
        endTime: order.parameters.endTime,
      };

      const mirrorOrderComponents = {
        ...mirrorOrderParameters,
        counter,
      };

      const flatSig = await signOrder(mirrorOrderComponents, buyer);

      const mirrorOrder = {
        parameters: mirrorOrderParameters,
        signature: flatSig,
        numerator: order.numerator, // only used for advanced orders
        denominator: order.denominator, // only used for advanced orders
        extraData: "0x", // only used for advanced orders
      };

      const fulfillments = defaultBuyNowMirrorFulfillment;

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );
      expect(executions.length).to.equal(4);

      const tx = marketplaceContract
        .connect(owner)
        .matchAdvancedOrders(
          [order, mirrorOrder],
          [],
          fulfillments,
          seller.address,
          {
            value,
          }
        );
      const receipt = await (await tx).wait();

      // Check that unspent offer items are sent back to caller.
      expect(await testERC1155.balanceOf(seller.address, nftId)).to.equal(
        unspentAmount
      );

      return receipt;
    });
  });
});
