import { expect } from "chai";
import { ethers, network } from "hardhat";

import { deployContract } from "./utils/contracts";
import {
  buildOrderStatus,
  getItemETH,
  randomBN,
  randomHex,
  toKey,
} from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { seaportFixture } from "./utils/fixtures";
import { VERSION, getCustomRevertSelector } from "./utils/helpers";

import type { ConsiderationInterface, Reenterer } from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { Wallet } from "ethers";

const { parseEther } = ethers.utils;

describe(`Validate, cancel, and increment counter flows (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let marketplaceContract: ConsiderationInterface;
  let reenterer: Reenterer;

  let checkExpectedEvents: SeaportFixtures["checkExpectedEvents"];
  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
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
      createOrder,
      getTestItem721,
      marketplaceContract,
      reenterer,
      mintAndApprove721,
      set721ApprovalForAll,
      withBalanceChecks,
    } = await seaportFixture(owner));
  });

  let seller: Wallet;
  let buyer: Wallet;
  let zone: Wallet;

  beforeEach(async () => {
    // Setup basic buyer/seller wallets with ETH
    seller = new ethers.Wallet(randomHex(32), provider);
    buyer = new ethers.Wallet(randomHex(32), provider);
    zone = new ethers.Wallet(randomHex(32), provider);

    for (const wallet of [seller, buyer, zone]) {
      await faucet(wallet.address, provider);
    }
  });

  describe("Validate", async () => {
    it("Validate signed order and fill it with no signature", async () => {
      // Seller mints an nft
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

      const signature = order.signature;

      const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...initialStatus }).to.deep.eq(
        buildOrderStatus(false, false, 0, 0)
      );

      // cannot fill it with no signature yet
      order.signature = "0x";

      if (!process.env.REFERENCE) {
        const expectedRevertReason =
          getCustomRevertSelector("InvalidSignature()");

        let tx = await marketplaceContract
          .connect(buyer)
          .populateTransaction.fulfillOrder(order, toKey(0), {
            value,
          });
        let returnData = await provider.call(tx);
        expect(returnData).to.equal(expectedRevertReason);

        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;

        // cannot validate it with no signature from a random account
        await expect(marketplaceContract.connect(owner).validate([order])).to.be
          .reverted;

        tx = await marketplaceContract
          .connect(owner)
          .populateTransaction.fulfillOrder(order, toKey(0), {
            value,
          });
        returnData = await provider.call(tx);
        expect(returnData).to.equal(expectedRevertReason);
      } else {
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;

        // cannot validate it with no signature from a random account
        await expect(marketplaceContract.connect(owner).validate([order])).to.be
          .reverted;
      }

      // can validate it once you add the signature back
      order.signature = signature;

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
        expect(eventConsideration.token).to.equal(suppliedConsideration.token);
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

      const newStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...newStatus }).to.deep.eq(buildOrderStatus(true, false, 0, 0));

      // Can validate it repeatedly, but no event after the first time
      await marketplaceContract.connect(owner).validate([order, order]);

      // Fulfill the order without a signature
      order.signature = "0x";
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

      const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...finalStatus }).to.deep.eq(
        buildOrderStatus(true, false, 1, 1)
      );

      // cannot validate it once it's been fully filled
      await expect(
        marketplaceContract.connect(owner).validate([order])
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "OrderAlreadyFilled"
      );
    });
    it("Validate unsigned order from offerer and fill it with no signature", async () => {
      // Seller mints an nft
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

      order.signature = "0x";

      const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...initialStatus }).to.deep.eq(
        buildOrderStatus(false, false, 0, 0)
      );

      if (!process.env.REFERENCE) {
        // cannot fill it with no signature yet
        const expectedRevertReason =
          getCustomRevertSelector("InvalidSignature()");

        let tx = await marketplaceContract
          .connect(buyer)
          .populateTransaction.fulfillOrder(order, toKey(0), {
            value,
          });
        let returnData = await provider.call(tx);
        expect(returnData).to.equal(expectedRevertReason);

        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;

        // cannot validate it with no signature from a random account
        tx = await marketplaceContract
          .connect(owner)
          .populateTransaction.validate([order]);
        returnData = await provider.call(tx);
        expect(returnData).to.equal(expectedRevertReason);

        await expect(marketplaceContract.connect(owner).validate([order])).to.be
          .reverted;
      } else {
        // cannot fill it with no signature yet
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;

        // cannot validate it with no signature from a random account
        await expect(marketplaceContract.connect(owner).validate([order])).to.be
          .reverted;
      }

      // can validate it from the seller
      const tx = await marketplaceContract.connect(seller).validate([order]);

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
        expect(eventConsideration.token).to.equal(suppliedConsideration.token);
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

      const newStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...newStatus }).to.deep.eq(buildOrderStatus(true, false, 0, 0));

      // Fulfill the order without a signature
      order.signature = "0x";
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

      const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...finalStatus }).to.deep.eq(
        buildOrderStatus(true, false, 1, 1)
      );
    });
    it("Cannot validate a cancelled order", async () => {
      // Seller mints an nft
      const nftId = randomBN();

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value, orderComponents } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const signature = order.signature;

      order.signature = "0x";

      const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...initialStatus }).to.deep.eq(
        buildOrderStatus(false, false, 0, 0)
      );

      if (!process.env.REFERENCE) {
        // cannot fill it with no signature yet
        const expectedRevertReason =
          getCustomRevertSelector("InvalidSignature()");

        let tx = await marketplaceContract
          .connect(buyer)
          .populateTransaction.fulfillOrder(order, toKey(0), {
            value,
          });
        let returnData = await provider.call(tx);
        expect(returnData).to.equal(expectedRevertReason);

        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;

        tx = await marketplaceContract
          .connect(owner)
          .populateTransaction.validate([order]);
        returnData = await provider.call(tx);
        expect(returnData).to.equal(expectedRevertReason);

        // cannot validate it with no signature from a random account
        await expect(marketplaceContract.connect(owner).validate([order])).to.be
          .reverted;
      } else {
        // cannot fill it with no signature yet
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;

        // cannot validate it with no signature from a random account
        await expect(marketplaceContract.connect(owner).validate([order])).to.be
          .reverted;
      }

      // can cancel it
      await expect(
        marketplaceContract.connect(seller).cancel([orderComponents])
      )
        .to.emit(marketplaceContract, "OrderCancelled")
        .withArgs(orderHash, seller.address, zone.address);

      // cannot validate it from the seller
      await expect(
        marketplaceContract.connect(seller).validate([order])
      ).to.be.revertedWithCustomError(marketplaceContract, "OrderIsCancelled");

      // cannot validate it with a signature either
      order.signature = signature;
      await expect(
        marketplaceContract.connect(owner).validate([order])
      ).to.be.revertedWithCustomError(marketplaceContract, "OrderIsCancelled");

      const newStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...newStatus }).to.deep.eq(buildOrderStatus(false, true, 0, 0));
    });

    it("Skip validation for contract order", async () => {
      // Seller mints an nft (FULL_OPEN order)
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

      const { order, orderHash } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...initialStatus }).to.deep.eq(
        buildOrderStatus(false, false, 0, 0)
      );

      // Seller mints nft (CONTRACT order)
      const contractOrderNftId = await mintAndApprove721(
        seller,
        marketplaceContract.address
      );

      // seller deploys offererContract and approves it for 721 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );

      await set721ApprovalForAll(seller, offererContract.address, true);

      const contractOrderOffer = [getTestItem721(contractOrderNftId) as any];

      const contractOrderConsideration = [
        getItemETH(
          parseEther("10"),
          parseEther("10"),
          offererContract.address
        ) as any,
      ];

      contractOrderOffer[0].identifier =
        contractOrderOffer[0].identifierOrCriteria;
      contractOrderOffer[0].amount = contractOrderOffer[0].endAmount;

      contractOrderConsideration[0].identifier =
        contractOrderConsideration[0].identifierOrCriteria;
      contractOrderConsideration[0].amount =
        contractOrderConsideration[0].endAmount;

      await offererContract
        .connect(seller)
        .activate(contractOrderOffer[0], contractOrderOffer[0]);

      const { order: contractOrder } = await createOrder(
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

      const contractOrderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(
        contractOrderHash
      );

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // can validate it from the seller
      const tx = await marketplaceContract
        .connect(seller)
        .validate([order, contractOrder]);

      const receipt = await tx.wait();

      // should only validate the FULL_OPEN order
      expect(receipt.events?.length).to.equal(1);

      const event = receipt.events && receipt.events[0];

      expect(event?.event).to.equal("OrderValidated");

      expect(event?.args?.orderHash).to.equal(orderHash);
    });

    it("Reverts on validate when consideration array length doesn't match totalOriginalConsiderationItems", async () => {
      // Seller mints an nft
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
      const { order } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );
      order.parameters.totalOriginalConsiderationItems = 2;

      // cannot validate when consideration array length is different than total
      // original consideration items value
      await expect(
        marketplaceContract.connect(seller).validate([order])
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "ConsiderationLengthExceedsTotalOriginal"
      );
    });
  });

  describe("Cancel", async () => {
    it("Can cancel an order", async () => {
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

      const { order, orderHash, value, orderComponents } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // cannot cancel it from a random account
      await expect(
        marketplaceContract.connect(owner).cancel([orderComponents])
      ).to.be.revertedWithCustomError(marketplaceContract, "InvalidCanceller");

      const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...initialStatus }).to.deep.eq(
        buildOrderStatus(false, false, 0, 0)
      );

      // can cancel it
      await expect(
        marketplaceContract.connect(seller).cancel([orderComponents])
      )
        .to.emit(marketplaceContract, "OrderCancelled")
        .withArgs(orderHash, seller.address, zone.address);

      // cannot fill the order anymore
      await expect(
        marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
          value,
        })
      ).to.be.revertedWithCustomError(marketplaceContract, "OrderIsCancelled");

      const newStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...newStatus }).to.deep.eq(buildOrderStatus(false, true, 0, 0));
    });
    it("Can cancel a validated order", async () => {
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

      const { order, orderHash, value, orderComponents } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // cannot cancel it from a random account
      await expect(
        marketplaceContract.connect(owner).cancel([orderComponents])
      ).to.be.revertedWithCustomError(marketplaceContract, "InvalidCanceller");

      const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...initialStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // Can validate it
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
        expect(eventConsideration.token).to.equal(suppliedConsideration.token);
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

      const newStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...newStatus }).to.deep.equal(
        buildOrderStatus(true, false, 0, 0)
      );

      // can cancel it
      await expect(
        marketplaceContract.connect(seller).cancel([orderComponents])
      )
        .to.emit(marketplaceContract, "OrderCancelled")
        .withArgs(orderHash, seller.address, zone.address);

      // cannot fill the order anymore
      await expect(
        marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
          value,
        })
      ).to.be.revertedWithCustomError(marketplaceContract, "OrderIsCancelled");

      const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...finalStatus }).to.deep.equal(
        buildOrderStatus(false, true, 0, 0)
      );
    });
    it("Can cancel an order from the zone", async () => {
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

      const { order, orderHash, value, orderComponents } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // cannot cancel it from a random account
      await expect(
        marketplaceContract.connect(owner).cancel([orderComponents])
      ).to.be.revertedWithCustomError(marketplaceContract, "InvalidCanceller");

      const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...initialStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // can cancel it from the zone
      await expect(marketplaceContract.connect(zone).cancel([orderComponents]))
        .to.emit(marketplaceContract, "OrderCancelled")
        .withArgs(orderHash, seller.address, zone.address);

      // cannot fill the order anymore
      await expect(
        marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
          value,
        })
      ).to.be.revertedWithCustomError(marketplaceContract, "OrderIsCancelled");

      const newStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...newStatus }).to.deep.equal(
        buildOrderStatus(false, true, 0, 0)
      );
    });
    it("Can cancel a validated order from a zone", async () => {
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

      const { order, orderHash, value, orderComponents } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...initialStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // Can validate it
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
        expect(eventConsideration.token).to.equal(suppliedConsideration.token);
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

      // cannot cancel it from a random account
      await expect(
        marketplaceContract.connect(owner).cancel([orderComponents])
      ).to.be.revertedWithCustomError(marketplaceContract, "InvalidCanceller");

      const newStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...newStatus }).to.deep.equal(
        buildOrderStatus(true, false, 0, 0)
      );

      // can cancel it from the zone
      await expect(marketplaceContract.connect(zone).cancel([orderComponents]))
        .to.emit(marketplaceContract, "OrderCancelled")
        .withArgs(orderHash, seller.address, zone.address);

      // cannot fill the order anymore
      await expect(
        marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
          value,
        })
      ).to.be.revertedWithCustomError(marketplaceContract, "OrderIsCancelled");

      const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...finalStatus }).to.deep.equal(
        buildOrderStatus(false, true, 0, 0)
      );
    });
  });

  describe("Increment Counter", async () => {
    it("Can increment the counter", async () => {
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

      let { order, orderHash, value, orderComponents } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const counter = await marketplaceContract.getCounter(seller.address);
      expect(counter).to.equal(0);
      expect(orderComponents.counter).to.equal(counter);

      // can increment the counter
      await expect(marketplaceContract.connect(seller).incrementCounter())
        .to.emit(marketplaceContract, "CounterIncremented")
        .withArgs(1, seller.address);

      const newCounter = await marketplaceContract.getCounter(seller.address);
      expect(newCounter).to.equal(1);

      if (!process.env.REFERENCE) {
        // Cannot fill order anymore
        const expectedRevertReason = getCustomRevertSelector("InvalidSigner()");

        const tx = await marketplaceContract
          .connect(buyer)
          .populateTransaction.fulfillOrder(order, toKey(0), {
            value,
          });
        const returnData = await provider.call(tx);
        expect(returnData).to.equal(expectedRevertReason);

        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;
      } else {
        // Cannot fill order anymore
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;
      }

      const newOrderDetails = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      order = newOrderDetails.order;
      orderHash = newOrderDetails.orderHash;
      value = newOrderDetails.value;
      orderComponents = newOrderDetails.orderComponents;

      expect(orderComponents.counter).to.equal(newCounter);

      // Can fill order with new counter
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
    it("Can increment the counter and implicitly cancel a validated order", async () => {
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

      let { order, orderHash, value, orderComponents } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const counter = await marketplaceContract.getCounter(seller.address);
      expect(counter).to.equal(0);
      expect(orderComponents.counter).to.equal(counter);

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
        expect(eventConsideration.token).to.equal(suppliedConsideration.token);
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

      // can increment the counter
      await expect(marketplaceContract.connect(seller).incrementCounter())
        .to.emit(marketplaceContract, "CounterIncremented")
        .withArgs(1, seller.address);

      const newCounter = await marketplaceContract.getCounter(seller.address);
      expect(newCounter).to.equal(1);

      if (!process.env.REFERENCE) {
        // Cannot fill order anymore
        const expectedRevertReason = getCustomRevertSelector("InvalidSigner()");

        const tx = await marketplaceContract
          .connect(buyer)
          .populateTransaction.fulfillOrder(order, toKey(0), {
            value,
          });
        const returnData = await provider.call(tx);
        expect(returnData).to.equal(expectedRevertReason);

        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;
      } else {
        // Cannot fill order anymore
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;
      }

      const newOrderDetails = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      order = newOrderDetails.order;
      orderHash = newOrderDetails.orderHash;
      value = newOrderDetails.value;
      orderComponents = newOrderDetails.orderComponents;

      expect(orderComponents.counter).to.equal(newCounter);

      // Can fill order with new counter
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
    it("Can increment the counter as the zone and implicitly cancel a validated order", async () => {
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

      let { order, orderHash, value, orderComponents } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const counter = await marketplaceContract.getCounter(seller.address);
      expect(counter).to.equal(0);
      expect(orderComponents.counter).to.equal(counter);

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
        expect(eventConsideration.token).to.equal(suppliedConsideration.token);
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

      // can increment the counter as the offerer
      await expect(marketplaceContract.connect(seller).incrementCounter())
        .to.emit(marketplaceContract, "CounterIncremented")
        .withArgs(1, seller.address);

      const newCounter = await marketplaceContract.getCounter(seller.address);
      expect(newCounter).to.equal(1);

      if (!process.env.REFERENCE) {
        // Cannot fill order anymore
        const expectedRevertReason = getCustomRevertSelector("InvalidSigner()");

        const tx = await marketplaceContract
          .connect(buyer)
          .populateTransaction.fulfillOrder(order, toKey(0), {
            value,
          });
        const returnData = await provider.call(tx);
        expect(returnData).to.equal(expectedRevertReason);

        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;
      } else {
        // Cannot fill order anymore
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
            value,
          })
        ).to.be.reverted;
      }

      const newOrderDetails = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      order = newOrderDetails.order;
      orderHash = newOrderDetails.orderHash;
      value = newOrderDetails.value;
      orderComponents = newOrderDetails.orderComponents;

      expect(orderComponents.counter).to.equal(newCounter);

      // Can fill order with new counter
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
    it("Reverts on a reentrant call", async () => {
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

      let { orderComponents } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const counter = await marketplaceContract.getCounter(seller.address);
      expect(counter).to.equal(0);
      expect(orderComponents.counter).to.equal(counter);

      const callData =
        marketplaceContract.interface.encodeFunctionData("incrementCounter");
      const tx = await reenterer.prepare(
        marketplaceContract.address,
        0,
        callData
      );
      await tx.wait();

      await expect(
        marketplaceContract.connect(seller).incrementCounter()
      ).to.be.revertedWithCustomError(marketplaceContract, "NoReentrantCalls");
    });
  });
});
