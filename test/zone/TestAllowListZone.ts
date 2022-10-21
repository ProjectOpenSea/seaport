import { expect } from "chai";
import { defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { ethers, network } from "hardhat";
import { MerkleTree } from "merkletreejs";

import { faucet } from "../utils/faucet";

import type { TestAllowListZone } from "../../typechain-types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const EMPTY_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
const IS_VALID_EXTRA_DATA_MAGIC = "0x33131570";

describe("Test Allow List Zone", function () {
  const { provider } = ethers;

  let owner: SignerWithAddress;
  let otherAccounts: SignerWithAddress[];
  let allowListZone: TestAllowListZone;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    [owner, ...otherAccounts] = await ethers.getSigners();
    await faucet(owner.address, provider);

    const allowListZoneFactory = await ethers.getContractFactory(
      "TestAllowListZone"
    );
    allowListZone = await allowListZoneFactory.deploy(NULL_ADDRESS);
  });

  it("Root not set", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: allowListZone.address,
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

    const leaves = [otherAccounts[0].address, owner.address];
    const tree = new MerkleTree(leaves, keccak256, {
      sortPairs: true,
      hashLeaves: true,
    });

    const merkleRoot = EMPTY_BYTES32; // Proof not set

    const merkleRootEncoded = defaultAbiCoder.encode(["bytes32"], [merkleRoot]);

    const merkleProofData = defaultAbiCoder.encode(
      ["bytes32[]"],
      [tree.getHexProof(keccak256(owner.address))]
    );
    const fixedExtraData = defaultAbiCoder.encode(
      ["bytes[]"],
      [[merkleRootEncoded]]
    );

    const extraDataInput = defaultAbiCoder.encode(
      ["bytes[]", "bytes[]"],
      [[merkleRootEncoded], [merkleProofData]]
    );
    const extraDataGiven = ethers.utils.solidityPack(
      ["uint8", "bytes"],
      [2, extraDataInput]
    );

    advancedOrder.extraData = extraDataGiven;
    advancedOrder.parameters.zoneHash = keccak256(fixedExtraData);

    await expect(
      allowListZone.isValidOrderIncludingExtraData(
        EMPTY_BYTES32,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.be.revertedWith("InvalidProof");
  });

  it("Success Version 2", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: allowListZone.address,
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

    const leaves = [otherAccounts[0].address, owner.address];
    const tree = new MerkleTree(leaves, keccak256, {
      sortPairs: true,
      hashLeaves: true,
    });

    const merkleRoot = tree.getHexRoot();

    const merkleRootEncoded = defaultAbiCoder.encode(["bytes32"], [merkleRoot]);

    const merkleProofData = defaultAbiCoder.encode(
      ["bytes32[]"],
      [tree.getHexProof(keccak256(owner.address))]
    );
    const fixedExtraData = defaultAbiCoder.encode(
      ["bytes[]"],
      [[merkleRootEncoded]]
    );

    const extraDataInput = defaultAbiCoder.encode(
      ["bytes[]", "bytes[]"],
      [[merkleRootEncoded], [merkleProofData]]
    );
    const extraDataGiven = ethers.utils.solidityPack(
      ["uint8", "bytes"],
      [2, extraDataInput]
    );

    advancedOrder.extraData = extraDataGiven;
    advancedOrder.parameters.zoneHash = keccak256(fixedExtraData);

    expect(
      await allowListZone.isValidOrderIncludingExtraData(
        EMPTY_BYTES32,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.equal(IS_VALID_EXTRA_DATA_MAGIC);

    await expect(
      allowListZone.isValidOrder(
        EMPTY_BYTES32,
        owner.address,
        NULL_ADDRESS,
        EMPTY_BYTES32
      )
    ).to.be.revertedWith("ExtraDataRequired");
  });

  it("Success Version 3", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: allowListZone.address,
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

    const leaves = [otherAccounts[0].address, owner.address];
    const tree = new MerkleTree(leaves, keccak256, {
      sortPairs: true,
      hashLeaves: true,
    });

    const merkleRoot = tree.getHexRoot();

    const merkleRootData = defaultAbiCoder.encode(["bytes32"], [merkleRoot]);
    const merkleProofData = defaultAbiCoder.encode(
      ["bytes32[]"],
      [tree.getHexProof(keccak256(owner.address))]
    );

    const hashesArray = defaultAbiCoder.encode(
      ["bytes32[]"],
      [[keccak256(merkleRootData), EMPTY_BYTES32]]
    );

    const extraDataInput = defaultAbiCoder.encode(
      ["bytes[]"],
      [[merkleRootData, merkleProofData, hashesArray]]
    );
    const extraDataGiven = ethers.utils.solidityPack(
      ["uint8", "bytes"],
      [3, extraDataInput]
    );

    advancedOrder.extraData = extraDataGiven;
    advancedOrder.parameters.zoneHash = keccak256(hashesArray);

    expect(
      await allowListZone.isValidOrderIncludingExtraData(
        EMPTY_BYTES32,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.equal(IS_VALID_EXTRA_DATA_MAGIC);

    await expect(
      allowListZone.isValidOrder(
        EMPTY_BYTES32,
        owner.address,
        NULL_ADDRESS,
        EMPTY_BYTES32
      )
    ).to.be.reverted;
  });
});
