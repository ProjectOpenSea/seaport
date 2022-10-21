import { expect } from "chai";
import { defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { ethers, network } from "hardhat";

import { randomHex } from "../utils/encoding";
import { faucet } from "../utils/faucet";
import { seaportFixture } from "../utils/fixtures";

import type {
  ConsiderationInterface,
  TestServerSignedZone,
} from "../../typechain-types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const EMPTY_BYTES32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
const IS_VALID_EXTRA_DATA_MAGIC = "0x33131570";

describe("Test Server Signed Zone", function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);
  let otherAccounts: SignerWithAddress[];
  let serverSignedZone: TestServerSignedZone;
  let marketplaceContract: ConsiderationInterface;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await faucet(owner.address, provider);

    ({ marketplaceContract } = await seaportFixture(owner));
    [, ...otherAccounts] = await ethers.getSigners();
  });

  beforeEach(async () => {
    const serverSignedZoneFactory = await ethers.getContractFactory(
      "TestServerSignedZone",
      owner
    );
    serverSignedZone = await serverSignedZoneFactory.deploy(
      marketplaceContract.address
    );
  });

  it("Success Version 0", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: serverSignedZone.address,
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

    const { chainId } = await ethers.provider.getNetwork();
    const orderHash = await marketplaceContract.getOrderHash({
      ...advancedOrder.parameters,
      counter: 0,
    });
    const serverSig = await otherAccounts[2]._signTypedData(
      {
        name: "Zone",
        chainId,
        verifyingContract: serverSignedZone.address,
      },
      {
        SignOrder: [{ name: "orderHash", type: "bytes32" }],
      },
      { orderHash }
    );

    const extraDataBytes = defaultAbiCoder.encode(["bytes[]"], [[serverSig]]);
    advancedOrder.extraData = extraDataBytes;

    await serverSignedZone.setSigner(otherAccounts[2].address);

    expect(
      await serverSignedZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.equal(IS_VALID_EXTRA_DATA_MAGIC);
  });

  it("Signer not set", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: serverSignedZone.address,
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

    const { chainId } = await ethers.provider.getNetwork();
    const orderHash = await marketplaceContract.getOrderHash({
      ...advancedOrder.parameters,
      counter: 0,
    });
    const serverSig = await otherAccounts[2]._signTypedData(
      {
        name: "Zone",
        chainId,
        verifyingContract: serverSignedZone.address,
      },
      {
        SignOrder: [{ name: "orderHash", type: "bytes32" }],
      },
      { orderHash }
    );

    const extraData = defaultAbiCoder.encode(["bytes[]"], [[serverSig]]);
    advancedOrder.extraData = extraData;

    // Revert prior to setting signer
    await expect(
      serverSignedZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.be.revertedWith("InvalidSignature");
  });

  it("Invalid Sig", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: serverSignedZone.address,
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

    const { chainId } = await ethers.provider.getNetwork();
    const orderHash = await marketplaceContract.getOrderHash({
      ...advancedOrder.parameters,
      counter: 0,
    });
    let serverSig = await otherAccounts[2]._signTypedData(
      {
        name: "Zone",
        chainId,
        verifyingContract: serverSignedZone.address,
      },
      {
        SignOrder: [{ name: "orderHash", type: "bytes32" }],
      },
      { orderHash }
    );

    // Make sig invalid
    serverSig = "0x00";

    const extraData = defaultAbiCoder.encode(["bytes[]"], [[serverSig]]);
    advancedOrder.extraData = extraData;

    await serverSignedZone.setSigner(otherAccounts[2].address);

    await expect(
      serverSignedZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.be.revertedWith("ECDSA: invalid signature");
  });

  it("Success Version 2", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: serverSignedZone.address,
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

    const { chainId } = await ethers.provider.getNetwork();
    const orderHash = await marketplaceContract.getOrderHash({
      ...advancedOrder.parameters,
      counter: 0,
    });
    const serverSig = await otherAccounts[2]._signTypedData(
      {
        name: "Zone",
        chainId,
        verifyingContract: serverSignedZone.address,
      },
      {
        SignOrder: [{ name: "orderHash", type: "bytes32" }],
      },
      { orderHash }
    );

    const fixedExtraDataBytes = defaultAbiCoder.encode(["bytes[]"], [[]]);
    const inputExtraDataBytes = defaultAbiCoder.encode(
      ["bytes[]", "bytes[]"],
      [[], [serverSig]]
    );

    advancedOrder.extraData = ethers.utils.solidityPack(
      ["uint8", "bytes"],
      [2, inputExtraDataBytes]
    );

    advancedOrder.parameters.zoneHash = keccak256(fixedExtraDataBytes);

    await serverSignedZone.setSigner(otherAccounts[2].address);

    expect(
      await serverSignedZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.equal(IS_VALID_EXTRA_DATA_MAGIC);
  });

  it("Invalid extra data version 2", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: serverSignedZone.address,
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

    const { chainId } = await ethers.provider.getNetwork();
    const orderHash = await marketplaceContract.getOrderHash({
      ...advancedOrder.parameters,
      counter: 0,
    });
    const serverSig = await otherAccounts[2]._signTypedData(
      {
        name: "Zone",
        chainId,
        verifyingContract: serverSignedZone.address,
      },
      {
        SignOrder: [{ name: "orderHash", type: "bytes32" }],
      },
      { orderHash }
    );

    const fixedExtraDataBytes = defaultAbiCoder.encode(["bytes[]"], [[]]);
    const inputExtraDataBytes = defaultAbiCoder.encode(
      ["bytes[]", "bytes[]"],
      [[], [serverSig]]
    );

    advancedOrder.extraData = ethers.utils.solidityPack(
      ["uint8", "bytes"],
      [2, inputExtraDataBytes]
    );

    advancedOrder.parameters.zoneHash =
      "0x00" + keccak256(fixedExtraDataBytes).substring(4); // kill the hash

    await serverSignedZone.setSigner(otherAccounts[2].address);

    await expect(
      serverSignedZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.be.revertedWith("InvalidExtraData");
  });

  it("Success Version 3", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: serverSignedZone.address,
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

    const { chainId } = await ethers.provider.getNetwork();
    const orderHash = await marketplaceContract.getOrderHash({
      ...advancedOrder.parameters,
      counter: 0,
    });
    const serverSig = await otherAccounts[2]._signTypedData(
      {
        name: "Zone",
        chainId,
        verifyingContract: serverSignedZone.address,
      },
      {
        SignOrder: [{ name: "orderHash", type: "bytes32" }],
      },
      { orderHash }
    );

    const hashesArray = defaultAbiCoder.encode(
      ["bytes32[]"],
      [[EMPTY_BYTES32]]
    );

    const extraDataBytes = defaultAbiCoder.encode(
      ["bytes[]"],
      [[serverSig, hashesArray]]
    );
    const extraDataAll = ethers.utils.solidityPack(
      ["uint8", "bytes"],
      [3, extraDataBytes]
    );

    advancedOrder.extraData = extraDataAll;

    advancedOrder.parameters.zoneHash = keccak256(hashesArray);

    await serverSignedZone.setSigner(otherAccounts[2].address);

    expect(
      await serverSignedZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.equal(IS_VALID_EXTRA_DATA_MAGIC);

    await expect(
      serverSignedZone.isValidOrder(
        EMPTY_BYTES32,
        owner.address,
        NULL_ADDRESS,
        EMPTY_BYTES32
      )
    ).to.be.revertedWith("ExtraDataRequired");
  });

  it("Invalid extra data version 3", async function () {
    const advancedOrder = {
      extraData: "0x",
      parameters: {
        zoneHash: EMPTY_BYTES32,
        offerer: NULL_ADDRESS,
        zone: serverSignedZone.address,
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

    const { chainId } = await ethers.provider.getNetwork();
    const orderHash = await marketplaceContract.getOrderHash({
      ...advancedOrder.parameters,
      counter: 0,
    });
    const serverSig = await otherAccounts[2]._signTypedData(
      {
        name: "Zone",
        chainId,
        verifyingContract: serverSignedZone.address,
      },
      {
        SignOrder: [{ name: "orderHash", type: "bytes32" }],
      },
      { orderHash }
    );

    const hashesArray = defaultAbiCoder.encode(
      ["bytes32[]"],
      [[EMPTY_BYTES32]]
    );

    const extraDataBytes = defaultAbiCoder.encode(
      ["bytes[]"],
      [[serverSig, hashesArray]]
    );
    const extraDataAll = ethers.utils.solidityPack(
      ["uint8", "bytes"],
      [3, extraDataBytes]
    );

    advancedOrder.extraData = extraDataAll;

    advancedOrder.parameters.zoneHash =
      "0x00" + keccak256(hashesArray).substring(4); // Kill the hash

    await serverSignedZone.setSigner(otherAccounts[2].address);

    await expect(
      serverSignedZone.isValidOrderIncludingExtraData(
        orderHash,
        owner.address,
        advancedOrder,
        [],
        []
      )
    ).to.be.revertedWith("InvalidExtraData");
  });
});
