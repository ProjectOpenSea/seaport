import { expect } from "chai";
import { constants, Wallet } from "ethers";
import { network } from "hardhat";

import {
  ConsiderationInterface,
  TestERC1155,
  TestERC20,
} from "../../typechain-types";
import { buildOrderStatus, toBN, toKey } from "../utils/encoding";
import { seaportFixture, SeaportFixtures } from "../utils/fixtures";
import { getWalletWithEther } from "../utils/impersonate";
import { AdvancedOrder, ConsiderationItem } from "../utils/types";

const IS_FIXED = true;

describe("Partial fill fractions can overflow to reset an order", async () => {
  let alice: Wallet;
  let bob: Wallet;
  let carol: Wallet;
  let order: AdvancedOrder;
  let orderHash: string;
  let testERC20: TestERC20;
  let testERC1155: TestERC1155;
  let marketplaceContract: ConsiderationInterface;
  let mintAndApprove1155: SeaportFixtures["mintAndApprove1155"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let getTestItem1155: SeaportFixtures["getTestItem1155"];
  let createOrder: SeaportFixtures["createOrder"];

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
      mintAndApprove1155,
      mintAndApproveERC20,
      marketplaceContract,
      getTestItem20,
      getTestItem1155,
      createOrder,
      testERC20,
      testERC1155,
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
    await expect(marketplaceContract.connect(bob).validate([order]))
      .to.emit(marketplaceContract, "OrderValidated")
      .withArgs(orderHash, alice.address, constants.AddressZero);

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
        .fulfillAdvancedOrder(order, [], toKey(false), bob.address);
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
        .fulfillAdvancedOrder(order, [], toKey(false), carol.address);
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
            .fulfillAdvancedOrder(order, [], toKey(false), carol.address);
          order.numerator = toBN(2).pow(118);
          order.denominator = toBN(2).pow(119);
          await marketplaceContract
            .connect(carol)
            .fulfillAdvancedOrder(order, [], toKey(false), carol.address);
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
