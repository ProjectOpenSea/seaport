import { expect } from "chai";
import { ethers } from "hardhat";

import { faucet } from "../utils/faucet";

import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import type { Contract } from "ethers";

const EMPTY_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
const IS_VALID_EXTRA_DATA_MAGIC = "0x33131570";
const IS_VALID_MAGIC = "0x0e1d31dc";

describe("Test Server Signed Zone", function () {
  const { provider } = ethers;

  let owner: SignerWithAddress;
  let pausableZone: Contract;

  before(async () => {
    [owner] = await ethers.getSigners();
    await faucet(owner.address, provider);
  });

  beforeEach(async () => {
    const pausableZoneFactory = await ethers.getContractFactory(
      "TestPausableZone"
    );
    pausableZone = await pausableZoneFactory.deploy(NULL_ADDRESS);
  });

  it("Success", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: pausableZone.address,
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

    expect(
      await pausableZone.isValidOrderIncludingExtraData(
        EMPTY_BYTES32,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.equal(IS_VALID_EXTRA_DATA_MAGIC);

    expect(
      await pausableZone.isValidOrder(
        EMPTY_BYTES32,
        owner.address,
        NULL_ADDRESS,
        EMPTY_BYTES32
      )
    ).to.equal(IS_VALID_MAGIC);
  });

  it("paused", async function () {
    await pausableZone.setPaused(true);
    expect(await pausableZone.isPaused()).to.be.equal(true);

    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: pausableZone.address,
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

    await expect(
      pausableZone.isValidOrderIncludingExtraData(
        EMPTY_BYTES32,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.be.revertedWith("Paused");

    await expect(
      pausableZone.isValidOrder(
        EMPTY_BYTES32,
        owner.address,
        NULL_ADDRESS,
        EMPTY_BYTES32
      )
    ).to.be.revertedWith("Paused");
  });

  it("Set to current paused value", async function () {
    await expect(pausableZone.setPaused(false)).to.be.revertedWith(
      "SetToCurrentPauseValue"
    );
  });
});
