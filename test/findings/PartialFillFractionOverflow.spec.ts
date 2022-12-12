import { expect } from "chai";
import { constants } from "ethers";
import { network } from "hardhat";

import { buildOrderStatus, toBN, toKey } from "../utils/encoding";
import { getWalletWithEther } from "../utils/faucet";
import { seaportFixture } from "../utils/fixtures";

import type {
  ConsiderationInterface,
  TestERC1155,
  TestERC20,
} from "../../typechain-types";
import type { SeaportFixtures } from "../utils/fixtures";
import type { AdvancedOrder, ConsiderationItem } from "../utils/types";
import type { Wallet } from "ethers";

const IS_FIXED = true;

describe("Partial fill fractions can overflow to reset an order", async () => {
  let alice: Wallet;
  let bob: Wallet;
  let carol: Wallet;

  let order: AdvancedOrder;
  let orderHash: string;

  let marketplaceContract: ConsiderationInterface;
  let testERC1155: TestERC1155;
  let testERC20: TestERC20;

  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem1155: SeaportFixtures["getTestItem1155"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let mintAndApprove1155: SeaportFixtures["mintAndApprove1155"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async function () {
    if (process.env.REFERENCE) {
      this.skip();
    }

    alice = await getWalletWithEther();
    bob = await getWalletWithEther();
    carol = await getWalletWithEther();

    ({
      createOrder,
      getTestItem1155,
      getTestItem20,
      marketplaceContract,
      mintAndApprove1155,
      mintAndApproveERC20,
      testERC1155,
      testERC20,
    } = await seaportFixture(await getWalletWithEther()));

    await mintAndApprove1155(alice, marketplaceContract.address, 1, 1, 10);
    await mintAndApproveERC20(bob, marketplaceContract.address, 500);
    await mintAndApproveERC20(carol, marketplaceContract.address, 4500);
  });

  it("Alice has ten 1155 tokens she has approved Seaport to spend", async () => {
    expect(await testERC1155.balanceOf(alice.address, 1)).to.eq(10);
  });

  it("Alice creates a partially fillable order to sell two 1155 tokens for 1000 DAI", async () => {
    const offer = [getTestItem1155(1, 2, 2)];

    const consideration: ConsiderationItem[] = [
      getTestItem20(1000, 1000, alice.address),
    ];

    const results = await createOrder(
      alice,
      constants.AddressZero, // zone
      offer,
      consideration,
      1, // PARTIAL_OPEN
      [], // criteria
      null, // timeFlag
      alice, // signer
      constants.HashZero, // zoneHash
      constants.HashZero, // conduitKey
      true // extraCheap
    );
    order = results.order;
    orderHash = results.orderHash;

    // OrderStatus is not validated
    let orderStatus = await marketplaceContract.getOrderStatus(orderHash);
    expect({ ...orderStatus }).to.deep.equal(
      buildOrderStatus(false, false, 0, 0)
    );

    // Bob validates the order
    const tx = await marketplaceContract.connect(bob).validate([order]);

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

    // OrderStatus is validated
    orderStatus = await marketplaceContract.getOrderStatus(orderHash);
    expect({ ...orderStatus }).to.deep.equal(
      buildOrderStatus(true, false, 0, 0)
    );
  });

  describe("Bob partially fills 1/2 of Alice's order", () => {
    it("Bob receives one 1155 token", async () => {
      order.numerator = 1;
      order.denominator = 2;
      await marketplaceContract
        .connect(bob)
        .fulfillAdvancedOrder(order, [], toKey(0), bob.address);
      expect(await testERC1155.balanceOf(bob.address, 1)).to.eq(1);
    });

    it("Alice receives 500 DAI", async () => {
      expect(await testERC20.balanceOf(alice.address)).to.eq(500);
    });
  });

  describe("Carol attempts to fill the order multiple times", () => {
    it("Carol fills the order with a fraction that overflows", async () => {
      order.numerator = toBN(2).pow(118);
      order.denominator = toBN(2).pow(119);
      await marketplaceContract
        .connect(carol)
        .fulfillAdvancedOrder(order, [], toKey(0), carol.address);
    });

    it("Carol receives one 1155 token from Alice", async () => {
      expect(await testERC1155.balanceOf(carol.address, 1)).to.eq(1);
      expect(await testERC1155.balanceOf(alice.address, 1)).to.eq(8);
    });

    it("Carol pays Alice 500 DAI", async () => {
      expect(await testERC20.balanceOf(carol.address)).to.eq(4000);
      expect(await testERC20.balanceOf(alice.address)).to.eq(1000);
    });

    if (!IS_FIXED) {
      it("Alice's order is reset and marked as 0% filled", async () => {
        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, toBN(0), toBN(0))
        );
      });

      it("Carol fills the same order multiple times", async () => {
        for (let i = 0; i < 4; i++) {
          order.numerator = toBN(2).pow(1);
          order.denominator = toBN(2).pow(2);
          await marketplaceContract
            .connect(carol)
            .fulfillAdvancedOrder(order, [], toKey(0), carol.address);
          order.numerator = toBN(2).pow(118);
          order.denominator = toBN(2).pow(119);
          await marketplaceContract
            .connect(carol)
            .fulfillAdvancedOrder(order, [], toKey(0), carol.address);
        }
      });

      it("Carol receives Alice's remaining eight 1155 tokens", async () => {
        expect(await testERC1155.balanceOf(carol.address, 1)).to.eq(9);
        expect(await testERC1155.balanceOf(alice.address, 1)).to.eq(0);
      });

      it("Alice receives 4000 DAI", async () => {
        expect(await testERC20.balanceOf(carol.address)).to.eq(0);
        expect(await testERC20.balanceOf(alice.address)).to.eq(5000);
      });
    } else {
      it("Alice's order is marked as completely filled", async () => {
        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, toBN(2), toBN(2))
        );
      });
    }
  });
});
