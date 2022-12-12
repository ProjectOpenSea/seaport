import { expect } from "chai";
import { ethers, network } from "hardhat";

import { deployContract } from "./utils/contracts";
import {
  convertSignatureToEIP2098,
  defaultAcceptOfferMirrorFulfillment,
  defaultBuyNowMirrorFulfillment,
  getBasicOrderExecutions,
  getBasicOrderParameters,
  getItemETH,
  random128,
  randomBN,
  randomHex,
  toAddress,
  toBN,
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
  EIP1271Wallet,
  EIP1271Wallet__factory,
  TestERC20,
  TestERC721,
  TestPostExecution,
  TestZone,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { Wallet } from "ethers";

const { parseEther, keccak256 } = ethers.utils;

/**
 * Buy now or accept offer for a single ERC721 or ERC1155 in exchange for
 * ETH, WETH or ERC20
 */
describe(`Basic buy now or accept offer flows (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let conduitKeyOne: string;
  let conduitOne: ConduitInterface;
  let EIP1271WalletFactory: EIP1271Wallet__factory;
  let marketplaceContract: ConsiderationInterface;
  let stubZone: TestZone;
  let postExecutionZone: TestPostExecution;
  let testERC20: TestERC20;
  let testERC721: TestERC721;

  let checkExpectedEvents: SeaportFixtures["checkExpectedEvents"];
  let createMirrorAcceptOfferOrder: SeaportFixtures["createMirrorAcceptOfferOrder"];
  let createMirrorBuyNowOrder: SeaportFixtures["createMirrorBuyNowOrder"];
  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem1155: SeaportFixtures["getTestItem1155"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let mint721: SeaportFixtures["mint721"];
  let mintAndApprove1155: SeaportFixtures["mintAndApprove1155"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];
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
      marketplaceContract,
      mint721,
      mintAndApprove1155,
      mintAndApprove721,
      mintAndApproveERC20,
      set721ApprovalForAll,
      stubZone,
      postExecutionZone,
      testERC20,
      testERC721,
      withBalanceChecks,
    } = await seaportFixture(owner));
  });

  let seller: Wallet;
  let buyer: Wallet;
  let zone: Wallet;

  let sellerContract: EIP1271Wallet;
  let buyerContract: EIP1271Wallet;

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

  describe("A single ERC721 is to be transferred", async () => {
    describe("[Buy now] User fulfills a sell order for a single ERC721", async () => {
      it("ERC721 <=> ETH (standard)", async () => {
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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0), {
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
      it("ERC721 <=> ETH (standard via conduit)", async () => {
        const nftId = await mintAndApprove721(seller, conduitOne.address);

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
          0, // FULL_OPEN
          [],
          null,
          seller,
          ethers.constants.HashZero,
          conduitKeyOne
        );

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC721 <=> ETH (standard with tip)", async () => {
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

        // Add a tip
        order.parameters.consideration.push(
          getItemETH(parseEther("1"), parseEther("1"), owner.address)
        );

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0), {
              value: value.add(parseEther("1")),
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
      it("ERC721 <=> ETH (standard with restricted order)", async () => {
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
          2 // FULL_RESTRICTED
        );

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC721 <=> ETH (standard with restricted order and extra data)", async () => {
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
          2 // FULL_RESTRICTED
        );

        order.extraData = "0x1234";

        await withBalanceChecks([order], 0, undefined, async () => {
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
      it("ERC721 <=> ETH (standard with restricted order, specified recipient and extra data)", async () => {
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
          stubZone,
          offer,
          consideration,
          2 // FULL_RESTRICTED
        );

        order.extraData = "0x1234";

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(order, [], toKey(0), owner.address, {
              value,
            });
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
      it("ERC721 <=> ETH (basic)", async () => {
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
      it("ERC721 <=> ETH (basic, minimal and listed off-chain)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [getItemETH(toBN(1), toBN(1), seller.address)];

        const { order, orderHash, value } = await createOrder(
          seller,
          ethers.constants.AddressZero,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          ethers.constants.HashZero,
          ethers.constants.HashZero,
          true // extraCheap
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
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
      it("ERC721 <=> ETH (basic, minimal and verified on-chain)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [getItemETH(toBN(1), toBN(1), seller.address)];

        const { order, orderHash, value } = await createOrder(
          seller,
          ethers.constants.AddressZero,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          ethers.constants.HashZero,
          ethers.constants.HashZero,
          true // extraCheap
        );

        // Validate the order from any account
        const tx = await marketplaceContract.connect(owner).validate([order]);

        const receipt = await tx.wait();

        expect(receipt.events?.length).to.equal(1);

        const event = receipt.events && receipt.events[0];

        expect(event?.event).to.equal("OrderValidated");

        expect(event?.args?.orderHash).to.equal(orderHash);

        const parameters = event && event.args && event.args.orderParameters;

        expect(parameters.offerer).to.equal(order.parameters.offerer);
        expect(parameters.zone).to.equal(order.parameters.zone);
        expect(parameters.orderType).to.equal(order.parameters.orderType);
        expect(parameters.startTime).to.equal(order.parameters.startTime);
        expect(parameters.endTime).to.equal(order.parameters.endTime);
        expect(parameters.zoneHash).to.equal(order.parameters.zoneHash);
        expect(parameters.salt).to.equal(order.parameters.salt);
        expect(parameters.conduitKey).to.equal(order.parameters.conduitKey);
        expect(parameters.totalOriginalConsiderationItems).to.equal(
          order.parameters.totalOriginalConsiderationItems
        );
        expect(parameters.totalOriginalConsiderationItems).to.equal(
          parameters.consideration.length
        );

        expect(parameters.offer.length).to.equal(order.parameters.offer.length);
        expect(parameters.consideration.length).to.equal(
          order.parameters.consideration.length
        );

        for (let i = 0; i < parameters.offer.length; i++) {
          const eventOffer = parameters.offer[i];
          const suppliedOffer = order.parameters.offer[i];
          expect(eventOffer.itemType).to.equal(suppliedOffer.itemType);
          expect(eventOffer.token).to.equal(suppliedOffer.token);
          expect(eventOffer.identifierOrCriteria).to.equal(
            suppliedOffer.identifierOrCriteria
          );
          expect(eventOffer.startAmount).to.equal(suppliedOffer.startAmount);
          expect(eventOffer.endAmount).to.equal(suppliedOffer.endAmount);
        }

        for (let i = 0; i < parameters.consideration.length; i++) {
          const eventConsideration = parameters.consideration[i];
          const suppliedConsideration = order.parameters.consideration[i];
          expect(eventConsideration.itemType).to.equal(
            suppliedConsideration.itemType
          );
          expect(eventConsideration.token).to.equal(
            suppliedConsideration.token
          );
          expect(eventConsideration.identifierOrCriteria).to.equal(
            suppliedConsideration.identifierOrCriteria
          );
          expect(eventConsideration.startAmount).to.equal(
            suppliedConsideration.startAmount
          );
          expect(eventConsideration.endAmount).to.equal(
            suppliedConsideration.endAmount
          );
          expect(eventConsideration.recipient).to.equal(
            suppliedConsideration.recipient
          );
        }

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
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
      it("ERC721 <=> ETH (standard, minimal and listed off-chain)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [getItemETH(toBN(1), toBN(1), seller.address)];

        const { order, orderHash, value } = await createOrder(
          seller,
          ethers.constants.AddressZero,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          ethers.constants.HashZero,
          ethers.constants.HashZero,
          true // extraCheap
        );

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC721 <=> ETH (standard, minimal and verified on-chain)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(toBN(1), toBN(1), ethers.constants.AddressZero),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          ethers.constants.AddressZero,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          ethers.constants.HashZero,
          ethers.constants.HashZero,
          true // extraCheap
        );

        // Validate the order from any account
        const tx = await marketplaceContract.connect(owner).validate([order]);

        const receipt = await tx.wait();

        expect(receipt.events?.length).to.equal(1);

        const event = receipt.events && receipt.events[0];

        expect(event?.event).to.equal("OrderValidated");

        expect(event?.args?.orderHash).to.equal(orderHash);

        const parameters = event && event.args && event.args.orderParameters;

        expect(parameters.offerer).to.equal(order.parameters.offerer);
        expect(parameters.zone).to.equal(order.parameters.zone);
        expect(parameters.orderType).to.equal(order.parameters.orderType);
        expect(parameters.startTime).to.equal(order.parameters.startTime);
        expect(parameters.endTime).to.equal(order.parameters.endTime);
        expect(parameters.zoneHash).to.equal(order.parameters.zoneHash);
        expect(parameters.salt).to.equal(order.parameters.salt);
        expect(parameters.conduitKey).to.equal(order.parameters.conduitKey);
        expect(parameters.totalOriginalConsiderationItems).to.equal(
          order.parameters.totalOriginalConsiderationItems
        );
        expect(parameters.totalOriginalConsiderationItems).to.equal(
          parameters.consideration.length
        );

        expect(parameters.offer.length).to.equal(order.parameters.offer.length);
        expect(parameters.consideration.length).to.equal(
          order.parameters.consideration.length
        );

        for (let i = 0; i < parameters.offer.length; i++) {
          const eventOffer = parameters.offer[i];
          const suppliedOffer = order.parameters.offer[i];
          expect(eventOffer.itemType).to.equal(suppliedOffer.itemType);
          expect(eventOffer.token).to.equal(suppliedOffer.token);
          expect(eventOffer.identifierOrCriteria).to.equal(
            suppliedOffer.identifierOrCriteria
          );
          expect(eventOffer.startAmount).to.equal(suppliedOffer.startAmount);
          expect(eventOffer.endAmount).to.equal(suppliedOffer.endAmount);
        }

        for (let i = 0; i < parameters.consideration.length; i++) {
          const eventConsideration = parameters.consideration[i];
          const suppliedConsideration = order.parameters.consideration[i];
          expect(eventConsideration.itemType).to.equal(
            suppliedConsideration.itemType
          );
          expect(eventConsideration.token).to.equal(
            suppliedConsideration.token
          );
          expect(eventConsideration.identifierOrCriteria).to.equal(
            suppliedConsideration.identifierOrCriteria
          );
          expect(eventConsideration.startAmount).to.equal(
            suppliedConsideration.startAmount
          );
          expect(eventConsideration.endAmount).to.equal(
            suppliedConsideration.endAmount
          );
          expect(eventConsideration.recipient).to.equal(
            suppliedConsideration.recipient
          );
        }

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC721 <=> ETH (advanced, minimal and listed off-chain)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [getItemETH(toBN(1), toBN(1), seller.address)];

        const { order, orderHash, value } = await createOrder(
          seller,
          ethers.constants.AddressZero,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          ethers.constants.HashZero,
          ethers.constants.HashZero,
          true // extraCheap
        );

        await withBalanceChecks([order], 0, undefined, async () => {
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
      it("ERC721 <=> ETH (advanced, minimal and verified on-chain)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [getItemETH(toBN(1), toBN(1), seller.address)];

        const { order, orderHash, value } = await createOrder(
          seller,
          ethers.constants.AddressZero,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          ethers.constants.HashZero,
          ethers.constants.HashZero,
          true // extraCheap
        );

        // Validate the order from any account
        const tx = await marketplaceContract.connect(owner).validate([order]);

        const receipt = await tx.wait();

        expect(receipt.events?.length).to.equal(1);

        const event = receipt.events && receipt.events[0];

        expect(event?.event).to.equal("OrderValidated");

        expect(event?.args?.orderHash).to.equal(orderHash);

        const parameters = event && event.args && event.args.orderParameters;

        expect(parameters.offerer).to.equal(order.parameters.offerer);
        expect(parameters.zone).to.equal(order.parameters.zone);
        expect(parameters.orderType).to.equal(order.parameters.orderType);
        expect(parameters.startTime).to.equal(order.parameters.startTime);
        expect(parameters.endTime).to.equal(order.parameters.endTime);
        expect(parameters.zoneHash).to.equal(order.parameters.zoneHash);
        expect(parameters.salt).to.equal(order.parameters.salt);
        expect(parameters.conduitKey).to.equal(order.parameters.conduitKey);
        expect(parameters.totalOriginalConsiderationItems).to.equal(
          order.parameters.totalOriginalConsiderationItems
        );
        expect(parameters.totalOriginalConsiderationItems).to.equal(
          parameters.consideration.length
        );

        expect(parameters.offer.length).to.equal(order.parameters.offer.length);
        expect(parameters.consideration.length).to.equal(
          order.parameters.consideration.length
        );

        for (let i = 0; i < parameters.offer.length; i++) {
          const eventOffer = parameters.offer[i];
          const suppliedOffer = order.parameters.offer[i];
          expect(eventOffer.itemType).to.equal(suppliedOffer.itemType);
          expect(eventOffer.token).to.equal(suppliedOffer.token);
          expect(eventOffer.identifierOrCriteria).to.equal(
            suppliedOffer.identifierOrCriteria
          );
          expect(eventOffer.startAmount).to.equal(suppliedOffer.startAmount);
          expect(eventOffer.endAmount).to.equal(suppliedOffer.endAmount);
        }

        for (let i = 0; i < parameters.consideration.length; i++) {
          const eventConsideration = parameters.consideration[i];
          const suppliedConsideration = order.parameters.consideration[i];
          expect(eventConsideration.itemType).to.equal(
            suppliedConsideration.itemType
          );
          expect(eventConsideration.token).to.equal(
            suppliedConsideration.token
          );
          expect(eventConsideration.identifierOrCriteria).to.equal(
            suppliedConsideration.identifierOrCriteria
          );
          expect(eventConsideration.startAmount).to.equal(
            suppliedConsideration.startAmount
          );
          expect(eventConsideration.endAmount).to.equal(
            suppliedConsideration.endAmount
          );
          expect(eventConsideration.recipient).to.equal(
            suppliedConsideration.recipient
          );
        }

        await withBalanceChecks([order], 0, undefined, async () => {
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
      it("ERC721 <=> ETH (basic with tips)", async () => {
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
          order,
          false,
          [
            {
              amount: parseEther("2"),
              recipient: `0x0000000000000000000000000000000000000001`,
            },
            {
              amount: parseEther("3"),
              recipient: `0x0000000000000000000000000000000000000002`,
            },
            {
              amount: parseEther("4"),
              recipient: `0x0000000000000000000000000000000000000003`,
            },
          ]
        );

        order.parameters.consideration.push(
          getItemETH(
            parseEther("2"),
            parseEther("2"),
            "0x0000000000000000000000000000000000000001"
          )
        );

        order.parameters.consideration.push(
          getItemETH(
            parseEther("3"),
            parseEther("3"),
            "0x0000000000000000000000000000000000000002"
          )
        );

        order.parameters.consideration.push(
          getItemETH(
            parseEther("4"),
            parseEther("4"),
            "0x0000000000000000000000000000000000000003"
          )
        );

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value: value.add(parseEther("9")),
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
      it("ERC721 <=> ETH (basic via conduit)", async () => {
        const nftId = await mintAndApprove721(seller, conduitOne.address);

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
          0, // FULL_OPEN
          [],
          null,
          seller,
          ethers.constants.HashZero,
          conduitKeyOne
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
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
      it("ERC721 <=> ETH (basic with restricted order)", async () => {
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
          2 // FULL_RESTRICTED
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
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
      it("ERC721 <=> ETH (basic with partial restricted order)", async () => {
        // Seller mints nft
        const nftId = randomBN();
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await expect(
          testERC721
            .connect(seller)
            .setApprovalForAll(marketplaceContract.address, true)
        )
          .to.emit(testERC721, "ApprovalForAll")
          .withArgs(seller.address, marketplaceContract.address, true);

        const offer = [getTestItem721(nftId)];

        const consideration = [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0), // ignored for ETH
            startAmount: ethers.utils.parseEther("10"),
            endAmount: ethers.utils.parseEther("10"),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0), // ignored for ETH
            startAmount: ethers.utils.parseEther("1"),
            endAmount: ethers.utils.parseEther("1"),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0), // ignored for ETH
            startAmount: ethers.utils.parseEther("1"),
            endAmount: ethers.utils.parseEther("1"),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          stubZone,
          offer,
          consideration,
          3 // PARTIAL_RESTRICTED
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, { value });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            { order, orderHash, fulfiller: buyer.address },
          ]);

          return receipt;
        });
      });

      it("ERC721 <=> ETH (basic, already validated)", async () => {
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

        // Validate the order from any account
        const tx = await marketplaceContract.connect(owner).validate([order]);

        const receipt = await tx.wait();

        expect(receipt.events?.length).to.equal(1);

        const event = receipt.events && receipt.events[0];

        expect(event?.event).to.equal("OrderValidated");

        expect(event?.args?.orderHash).to.equal(orderHash);

        const parameters = event && event.args && event.args.orderParameters;

        expect(parameters.offerer).to.equal(order.parameters.offerer);
        expect(parameters.zone).to.equal(order.parameters.zone);
        expect(parameters.orderType).to.equal(order.parameters.orderType);
        expect(parameters.startTime).to.equal(order.parameters.startTime);
        expect(parameters.endTime).to.equal(order.parameters.endTime);
        expect(parameters.zoneHash).to.equal(order.parameters.zoneHash);
        expect(parameters.salt).to.equal(order.parameters.salt);
        expect(parameters.conduitKey).to.equal(order.parameters.conduitKey);
        expect(parameters.totalOriginalConsiderationItems).to.equal(
          order.parameters.totalOriginalConsiderationItems
        );
        expect(parameters.totalOriginalConsiderationItems).to.equal(
          parameters.consideration.length
        );

        expect(parameters.offer.length).to.equal(order.parameters.offer.length);
        expect(parameters.consideration.length).to.equal(
          order.parameters.consideration.length
        );

        for (let i = 0; i < parameters.offer.length; i++) {
          const eventOffer = parameters.offer[i];
          const suppliedOffer = order.parameters.offer[i];
          expect(eventOffer.itemType).to.equal(suppliedOffer.itemType);
          expect(eventOffer.token).to.equal(suppliedOffer.token);
          expect(eventOffer.identifierOrCriteria).to.equal(
            suppliedOffer.identifierOrCriteria
          );
          expect(eventOffer.startAmount).to.equal(suppliedOffer.startAmount);
          expect(eventOffer.endAmount).to.equal(suppliedOffer.endAmount);
        }

        for (let i = 0; i < parameters.consideration.length; i++) {
          const eventConsideration = parameters.consideration[i];
          const suppliedConsideration = order.parameters.consideration[i];
          expect(eventConsideration.itemType).to.equal(
            suppliedConsideration.itemType
          );
          expect(eventConsideration.token).to.equal(
            suppliedConsideration.token
          );
          expect(eventConsideration.identifierOrCriteria).to.equal(
            suppliedConsideration.identifierOrCriteria
          );
          expect(eventConsideration.startAmount).to.equal(
            suppliedConsideration.startAmount
          );
          expect(eventConsideration.endAmount).to.equal(
            suppliedConsideration.endAmount
          );
          expect(eventConsideration.recipient).to.equal(
            suppliedConsideration.recipient
          );
        }

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
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
      it("ERC721 <=> ETH (basic, EIP-2098 signature)", async () => {
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

        // Convert signature to EIP 2098
        expect(order.signature.length).to.equal(132);
        order.signature = convertSignatureToEIP2098(order.signature);
        expect(order.signature.length).to.equal(130);

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
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
      it("ERC721 <=> ETH (basic, extra ether supplied and returned to caller)", async () => {
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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value: value.add(1),
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
      it("ERC721 <=> ETH (match)", async () => {
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
      it("ERC721 <=> ETH (match via conduit)", async () => {
        const nftId = await mintAndApprove721(seller, conduitOne.address);

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
      it("ERC721 <=> ETH (match, extra eth supplied and returned to caller)", async () => {
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

        const tx = marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value: value.add(101),
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
      it("ERC721 <=> ERC20 (standard)", async () => {
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

        const { order, orderHash } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0));
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);
          return receipt;
        });
      });
      it("ERC721 <=> ERC20 (standard via conduit)", async () => {
        const nftId = await mintAndApprove721(seller, conduitOne.address);

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

        const { order, orderHash } = await createOrder(
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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0));
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC721 <=> ERC20 (basic)", async () => {
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

        const { order, orderHash } = await createOrder(
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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
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
      it("ERC721 <=> ERC20 (basic via conduit)", async () => {
        const nftId = await mintAndApprove721(seller, conduitOne.address);

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

        const { order, orderHash } = await createOrder(
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

        const basicOrderParameters = getBasicOrderParameters(
          2, // ERC20ForERC721
          order
        );

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
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
      it("ERC721 <=> ERC20 (basic, EIP-1271 signature)", async () => {
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
            sellerContract.address
          ),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order, orderHash } = await createOrder(
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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
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
      it("ERC721 <=> ERC20 (EIP-1271 signature on non-ECDSA 64 bytes)", async () => {
        const sellerContract = await deployContract(
          "EIP1271Wallet",
          seller,
          seller.address
        );

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
            sellerContract.address
          ),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order, orderHash } = await createOrder(
          sellerContract,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller
        );

        const signature = `0x`.padEnd(130, "f");

        const basicOrderParameters = {
          ...getBasicOrderParameters(
            2, // ERC20ForERC721
            order
          ),
          signature,
        };

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
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
      it("ERC721 <=> ERC20 (EIP-1271 signature on non-ECDSA 65 bytes)", async () => {
        const sellerContract = await deployContract(
          "EIP1271Wallet",
          seller,
          seller.address
        );

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
            sellerContract.address
          ),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order, orderHash } = await createOrder(
          sellerContract,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller
        );

        // Compute the digest based on the order hash
        const { domainSeparator } = await marketplaceContract.information();
        const digest = keccak256(
          `0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`
        );

        await sellerContract.registerDigest(digest, true);

        const signature = `0x`.padEnd(132, "f");

        const basicOrderParameters = {
          ...getBasicOrderParameters(
            2, // ERC20ForERC721
            order
          ),
          signature,
        };

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
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

        await sellerContract.registerDigest(digest, false);
      });
      it("ERC721 <=> ERC20 (basic, EIP-1271 signature w/ non-standard length)", async () => {
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
            sellerContract.address
          ),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order, orderHash } = await createOrder(
          sellerContract,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller
        );

        const basicOrderParameters = {
          ...getBasicOrderParameters(
            2, // ERC20ForERC721
            order
          ),
          signature: "0x",
        };

        // Fails before seller contract approves the digest (note that any
        // non-standard signature length is treated as a contract signature)
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

        // Compute the digest based on the order hash
        const { domainSeparator } = await marketplaceContract.information();
        const digest = keccak256(
          `0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`
        );

        // Seller approves the digest
        await sellerContract.connect(seller).registerDigest(digest, true);

        // Now it succeeds
        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
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
      it("ERC721 <=> ERC20 (match)", async () => {
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

        const tx = marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments);
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
      it("ERC721 <=> ERC20 (match via conduit)", async () => {
        const nftId = await mintAndApprove721(seller, conduitOne.address);

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
          .matchOrders([order, mirrorOrder], fulfillments);
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
    describe("[Accept offer] User accepts a buy offer on a single ERC721", async () => {
      // Note: ETH is not a possible case
      it("ERC721 <=> ERC20 (standard)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // Buyer approves marketplace contract to transfer ERC20 tokens too
        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0));
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC721 <=> ETH (restricted order checked post-execution)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // Buyer approves marketplace contract to transfer ERC20 tokens too
        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

        const consideration = [
          getTestItem721(nftId, 1, 1, seller.address),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order, orderHash } = await createOrder(
          seller,
          postExecutionZone,
          offer,
          consideration,
          2 // FULL_RESTRICTED
        );

        order.extraData = "0x1234";

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(0),
              ethers.constants.AddressZero
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC721 <=> ERC20 (standard, via conduit)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(seller, conduitOne.address, tokenAmount);

        // Buyer approves marketplace contract to transfer ERC20 tokens
        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

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
          0, // FULL_OPEN
          [],
          null,
          seller,
          ethers.constants.HashZero,
          conduitKeyOne
        );

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0));
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC721 <=> ERC20 (standard, fulfilled via conduit)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves conduit contract to transfer NFT
        await set721ApprovalForAll(buyer, conduitOne.address, true);

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // Buyer approves conduit to transfer ERC20 tokens
        await expect(
          testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, conduitOne.address, tokenAmount);

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, conduitKeyOne);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: conduitKeyOne,
            },
          ]);

          return receipt;
        });
      });
      it("ERC721 <=> ERC20 (basic)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Seller mints ERC20
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [getTestItem20(tokenAmount, tokenAmount)];

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

        await withBalanceChecks([order], toBN(0), undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ],
            getBasicOrderExecutions(order, buyer.address, conduitKeyOne)
          );

          return receipt;
        });
      });
      it("ERC721 <=> ETH (basic simple with restricted order checked post-execution)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Seller mints ERC20
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [getTestItem20(tokenAmount, tokenAmount)];

        const consideration = [getTestItem721(nftId, 1, 1, seller.address)];

        const { order, orderHash } = await createOrder(
          seller,
          postExecutionZone,
          offer,
          consideration,
          2 // FULL_RESTRICTED
        );

        const basicOrderParameters = getBasicOrderParameters(
          4, // ERC721ForERC20
          order
        );

        await withBalanceChecks([order], toBN(0), undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ],
            getBasicOrderExecutions(order, buyer.address, conduitKeyOne)
          );

          return receipt;
        });
      });
      it("ERC721 <=> ETH (basic with restricted order checked post-execution and tips)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Seller mints ERC20
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [getTestItem20(tokenAmount, tokenAmount)];

        const consideration = [getTestItem721(nftId, 1, 1, seller.address)];

        const { order, orderHash } = await createOrder(
          seller,
          postExecutionZone,
          offer,
          consideration,
          2 // FULL_RESTRICTED
        );

        order.parameters.consideration.push(
          getTestItem20(50, 50, zone.address)
        );

        const basicOrderParameters = getBasicOrderParameters(
          4, // ERC721ForERC20
          order
        );

        basicOrderParameters.totalOriginalAdditionalRecipients = toBN(0);

        await withBalanceChecks([order], toBN(0), undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ],
            getBasicOrderExecutions(order, buyer.address, conduitKeyOne)
          );

          return receipt;
        });
      });
      it("ERC721 <=> ETH (basic with restricted order checked post-execution)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Seller mints ERC20
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [getTestItem20(tokenAmount, tokenAmount)];

        const consideration = [
          getTestItem721(nftId, 1, 1, seller.address),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order, orderHash } = await createOrder(
          seller,
          postExecutionZone,
          offer,
          consideration,
          2 // FULL_RESTRICTED
        );

        const basicOrderParameters = getBasicOrderParameters(
          4, // ERC721ForERC20
          order
        );

        await withBalanceChecks([order], toBN(0), undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ],
            getBasicOrderExecutions(order, buyer.address, conduitKeyOne)
          );

          return receipt;
        });
      });
      it("ERC721 <=> ERC20 (basic, many via conduit)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Seller mints ERC20
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(seller, conduitOne.address, tokenAmount);

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [getTestItem20(tokenAmount, tokenAmount)];

        const consideration = [
          getTestItem721(nftId, 1, 1, seller.address),
          getTestItem20(1, 1, zone.address),
        ];

        for (let i = 1; i <= 50; ++i) {
          consideration.push(getTestItem20(i, i, toAddress(i + 10000)));
        }

        const { order, orderHash } = await createOrder(
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

        const basicOrderParameters = getBasicOrderParameters(
          4, // ERC721ForERC20
          order
        );

        await withBalanceChecks([order], toBN(0), undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ],
            getBasicOrderExecutions(order, buyer.address, conduitKeyOne)
          );

          return receipt;
        });
      });
      it("ERC721 <=> ERC20 (basic, fulfilled via conduit)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves conduit contract to transfer NFT
        await set721ApprovalForAll(buyer, conduitOne.address, true);

        // Seller mints ERC20
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [getTestItem20(tokenAmount, tokenAmount)];

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
          order,
          conduitKeyOne
        );

        await withBalanceChecks([order], toBN(0), undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
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
            getBasicOrderExecutions(order, buyer.address, conduitKeyOne)
          );

          return receipt;
        });
      });
      it("ERC721 <=> ERC20 (match)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

        const consideration = [
          getTestItem721(nftId, 1, 1, seller.address),
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

        const { mirrorOrder, mirrorOrderHash } =
          await createMirrorAcceptOfferOrder(buyer, zone, order);

        const fulfillments = defaultAcceptOfferMirrorFulfillment;

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
          .matchOrders([order, mirrorOrder], fulfillments);
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
      it("ERC721 <=> ERC20 (restriced match checked post-execution)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

        const consideration = [
          getTestItem721(nftId, 1, 1, seller.address),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          postExecutionZone,
          offer,
          consideration,
          2 // FULL_RESTRICTED
        );

        order.extraData = "0x1234";

        const { mirrorOrder, mirrorOrderHash } =
          await createMirrorAcceptOfferOrder(buyer, zone, order);

        const fulfillments = defaultAcceptOfferMirrorFulfillment;

        const executions = await simulateAdvancedMatchOrders(
          marketplaceContract,
          [order, mirrorOrder],
          [],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        const tx = marketplaceContract
          .connect(owner)
          .matchAdvancedOrders([order, mirrorOrder], [], fulfillments);
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
      it("ERC721 <=> ERC20 (match via conduit)", async () => {
        // Buyer mints nft
        const nftId = await mint721(buyer);

        // Buyer approves conduit contract to transfer NFT
        await set721ApprovalForAll(buyer, conduitOne.address, true);

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

        const consideration = [
          getTestItem721(nftId, 1, 1, seller.address),
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

        const { mirrorOrder, mirrorOrderHash } =
          await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            [],
            conduitKeyOne
          );

        const fulfillments = defaultAcceptOfferMirrorFulfillment;

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
          .matchOrders([order, mirrorOrder], fulfillments);
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
  });

  describe("A single ERC1155 is to be transferred", async () => {
    describe("[Buy now] User fulfills a sell order for a single ERC1155", async () => {
      it("ERC1155 <=> ETH (standard)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem1155(nftId, amount, amount)];

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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC1155 <=> ETH (standard via conduit)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          conduitOne.address
        );

        const offer = [getTestItem1155(nftId, amount, amount)];

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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC1155 <=> ETH (basic)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem1155(nftId, amount, amount)];

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
          1, // EthForERC1155
          order
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
      it("ERC1155 <=> ETH (basic via conduit)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          conduitOne.address
        );

        const offer = [getTestItem1155(nftId, amount, amount)];

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

        const basicOrderParameters = getBasicOrderParameters(
          1, // EthForERC1155
          order
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
      it("ERC1155 <=> ETH (match)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem1155(nftId, amount, amount)];

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
      it("ERC1155 <=> ETH (match via conduit)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          conduitOne.address
        );

        const offer = [getTestItem1155(nftId, amount, amount)];

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
      it("ERC1155 <=> ERC20 (standard)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
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

        const offer = [getTestItem1155(nftId, amount, amount)];

        const consideration = [
          getTestItem20(
            tokenAmount.sub(100),
            tokenAmount.sub(100),
            seller.address
          ),
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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0));
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC1155 <=> ERC20 (standard via conduit)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          conduitOne.address
        );

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          buyer,
          marketplaceContract.address,
          tokenAmount
        );

        const offer = [getTestItem1155(nftId, amount, amount)];

        const consideration = [
          getTestItem20(
            tokenAmount.sub(100),
            tokenAmount.sub(100),
            seller.address
          ),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order, orderHash } = await createOrder(
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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0));
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC1155 <=> ERC20 (basic)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
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

        const offer = [getTestItem1155(nftId, amount, amount)];

        const consideration = [
          getTestItem20(
            tokenAmount.sub(100),
            tokenAmount.sub(100),
            seller.address
          ),
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
          3, // ERC20ForERC1155
          order
        );

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ],
            getBasicOrderExecutions(order, buyer.address, conduitKeyOne)
          );

          return receipt;
        });
      });
      it("ERC1155 <=> ERC20 (basic via conduit)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          conduitOne.address
        );

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          buyer,
          marketplaceContract.address,
          tokenAmount
        );

        const offer = [getTestItem1155(nftId, amount, amount)];

        const consideration = [
          getTestItem20(
            tokenAmount.sub(100),
            tokenAmount.sub(100),
            seller.address
          ),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order, orderHash } = await createOrder(
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

        const basicOrderParameters = getBasicOrderParameters(3, order);

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
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
      it("ERC1155 <=> ERC20 (match)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
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

        const offer = [getTestItem1155(nftId, amount, amount)];

        const consideration = [
          getTestItem20(
            tokenAmount.sub(100),
            tokenAmount.sub(100),
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
          .matchOrders([order, mirrorOrder], fulfillments);
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
      it("ERC1155 <=> ERC20 (match via conduit)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          conduitOne.address
        );

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          buyer,
          marketplaceContract.address,
          tokenAmount
        );

        const offer = [getTestItem1155(nftId, amount, amount)];

        const consideration = [
          getTestItem20(
            tokenAmount.sub(100),
            tokenAmount.sub(100),
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
          .matchOrders([order, mirrorOrder], fulfillments);
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
    describe("[Accept offer] User accepts a buy offer on a single ERC1155", async () => {
      // Note: ETH is not a possible case
      it("ERC1155 <=> ERC20 (standard)", async () => {
        // Buyer mints nft
        const { nftId, amount } = await mintAndApprove1155(
          buyer,
          marketplaceContract.address
        );

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // Buyer approves marketplace contract to transfer ERC20 tokens too
        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

        const consideration = [
          getTestItem1155(nftId, amount, amount, undefined, seller.address),
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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(0));
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ]);

          return receipt;
        });
      });
      it("ERC1155 <=> ERC20 (standard, fulfilled via conduit)", async () => {
        // Buyer mints nft
        const { nftId, amount } = await mintAndApprove1155(
          buyer,
          conduitOne.address
        );

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // Buyer approves conduit to transfer ERC20 tokens
        await expect(
          testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, conduitOne.address, tokenAmount);

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

        const consideration = [
          getTestItem1155(nftId, amount, amount, undefined, seller.address),
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

        await withBalanceChecks([order], 0, undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, conduitKeyOne);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: conduitKeyOne,
            },
          ]);

          return receipt;
        });
      });
      it("ERC1155 <=> ERC20 (basic)", async () => {
        // Buyer mints nft
        const { nftId, amount } = await mintAndApprove1155(
          buyer,
          marketplaceContract.address
        );

        // Seller mints ERC20
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [getTestItem20(tokenAmount, tokenAmount)];

        const consideration = [
          getTestItem1155(nftId, amount, amount, undefined, seller.address),
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
          5, // ERC1155ForERC20
          order
        );

        await withBalanceChecks([order], toBN(0), undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ],
            getBasicOrderExecutions(order, buyer.address, "")
          );

          return receipt;
        });
      });
      it("ERC1155 <=> ERC20 (basic, fulfilled via conduit)", async () => {
        // Buyer mints nft
        const { nftId, amount } = await mintAndApprove1155(
          buyer,
          conduitOne.address
        );

        // Seller mints ERC20
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [getTestItem20(tokenAmount, tokenAmount)];

        const consideration = [
          getTestItem1155(nftId, amount, amount, undefined, seller.address),
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
          5, // ERC1155ForERC20
          order,
          conduitKeyOne
        );

        await withBalanceChecks([order], toBN(0), undefined, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters);

          const executions = getBasicOrderExecutions(
            order,
            buyer.address,
            conduitKeyOne
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
            executions
          );

          return receipt;
        });
      });
      it("ERC1155 <=> ERC20 (match)", async () => {
        // Buyer mints nft
        const { nftId, amount } = await mintAndApprove1155(
          buyer,
          marketplaceContract.address
        );

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

        const consideration = [
          getTestItem1155(nftId, amount, amount, undefined, seller.address),
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

        const { mirrorOrder, mirrorOrderHash } =
          await createMirrorAcceptOfferOrder(buyer, zone, order);

        const fulfillments = defaultAcceptOfferMirrorFulfillment;

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
          .matchOrders([order, mirrorOrder], fulfillments);
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
      it("ERC1155 <=> ERC20 (match via conduit)", async () => {
        // Buyer mints nft
        const { nftId, amount } = await mintAndApprove1155(
          buyer,
          conduitOne.address
        );

        // Seller mints ERC20
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

        const offer = [
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

        const consideration = [
          getTestItem1155(nftId, amount, amount, undefined, seller.address),
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

        const { mirrorOrder, mirrorOrderHash } =
          await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            [],
            conduitKeyOne
          );

        const fulfillments = defaultAcceptOfferMirrorFulfillment;

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
          .matchOrders([order, mirrorOrder], fulfillments);
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
  });
});
