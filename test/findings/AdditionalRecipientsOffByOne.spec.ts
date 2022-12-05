import { expect } from "chai";
import { constants } from "ethers";
import { hexZeroPad } from "ethers/lib/utils";
import { network } from "hardhat";
import { getScuffedContract } from "scuffed-abi";

import { buildOrderStatus, getBasicOrderParameters } from "../utils/encoding";
import { getWalletWithEther } from "../utils/faucet";
import { seaportFixture } from "../utils/fixtures";

import type {
  ConsiderationInterface,
  TestERC20,
  TestERC721,
} from "../../typechain-types";
import type { SeaportFixtures } from "../utils/fixtures";
import type { AdvancedOrder, ConsiderationItem } from "../utils/types";
import type { Wallet } from "ethers";

const IS_FIXED = true;

describe("Additional recipients off by one error allows skipping second consideration", async () => {
  let alice: Wallet;
  let bob: Wallet;
  let carol: Wallet;

  let order: AdvancedOrder;
  let orderHash: string;

  let marketplaceContract: ConsiderationInterface;
  let testERC20: TestERC20;
  let testERC721: TestERC721;

  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async function () {
    alice = await getWalletWithEther();
    bob = await getWalletWithEther();
    carol = await getWalletWithEther();

    ({
      createOrder,
      getTestItem20,
      getTestItem721,
      marketplaceContract,
      mintAndApprove721,
      mintAndApproveERC20,
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
