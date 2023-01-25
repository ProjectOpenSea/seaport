import { PANIC_CODES } from "@nomicfoundation/hardhat-chai-matchers/panic";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import hre, { ethers, network } from "hardhat";

import { deployContract } from "./utils/contracts";
import { merkleTree } from "./utils/criteria";
import {
  buildOrderStatus,
  buildResolver,
  defaultBuyNowMirrorFulfillment,
  getBasicOrderParameters,
  getItemETH,
  randomBN,
  randomHex,
  toBN,
  toFulfillment,
  toFulfillmentComponents,
  toKey,
} from "./utils/encoding";
import { faucet, getWalletWithEther } from "./utils/faucet";
import { fixtureERC20, seaportFixture } from "./utils/fixtures";
import {
  VERSION,
  getCustomRevertSelector,
  minRandom,
  simulateMatchOrders,
} from "./utils/helpers";

import type {
  ConduitInterface,
  ConsiderationInterface,
  EIP1271Wallet,
  EIP1271Wallet__factory,
  Reenterer,
  TestBadContractOfferer,
  TestERC1155,
  TestERC20,
  TestERC721,
  TestZone,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { ConsiderationItem, Fulfillment, OfferItem } from "./utils/types";
import type { BigNumber, Wallet } from "ethers";

const { parseEther } = ethers.utils;

describe(`Reverts (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let conduitKeyOne: string;
  let conduitOne: ConduitInterface;
  let EIP1271WalletFactory: EIP1271Wallet__factory;
  let marketplaceContract: ConsiderationInterface;
  let stubZone: TestZone;
  let testERC1155: TestERC1155;
  let testERC20: TestERC20;
  let testERC721: TestERC721;

  let checkExpectedEvents: SeaportFixtures["checkExpectedEvents"];
  let createMirrorAcceptOfferOrder: SeaportFixtures["createMirrorAcceptOfferOrder"];
  let createMirrorBuyNowOrder: SeaportFixtures["createMirrorBuyNowOrder"];
  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem1155: SeaportFixtures["getTestItem1155"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let getTestItem721WithCriteria: SeaportFixtures["getTestItem721WithCriteria"];
  let mint1155: SeaportFixtures["mint1155"];
  let mint721: SeaportFixtures["mint721"];
  let mintAndApprove1155: SeaportFixtures["mintAndApprove1155"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];
  let set1155ApprovalForAll: SeaportFixtures["set1155ApprovalForAll"];
  let set721ApprovalForAll: SeaportFixtures["set721ApprovalForAll"];
  let withBalanceChecks: SeaportFixtures["withBalanceChecks"];

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
      EIP1271WalletFactory,
      getTestItem1155,
      getTestItem20,
      getTestItem721,
      getTestItem721WithCriteria,
      marketplaceContract,
      mint1155,
      mint721,
      mintAndApprove1155,
      mintAndApprove721,
      mintAndApproveERC20,
      reenterer,
      set1155ApprovalForAll,
      set721ApprovalForAll,
      stubZone,
      testERC1155,
      testERC20,
      testERC721,
      withBalanceChecks,
    } = await seaportFixture(owner));
  });

  let seller: Wallet;
  let buyer: Wallet;
  let zone: Wallet;
  let reenterer: Reenterer;

  let sellerContract: EIP1271Wallet;

  async function setupFixture() {
    // Setup basic buyer/seller wallets with ETH
    const seller = new ethers.Wallet(randomHex(32), provider);
    const buyer = new ethers.Wallet(randomHex(32), provider);
    const zone = new ethers.Wallet(randomHex(32), provider);

    const sellerContract = await EIP1271WalletFactory.deploy(seller.address);

    for (const wallet of [seller, buyer, zone, sellerContract, reenterer]) {
      await faucet(wallet.address, provider);
    }

    return {
      seller,
      buyer,
      zone,
      sellerContract,
    };
  }

  beforeEach(async () => {
    ({ seller, buyer, zone, sellerContract } = await loadFixture(setupFixture));
  });

  describe("Misconfigured orders", async () => {
    it("Reverts on bad fraction amounts", async () => {
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

      order.numerator = 0;
      order.denominator = 10;

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
      ).to.be.revertedWithCustomError(marketplaceContract, "BadFraction");

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 1;
      order.denominator = 0;

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
      ).to.be.revertedWithCustomError(marketplaceContract, "BadFraction");

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 2;
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
      ).to.be.revertedWithCustomError(marketplaceContract, "BadFraction");

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 1;
      order.denominator = 2;

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
        buildOrderStatus(true, false, 1, 2)
      );
    });
    it("Reverts on inexact fraction amounts", async () => {
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

      order.numerator = 1;
      order.denominator = 8191;

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
      ).to.be.revertedWithCustomError(marketplaceContract, "InexactFraction");

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 1;
      order.denominator = 2;

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
        buildOrderStatus(true, false, 1, 2)
      );
    });
    it("Reverts on partial fill attempt when not supported by order", async () => {
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
        0 // FULL_OPEN
      );

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 1;
      order.denominator = 2;

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
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "PartialFillsNotEnabledForOrder"
      );

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 1;
      order.denominator = 1;

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
    it("Reverts on partially filled order via basic fulfillment", async () => {
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

      order.numerator = 1;
      order.denominator = 2;

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
        buildOrderStatus(true, false, 1, 2)
      );

      const basicOrderParameters = getBasicOrderParameters(
        1, // EthForERC1155
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          `OrderPartiallyFilled`
        )
        .withArgs(orderHash);
    });
    it("Reverts on fully filled order", async () => {
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

      order.numerator = 1;
      order.denominator = 1;

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
          "OrderAlreadyFilled"
        )
        .withArgs(orderHash);
    });
    it("Reverts on non-zero unused item parameters (identifier set on native, basic, ERC721)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(1000, 1000, seller.address),
        getItemETH(10, 10, zone.address),
        getItemETH(20, 20, owner.address),
      ];

      consideration[0].identifierOrCriteria = minRandom(1);

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        `UnusedItemParameters`
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );
    });
    it("Reverts on non-zero unused item parameters (identifier set on ERC20, basic, ERC721)", async () => {
      // Seller mints ERC20
      await mintAndApproveERC20(seller, marketplaceContract.address, 1000);

      // Buyer mints nft
      const nftId = await mintAndApprove721(buyer, marketplaceContract.address);

      const offer = [getTestItem20(500, 500)];

      offer[0].identifierOrCriteria = minRandom(1);

      const consideration = [
        getTestItem721(nftId, 1, 1, seller.address),
        getTestItem20(50, 50, zone.address),
        getTestItem20(50, 50, owner.address),
      ];

      const { order, orderHash } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const basicOrderParameters = getBasicOrderParameters(
        4, // ERC721ForERC20
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters)
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        `UnusedItemParameters`
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );
    });
    it("Reverts on non-zero unused item parameters (identifier set on native, basic, ERC1155)", async () => {
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

      consideration[0].identifierOrCriteria = amount;

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const basicOrderParameters = getBasicOrderParameters(
        1, // EthForERC1155
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        `UnusedItemParameters`
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );
    });
    it("Reverts on non-zero unused item parameters (identifier set on ERC20, basic)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
        getTestItem20(amount.mul(10), amount.mul(10), zone.address),
        getTestItem20(amount.mul(20), amount.mul(20), owner.address),
      ];

      consideration[0].identifierOrCriteria = amount;

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const basicOrderParameters = getBasicOrderParameters(
        3, // ERC20ForERC1155
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        `UnusedItemParameters`
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );
    });
    it("Reverts on non-zero unused item parameters (token set on native, standard)", async () => {
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

      consideration[0].token = seller.address;

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

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
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        `UnusedItemParameters`
      );
    });
    it("Reverts on non-zero unused item parameters (identifier set on native, standard)", async () => {
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

      consideration[0].identifierOrCriteria = amount;

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

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
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        `UnusedItemParameters`
      );
    });
    it("Reverts on non-zero unused item parameters (identifier set on ERC20, standard)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
        getTestItem20(amount.mul(10), amount.mul(10), zone.address),
        getTestItem20(amount.mul(20), amount.mul(20), owner.address),
      ];

      consideration[0].identifierOrCriteria = amount;

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

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
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        `UnusedItemParameters`
      );
    });
    it("Reverts on inadequate consideration items", async () => {
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

      // Remove a consideration item, but do not reduce
      // totalOriginalConsiderationItems as MissingOriginalConsiderationItems
      // is being tested for
      order.parameters.consideration.pop();

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

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
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "MissingOriginalConsiderationItems"
      );
    });
    it("Reverts on invalid submitter when required by order", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
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
        2 // FULL_RESTRICTED
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
        zone,
        value
      );

      expect(executions.length).to.equal(4);

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        )
          .to.be.revertedWithCustomError(
            marketplaceContract,
            `InvalidRestrictedOrder`
          )
          .withArgs(orderHash);
      } else {
        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.reverted;
      }

      const tx = marketplaceContract
        .connect(zone)
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
            fulfiller: zone.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: zone.address,
          },
        ],
        executions
      );
      return receipt;
    });
    it("Reverts on invalid signatures", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
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

      const originalSignature = order.signature;

      // set an invalid V value
      order.signature = order.signature.slice(0, -2) + "01";

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      let expectedRevertReason =
        getCustomRevertSelector("BadSignatureV(uint8)") + "1".padStart(64, "0");

      let tx = await marketplaceContract
        .connect(buyer)
        .populateTransaction.fulfillBasicOrder(basicOrderParameters, {
          value,
        });
      const returnData = await provider.call(tx);
      expect(returnData).to.equal(expectedRevertReason);

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      ).to.be.reverted;

      // construct an invalid signature
      basicOrderParameters.signature = "0x".padEnd(130, "f") + "1c";

      expectedRevertReason = getCustomRevertSelector("InvalidSigner()");

      tx = await marketplaceContract
        .connect(buyer)
        .populateTransaction.fulfillBasicOrder(basicOrderParameters, {
          value,
        });
      expect(provider.call(tx)).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidSigner"
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      ).to.be.reverted;

      basicOrderParameters.signature = originalSignature;

      await withBalanceChecks([order], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          });
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
    it("Reverts on invalid 1271 signature", async () => {
      // Seller mints nft to contract
      const nftId = await mint721(sellerContract);

      // Seller approves marketplace contract to transfer NFT
      await expect(
        sellerContract
          .connect(seller)
          .approveNFT(testERC721.address, marketplaceContract.address)
      )
        .to.emit(testERC721, "ApprovalForAll")
        .withArgs(sellerContract.address, marketplaceContract.address, true);

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await testERC20.mint(buyer.address, tokenAmount);

      // Buyer approves marketplace contract to transfer tokens
      await expect(
        testERC20
          .connect(buyer)
          .approve(marketplaceContract.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getTestItem20(
          tokenAmount.sub(100),
          tokenAmount.sub(100),
          sellerContract.address
        ),
        getTestItem20(40, 40, zone.address),
        getTestItem20(40, 40, owner.address),
      ];

      const { order } = await createOrder(
        sellerContract,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        null,
        zone // wrong signer
      );

      const basicOrderParameters = getBasicOrderParameters(
        2, // ERC20ForERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters)
      ).to.be.revertedWith("BAD SIGNER");
    });
    it("Reverts on invalid contract 1271 signature and contract does not supply a revert reason", async () => {
      await sellerContract.connect(owner).revertWithMessage(false);

      // Seller mints nft to contract
      const nftId = await mint721(sellerContract);

      // Seller approves marketplace contract to transfer NFT
      await expect(
        sellerContract
          .connect(seller)
          .approveNFT(testERC721.address, marketplaceContract.address)
      )
        .to.emit(testERC721, "ApprovalForAll")
        .withArgs(sellerContract.address, marketplaceContract.address, true);

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await testERC20.mint(buyer.address, tokenAmount);

      // Buyer approves marketplace contract to transfer tokens
      await expect(
        testERC20
          .connect(buyer)
          .approve(marketplaceContract.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getTestItem20(
          tokenAmount.sub(100),
          tokenAmount.sub(100),
          sellerContract.address
        ),
        getTestItem20(50, 50, zone.address),
        getTestItem20(50, 50, owner.address),
      ];

      const { order } = await createOrder(
        sellerContract,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        null,
        zone // wrong signer
      );

      const basicOrderParameters = getBasicOrderParameters(
        2, // ERC20ForERC721
        order
      );

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters)
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "BadContractSignature"
        );
      } else {
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters)
        ).to.be.reverted;
      }
    });
    it("Reverts on invalid contract 1271 signature and contract does not return magic value", async () => {
      await sellerContract.connect(owner).setValid(false);

      // Seller mints nft to contract
      const nftId = await mint721(sellerContract);

      // Seller approves marketplace contract to transfer NFT
      await expect(
        sellerContract
          .connect(seller)
          .approveNFT(testERC721.address, marketplaceContract.address)
      )
        .to.emit(testERC721, "ApprovalForAll")
        .withArgs(sellerContract.address, marketplaceContract.address, true);

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await testERC20.mint(buyer.address, tokenAmount);

      // Buyer approves marketplace contract to transfer tokens
      await expect(
        testERC20
          .connect(buyer)
          .approve(marketplaceContract.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getTestItem20(
          tokenAmount.sub(100),
          tokenAmount.sub(100),
          sellerContract.address
        ),
        getTestItem20(50, 50, zone.address),
        getTestItem20(50, 50, owner.address),
      ];

      const { order } = await createOrder(
        sellerContract,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        null,
        seller
      );

      const basicOrderParameters = getBasicOrderParameters(
        2, // ERC20ForERC721
        order
      );

      if (!process.env.REFERENCE) {
        const expectedRevertReason = getCustomRevertSelector(
          "BadContractSignature()"
        );

        const tx = await marketplaceContract
          .connect(buyer)
          .populateTransaction.fulfillBasicOrder(basicOrderParameters);
        const returnData = await provider.call(tx);
        expect(returnData).to.equal(expectedRevertReason);

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters)
        ).to.be.reverted;
      } else {
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters)
        ).to.be.reverted;
      }

      await sellerContract.connect(owner).setValid(true);
    });
    it("Reverts on restricted order where isValidOrder reverts with no data", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        stubZone,
        offer,
        consideration,
        2, // FULL_RESTRICTED,
        [],
        null,
        seller,
        "0x".padEnd(65, "0") + "2"
      );

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        )
          .to.be.revertedWithCustomError(
            marketplaceContract,
            `InvalidRestrictedOrder`
          )
          .withArgs(orderHash);
      } else {
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;
      }

      order.extraData = "0x0102030405";

      if (!process.env.REFERENCE) {
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
            `InvalidRestrictedOrder`
          )
          .withArgs(orderHash);
      } else {
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
        ).to.be.reverted;
      }
    });
    it("Reverts on restricted order where isValidOrder returns non-magic value", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        stubZone,
        offer,
        consideration,
        2, // FULL_RESTRICTED,
        [],
        null,
        seller,
        "0x".padEnd(65, "0") + "3"
      );

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            })
        )
          .to.be.revertedWithCustomError(
            marketplaceContract,
            `InvalidRestrictedOrder`
          )
          .withArgs(orderHash);
      } else {
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            })
        ).to.be.reverted;
      }

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        )
          .to.be.revertedWithCustomError(
            marketplaceContract,
            `InvalidRestrictedOrder`
          )
          .withArgs(orderHash);
      } else {
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;
      }

      order.extraData = "0x01";

      if (!process.env.REFERENCE) {
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
            `InvalidRestrictedOrder`
          )
          .withArgs(orderHash);
      } else {
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
        ).to.be.reverted;
      }
    });
    it("Reverts on missing offer or consideration components", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
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

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      let fulfillments: Fulfillment[] = [
        {
          offerComponents: [],
          considerationComponents: [],
        },
      ];

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, { value })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "OfferAndConsiderationRequiredOnFulfillment"
      );

      fulfillments = [
        {
          offerComponents: [],
          considerationComponents: [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
        },
      ];

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, { value })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "OfferAndConsiderationRequiredOnFulfillment"
      );

      fulfillments = [
        {
          offerComponents: [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
          considerationComponents: [],
        },
      ];

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "OfferAndConsiderationRequiredOnFulfillment"
      );

      fulfillments = defaultBuyNowMirrorFulfillment;

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
    it("Reverts on mismatched offer and consideration components", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
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

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      let fulfillments = [toFulfillment([[0, 0]], [[0, 0]])];

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "MismatchedFulfillmentOfferAndConsiderationComponents"
        )
        .withArgs(0);

      fulfillments = defaultBuyNowMirrorFulfillment;

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
    it("Reverts on mismatched offer and consideration components (branch coverage 1)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [getTestItem721(10, 1, 1, seller.address)];

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [toFulfillment([[0, 0]], [[0, 0]])];

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments)
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "MismatchedFulfillmentOfferAndConsiderationComponents"
      );
    });
    it("Reverts on mismatched offer and consideration components (branch coverage 2)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getTestItem721(10, 1, 1, seller.address, owner.address),
      ];

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [toFulfillment([[0, 0]], [[0, 0]])];

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments)
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "MismatchedFulfillmentOfferAndConsiderationComponents"
      );
    });
    it("Reverts on mismatched offer components", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      const secondNFTId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: secondNFTId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
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
        [
          [
            [0, 0],
            [0, 1],
          ],
          [[1, 0]],
        ],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on mismatched offer components (branch coverage 1)", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      const secondNFTId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: secondNFTId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
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
        [
          [
            [0, 1],
            [0, 0],
          ],
          [[1, 0]],
        ],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on invalid matching offerer (branch coverage 2)", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      const secondNFTId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: secondNFTId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
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

      const offer2 = offer.map((o) => ({ ...o }));

      offer2[0].identifierOrCriteria = secondNFTId;

      const { order: order2 } = await createOrder(
        owner,
        zone,
        offer2,
        consideration,
        0
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [
          [
            [2, 0],
            [0, 1],
          ],
          [[1, 0]],
        ],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder, order2], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on invalid matching conduit key (branch coverage 3)", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      const secondNFTId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: secondNFTId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
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

      const offer2 = offer.map((o) => ({ ...o }));

      offer2[0].identifierOrCriteria = secondNFTId;

      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer2,
        consideration,
        0,
        [],
        null,
        undefined,
        ethers.constants.HashZero,
        conduitKeyOne
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [
          [
            [2, 0],
            [0, 1],
          ],
          [[1, 0]],
        ],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder, order2], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on invalid matching itemType (branch coverage 4)", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      const secondNFTId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: secondNFTId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
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

      const offer2 = offer.map((o) => ({ ...o }));

      offer2[0].identifierOrCriteria = secondNFTId;

      offer2[0].itemType = 1;

      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer2,
        consideration,
        0
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [
          [
            [2, 0],
            [0, 1],
          ],
          [[1, 0]],
        ],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder, order2], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on invalid matching token", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      const secondNFTId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: secondNFTId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
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

      const offer2 = offer.map((o) => ({ ...o }));

      offer2[0].identifierOrCriteria = secondNFTId;

      offer2[0].token = testERC1155.address;

      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer2,
        consideration,
        0
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [
          [
            [2, 0],
            [0, 1],
          ],
          [[1, 0]],
        ],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder, order2], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on invalid matching recipient", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("10"), parseEther("1"), zone.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const consideration2 = consideration.map((o) => ({ ...o }));

      consideration2[0].recipient = owner.address;

      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer,
        consideration2,
        0
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [
          [[1, 0]],
          [
            [2, 0],
            [2, 1],
          ],
        ],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder, order2], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on invalid matching itemType", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("10"), parseEther("1"), zone.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const consideration2 = consideration.map((o) => ({ ...o }));

      consideration2[0].itemType = 1;

      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer,
        consideration2,
        0
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [
          [[1, 0]],
          [
            [2, 0],
            [0, 0],
          ],
        ],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder, order2], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on invalid matching token", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("10"), parseEther("1"), zone.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const consideration2 = consideration.map((o) => ({ ...o }));

      consideration2[0].token = testERC1155.address;

      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer,
        consideration2,
        0
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [
          [[1, 0]],
          [
            [2, 0],
            [0, 0],
          ],
        ],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder, order2], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on invalid matching identifier", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("10"), parseEther("1"), zone.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const consideration2 = consideration.map((o) => ({ ...o }));

      consideration2[0].identifierOrCriteria = nftId;

      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer,
        consideration2,
        0
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [
          [[1, 0]],
          [
            [2, 0],
            [0, 0],
          ],
        ],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder, order2], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on mismatched consideration components", async () => {
      // Seller mints nft
      const nftId = await mint721(seller);

      const secondNFTId = await mint721(seller);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: secondNFTId,
          startAmount: toBN(1),
          endAmount: toBN(1),
        },
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getTestItem20(parseEther("1"), parseEther("1"), zone.address),
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
        [
          [[0, 0]],
          [
            [1, 0],
            [1, 1],
          ],
        ],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on fulfillment component with out-of-range order", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

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
        [
          [[2, 0]],
          [
            [1, 0],
            [1, 1],
          ],
        ],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });

    it("Reverts on fulfillment component with out-of-range initial order on fulfillAvailableOrders", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address
      );

      const offer = [
        getTestItem1155(nftId, amount.div(2), amount.div(2)),
        getTestItem1155(nftId, amount.div(2), amount.div(2)),
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

      const offerComponents = [
        [
          { orderIndex: 5, itemIndex: 0 },
          { orderIndex: 0, itemIndex: 0 },
        ],
      ];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
        [{ orderIndex: 0, itemIndex: 2 }],
      ];

      await expect(
        marketplaceContract
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
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on unmet consideration items", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

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
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "ConsiderationNotMet"
        )
        .withArgs(0, 2, parseEther("1"));
    });
    it("Reverts on fulfillAvailableAdvancedOrders with empty fulfillment component", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

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

      const offerComponents = [[]];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
        [{ orderIndex: 0, itemIndex: 2 }],
      ];

      await expect(
        marketplaceContract
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
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "MissingFulfillmentComponentOnAggregation"
        )
        .withArgs(0);
    });
    it("Reverts on fulfillAvailableAdvancedOrders with out-of-range initial offer order", async () => {
      // Seller mints nft
      const { nftId, amount } = await mint1155(seller, 2);

      // Seller approves marketplace contract to transfer NFT

      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(nftId, amount, amount, undefined),
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

      const offerComponents = [
        [
          { orderIndex: 2, itemIndex: 0 },
          { orderIndex: 0, itemIndex: 0 },
        ],
      ];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
        [{ orderIndex: 0, itemIndex: 2 }],
      ];

      await expect(
        marketplaceContract
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
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on fulfillAvailableAdvancedOrders with out-of-range offer order", async () => {
      // Seller mints nft
      const { nftId, amount } = await mint1155(seller, 2);

      // Seller approves marketplace contract to transfer NFT

      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(nftId, amount, amount, undefined),
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

      const offerComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 2, itemIndex: 0 },
        ],
      ];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
        [{ orderIndex: 0, itemIndex: 2 }],
      ];

      await expect(
        marketplaceContract
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
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on fulfillAvailableAdvancedOrders with mismatched offer components", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId), getTestItem20(1, 1)];

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

      const offerComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 0, itemIndex: 1 },
        ],
      ];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
        [{ orderIndex: 0, itemIndex: 2 }],
      ];

      await expect(
        marketplaceContract
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
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on fulfillAvailableAdvancedOrders with out-of-range consideration order", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

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

      const offerComponents = [[{ orderIndex: 0, itemIndex: 0 }]];
      const considerationComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 2, itemIndex: 1 },
        ],
        [{ orderIndex: 2, itemIndex: 2 }],
      ];

      await expect(
        marketplaceContract
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
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on fulfillAvailableAdvancedOrders with mismatched consideration components", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          identifierOrCriteria: nftId,
          startAmount: toBN(1),
          endAmount: toBN(1),
          recipient: zone.address,
        },
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [[{ orderIndex: 0, itemIndex: 0 }]];
      const considerationComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 0, itemIndex: 1 },
        ],
      ];

      await expect(
        marketplaceContract
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
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });
    it("Reverts on fulfillAvailableAdvancedOrders no available components", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      // first order is expired
      const { order: orderOne, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        "EXPIRED"
      );

      // second order will be cancelled
      const {
        order: orderTwo,
        orderHash: orderHashTwo,
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
        .withArgs(orderHashTwo, seller.address, zone.address);

      // third order will be filled
      const { order: orderThree, orderHash: orderHashThree } =
        await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

      // can fill it
      await withBalanceChecks([orderThree], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillOrder(orderThree, toKey(0), {
            value,
          });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order: orderThree,
            orderHash: orderHashThree,
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
        ],
      ];
      const considerationComponents = [
        [
          { orderIndex: 0, itemIndex: 0 },
          { orderIndex: 1, itemIndex: 0 },
          { orderIndex: 2, itemIndex: 0 },
        ],
        [
          { orderIndex: 0, itemIndex: 1 },
          { orderIndex: 1, itemIndex: 1 },
          { orderIndex: 2, itemIndex: 1 },
        ],
        [
          { orderIndex: 0, itemIndex: 2 },
          { orderIndex: 1, itemIndex: 2 },
          { orderIndex: 2, itemIndex: 2 },
        ],
      ];

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAvailableAdvancedOrders(
            [orderOne, orderTwo, orderThree],
            [],
            offerComponents,
            considerationComponents,
            toKey(0),
            ethers.constants.AddressZero,
            100,
            {
              value: value.mul(3),
            }
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "NoSpecifiedOrdersAvailable"
      );
    });
    it("Reverts on out-of-range criteria resolvers", async () => {
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

      let criteriaResolvers = [
        buildResolver(3, 0, 0, nftId, proofs[nftId.toString()]),
      ];

      const { order, orderHash, value } = await createOrder(
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
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "OrderCriteriaResolverOutOfRange"
        )
        .withArgs(0);

      criteriaResolvers = [
        buildResolver(0, 0, 5, nftId, proofs[nftId.toString()]),
      ];

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
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "OfferCriteriaResolverOutOfRange"
      );

      criteriaResolvers = [
        buildResolver(0, 1, 5, nftId, proofs[nftId.toString()]),
      ];

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
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "ConsiderationCriteriaResolverOutOfRange"
      );

      criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
      ];

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
    if (process.env.REFERENCE) {
      it("Reverts on out-of-range criteria resolver (match)", async () => {
        // Seller mints nfts
        const nftId = await mint721(seller);

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const { root, proofs } = merkleTree([nftId]);

        const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        let criteriaResolvers = [
          buildResolver(3, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        const { mirrorOrder } = await createMirrorAcceptOfferOrder(
          buyer,
          zone,
          order,
          criteriaResolvers
        );

        const fulfillments = [toFulfillment([[1, 0]], [[0, 0]])];

        await expect(
          marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [order, mirrorOrder],
              criteriaResolvers,
              fulfillments,
              ethers.constants.AddressZero,
              {
                value,
              }
            )
        )
          .to.be.revertedWithCustomError(
            marketplaceContract,
            "OrderCriteriaResolverOutOfRange"
          )
          .withArgs(0);

        criteriaResolvers = [
          buildResolver(0, 0, 5, nftId, proofs[nftId.toString()]),
        ];

        await expect(
          marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [order, mirrorOrder],
              criteriaResolvers,
              fulfillments,
              ethers.constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "OfferCriteriaResolverOutOfRange"
        );

        criteriaResolvers = [
          buildResolver(0, 1, 5, nftId, proofs[nftId.toString()]),
        ];

        await expect(
          marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [order, mirrorOrder],
              criteriaResolvers,
              fulfillments,
              ethers.constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "ConsiderationCriteriaResolverOutOfRange"
        );
      });
    }
    it("Reverts on unresolved criteria items", async () => {
      // Seller and buyer both mints nfts
      const nftId = randomBN();
      const secondNFTId = randomBN();

      await testERC721.mint(seller.address, nftId);
      await testERC721.mint(buyer.address, secondNFTId);

      const tokenIds = [nftId, secondNFTId];

      // Seller approves marketplace contract to transfer NFTs
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      // Buyer approves marketplace contract to transfer NFTs
      await set721ApprovalForAll(buyer, marketplaceContract.address, true);

      const { root, proofs } = merkleTree(tokenIds);

      const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

      const consideration = [
        getTestItem721WithCriteria(root, toBN(1), toBN(1), owner.address),
      ];

      let criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
      ];

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
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "UnresolvedConsiderationCriteria"
        )
        .withArgs(0, 0);

      criteriaResolvers = [
        buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
      ];

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
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "UnresolvedOfferCriteria"
        )
        .withArgs(0, 0);

      criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
      ];

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
    if (process.env.REFERENCE) {
      it("Reverts on unresolved criteria items (match)", async () => {
        // Seller mints nfts
        const nftId = randomBN();
        const secondNFTId = randomBN();

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);

        const tokenIds = [nftId, secondNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

        const consideration = [
          getTestItem721WithCriteria(root, toBN(1), toBN(1), owner.address),
        ];

        let criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
          buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        const { mirrorOrder } = await createMirrorAcceptOfferOrder(
          buyer,
          zone,
          order,
          criteriaResolvers
        );

        const fulfillments = [toFulfillment([[1, 0]], [[0, 0]])];

        await expect(
          marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [order, mirrorOrder],
              criteriaResolvers,
              fulfillments,
              ethers.constants.AddressZero,
              {
                value,
              }
            )
        )
          .to.be.revertedWithCustomError(
            marketplaceContract,
            "UnresolvedConsiderationCriteria"
          )
          .withArgs(0, 0);

        criteriaResolvers = [
          buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
        ];

        await expect(
          marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [order, mirrorOrder],
              criteriaResolvers,
              fulfillments,
              ethers.constants.AddressZero,
              {
                value,
              }
            )
        )
          .to.be.revertedWithCustomError(
            marketplaceContract,
            "UnresolvedOfferCriteria"
          )
          .withArgs(0, 0);

        criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
          buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
        ];
      });
    }
    it("Reverts on attempts to resolve criteria for non-criteria item", async () => {
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

      const { proofs } = merkleTree(tokenIds);

      const offer = [
        getTestItem721(nftId, toBN(1), toBN(1), undefined, testERC721.address),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
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
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "CriteriaNotEnabledForItem"
      );
    });
    if (process.env.REFERENCE) {
      it("Reverts on attempts to resolve criteria for non-criteria item (match)", async () => {
        // Seller mints nfts
        const nftId = await mint721(seller);

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const { root, proofs } = merkleTree([nftId]);

        const offer = [
          getTestItem721(root, toBN(1), toBN(1), undefined, testERC721.address),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        const { mirrorOrder } = await createMirrorAcceptOfferOrder(
          buyer,
          zone,
          order,
          criteriaResolvers
        );

        const fulfillments = [toFulfillment([[1, 0]], [[0, 0]])];

        await expect(
          marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [order, mirrorOrder],
              criteriaResolvers,
              fulfillments,
              ethers.constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "CriteriaNotEnabledForItem"
        );
      });
    }
    it("Reverts on offer amount overflow", async () => {
      const { testERC20: testERC20Two } = await fixtureERC20(owner);
      // Buyer mints nfts
      const nftId = await mintAndApprove721(buyer, marketplaceContract.address);

      await testERC20Two.mint(seller.address, ethers.constants.MaxUint256);
      // Seller approves marketplace contract to transfer NFTs
      await testERC20Two
        .connect(seller)
        .approve(marketplaceContract.address, ethers.constants.MaxUint256);

      const offer = [
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          undefined,
          testERC20Two.address
        ),
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          undefined,
          testERC20Two.address
        ),
      ];

      const consideration = [getTestItem721(nftId, 1, 1, seller.address)];

      const offer2 = [getTestItem721(nftId, 1, 1)];
      const consideration2 = [
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          buyer.address,
          testERC20Two.address
        ),
      ];

      const fulfillments = [
        toFulfillment(
          [
            [0, 0],
            [0, 1],
          ],
          [[1, 0]]
        ),
        toFulfillment([[1, 0]], [[0, 0]]),
      ];

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1
      );

      const { order: order2 } = await createOrder(
        buyer,
        zone,
        offer2,
        consideration2,
        1
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchAdvancedOrders(
            [order, order2],
            [],
            fulfillments,
            ethers.constants.AddressZero
          )
      ).to.be.revertedWithPanic(PANIC_CODES.ARITHMETIC_UNDER_OR_OVERFLOW);
    });

    it("Reverts on offer amount overflow when another amount is 0", async () => {
      const { testERC20: testERC20Two } = await fixtureERC20(owner);
      // Buyer mints nfts
      const nftId = await mintAndApprove721(buyer, marketplaceContract.address);

      await testERC20Two.mint(seller.address, ethers.constants.MaxUint256);
      // Seller approves marketplace contract to transfer NFTs
      await testERC20Two
        .connect(seller)
        .approve(marketplaceContract.address, ethers.constants.MaxUint256);

      const offer = [
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          undefined,
          testERC20Two.address
        ),
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          undefined,
          testERC20Two.address
        ),
        getTestItem20(0, 0, undefined, testERC20Two.address),
      ];

      const consideration = [getTestItem721(nftId, 1, 1, seller.address)];

      const offer2 = [getTestItem721(nftId, 1, 1)];
      const consideration2 = [
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          buyer.address,
          testERC20Two.address
        ),
      ];

      const fulfillments = [
        toFulfillment(
          [
            [0, 0],
            [0, 1],
            [0, 2],
          ],
          [[1, 0]]
        ),
        toFulfillment([[1, 0]], [[0, 0]]),
      ];

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1
      );

      const { order: order2 } = await createOrder(
        buyer,
        zone,
        offer2,
        consideration2,
        1
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchAdvancedOrders(
            [order, order2],
            [],
            fulfillments,
            ethers.constants.AddressZero
          )
      ).to.be.revertedWithPanic(PANIC_CODES.ARITHMETIC_UNDER_OR_OVERFLOW);

      // Reverts on out-of-bounds fulfillment orderIndex
      await expect(
        marketplaceContract
          .connect(owner)
          .matchAdvancedOrders(
            [order, order2],
            [],
            [toFulfillment([[3, 0]], [[0, 0]])],
            ethers.constants.AddressZero
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidFulfillmentComponentData"
      );
    });

    it("Reverts on consideration amount overflow", async () => {
      const { testERC20: testERC20Two } = await fixtureERC20(owner);
      // Buyer mints nfts
      const nftId = await mintAndApprove721(buyer, marketplaceContract.address);

      await testERC20Two.mint(seller.address, ethers.constants.MaxUint256);
      // Seller approves marketplace contract to transfer NFTs
      await testERC20Two
        .connect(seller)
        .approve(marketplaceContract.address, ethers.constants.MaxUint256);

      const offer = [getTestItem721(nftId, 1, 1)];

      const consideration = [
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          seller.address,
          testERC20Two.address
        ),
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          seller.address,
          testERC20Two.address
        ),
      ];

      const offer2 = [
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          undefined,
          testERC20Two.address
        ),
      ];
      const consideration2 = [getTestItem721(nftId, 1, 1, buyer.address)];

      const fulfillments = [
        toFulfillment(
          [[1, 0]],
          [
            [0, 0],
            [0, 1],
          ]
        ),
        toFulfillment([[0, 0]], [[1, 0]]),
      ];

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1
      );

      const { order: order2 } = await createOrder(
        buyer,
        zone,
        offer2,
        consideration2,
        1
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchAdvancedOrders(
            [order, order2],
            [],
            fulfillments,
            ethers.constants.AddressZero
          )
      ).to.be.revertedWithPanic(PANIC_CODES.ARITHMETIC_UNDER_OR_OVERFLOW);
    });

    it("Reverts on consideration amount overflow when another amount is 0", async () => {
      const { testERC20: testERC20Two } = await fixtureERC20(owner);
      // Buyer mints nfts
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      await testERC20Two.mint(buyer.address, ethers.constants.MaxUint256);
      // Seller approves marketplace contract to transfer NFTs
      await testERC20Two
        .connect(buyer)
        .approve(marketplaceContract.address, ethers.constants.MaxUint256);

      const offer = [getTestItem721(nftId, 1, 1)];

      const consideration = [
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          seller.address,
          testERC20Two.address
        ),
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          seller.address,
          testERC20Two.address
        ),
        getTestItem20(0, 0, seller.address, testERC20Two.address),
      ];

      const offer2 = [
        getTestItem20(
          ethers.constants.MaxUint256,
          ethers.constants.MaxUint256,
          undefined,
          testERC20Two.address
        ),
      ];
      const consideration2 = [getTestItem721(nftId, 1, 1, buyer.address)];

      const fulfillments = [
        toFulfillment(
          [[1, 0]],
          [
            [0, 0],
            [0, 1],
            [0, 2],
          ]
        ),
        toFulfillment([[0, 0]], [[1, 0]]),
      ];

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1
      );

      const { order: order2 } = await createOrder(
        buyer,
        zone,
        offer2,
        consideration2,
        1
      );

      await expect(
        marketplaceContract.matchAdvancedOrders(
          [order, order2],
          [],
          fulfillments,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWithPanic(PANIC_CODES.ARITHMETIC_UNDER_OR_OVERFLOW);
    });

    it("Reverts on supplying a criteria proof to a collection-wide criteria item", async () => {
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

      const { proofs } = merkleTree(tokenIds);

      const offer = [getTestItem721WithCriteria(0, toBN(1), toBN(1))];

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

      criteriaResolvers[0].criteriaProof = [];

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

    it("Reverts on supplying a criteria proof to a collection-wide criteria item (aggregate)", async () => {
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

      const { proofs } = merkleTree(tokenIds);

      const offer = [getTestItem721WithCriteria(0, toBN(1), toBN(1))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
      ];

      const { order: orderOne, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );

      const { order: orderTwo } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
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

      await expect(
        marketplaceContract
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
          )
      ).to.be.revertedWithCustomError(marketplaceContract, "InvalidProof");
    });

    it("Reverts on invalid criteria proof", async () => {
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

      criteriaResolvers[0].identifier = criteriaResolvers[0].identifier.add(1);

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

      criteriaResolvers[0].identifier = criteriaResolvers[0].identifier.sub(1);

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
    it("Reverts on attempts to transfer >1 ERC721 in single transfer", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [
        getTestItem721(nftId, toBN(2), toBN(2), undefined, testERC721.address),
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

      await expect(
        marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
          value,
        })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidERC721TransferAmount"
        )
        .withArgs(2);
    });
    it("Reverts on attempts to transfer >1 ERC721 in single transfer (basic)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [
        getTestItem721(nftId, toBN(2), toBN(2), undefined, testERC721.address),
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

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidERC721TransferAmount"
        )
        .withArgs(2);
    });
    it("Reverts on attempts to transfer >1 ERC721 in single transfer via conduit", async () => {
      const nftId = await mintAndApprove721(seller, conduitOne.address, 0);

      const offer = [
        getTestItem721(nftId, toBN(2), toBN(2), undefined, testERC721.address),
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
        0, // FULL_OPEN
        [],
        null,
        seller,
        ethers.constants.HashZero,
        conduitKeyOne
      );

      await expect(
        marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
          value,
        })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidERC721TransferAmount"
        )
        .withArgs(2);
    });
  });

  describe("Out of timespan", async () => {
    it("Reverts on orders that have not started (standard)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value, startTime, endTime } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        "NOT_STARTED"
      );

      await expect(
        marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
          value,
        })
      )
        .to.be.revertedWithCustomError(marketplaceContract, "InvalidTime")
        .withArgs(startTime, endTime);
    });
    it("Reverts on orders that have expired (standard)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value, startTime, endTime } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        "EXPIRED"
      );

      await expect(
        marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
          value,
        })
      )
        .to.be.revertedWithCustomError(marketplaceContract, "InvalidTime")
        .withArgs(startTime, endTime);
    });
    it("Reverts on orders that have not started (basic)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value, startTime, endTime } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        "NOT_STARTED"
      );

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      )
        .to.be.revertedWithCustomError(marketplaceContract, "InvalidTime")
        .withArgs(startTime, endTime);
    });
    it("Reverts on orders that have expired (basic)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value, startTime, endTime } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        "EXPIRED"
      );

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      )
        .to.be.revertedWithCustomError(marketplaceContract, "InvalidTime")
        .withArgs(startTime, endTime);
    });
    it("Reverts on orders that have not started (match)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value, startTime, endTime } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        "NOT_STARTED"
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], defaultBuyNowMirrorFulfillment, {
            value,
          })
      )
        .to.be.revertedWithCustomError(marketplaceContract, "InvalidTime")
        .withArgs(startTime, endTime);
    });
    it("Reverts on orders that have expired (match)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value, startTime, endTime } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        "EXPIRED"
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], defaultBuyNowMirrorFulfillment, {
            value,
          })
      )
        .to.be.revertedWithCustomError(marketplaceContract, "InvalidTime")
        .withArgs(startTime, endTime);
    });
  });

  describe("Insufficient amounts and bad items", async () => {
    it("Reverts when no ether is supplied (basic)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
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

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value: toBN(0),
          })
      ).to.be.revertedWithCustomError(marketplaceContract, "InvalidMsgValue");

      await withBalanceChecks([order], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          });
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
    it("Reverts when not enough ether is supplied (basic)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
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

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value: toBN(1),
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InsufficientNativeTokenSupplied"
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value: value.sub(1),
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InsufficientNativeTokenSupplied"
      );

      await withBalanceChecks([order], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          });
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
    it("Reverts when not enough ether is supplied as offer item (match)", async () => {
      // NOTE: this is a ridiculous scenario, buyer is paying the seller's offer
      const offer = [getItemETH(parseEther("10"), parseEther("10"))];

      const consideration = [
        getItemETH(parseEther("1"), parseEther("1"), seller.address),
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

      const fulfillments = defaultBuyNowMirrorFulfillment;

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(4);

      await expect(
        marketplaceContract
          .connect(buyer)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value: toBN(1),
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InsufficientNativeTokenSupplied"
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value: parseEther("9.999999"),
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InsufficientNativeTokenSupplied"
      );

      await marketplaceContract
        .connect(buyer)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value: parseEther("13"),
        });
    });
    it("Reverts when not enough ether is supplied (standard + advanced)", async () => {
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
        0 // FULL_OPEN
      );

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value: toBN(1),
            }
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InsufficientNativeTokenSupplied"
      );

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value: value.sub(1),
            }
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InsufficientNativeTokenSupplied"
      );

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // fulfill with a tiny bit extra to test for returning eth
      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            {
              value: value.add(1),
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
    it("Reverts when not enough ether is supplied (match)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
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

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value: toBN(1),
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InsufficientNativeTokenSupplied"
      );

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value: value.sub(1),
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InsufficientNativeTokenSupplied"
      );

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
    it("Reverts when ether is supplied to a non-payable route (basic)", async () => {
      // Seller mints nft
      const nftId = randomBN();
      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(
          parseEther("1"),
          parseEther("1"),
          marketplaceContract.address
        ),
      ];

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const basicOrderParameters = getBasicOrderParameters(
        2, // ERC20_TO_ERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value: 1,
          })
      )
        .to.be.revertedWithCustomError(marketplaceContract, "InvalidMsgValue")
        .withArgs(1);
    });

    it(`Reverts when ether transfer fails (returndata)${
      process.env.REFERENCE ? " — SKIPPED ON REFERENCE" : ""
    }`, async () => {
      if (process.env.REFERENCE) {
        return;
      }

      const recipient = await (
        await ethers.getContractFactory("ExcessReturnDataRecipient")
      ).deploy();
      const setup = async () => {
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Seller approves marketplace contract to transfer NFT
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        // Buyer approves marketplace contract to transfer tokens

        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), recipient.address),
        ];

        const { order } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );
        return basicOrderParameters;
      };
      let basicOrderParameters = await setup();
      const baseGas = await marketplaceContract
        .connect(buyer)
        .estimateGas.fulfillBasicOrder(basicOrderParameters, {
          value: parseEther("12"),
        });

      // TODO: clean *this* up
      basicOrderParameters = await setup();
      await recipient.setRevertDataSize(1);

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value: parseEther("12"),
            gasLimit: (hre as any).__SOLIDITY_COVERAGE_RUNNING
              ? baseGas.add(35000)
              : baseGas.add(1000),
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "NativeTokenTransferGenericFailure"
      );
    });

    it("Reverts when ether transfer fails (basic)", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await testERC20.mint(buyer.address, tokenAmount);

      // Seller approves marketplace contract to transfer NFT
      await set721ApprovalForAll(seller, marketplaceContract.address, true);

      // Buyer approves marketplace contract to transfer tokens

      await expect(
        testERC20
          .connect(buyer)
          .approve(marketplaceContract.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), conduitOne.address),
      ];

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value: parseEther("12"),
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        )
        .withArgs(conduitOne.address, parseEther("1"));
    });
    it("Reverts when tokens are not approved", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await testERC20.mint(buyer.address, tokenAmount);

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
        getTestItem20(amount.mul(10), amount.mul(10), zone.address),
        getTestItem20(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

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
      ).to.be.reverted; // panic code thrown by underlying 721

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // Buyer approves marketplace contract to transfer tokens
      await expect(
        testERC20
          .connect(buyer)
          .approve(marketplaceContract.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

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
    it("Reverts when 1155 token transfer reverts", async () => {
      // Seller mints nft
      const { nftId, amount } = await mint1155(seller, 10000);

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

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
      ).to.be.revertedWith("NOT_AUTHORIZED");
    });
    it("Reverts when 1155 token transfer reverts (via conduit)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mint1155(seller, 10000);

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
      ];

      const { order, value } = await createOrder(
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
      ).to.be.revertedWith("NOT_AUTHORIZED");
    });

    // Skip this test when testing the reference contract
    if (!process.env.REFERENCE) {
      it("Reverts when 1155 token transfer reverts (via conduit, returndata)", async () => {
        const recipient = await (
          await ethers.getContractFactory("ExcessReturnDataRecipient")
        ).deploy();

        const setup = async () => {
          // seller mints ERC20
          const tokenAmount = minRandom(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves conduit contract to transfer tokens
          await expect(
            testERC20.connect(seller).approve(conduitOne.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(seller.address, conduitOne.address, tokenAmount);

          // Buyer mints nft
          const nftId = randomBN();
          const amount = toBN(randomBN(2));
          await testERC1155.mint(buyer.address, nftId, amount.mul(10000));

          // Buyer approves conduit contract to transfer NFTs
          await expect(
            testERC1155
              .connect(buyer)
              .setApprovalForAll(conduitOne.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(buyer.address, conduitOne.address, true);

          const offer = [getTestItem20(tokenAmount, tokenAmount)];

          const consideration = [
            getTestItem1155(
              nftId,
              amount.mul(10),
              amount.mul(10),
              undefined,
              recipient.address
            ),
          ];

          const { order, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            undefined,
            seller,
            ethers.constants.HashZero,
            conduitKeyOne
          );

          return {
            order,
            value,
          };
        };

        const { order: initialOrder, value } = await setup();
        const baseGas = await marketplaceContract
          .connect(buyer)
          .estimateGas.fulfillAdvancedOrder(
            initialOrder,
            [],
            conduitKeyOne,
            ethers.constants.AddressZero,
            {
              value,
            }
          );

        // TODO: clean *this* up
        const { order } = await setup();
        await recipient.setRevertDataSize(1);
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              conduitKeyOne,
              ethers.constants.AddressZero,
              {
                value,
                gasLimit: baseGas.add(74000),
              }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidCallToConduit"
        );
      });
    }

    it("Reverts when transferred item amount is zero", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await testERC20.mint(buyer.address, tokenAmount);

      // Buyer approves marketplace contract to transfer tokens

      await expect(
        testERC20
          .connect(buyer)
          .approve(marketplaceContract.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

      const offer = [getTestItem1155(nftId, 0, 0, undefined)];

      const consideration = [
        getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
        getTestItem20(amount.mul(10), amount.mul(10), zone.address),
        getTestItem20(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

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
      ).to.be.revertedWithCustomError(marketplaceContract, "MissingItemAmount");
    });
    it("Reverts when aggregating zero-amount items", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // Buyer mints ERC20
      await testERC20.mint(buyer.address, 1000);

      // Buyer approves marketplace contract to transfer tokens

      await expect(
        testERC20.connect(buyer).approve(marketplaceContract.address, 1000)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, marketplaceContract.address, 1000);

      const offer = [getTestItem1155(nftId, 0, 0, undefined)];

      const consideration = [
        getTestItem20(amount.mul(100), amount.mul(100), seller.address),
        getTestItem20(amount.mul(10), amount.mul(10), zone.address),
        getTestItem20(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order: orderOne } = await createOrder(
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

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAvailableOrders(
            [orderOne, orderTwo],
            offerComponents,
            considerationComponents,
            toKey(0),
            100
          )
      ).to.be.revertedWithCustomError(marketplaceContract, "MissingItemAmount");
    });
    it("Reverts when ERC20 tokens return falsey values", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await testERC20.mint(buyer.address, tokenAmount);

      // Buyer approves marketplace contract to transfer tokens

      await expect(
        testERC20
          .connect(buyer)
          .approve(marketplaceContract.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
        getTestItem20(amount.mul(10), amount.mul(10), zone.address),
        getTestItem20(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // block transfers
      await testERC20.blockTransfer(true);

      expect(await testERC20.blocked()).to.be.true;

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
      ).to.be.reverted; // TODO: hardhat can't find error msg on IR pipeline

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      await testERC20.blockTransfer(false);

      expect(await testERC20.blocked()).to.be.false;

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
    it("Works when ERC20 tokens return falsey values", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await testERC20.mint(buyer.address, tokenAmount);

      // Buyer approves marketplace contract to transfer tokens

      await expect(
        testERC20
          .connect(buyer)
          .approve(marketplaceContract.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
        getTestItem20(amount.mul(10), amount.mul(10), zone.address),
        getTestItem20(amount.mul(20), amount.mul(20), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      await testERC20.setNoReturnData(true);

      expect(await testERC20.noReturnData()).to.be.true;

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

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 1, 1)
      );

      await testERC20.setNoReturnData(false);

      expect(await testERC20.noReturnData()).to.be.false;
    });

    it("Reverts when ERC20 tokens return falsey values (via conduit)", async () => {
      // Seller mints nft
      const { nftId, amount } = await mint1155(seller, 10000);

      // Seller approves conduit contract to transfer NFTs
      await set1155ApprovalForAll(seller, conduitOne.address, true);

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await testERC20.mint(buyer.address, tokenAmount);

      // Buyer approves conduit contract to transfer tokens

      await expect(
        testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, conduitOne.address, tokenAmount);

      // Seller approves conduit contract to transfer tokens
      await expect(
        testERC20.connect(seller).approve(conduitOne.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(seller.address, conduitOne.address, tokenAmount);

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
        getTestItem20(amount.mul(10), amount.mul(10), zone.address),
        getTestItem20(amount.mul(20), amount.mul(20), owner.address),
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

      // block transfers
      await testERC20.blockTransfer(true);

      if (!process.env.REFERENCE) {
        const data = await marketplaceContract.interface.encodeFunctionData(
          "fulfillAdvancedOrder",
          [order, [], conduitKeyOne, ethers.constants.AddressZero]
        );

        const fullTx = await buyer.populateTransaction({
          from: buyer.address,
          to: marketplaceContract.address,
          value,
          data,
          gasLimit: 30_000_000,
        });

        const returnedData = await provider.call(fullTx);

        const expectedData = marketplaceContract.interface.encodeErrorResult(
          "BadReturnValueFromERC20OnTransfer",
          [testERC20.address, buyer.address, seller.address, amount.mul(1000)]
        );

        expect(returnedData).to.equal(expectedData);

        let success = false;

        try {
          const tx = await marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              conduitKeyOne,
              ethers.constants.AddressZero,
              {
                value,
              }
            );

          const receipt = await tx.wait();
          success = receipt.status === 1;
        } catch (err) {}

        expect(success).to.be.false;
      } else {
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              conduitKeyOne,
              ethers.constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.reverted;
      }

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect(orderStatus.isValidated).to.equal(false);
      expect(orderStatus.isCancelled).to.equal(false);
      expect(orderStatus.totalFilled.toString()).to.equal("0");
      expect(orderStatus.totalSize.toString()).to.equal("0");

      await testERC20.blockTransfer(false);

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            conduitKeyOne,
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
              fulfillerConduitKey: conduitKeyOne,
            },
          ],
          undefined,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect(orderStatus.isValidated).to.equal(true);
      expect(orderStatus.isCancelled).to.equal(false);
      expect(orderStatus.totalFilled.toString()).to.equal("1");
      expect(orderStatus.totalSize.toString()).to.equal("1");
    });

    it("Reverts when providing non-existent conduit", async () => {
      // Seller mints nft
      const { nftId, amount } = await mint1155(seller, 10000);

      // Seller approves conduit contract to transfer NFTs
      await set1155ApprovalForAll(seller, conduitOne.address, true);

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await testERC20.mint(buyer.address, tokenAmount);

      // Buyer approves conduit contract to transfer tokens
      await expect(
        testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(buyer.address, conduitOne.address, tokenAmount);

      // Seller approves conduit contract to transfer tokens
      await expect(
        testERC20.connect(seller).approve(conduitOne.address, tokenAmount)
      )
        .to.emit(testERC20, "Approval")
        .withArgs(seller.address, conduitOne.address, tokenAmount);

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
        getTestItem20(amount.mul(10), amount.mul(10), zone.address),
        getTestItem20(amount.mul(20), amount.mul(20), owner.address),
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

      const badKey = ethers.constants.HashZero.slice(0, -1) + "2";

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            badKey,
            ethers.constants.AddressZero,
            {
              value,
            }
          )
      ).to.be.revertedWithCustomError(marketplaceContract, "InvalidConduit");

      let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect(orderStatus.isValidated).to.equal(false);
      expect(orderStatus.isCancelled).to.equal(false);
      expect(orderStatus.totalFilled.toString()).to.equal("0");
      expect(orderStatus.totalSize.toString()).to.equal("0");

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            conduitKeyOne,
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
              fulfillerConduitKey: conduitKeyOne,
            },
          ],
          undefined,
          undefined
        );
        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect(orderStatus.isValidated).to.equal(true);
      expect(orderStatus.isCancelled).to.equal(false);
      expect(orderStatus.totalFilled.toString()).to.equal("1");
      expect(orderStatus.totalSize.toString()).to.equal("1");
    });

    it("Reverts when 1155 tokens are not approved", async () => {
      // Seller mints first nft
      const { nftId } = await mint1155(seller);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        seller
      );

      const offer = [
        getTestItem1155(nftId, 0, 0),
        getTestItem1155(secondNftId, secondAmount, secondAmount),
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

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(marketplaceContract, "MissingItemAmount");
    });
    it("Reverts when 1155 tokens are not approved", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        seller
      );

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

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      ).to.be.revertedWith("NOT_AUTHORIZED");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // Seller approves marketplace contract to transfer NFT

      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

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
    it("Reverts when token account with no code is supplied", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem1155(nftId, amount, amount, undefined)];

      const consideration = [
        getTestItem20(
          amount,
          amount,
          seller.address,
          ethers.constants.AddressZero
        ),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

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
      ).to.be.reverted; // TODO: look into the revert reason more thoroughly
      // Transaction reverted: function returned an unexpected amount of data
    });
    it("Reverts when 721 account with no code is supplied", async () => {
      const offer = [getTestItem721(0, 1, 1, undefined, buyer.address)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            { value }
          )
      )
        .to.be.revertedWithCustomError(marketplaceContract, "NoContract")
        .withArgs(buyer.address);
    });
    it("Reverts when 1155 account with no code is supplied", async () => {
      const amount = toBN(randomBN(2));

      const offer = [
        getTestItem1155(0, amount, amount, ethers.constants.AddressZero),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

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
        .to.be.revertedWithCustomError(marketplaceContract, `NoContract`)
        .withArgs(ethers.constants.AddressZero);
    });
    it("Reverts when 1155 account with no code is supplied (via conduit)", async () => {
      const amount = toBN(randomBN(2));

      const offer = [
        getTestItem1155(0, amount, amount, ethers.constants.AddressZero),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
      ];

      const { order, value } = await createOrder(
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
        .to.be.revertedWithCustomError(marketplaceContract, `NoContract`)
        .withArgs(ethers.constants.AddressZero);
    });
    it("Reverts when non-token account is supplied as the token", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem1155(nftId, amount, amount, undefined)];

      const consideration = [
        getTestItem20(
          amount,
          amount,
          seller.address,
          marketplaceContract.address
        ),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

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
          "TokenTransferGenericFailure"
        )
        .withArgs(
          marketplaceContract.address,
          buyer.address,
          seller.address,
          0,
          amount
        );
    });
    it("Reverts when non-token account is supplied as the token fulfilled via conduit", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem1155(nftId, amount, amount, undefined)];

      const consideration = [
        getTestItem20(
          amount,
          amount,
          seller.address,
          marketplaceContract.address
        ),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            conduitKeyOne,
            ethers.constants.AddressZero,
            {
              value,
            }
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "TokenTransferGenericFailure"
        )
        .withArgs(
          marketplaceContract.address,
          buyer.address,
          seller.address,
          0,
          amount
        );
    });
    it("Reverts when non-1155 account is supplied as the token", async () => {
      const amount = toBN(randomBN(2));

      const offer = [
        getTestItem1155(0, amount, amount, marketplaceContract.address),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      if (!process.env.REFERENCE) {
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
            "TokenTransferGenericFailure"
          )
          .withArgs(
            marketplaceContract.address,
            seller.address,
            buyer.address,
            0,
            amount
          );
      } else {
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
        ).to.be.reverted;
      }
    });
    it("Reverts when 1155 token is not approved via conduit", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        seller
      );

      const offer = [
        getTestItem1155(nftId, amount, amount, testERC1155.address),
        getTestItem1155(
          secondNftId,
          secondAmount,
          secondAmount,
          testERC1155.address
        ),
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

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      ).to.be.revertedWith("NOT_AUTHORIZED");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );
    });
    it("Reverts when 1155 token with no code is supplied as the token via conduit", async () => {
      // Seller mints first nft
      const nftId = toBN(randomBN(4));
      const amount = toBN(randomBN(4));

      // Seller mints second nft
      const secondNftId = toBN(randomBN(4));
      const secondAmount = toBN(randomBN(4));

      const offer = [
        getTestItem1155(nftId, amount, amount, ethers.constants.AddressZero),
        getTestItem1155(
          secondNftId,
          secondAmount,
          secondAmount,
          ethers.constants.AddressZero
        ),
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

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          })
      ).to.be.revertedWithCustomError(marketplaceContract, "NoContract");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );
    });
    it("Reverts when non-payable ether recipient is supplied", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), conduitOne.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        )
        .withArgs(conduitOne.address, parseEther("1"));
    });
    it("Reverts when marketplace is an ether recipient for basic orders", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(
          parseEther("1"),
          parseEther("1"),
          marketplaceContract.address
        ),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      const customError = !process.env.REFERENCE
        ? "InvalidMsgValue"
        : "NativeTokenTransferGenericFailure";
      const args = !process.env.REFERENCE
        ? [parseEther("1")]
        : [marketplaceContract.address, parseEther("1")];

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      )
        .to.be.revertedWithCustomError(marketplaceContract, customError)
        .withArgs(...args);
    });
  });

  describe("Basic Order Calldata", () => {
    let calldata: string | undefined;
    let value: BigNumber;

    before(async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
      ];
      let order;
      ({ order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      ));

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      ({ data: calldata } =
        await marketplaceContract.populateTransaction.fulfillBasicOrder(
          basicOrderParameters
        ));
    });

    it("Reverts if BasicOrderParameters has non-default offset", async () => {
      calldata = calldata as string;
      const badData = [calldata.slice(0, 73), "1", calldata.slice(74)].join("");
      expect(badData.length).to.eq(calldata.length);

      await expect(
        buyer.sendTransaction({
          to: marketplaceContract.address,
          data: badData,
          value,
          gasLimit: 100_000,
        })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidBasicOrderParameterEncoding"
      );
    });

    it("Reverts if additionalRecipients has non-default offset", async () => {
      calldata = calldata as string;
      const badData = [calldata.slice(0, 1161), "1", calldata.slice(1162)].join(
        ""
      );

      await expect(
        buyer.sendTransaction({
          to: marketplaceContract.address,
          data: badData,
          value,
          gasLimit: 100_000,
        })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidBasicOrderParameterEncoding"
      );
    });

    it("Reverts if signature has non-default offset", async () => {
      calldata = calldata as string;
      const badData = [calldata.slice(0, 1161), "2", calldata.slice(1162)].join(
        ""
      );

      await expect(
        buyer.sendTransaction({
          to: marketplaceContract.address,
          data: badData,
          value,
          gasLimit: 100_000,
        })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidBasicOrderParameterEncoding"
      );
    });
  });

  describe("Reentrancy", async () => {
    it("Reverts on a reentrant call to fulfillOrder", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), reenterer.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // prepare the reentrant call on the reenterer
      const callData = marketplaceContract.interface.encodeFunctionData(
        "fulfillOrder",
        [order, toKey(0)]
      );
      const tx = await reenterer.prepare(
        marketplaceContract.address,
        0,
        callData
      );
      await tx.wait();

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NoReentrantCalls"
        );
      } else {
        // NoReentrantCalls gets bubbled up in _transferNativeToken, which
        // reverts with NativeTokenTransferGenericFailure.
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        );
      }
    });

    it("Reverts on a reentrant call to fulfillBasicOrder", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
        getItemETH(parseEther("1"), parseEther("1"), reenterer.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const basicOrderParameters = getBasicOrderParameters(
        0, // EthForERC721
        order
      );

      const callData = marketplaceContract.interface.encodeFunctionData(
        "fulfillBasicOrder",
        [basicOrderParameters]
      );
      const tx = await reenterer.prepare(
        marketplaceContract.address,
        value,
        callData
      );
      await tx.wait();

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, { value })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NoReentrantCalls"
        );
      } else {
        // NoReentrantCalls gets bubbled up in _transferNativeToken, which reverts with NativeTokenTransferGenericFailure
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, { value })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        );
      }
    });

    it("Reverts on a reentrant call to fulfillAdvancedOrder", async () => {
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000
      );

      const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

      const consideration = [
        getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
        getItemETH(amount.mul(10), amount.mul(10), reenterer.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1 // PARTIAL_OPEN
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 2; // fill two tenths or one fifth
      order.denominator = 10; // fill two tenths or one fifth

      const callData = marketplaceContract.interface.encodeFunctionData(
        "fulfillAdvancedOrder",
        [order, [], toKey(0), ethers.constants.AddressZero]
      );
      const tx = await reenterer.prepare(
        marketplaceContract.address,
        value,
        callData
      );
      await tx.wait();

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(0),
              ethers.constants.AddressZero,
              { value }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NoReentrantCalls"
        );
      } else {
        // NoReentrantCalls gets bubbled up in _transferNativeToken, which reverts with NativeTokenTransferGenericFailure
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(0),
              ethers.constants.AddressZero,
              { value }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        );
      }
    });

    it("Reverts on a reentrant call to fulfillAvailableOrders", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
        getItemETH(parseEther("1"), parseEther("1"), reenterer.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const offerComponents = [toFulfillmentComponents([[0, 0]])];

      const considerationComponents = [
        [[0, 0]],
        [[0, 1]],
        [[0, 2]],
        [[0, 3]],
      ].map(toFulfillmentComponents);

      const callData = marketplaceContract.interface.encodeFunctionData(
        "fulfillAvailableOrders",
        [[order], offerComponents, considerationComponents, toKey(0), 100]
      );
      const tx = await reenterer.prepare(
        marketplaceContract.address,
        value,
        callData
      );
      await tx.wait();

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [order],
              offerComponents,
              considerationComponents,
              toKey(0),
              100,
              { value }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NoReentrantCalls"
        );
      } else {
        // NoReentrantCalls gets bubbled up in _transferNativeToken, which reverts with NativeTokenTransferGenericFailure
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [order],
              offerComponents,
              considerationComponents,
              toKey(0),
              100,
              { value }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        );
      }
    });

    it("Reverts on a reentrant call to fulfillAvailableAdvancedOrders", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
        getItemETH(parseEther("1"), parseEther("1"), reenterer.address),
      ];

      const { order, value } = await createOrder(
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
        [{ orderIndex: 0, itemIndex: 3 }],
      ];

      const callData = marketplaceContract.interface.encodeFunctionData(
        "fulfillAvailableAdvancedOrders",
        [
          [order],
          [],
          offerComponents,
          considerationComponents,
          toKey(0),
          ethers.constants.AddressZero,
          100,
        ]
      );
      const tx = await reenterer.prepare(
        marketplaceContract.address,
        value,
        callData
      );
      await tx.wait();

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              offerComponents,
              considerationComponents,
              toKey(0),
              ethers.constants.AddressZero,
              100,
              { value }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NoReentrantCalls"
        );
      } else {
        // NoReentrantCalls gets bubbled up in _transferNativeToken, which reverts with NativeTokenTransferGenericFailure
        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              offerComponents,
              considerationComponents,
              toKey(0),
              ethers.constants.AddressZero,
              100,
              { value }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        );
      }
    });

    it("Reverts on a reentrant call to matchOrders", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), reenterer.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = defaultBuyNowMirrorFulfillment;

      const callData = marketplaceContract.interface.encodeFunctionData(
        "matchOrders",
        [[order, mirrorOrder], fulfillments]
      );
      const tx = await reenterer.prepare(
        marketplaceContract.address,
        value,
        callData
      );
      await tx.wait();

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(buyer)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NoReentrantCalls"
        );
      } else {
        // NoReentrantCalls gets bubbled up in _transferNativeToken, which reverts with NativeTokenTransferGenericFailure
        await expect(
          marketplaceContract
            .connect(buyer)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        );
      }
    });

    it("Reverts on a reentrant call to matchAdvancedOrders", async () => {
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
        getItemETH(amount.mul(20), amount.mul(20), reenterer.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        1 // PARTIAL_OPEN
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.numerator = 2; // fill two tenths or one fifth
      order.denominator = 10; // fill two tenths or one fifth

      const mirrorObject = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = defaultBuyNowMirrorFulfillment;

      const callData = marketplaceContract.interface.encodeFunctionData(
        "matchAdvancedOrders",
        [
          [order, mirrorObject.mirrorOrder],
          [],
          fulfillments,
          ethers.constants.AddressZero,
        ]
      );
      const tx = await reenterer.prepare(
        marketplaceContract.address,
        value,
        callData
      );
      await tx.wait();

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(buyer)
            .matchAdvancedOrders(
              [order, mirrorObject.mirrorOrder],
              [],
              fulfillments,
              ethers.constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NoReentrantCalls"
        );
      } else {
        // NoReentrantCalls gets bubbled up in _transferNativeToken, which reverts with NativeTokenTransferGenericFailure
        await expect(
          marketplaceContract
            .connect(buyer)
            .matchAdvancedOrders(
              [order, mirrorObject.mirrorOrder],
              [],
              fulfillments,
              ethers.constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        );
      }
    });

    it("Reverts on a reentrant call to cancel", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
        getItemETH(parseEther("1"), parseEther("1"), reenterer.address),
      ];

      const { order, orderComponents, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      const callData = marketplaceContract.interface.encodeFunctionData(
        "cancel",
        [[orderComponents]]
      );

      const tx = await reenterer.prepare(
        marketplaceContract.address,
        0,
        callData
      );
      await tx.wait();

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(seller)
            .fulfillOrder(order, toKey(0), { value })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NoReentrantCalls"
        );
      } else {
        // NoReentrantCalls gets bubbled up in _transferNativeToken, which reverts with NativeTokenTransferGenericFailure
        await expect(
          marketplaceContract
            .connect(seller)
            .fulfillOrder(order, toKey(0), { value })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        );
      }
    });

    it("Reverts on a reentrant call to validate", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
        getItemETH(parseEther("1"), parseEther("1"), reenterer.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      const callData = marketplaceContract.interface.encodeFunctionData(
        "validate",
        [[order]]
      );

      const tx = await reenterer.prepare(
        marketplaceContract.address,
        0,
        callData
      );
      await tx.wait();

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(seller)
            .fulfillOrder(order, toKey(0), { value })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NoReentrantCalls"
        );
      } else {
        // NoReentrantCalls gets bubbled up in _transferNativeToken,
        // which reverts with NativeTokenTransferGenericFailure
        await expect(
          marketplaceContract
            .connect(seller)
            .fulfillOrder(order, toKey(0), { value })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        );
      }
    });

    it("Reverts on a reentrant call to incrementCounter", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
        getItemETH(parseEther("1"), parseEther("1"), reenterer.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      const callData =
        marketplaceContract.interface.encodeFunctionData("incrementCounter");

      const tx = await reenterer.prepare(
        marketplaceContract.address,
        0,
        callData
      );
      await tx.wait();

      if (!process.env.REFERENCE) {
        await expect(
          marketplaceContract
            .connect(seller)
            .fulfillOrder(order, toKey(0), { value })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NoReentrantCalls"
        );
      } else {
        // NoReentrantCalls gets bubbled up in _transferNativeToken,
        // which reverts with NativeTokenTransferGenericFailure
        await expect(
          marketplaceContract
            .connect(seller)
            .fulfillOrder(order, toKey(0), { value })
        ).to.be.revertedWithCustomError(
          marketplaceContract,
          "NativeTokenTransferGenericFailure"
        );
      }
    });
  });

  describe("ETH offer items", async () => {
    let ethAmount: BigNumber;
    const tokenAmount = minRandom(100);
    let offer: OfferItem[];
    let consideration: ConsiderationItem[];
    let seller: Wallet;
    let buyer: Wallet;

    beforeEach(async () => {
      ethAmount = parseEther("1");
      seller = await getWalletWithEther();
      buyer = await getWalletWithEther();
      zone = new ethers.Wallet(randomHex(32), provider);
      offer = [getItemETH(ethAmount, ethAmount)];
      consideration = [getTestItem20(tokenAmount, tokenAmount, seller.address)];
    });

    it("fulfillOrder reverts if any offer item is ETH", async () => {
      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillOrder(order, toKey(0), { value })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidNativeOfferItem"
      );
    });

    it("fulfillAdvancedOrder reverts if any offer item is ETH", async () => {
      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
            value: ethAmount,
          })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidNativeOfferItem"
      );
    });

    it("fulfillAvailableOrders reverts if any offer item is ETH", async () => {
      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAvailableOrders(
            [order],
            [[{ orderIndex: 0, itemIndex: 0 }]],
            [[{ orderIndex: 0, itemIndex: 0 }]],
            toKey(0),
            100,
            { value: ethAmount }
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidNativeOfferItem"
      );
    });

    it("fulfillAvailableAdvancedOrders reverts if any offer item is ETH", async () => {
      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAvailableAdvancedOrders(
            [order],
            [],
            [[{ orderIndex: 0, itemIndex: 0 }]],
            [[{ orderIndex: 0, itemIndex: 0 }]],
            toKey(0),
            buyer.address,
            100,
            { value: ethAmount }
          )
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidNativeOfferItem"
      );
    });

    it("matchOrders allows fulfilling with native offer items", async () => {
      await mintAndApproveERC20(
        buyer,
        marketplaceContract.address,
        tokenAmount
      );

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );
      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);
      const fulfillments = [
        toFulfillment([[0, 0]], [[1, 0]]),
        toFulfillment([[1, 0]], [[0, 0]]),
      ];

      await marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value: ethAmount,
        });
    });

    it("matchAdvancedOrders allows fulfilling with native offer items", async () => {
      await mintAndApproveERC20(
        buyer,
        marketplaceContract.address,
        tokenAmount
      );

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );
      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);
      const fulfillments = [
        toFulfillment([[0, 0]], [[1, 0]]),
        toFulfillment([[1, 0]], [[0, 0]]),
      ];

      await marketplaceContract
        .connect(owner)
        .matchAdvancedOrders(
          [order, mirrorOrder],
          [],
          fulfillments,
          ethers.constants.AddressZero,
          {
            value: ethAmount,
          }
        );
    });
  });

  describe("Bad contract offerer", async () => {
    let seller: Wallet;
    let buyer: Wallet;
    let offererContract: TestBadContractOfferer;

    beforeEach(async () => {
      seller = await getWalletWithEther();
      buyer = await getWalletWithEther();
      zone = new ethers.Wallet(randomHex(32), provider);

      offererContract = await deployContract<TestBadContractOfferer>(
        "TestBadContractOfferer",
        owner,
        marketplaceContract.address,
        testERC721.address
      );
    });

    it("Fulfillment reverts if contract offerer is an EOA", async () => {
      const offererContract = new ethers.Wallet(randomHex(32), provider);

      // Contract offerer mints nft
      const nftId = await mint721(offererContract);

      await set721ApprovalForAll(seller, offererContract.address);

      const offer = [getTestItem721(nftId) as any];

      const consideration = [
        getItemETH(100, 100, offererContract.address) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            { value }
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Fulfillment does not revert when valid", async () => {
      // Contract offerer mints nft
      const nftId = await mint721(
        offererContract,
        1 // identifier 1: valid
      );

      const offer = [getTestItem721(nftId) as any];

      const consideration = [
        getItemETH(100, 100, offererContract.address) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

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
    it("Fulfillment reverts if contract offerer returns no data", async () => {
      // Contract offerer mints nft
      const nftId = await mint721(
        offererContract,
        2 // identifier 2: returns nothing
      );

      const offer = [getTestItem721(nftId) as any];

      const consideration = [
        getItemETH(100, 100, offererContract.address) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

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
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            { value }
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Fulfillment reverts if contract offerer reverts", async () => {
      // Contract offerer mints nft
      const nftId = await mint721(
        offererContract,
        3 // identifier 3: reverts with IntentionalRevert()
      );

      const offer = [getTestItem721(nftId) as any];

      const consideration = [
        getItemETH(100, 100, offererContract.address) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

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
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            { value }
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Fulfillment reverts if contract offerer returns with garbage data", async () => {
      // Contract offerer mints nft
      const nftId = await mint721(
        offererContract,
        4 // identifier 4: reverts with garbage data)
      );

      const offer = [getTestItem721(nftId) as any];

      const consideration = [
        getItemETH(100, 100, offererContract.address) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

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
          .fulfillAdvancedOrder(
            order,
            [],
            toKey(0),
            ethers.constants.AddressZero,
            { value }
          )
      )
        .to.be.revertedWithCustomError(
          marketplaceContract,
          "InvalidContractOrder"
        )
        .withArgs(orderHash);
    });
    it("Fulfillment does not revert when valid order included with invalid contract offerer order", async () => {
      // Contract offerer mints nft
      const nftId10 = await mint721(
        offererContract,
        10 // identifier 10: returns garbage data
      );
      // Seller mints nft
      const nftId100 = await mintAndApprove721(
        seller,
        marketplaceContract.address,
        100
      );

      const offer = [getTestItem721(nftId10) as any];
      const offer2 = [getTestItem721(nftId100) as any];

      const consideration = [
        getItemETH(100, 100, offererContract.address) as any,
      ];
      const consideration2 = [getItemETH(100, 100, seller.address) as any];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const { order: order2, orderHash: orderHash2 } = await createOrder(
        seller,
        zone,
        offer2,
        consideration2,
        0 // FULL_OPEN
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

      const orderStatus2 = await marketplaceContract.getOrderStatus(orderHash2);

      expect({ ...orderStatus2 }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";

      const offerComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 1, itemIndex: 0 }],
      ];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 1, itemIndex: 0 }],
      ];

      await withBalanceChecks([order2], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAvailableAdvancedOrders(
            [order, order2],
            [],
            offerComponents,
            considerationComponents,
            toKey(0),
            ethers.constants.AddressZero,
            2,
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
              order: order2,
              orderHash: orderHash2,
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

  describe(`Changing chainId`, function () {
    // Note: Run this test last in this file as it hacks changing the hre
    it("Reverts on changed chainId", async () => {
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      // Buyer mints ERC20
      const tokenAmount = minRandom(100);
      await mintAndApproveERC20(
        buyer,
        marketplaceContract.address,
        tokenAmount
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getTestItem20(
          tokenAmount.sub(100),
          tokenAmount.sub(100),
          seller.address
        ),
        getTestItem20(50, 50, zone.address),
        getTestItem20(50, 50, owner.address),
      ];

      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const basicOrderParameters = getBasicOrderParameters(
        2, // ERC20ForERC721
        order
      );

      // Change chainId in-flight to test branch coverage for _deriveDomainSeparator()
      // (hacky way, until https://github.com/NomicFoundation/hardhat/issues/3074 is added)
      const changeChainId = () => {
        const recurse = (obj: any) => {
          for (const [key, value] of Object.entries(obj ?? {})) {
            if (key === "transactions") continue;
            if (key === "chainId") {
              obj[key] = typeof value === "bigint" ? BigInt(1) : 1;
            } else if (typeof value === "object") {
              recurse(obj[key]);
            }
          }
        };
        const hreProvider = hre.network.provider as any;
        recurse(
          hreProvider._wrapped._wrapped._wrapped?._node?._vm ??
            // When running coverage, there was an additional layer of wrapping
            hreProvider._wrapped._wrapped._wrapped._wrapped._node._vm
        );
      };
      changeChainId();

      const expectedRevertReason = getCustomRevertSelector("InvalidSigner()");

      const tx = await marketplaceContract
        .connect(buyer)
        .populateTransaction.fulfillBasicOrder(basicOrderParameters);
      tx.chainId = 1;
      const returnData = await provider.call(tx);
      expect(returnData).to.equal(expectedRevertReason);
    });
  });
});
