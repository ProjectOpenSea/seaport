import { expect } from "chai";
import { defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import hre, { ethers, network } from "hardhat";

import { randomHex } from "../utils/encoding";
import { faucet } from "../utils/faucet";
import { seaportFixture } from "../utils/fixtures";

import type {
  ConsiderationInterface,
  TestCommitAndRevealZone,
} from "../../typechain-types";
import type { AdvancedOrderStruct } from "../../typechain-types/contracts/zones/modules/CommitAndReveal";

const EMPTY_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
const IS_VALID_EXTRA_DATA_MAGIC = "0x33131570";

describe("Test Commit and Reveal Zone", function () {
  const { provider } = ethers;

  let marketplaceContract: ConsiderationInterface;
  let commitAndRevealZone: TestCommitAndRevealZone;
  let advancedOrder: AdvancedOrderStruct;
  let orderHash: string;
  let secret: string;
  const owner = new ethers.Wallet(randomHex(32), provider);

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await faucet(owner.address, provider);

    ({ marketplaceContract } = await seaportFixture(owner));
  });

  beforeEach(async function () {
    const commitAndRevealZoneFactory = await ethers.getContractFactory(
      "TestCommitAndRevealZone"
    );
    commitAndRevealZone = await commitAndRevealZoneFactory.deploy(NULL_ADDRESS);

    advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: commitAndRevealZone.address,
        offer: [],
        consideration: [],
        startTime: 0,
        endTime: 0,
        salt: 0,
        totalOriginalConsiderationItems: 0,
        orderType: 0,
        conduitKey: EMPTY_BYTES32,
      },
      numerator: 0,
      denominator: 0,
      signature: "0x",
    };

    orderHash = await marketplaceContract.getOrderHash({
      ...advancedOrder.parameters,
      counter: 0,
    });

    secret = keccak256(defaultAbiCoder.encode(["string"], ["PASSWORD"]));

    const messageToCommit = keccak256(
      ethers.utils.solidityPack(
        ["address", "bytes32", "bytes32"],
        [owner.address, orderHash, secret]
      )
    );

    await commitAndRevealZone.commitMessage(messageToCommit);

    const encodedSecret = defaultAbiCoder.encode(["bytes32"], [secret]);
    const extraData = defaultAbiCoder.encode(["bytes[]"], [[encodedSecret]]);

    advancedOrder.extraData = extraData;
  });

  it("Success", async function () {
    await hre.network.provider.request({
      method: "evm_increaseTime",
      params: [360],
    });
    await hre.network.provider.send("evm_mine");

    expect(
      await commitAndRevealZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.equal(IS_VALID_EXTRA_DATA_MAGIC);

    await expect(
      commitAndRevealZone.isValidOrder(
        EMPTY_BYTES32,
        owner.address,
        NULL_ADDRESS,
        EMPTY_BYTES32
      )
    ).to.be.revertedWith("ExtraDataRequired");
  });

  it("Too early", async function () {
    await expect(
      commitAndRevealZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.be.revertedWith("InvalidSecret");
  });

  it("Too late", async function () {
    await hre.network.provider.request({
      method: "evm_increaseTime",
      params: [60 * 15.1],
    });
    await hre.network.provider.send("evm_mine");

    await expect(
      commitAndRevealZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.be.revertedWith("InvalidSecret");
  });

  it("Invalid secret", async function () {
    const encodedSecret = defaultAbiCoder.encode(
      ["bytes32"],
      [secret.substring(0, secret.length - 4) + "0000"]
    );
    const extraData = defaultAbiCoder.encode(["bytes[]"], [[encodedSecret]]);

    advancedOrder.extraData = extraData;

    await hre.network.provider.request({
      method: "evm_increaseTime",
      params: [360],
    });
    await hre.network.provider.send("evm_mine");

    await expect(
      commitAndRevealZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.be.revertedWith("InvalidSecret");
  });

  it("Can't commit message twice", async function () {
    const messageToCommit = keccak256(
      ethers.utils.solidityPack(
        ["address", "bytes32", "bytes32"],
        [owner.address, orderHash, secret]
      )
    );

    await expect(
      commitAndRevealZone.commitMessage(messageToCommit)
    ).to.be.revertedWith("MessageAlreadyCommitted");
  });
});
