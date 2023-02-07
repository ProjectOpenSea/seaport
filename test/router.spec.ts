import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";
import { ethers, network } from "hardhat";

import { deployContract } from "./utils/contracts";
import { getItemETH, randomHex, toKey } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { seaportFixture } from "./utils/fixtures";
import { VERSION } from "./utils/helpers";

import type {
  ConduitControllerInterface,
  ConduitInterface,
  ConsiderationInterface,
  Reenterer,
  SeaportRouter,
  TestERC721,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { Wallet } from "ethers";

describe(`SeaportRouter tests (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let conduitController: ConduitControllerInterface;
  let conduitKeyOne: string;
  let conduitOne: ConduitInterface;
  let marketplaceContract: ConsiderationInterface;
  let marketplaceContract2: ConsiderationInterface;
  let reenterer: Reenterer;

  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
  let set721ApprovalForAll: SeaportFixtures["set721ApprovalForAll"];
  let testERC721: TestERC721;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await faucet(owner.address, provider);

    ({
      conduitController,
      conduitKeyOne,
      conduitOne,
      createOrder,
      getTestItem721,
      marketplaceContract,
      mintAndApprove721,
      reenterer,
      set721ApprovalForAll,
      testERC721,
    } = await seaportFixture(owner));

    marketplaceContract2 = await deployContract<ConsiderationInterface>(
      "Seaport",
      owner,
      conduitController.address
    );
  });

  let buyer: Wallet;
  let seller: Wallet;
  let zone: Wallet;

  let router: SeaportRouter;

  beforeEach(async () => {
    // Setup basic buyer/seller wallets with ETH
    buyer = new ethers.Wallet(randomHex(32), provider);
    seller = new ethers.Wallet(randomHex(32), provider);
    zone = new ethers.Wallet(randomHex(32), provider);

    for (const wallet of [buyer, seller, zone, reenterer]) {
      await faucet(wallet.address, provider);
    }

    router = await deployContract(
      "SeaportRouter",
      owner,
      marketplaceContract.address,
      marketplaceContract2.address
    );
  });

  describe("fulfillAvailableAdvancedOrders", async () => {
    it("Should return the allowed Seaport contracts usable through the router", async () => {
      expect(marketplaceContract.address).to.not.equal(
        marketplaceContract2.address
      );
      expect(await router.getAllowedSeaportContracts()).to.deep.equal([
        marketplaceContract.address,
        marketplaceContract2.address,
      ]);
    });
    it("Should be able to fulfill orders through a single Seaport contract", async () => {
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
      ];

      const params = {
        seaportContracts: [marketplaceContract.address],
        advancedOrderParams: [
          {
            advancedOrders: [order],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
        ],
        fulfillerConduitKey: toKey(0),
        recipient: buyer.address,
        maximumFulfilled: 100,
      };

      // Expect trying to fulfill through a non-allowed contract to fail
      await expect(
        router.connect(buyer).fulfillAvailableAdvancedOrders(
          { ...params, seaportContracts: [testERC721.address] },
          {
            value,
          }
        )
      )
        .to.be.revertedWithCustomError(router, "SeaportNotAllowed")
        .withArgs(testERC721.address);

      // Execute order
      await router.connect(buyer).fulfillAvailableAdvancedOrders(params, {
        value,
      });

      // Ensure buyer now owns the nft
      expect(await testERC721.ownerOf(nftId)).to.equal(buyer.address);
    });
    it("Should be able to fulfill orders through multiple Seaport contracts", async () => {
      // Seller mints nfts
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );
      const nftId2 = await mintAndApprove721(
        seller,
        marketplaceContract2.address
      );

      const offer = [getTestItem721(nftId)];
      const offer2 = [getTestItem721(nftId2)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );
      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer2,
        consideration,
        0, // FULL_OPEN
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        marketplaceContract2
      );

      const offerComponents = [[{ orderIndex: 0, itemIndex: 0 }]];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
      ];

      const params = {
        seaportContracts: [
          marketplaceContract.address,
          marketplaceContract2.address,
        ],
        advancedOrderParams: [
          {
            advancedOrders: [order],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
          {
            advancedOrders: [order2],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
        ],
        fulfillerConduitKey: toKey(0),
        recipient: owner.address,
        maximumFulfilled: 100,
      };

      // Execute orders
      await router.connect(buyer).fulfillAvailableAdvancedOrders(params, {
        value: value.mul(2),
      });

      // Ensure the recipient (owner) now owns both nfts
      expect(await testERC721.ownerOf(nftId)).to.equal(owner.address);
      expect(await testERC721.ownerOf(nftId2)).to.equal(owner.address);
    });
    it("Should respect maximumFulfilled across multiple Seaport contracts", async () => {
      // Seller mints nfts
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );
      const nftId2 = await mintAndApprove721(
        seller,
        marketplaceContract2.address
      );

      const offer = [getTestItem721(nftId)];
      const offer2 = [getTestItem721(nftId2)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );
      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer2,
        consideration,
        0, // FULL_OPEN
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        marketplaceContract2
      );

      const offerComponents = [[{ orderIndex: 0, itemIndex: 0 }]];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
      ];

      const params = {
        seaportContracts: [
          marketplaceContract.address,
          marketplaceContract2.address,
        ],
        advancedOrderParams: [
          {
            advancedOrders: [order],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
          {
            advancedOrders: [order2],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
        ],
        fulfillerConduitKey: toKey(0),
        recipient: owner.address,
        maximumFulfilled: 1,
      };

      // Execute orders
      await router.connect(buyer).fulfillAvailableAdvancedOrders(params, {
        value: value.mul(2),
      });

      // Ensure the recipient (owner) now owns only the first NFT (maximumFulfilled=1)
      expect(await testERC721.ownerOf(nftId)).to.equal(owner.address);
      expect(await testERC721.ownerOf(nftId2)).to.equal(seller.address);
    });
    it("Should be able to fulfill orders through multiple Seaport contracts using conduit", async () => {
      // Seller mints nfts
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );
      const nftId2 = await mintAndApprove721(
        seller,
        marketplaceContract2.address
      );
      // Seller approves conduit contract to transfer NFTs
      await set721ApprovalForAll(seller, conduitOne.address, true);

      const offer = [getTestItem721(nftId)];
      const offer2 = [getTestItem721(nftId2)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );
      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer2,
        consideration,
        0, // FULL_OPEN
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        marketplaceContract2
      );

      const offerComponents = [[{ orderIndex: 0, itemIndex: 0 }]];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
      ];

      const params = {
        seaportContracts: [
          marketplaceContract.address,
          marketplaceContract2.address,
        ],
        advancedOrderParams: [
          {
            advancedOrders: [order],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
          {
            advancedOrders: [order2],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
        ],
        fulfillerConduitKey: conduitKeyOne,
        recipient: owner.address,
        maximumFulfilled: 100,
      };

      // Execute orders
      await router.connect(buyer).fulfillAvailableAdvancedOrders(params, {
        value: value.mul(2),
      });

      // Ensure the recipient (owner) now owns both nfts
      expect(await testERC721.ownerOf(nftId)).to.equal(owner.address);
      expect(await testERC721.ownerOf(nftId2)).to.equal(owner.address);
    });
    it("Should process valid orders while skipping invalid orders", async () => {
      // Seller mints nfts
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );
      const nftId2 = await mintAndApprove721(
        seller,
        marketplaceContract2.address
      );

      const offer = [getTestItem721(nftId)];
      const offer2 = [getTestItem721(nftId2)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );
      const { order: order2 } = await createOrder(
        seller,
        zone,
        offer2,
        consideration,
        0, // FULL_OPEN
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        marketplaceContract2
      );

      const offerComponents = [[{ orderIndex: 0, itemIndex: 0 }]];
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
      ];

      const params = {
        seaportContracts: [
          marketplaceContract.address,
          marketplaceContract2.address,
        ],
        advancedOrderParams: [
          {
            advancedOrders: [order],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
          {
            advancedOrders: [order2],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
        ],
        fulfillerConduitKey: toKey(0),
        recipient: buyer.address,
        maximumFulfilled: 100,
      };

      const buyerEthBalanceBefore = await provider.getBalance(buyer.address);

      // Execute the first order so it is fulfilled thus invalid for the next call
      await router.connect(buyer).fulfillAvailableAdvancedOrders(
        {
          ...params,
          seaportContracts: params.seaportContracts.slice(0, 1),
          advancedOrderParams: params.advancedOrderParams.slice(0, 1),
        },
        {
          value,
        }
      );

      // Execute orders
      await router.connect(buyer).fulfillAvailableAdvancedOrders(params, {
        value: value.mul(2),
      });

      // Ensure the recipient (buyer) owns both nfts
      expect(await testERC721.ownerOf(nftId)).to.equal(buyer.address);
      expect(await testERC721.ownerOf(nftId2)).to.equal(buyer.address);

      // Ensure the excess eth was returned
      const buyerEthBalanceAfter = await provider.getBalance(buyer.address);
      expect(buyerEthBalanceBefore).to.be.gt(
        buyerEthBalanceAfter.sub(value.mul(3))
      );
    });
    it("Should revert if cannot return excess ether value", async () => {
      // Seller mints nfts
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
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
      ];

      const params = {
        seaportContracts: [marketplaceContract.address],
        advancedOrderParams: [
          {
            advancedOrders: [order],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
        ],
        fulfillerConduitKey: toKey(0),
        recipient: buyer.address,
        maximumFulfilled: 100,
      };

      // prepare the reentrant call on the reenterer
      const tx = await reenterer.prepare(testERC721.address, 0, []);
      await tx.wait();

      // Execute orders
      const callData = router.interface.encodeFunctionData(
        "fulfillAvailableAdvancedOrders",
        [params]
      );
      await expect(reenterer.execute(router.address, value.mul(2), callData))
        .to.be.revertedWithCustomError(router, "EtherReturnTransferFailed")
        .withArgs(reenterer.address, value, "0x");
    });
    it("Should not be able to reenter through receive()", async () => {
      // Seller mints nfts
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
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
      ];

      const params = {
        seaportContracts: [marketplaceContract.address],
        advancedOrderParams: [
          {
            advancedOrders: [order],
            criteriaResolvers: [],
            offerFulfillments: offerComponents,
            considerationFulfillments: considerationComponents,
            etherValue: value,
          },
        ],
        fulfillerConduitKey: toKey(0),
        recipient: buyer.address,
        maximumFulfilled: 100,
      };

      // prepare the reentrant call on the reenterer
      const callData = router.interface.encodeFunctionData(
        "fulfillAvailableAdvancedOrders",
        [params]
      );
      const tx = await reenterer.prepare(router.address, 0, callData);
      await tx.wait();

      // Execute orders
      await expect(reenterer.execute(router.address, value.mul(2), callData))
        .to.be.revertedWithCustomError(router, "EtherReturnTransferFailed")
        .withArgs(
          reenterer.address,
          value,
          marketplaceContract.interface.getSighash("NoReentrantCalls")
        );
    });
    it("Should not be able to receive ether from a non-Seaport address", async () => {
      // Test receive(), which is triggered when sent eth with no data
      const txTriggerReceive = await owner.signTransaction({
        to: router.address,
        value: 1,
        nonce: await owner.getTransactionCount(),
        gasPrice: await provider.getGasPrice(),
        gasLimit: 50_000,
      });
      await expect(provider.sendTransaction(txTriggerReceive))
        .to.be.revertedWithCustomError(router, "SeaportNotAllowed")
        .withArgs(owner.address);

      // Test receive() impersonating as Seaport
      await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [marketplaceContract.address],
      });

      const seaportSigner = await ethers.getSigner(marketplaceContract.address);
      await faucet(marketplaceContract.address, provider);

      await seaportSigner.sendTransaction({ to: router.address, value: 1 });
      expect((await provider.getBalance(router.address)).toNumber()).to.eq(1);

      await network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [marketplaceContract.address],
      });
    });
  });
});
