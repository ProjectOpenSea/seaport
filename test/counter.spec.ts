import { expect } from "chai";
import { ethers, network } from "hardhat";

import {
  buildOrderStatus,
  getItemETH,
  randomBN,
  randomHex,
  toKey,
} from "./utils/encoding";
import { seaportFixture } from "./utils/fixtures";
import { VERSION, getCustomRevertSelector } from "./utils/helpers";
import { faucet } from "./utils/impersonate";

import type { ConsiderationInterface } from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { Wallet } from "ethers";

const { parseEther } = ethers.utils;

describe(`Validate, cancel, and increment counter flows (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let marketplaceContract: ConsiderationInterface;

  let checkExpectedEvents: SeaportFixtures["checkExpectedEvents"];
  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
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
      mintAndApprove721,
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
      await expect(marketplaceContract.connect(owner).validate([order]))
        .to.emit(marketplaceContract, "OrderValidated")
        .withArgs(orderHash, seller.address, zone.address);

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
      ).to.be.revertedWith("OrderAlreadyFilled");
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
      await expect(marketplaceContract.connect(seller).validate([order]))
        .to.emit(marketplaceContract, "OrderValidated")
        .withArgs(orderHash, seller.address, zone.address);

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
      ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

      // cannot validate it with a signature either
      order.signature = signature;
      await expect(
        marketplaceContract.connect(owner).validate([order])
      ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

      const newStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...newStatus }).to.deep.eq(buildOrderStatus(false, true, 0, 0));
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
      ).to.be.revertedWith("InvalidCanceller");

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
      ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

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
      ).to.be.revertedWith("InvalidCanceller");

      const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
      expect({ ...initialStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      // Can validate it
      await expect(marketplaceContract.connect(owner).validate([order]))
        .to.emit(marketplaceContract, "OrderValidated")
        .withArgs(orderHash, seller.address, zone.address);

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
      ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

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
      ).to.be.revertedWith("InvalidCanceller");

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
      ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

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
      await expect(marketplaceContract.connect(owner).validate([order]))
        .to.emit(marketplaceContract, "OrderValidated")
        .withArgs(orderHash, seller.address, zone.address);

      // cannot cancel it from a random account
      await expect(
        marketplaceContract.connect(owner).cancel([orderComponents])
      ).to.be.revertedWith("InvalidCanceller");

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
      ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

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

      await expect(marketplaceContract.connect(owner).validate([order]))
        .to.emit(marketplaceContract, "OrderValidated")
        .withArgs(orderHash, seller.address, zone.address);

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

      await expect(marketplaceContract.connect(owner).validate([order]))
        .to.emit(marketplaceContract, "OrderValidated")
        .withArgs(orderHash, seller.address, zone.address);

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
  });
});
