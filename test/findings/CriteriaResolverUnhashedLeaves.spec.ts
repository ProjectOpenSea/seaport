import { expect } from "chai";
import { constants } from "ethers";
import { network } from "hardhat";

import { merkleTree } from "../utils/criteria";
import { buildResolver, toBN, toKey } from "../utils/encoding";
import { getWalletWithEther } from "../utils/faucet";
import { seaportFixture } from "../utils/fixtures";

import type {
  ConsiderationInterface,
  TestERC20,
  TestERC721,
} from "../../typechain-types";
import type { SeaportFixtures } from "../utils/fixtures";
import type { AdvancedOrder } from "../utils/types";
import type { BigNumber, Wallet } from "ethers";

const IS_FIXED = true;

describe("Criteria resolver allows root hash to be given as a leaf", async () => {
  let alice: Wallet;
  let bob: Wallet;
  let carol: Wallet;

  let order: AdvancedOrder;

  let marketplaceContract: ConsiderationInterface;
  let testERC20: TestERC20;
  let testERC721: TestERC721;

  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let getTestItem721WithCriteria: SeaportFixtures["getTestItem721WithCriteria"];
  let mint721s: SeaportFixtures["mint721s"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];
  let set721ApprovalForAll: SeaportFixtures["set721ApprovalForAll"];

  let tokenIds: BigNumber[];
  let root: string;

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
      getTestItem20,
      getTestItem721WithCriteria,
      marketplaceContract,
      mint721s,
      mintAndApproveERC20,
      set721ApprovalForAll,
      testERC20,
      testERC721,
    } = await seaportFixture(await getWalletWithEther()));

    await mintAndApproveERC20(alice, marketplaceContract.address, 1000);
    await set721ApprovalForAll(bob, marketplaceContract.address);
    await set721ApprovalForAll(carol, marketplaceContract.address);

    tokenIds = await mint721s(bob, 10);
    ({ root } = merkleTree(tokenIds));
  });

  it("Alice makes an offer to buy any of 10 NFTs with a particular trait for 1000 DAI", async () => {
    const offer = [getTestItem20(1000, 1000)];
    const consideration = [
      getTestItem721WithCriteria(root, 1, 1, alice.address),
    ];

    const results = await createOrder(
      alice,
      constants.AddressZero, // zone
      offer,
      consideration,
      1, // FULL_OPEN
      [], // criteria
      null, // timeFlag
      alice, // signer
      constants.HashZero, // zoneHash
      constants.HashZero, // conduitKey
      true // extraCheap
    );
    order = results.order;
  });

  describe("Carol, the collection owner, attempts to fill Alice's order with an NFT outside of Alice's criteria", async () => {
    it("Carol mints a new NFT with its identifier set to the merkle tree's root hash", async () => {
      await testERC721.mint(carol.address, root);
      expect(tokenIds.filter((id) => id.eq(toBN(root))).length).to.eq(0);
    });

    if (!IS_FIXED) {
      it("Carol fills Alice's order, giving the merkle root as the token ID and an empty proof", async () => {
        const criteriaResolver = buildResolver(0, 1, 0, toBN(root), []);
        await marketplaceContract
          .connect(carol)
          .fulfillAdvancedOrder(
            order,
            [criteriaResolver],
            toKey(0),
            carol.address
          );
      });

      it("Carol receives 1000 DAI from Alice", async () => {
        expect(await testERC20.balanceOf(alice.address)).to.eq(0);
        expect(await testERC20.balanceOf(carol.address)).to.eq(1000);
      });

      it("Alice receives the merkle root identified token from Carol", async () => {
        expect(await testERC721.ownerOf(root)).to.equal(alice.address);
      });
    } else {
      it("Carol's attempt to fill Alice's order with the merkle root as the token ID reverts", async () => {
        const criteriaResolver = buildResolver(0, 1, 0, toBN(root), []);
        await expect(
          marketplaceContract
            .connect(carol)
            .fulfillAdvancedOrder(
              order,
              [criteriaResolver],
              toKey(0),
              carol.address
            )
        ).to.be.revertedWith("InvalidProof");
      });
    }
  });
});
