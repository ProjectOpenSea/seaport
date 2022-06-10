import { expect } from "chai";
import { constants, Wallet } from "ethers";
import { network } from "hardhat";
import {
  ConsiderationInterface,
  TestERC20,
  TestERC721,
} from "../../typechain-types";
import { toFulfillment } from "../utils/encoding";
import { seaportFixture, SeaportFixtures } from "../utils/fixtures";
import { getWalletWithEther } from "../utils/impersonate";
import { AdvancedOrder, OfferItem } from "../utils/types";

const IS_FIXED = true;

describe("Fulfillment applier allows overflow when a missing item is provided", async () => {
  let alice: Wallet;
  let bob: Wallet;
  let order: AdvancedOrder;
  let maliciousOrder: AdvancedOrder;
  let testERC20: TestERC20;
  let testERC721: TestERC721;
  let marketplaceContract: ConsiderationInterface;
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
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
    ({
      mintAndApprove721,
      mintAndApproveERC20,
      marketplaceContract,
      getTestItem20,
      getTestItem721,
      createOrder,
      testERC20,
      testERC721,
    } = await seaportFixture(await getWalletWithEther()));
    // ERC721 with ID = 1
    await mintAndApprove721(alice, marketplaceContract.address, 1);
    // ERC20 with amount = 1100
    await mintAndApproveERC20(bob, marketplaceContract.address, 1);
  });

  it("Alice offers to sell an NFT for 1000 DAI", async () => {
    const offer = [getTestItem721(1, 1, 1)];
    const consideration = [getTestItem20(1000, 1000, alice.address)];

    const results = await createOrder(
      alice,
      constants.AddressZero, // zone
      offer,
      consideration,
      0, // FULL_OPEN
      [], // criteria
      null, // timeFlag
      alice, // signer
      constants.HashZero, // zoneHash
      constants.HashZero, // conduitKey
      true // extraCheap
    );
    order = results.order;
  });

  it("Bob constructs a malicious order with one empty consideration and one which will overflow Alice's", async () => {
    const offer: OfferItem[] = [getTestItem20(1, 1)];
    const consideration = [
      getTestItem721(1, 1, 1, bob.address),
      getTestItem20(0, 0, alice.address),
      getTestItem20(
        constants.MaxUint256.sub(998),
        constants.MaxUint256.sub(998),
        alice.address
      ),
    ];
    const results = await createOrder(
      bob,
      constants.AddressZero,
      offer,
      consideration,
      1
    );
    maliciousOrder = results.order;
  });

  describe("Bob attempts to match Alice's order with his malicious order", () => {
    const fulfillments = [
      toFulfillment([[0, 0]], [[1, 0]]),
      toFulfillment(
        [[1, 0]],
        [
          [0, 0],
          [1, 1],
          [1, 2],
        ]
      ),
    ];

    if (!IS_FIXED) {
      it("Bob is able to match Alice's order with his malicious one", async () => {
        await marketplaceContract
          .connect(bob)
          .matchAdvancedOrders([order, maliciousOrder], [], fulfillments);
      });

      it("Bob receives Alice's NFT, having paid 1 DAI", async () => {
        expect(await testERC721.ownerOf(1)).to.equal(bob.address);
        expect(await testERC20.balanceOf(bob.address)).to.equal(0);
      });

      it("Alice receives 1 DAI", async () => {
        expect(await testERC20.balanceOf(alice.address)).to.equal(1);
      });
    } else {
      it("The transaction reverts", async () => {
        await expect(
          marketplaceContract
            .connect(bob)
            .matchAdvancedOrders([order, maliciousOrder], [], fulfillments)
        ).to.be.revertedWith(
          "panic code 0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
        );
      });
    }
  });
});
