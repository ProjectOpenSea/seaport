import { expect } from "chai";
import hre, { ethers, network } from "hardhat";

import { merkleTree } from "./utils/criteria";
import {
  randomHex,
  toKey,
  getBasicOrderParameters,
  getItemETH,
  toBN,
  randomBN,
  toFulfillment,
  buildResolver,
  buildOrderStatus,
  defaultBuyNowMirrorFulfillment,
} from "./utils/encoding";
import { fixtureERC20, seaportFixture } from "./utils/fixtures";
import {
  VERSION,
  getCustomRevertSelector,
  minRandom,
  simulateMatchOrders,
} from "./utils/helpers";
import {
  faucet,
  whileImpersonating,
  getWalletWithEther,
} from "./utils/impersonate";

import type { ConsiderationItem, Fulfillment, OfferItem } from "./utils/types";
import type { BigNumber, Contract, ContractFactory, Wallet } from "ethers";

const { parseEther } = ethers.utils;

describe(`Reverts (Seaport ${VERSION})`, function () {
  const { provider } = ethers;
  let zone: Wallet;
  let marketplaceContract: Contract;
  let testERC20: Contract;
  let testERC721: Contract;
  let testERC1155: Contract;
  let owner: Wallet;
  let withBalanceChecks: Function;
  let EIP1271WalletFactory: ContractFactory;
  let reenterer: Contract;
  let stubZone: Contract;
  let conduitOne: Contract;
  let conduitKeyOne: string;
  let mintAndApproveERC20: Function;
  let getTestItem20: Function;
  let set721ApprovalForAll: Function;
  let mint721: Function;
  let mintAndApprove721: Function;
  let getTestItem721: Function;
  let getTestItem721WithCriteria: Function;
  let set1155ApprovalForAll: Function;
  let mint1155: Function;
  let mintAndApprove1155: Function;
  let getTestItem1155: Function;
  let createOrder: Function;
  let createMirrorBuyNowOrder: Function;
  let createMirrorAcceptOfferOrder: Function;
  let checkExpectedEvents: Function;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    owner = new ethers.Wallet(randomHex(32), provider);

    await faucet(owner.address, provider);

    ({
      EIP1271WalletFactory,
      reenterer,
      conduitKeyOne,
      conduitOne,
      testERC20,
      mintAndApproveERC20,
      getTestItem20,
      testERC721,
      set721ApprovalForAll,
      mint721,
      mintAndApprove721,
      getTestItem721,
      getTestItem721WithCriteria,
      testERC1155,
      set1155ApprovalForAll,
      mint1155,
      mintAndApprove1155,
      getTestItem1155,
      marketplaceContract,
      stubZone,
      createOrder,
      createMirrorBuyNowOrder,
      createMirrorAcceptOfferOrder,
      withBalanceChecks,
      checkExpectedEvents,
    } = await seaportFixture(owner));
  });

  let seller: Wallet;
  let buyer: Wallet;
  let sellerContract: Contract;
  let buyerContract: Contract;

  beforeEach(async () => {
    // Setup basic buyer/seller wallets with ETH
    seller = new ethers.Wallet(randomHex(32), provider);
    buyer = new ethers.Wallet(randomHex(32), provider);
    zone = new ethers.Wallet(randomHex(32), provider);

    sellerContract = await EIP1271WalletFactory.deploy(seller.address);
    buyerContract = await EIP1271WalletFactory.deploy(buyer.address);

    for (const wallet of [seller, buyer, zone, sellerContract, buyerContract]) {
      await faucet(wallet.address, provider);
    }
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
      ).to.be.revertedWith("BadFraction");

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
      ).to.be.revertedWith("BadFraction");

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
      ).to.be.revertedWith("BadFraction");

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
          null,
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
      ).to.be.revertedWith("InexactFraction");

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
          null,
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
      ).to.be.revertedWith("PartialFillsNotEnabledForOrder");

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
          null,
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
          null,
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
      ).to.be.revertedWith(`OrderPartiallyFilled("${orderHash}")`);
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
          null,
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
      ).to.be.revertedWith(`OrderAlreadyFilled("${orderHash}")`);
    });
    it("Reverts on non-zero unused item parameters (identifier set on native, basic)", async () => {
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
      ).to.be.revertedWith(`UnusedItemParameters`);

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
      ).to.be.revertedWith(`UnusedItemParameters`);

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
      ).to.be.revertedWith(`UnusedItemParameters`);
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
      ).to.be.revertedWith(`UnusedItemParameters`);
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
      ).to.be.revertedWith(`UnusedItemParameters`);
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
      ).to.be.revertedWith("MissingOriginalConsiderationItems");
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
        ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
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
            fulfiller: ethers.constants.AddressZero,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: ethers.constants.AddressZero,
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
      expect(provider.call(tx)).to.be.revertedWith("InvalidSigner");

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      ).to.be.reverted;

      basicOrderParameters.signature = originalSignature;

      await withBalanceChecks([order], 0, null, async () => {
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
        ).to.be.revertedWith("BadContractSignature");
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
        ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
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
        ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
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
        ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
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
        ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
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
        ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
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
      ).to.be.revertedWith("OfferAndConsiderationRequiredOnFulfillment");

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
      ).to.be.revertedWith("OfferAndConsiderationRequiredOnFulfillment");

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
      ).to.be.revertedWith("OfferAndConsiderationRequiredOnFulfillment");

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
            fulfiller: ethers.constants.AddressZero,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: ethers.constants.AddressZero,
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
      ).to.be.revertedWith(
        "MismatchedFulfillmentOfferAndConsiderationComponents"
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
            fulfiller: ethers.constants.AddressZero,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: ethers.constants.AddressZero,
          },
        ],
        executions
      );
      return receipt;
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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
    });
    it("Reverts on fulfillment component with out-of-range offer item", async () => {
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
        [[[0, 5]], [[1, 0]]],
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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
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
          [5, 0],
          [0, 0],
        ],
      ];

      const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
    });
    it("Reverts on fulfillment component with out-of-range initial offer item on fulfillAvailableOrders", async () => {
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
          [0, 5],
          [0, 0],
        ],
      ];

      const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

      let success = false;

      try {
        const tx = await marketplaceContract
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

        const receipt = await tx.wait();
        success = receipt.status;
      } catch (err) {}

      expect(success).to.be.false; // TODO: fix out-of-gas
    });
    it("Reverts on fulfillment component with out-of-range subsequent offer item on fulfillAvailableOrders", async () => {
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
          [0, 0],
          [0, 5],
        ],
      ];

      const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
    });
    it("Reverts on fulfillment component with out-of-range consideration item", async () => {
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
        [[[0, 0]], [[1, 5]]],
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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
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
      ).to.be.revertedWith(
        `ConsiderationNotMet(0, 2, ${parseEther("1").toString()}`
      );
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

      const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

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
      ).to.be.revertedWith("MissingFulfillmentComponentOnAggregation(0)");
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
          [2, 0],
          [0, 0],
        ],
      ];

      const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
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
          [0, 0],
          [2, 0],
        ],
      ];

      const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
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
          [0, 0],
          [0, 1],
        ],
      ];

      const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
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

      const offerComponents = [[[0, 0]]];

      const considerationComponents = [
        [
          [0, 0],
          [2, 1],
        ],
        [[2, 2]],
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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
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

      const offerComponents = [[[0, 0]]];

      const considerationComponents = [
        [
          [0, 0],
          [0, 1],
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
      ).to.be.revertedWith("InvalidFulfillmentComponentData");
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
      await withBalanceChecks([orderThree], 0, null, async () => {
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
          [0, 0],
          [1, 0],
          [2, 0],
        ],
      ];

      const considerationComponents = [
        [
          [0, 0],
          [1, 0],
          [2, 0],
        ],
        [
          [0, 1],
          [1, 1],
          [2, 1],
        ],
        [
          [0, 2],
          [1, 2],
          [2, 2],
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
      ).to.be.revertedWith("NoSpecifiedOrdersAvailable");
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
      ).to.be.revertedWith("OrderCriteriaResolverOutOfRange");

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
      ).to.be.revertedWith("OfferCriteriaResolverOutOfRange");

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
      ).to.be.revertedWith("ConsiderationCriteriaResolverOutOfRange");

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
          null,
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
              {
                value,
              }
            )
        ).to.be.revertedWith("OrderCriteriaResolverOutOfRange");

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
              {
                value,
              }
            )
        ).to.be.revertedWith("OfferCriteriaResolverOutOfRange");

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
              {
                value,
              }
            )
        ).to.be.revertedWith("ConsiderationCriteriaResolverOutOfRange");
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
      ).to.be.revertedWith("UnresolvedConsiderationCriteria");

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
      ).to.be.revertedWith("UnresolvedOfferCriteria");

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
          null,
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
              {
                value,
              }
            )
        ).to.be.revertedWith("UnresolvedConsiderationCriteria");

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
              {
                value,
              }
            )
        ).to.be.revertedWith("UnresolvedOfferCriteria");

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
      ).to.be.revertedWith("CriteriaNotEnabledForItem");
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
              {
                value,
              }
            )
        ).to.be.revertedWith("CriteriaNotEnabledForItem");
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
          .matchAdvancedOrders([order, order2], [], fulfillments)
      ).to.be.revertedWith(
        "panic code 0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
      );
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
          .matchAdvancedOrders([order, order2], [], fulfillments)
      ).to.be.revertedWith(
        "panic code 0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
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
          .matchAdvancedOrders([order, order2], [], fulfillments)
      ).to.be.revertedWith(
        "panic code 0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
      );
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
          fulfillments
        )
      ).to.be.revertedWith(
        "panic code 0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
      );
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
      ).to.be.revertedWith("InvalidProof");

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
          null,
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
      ).to.be.revertedWith("InvalidERC721TransferAmount");
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
      ).to.be.revertedWith("InvalidERC721TransferAmount");
    });
    it("Reverts on attempts to transfer >1 ERC721 in single transfer via conduit", async () => {
      const nftId = await mintAndApprove721(seller, conduitOne.address, true);

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
      ).to.be.revertedWith("InvalidERC721TransferAmount");
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

      const { order, value } = await createOrder(
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
      ).to.be.revertedWith("InvalidTime");
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

      const { order, value } = await createOrder(
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
      ).to.be.revertedWith("InvalidTime");
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

      const { order, value } = await createOrder(
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
      ).to.be.revertedWith("InvalidTime");
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

      const { order, value } = await createOrder(
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
      ).to.be.revertedWith("InvalidTime");
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

      const { order, value } = await createOrder(
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
      ).to.be.revertedWith("InvalidTime");
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

      const { order, value } = await createOrder(
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
      ).to.be.revertedWith("InvalidTime");
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
      ).to.be.revertedWith("InvalidMsgValue");

      await withBalanceChecks([order], 0, null, async () => {
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
      ).to.be.revertedWith("InsufficientEtherSupplied");

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value: value.sub(1),
          })
      ).to.be.revertedWith("InsufficientEtherSupplied");

      await withBalanceChecks([order], 0, null, async () => {
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
      ).to.be.revertedWith("InsufficientEtherSupplied");

      await expect(
        marketplaceContract
          .connect(buyer)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value: parseEther("9.999999"),
          })
      ).to.be.revertedWith("InsufficientEtherSupplied");

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
      ).to.be.revertedWith("InsufficientEtherSupplied");

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
      ).to.be.revertedWith("InsufficientEtherSupplied");

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
          null,
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
      ).to.be.revertedWith("InsufficientEtherSupplied");

      await expect(
        marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value: value.sub(1),
          })
      ).to.be.revertedWith("InsufficientEtherSupplied");

      await whileImpersonating(owner.address, provider, async () => {
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
              fulfiller: ethers.constants.AddressZero,
            },
            {
              order: mirrorOrder,
              orderHash: mirrorOrderHash,
              fulfiller: ethers.constants.AddressZero,
            },
          ],
          executions
        );
        return receipt;
      });
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
      ).to.be.revertedWith("InvalidMsgValue(1)");
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
      ).to.be.revertedWith("EtherTransferGenericFailure");
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
        0, // EthForERC721
        order
      );

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value: parseEther("12"),
          })
      ).to.be.revertedWith(
        `EtherTransferGenericFailure("${
          marketplaceContract.address
        }", ${parseEther("1").toString()})`
      );
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
          null,
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
      ).to.be.revertedWith(`NOT_AUTHORIZED`);
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
            null,
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
        ).to.be.revertedWith("InvalidCallToConduit");
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
      ).to.be.revertedWith("MissingItemAmount");
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
          null,
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
          null,
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
        ).to.be.revertedWith(
          `BadReturnValueFromERC20OnTransfer("${testERC20.address}", "${
            buyer.address
          }", "${seller.address}", ${amount.mul(1000).toString()})`
        );
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

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

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
          null,
          []
        );

        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 1, 1)
      );
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
      ).to.be.revertedWith("InvalidConduit");

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
          null,
          null
        );
        return receipt;
      });

      orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(true, false, 1, 1)
      );
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
      ).to.be.revertedWith("MissingItemAmount");
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
            fulfiller: ethers.constants.AddressZero,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: ethers.constants.AddressZero,
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
      ).to.be.revertedWith(`NoContract("${buyer.address}")`);
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
      ).to.be.revertedWith(`NoContract("${ethers.constants.AddressZero}")`);
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
      ).to.be.revertedWith(`NoContract("${ethers.constants.AddressZero}")`);
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
      ).to.be.revertedWith(
        `TokenTransferGenericFailure("${marketplaceContract.address}", "${
          buyer.address
        }", "${seller.address}", 0, ${amount.toString()})`
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
      ).to.be.revertedWith(
        `TokenTransferGenericFailure("${marketplaceContract.address}", "${
          buyer.address
        }", "${seller.address}", 0, ${amount.toString()})`
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
        ).to.be.revertedWith(
          `TokenTransferGenericFailure("${marketplaceContract.address}", "${
            seller.address
          }", "${buyer.address}", 0, ${amount.toString()})`
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
      ).to.be.revertedWith("NoContract");

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

      await expect(
        marketplaceContract
          .connect(buyer)
          .fulfillBasicOrder(basicOrderParameters, {
            value,
          })
      ).to.be.revertedWith(
        `EtherTransferGenericFailure("${
          marketplaceContract.address
        }", ${parseEther("1").toString()})`
      );
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
        })
      ).to.be.revertedWith("InvalidBasicOrderParameterEncoding");
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
        })
      ).to.be.revertedWith("InvalidBasicOrderParameterEncoding");
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
        })
      ).to.be.revertedWith("InvalidBasicOrderParameterEncoding");
    });
  });

  describe("Reentrancy", async () => {
    it("Reverts on a reentrant call", async () => {
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
        ).to.be.revertedWith("NoReentrantCalls");
      } else {
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;
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

    before(async () => {
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
      ).to.be.revertedWith("InvalidNativeOfferItem");
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
      ).to.be.revertedWith("InvalidNativeOfferItem");
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
            [[[0, 0]]],
            [[[0, 0]]],
            toKey(0),
            100,
            { value: ethAmount }
          )
      ).to.be.revertedWith("InvalidNativeOfferItem");
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
            [[[0, 0]]],
            [[[0, 0]]],
            toKey(0),
            buyer.address,
            100,
            { value: ethAmount }
          )
      ).to.be.revertedWith("InvalidNativeOfferItem");
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
        .matchAdvancedOrders([order, mirrorOrder], [], fulfillments, {
          value: ethAmount,
        });
    });
  });
});
