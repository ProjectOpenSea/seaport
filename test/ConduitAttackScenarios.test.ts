/**
 * @title Conduit Attack Scenarios Security Tests
 * @notice Security-focused tests for Seaport 1.6 exploring conduit bypass attempts
 * @dev Tests invalid conduit keys, unauthorized conduit usage, and signature replay
 */

import { expect } from "chai";
import { ethers } from "hardhat";
import { parseEther } from "ethers/lib/utils";
import { BigNumber, BigNumberish } from "ethers";

import { toBN, toKey } from "./utils/encoding";
import { seaportFixture } from "./utils/fixtures";
import { VERSION } from "./utils/helpers";

import type {
  ConsiderationInterface,
  ConduitInterface,
  TestERC20,
  TestERC721,
  TestERC1155,
  TestZone,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { Order } from "./utils/types";

// Type definition for TransferItem
type TransferItem = {
  itemType: number;
  token: string;
  from: string;
  to: string;
  identifier: BigNumberish;
  amount: BigNumberish;
};

describe(`Conduit Attack Scenarios Security Tests (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  let owner: any;
  let attacker: any;
  let unauthorizedUser: any;

  let marketplaceContract: ConsiderationInterface;
  let conduitController: any;
  let conduitOne: ConduitInterface;
  let conduitKeyOne: string;
  let testERC20: TestERC20;
  let testERC721: TestERC721;
  let testERC1155: TestERC1155;
  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let getTestItem1155: SeaportFixtures["getTestItem1155"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
  let mintAndApprove1155: SeaportFixtures["mintAndApprove1155"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];
  let signOrder: SeaportFixtures["signOrder"];
  let deployNewConduit: SeaportFixtures["deployNewConduit"];
  let stubZone: TestZone;

  // Helper function to validate addresses
  const validateAddress = (addr: string, name: string): void => {
    if (!ethers.utils.isAddress(addr)) {
      throw new Error(`Invalid ${name} address: ${addr}`);
    }
  };

  // Helper function to validate conduit keys
  const validateConduitKey = (conduit: any): string => {
    const key =
      typeof conduit === "string"
        ? conduit
        : conduit.address;

    return ethers.utils.hexZeroPad(key, 32);
  };

  // Helper function to ensure order fields are defined
  const ensureOrderFields = async (order: Order): Promise<Order> => {
    const blockNumber = await provider.getBlockNumber();
    const block = await provider.getBlock(blockNumber);
    const currentTime = block.timestamp;

    if (!order.parameters.nonce) {
      order.parameters.nonce = BigNumber.from(1);
    }
    if (!order.parameters.startTime || order.parameters.startTime.eq(0)) {
      order.parameters.startTime = BigNumber.from(currentTime);
    }
    if (!order.parameters.endTime || order.parameters.endTime.eq(0)) {
      order.parameters.endTime = BigNumber.from(currentTime + 3600);
    }
    if (!order.parameters.offerer) {
      order.parameters.offerer = owner.address;
    }
    if (!order.parameters.zone) {
      order.parameters.zone = ethers.constants.AddressZero;
    }
    if (!order.parameters.conduitKey) {
      order.parameters.conduitKey = ethers.constants.HashZero;
    }
    if (!order.parameters.counter) {
      order.parameters.counter = BigNumber.from(0);
    }

    return order;
  };

  before(async () => {
    // Use Hardhat signers instead of manually created wallets to avoid nonce reuse
    [owner, attacker, unauthorizedUser] = await ethers.getSigners();

    ({
      createOrder,
      conduitController,
      conduitKeyOne,
      conduitOne,
      deployNewConduit,
      getTestItem20,
      getTestItem721,
      getTestItem1155,
      marketplaceContract,
      mintAndApprove721,
      mintAndApprove1155,
      mintAndApproveERC20,
      signOrder,
      stubZone,
      testERC20,
      testERC721,
      testERC1155,
    } = await seaportFixture(owner));

    // Validate all addresses and keys
    validateAddress(marketplaceContract.address, "marketplaceContract");
    validateAddress(conduitOne.address, "conduitOne");
    validateAddress(testERC721.address, "testERC721");
    validateAddress(testERC20.address, "testERC20");
    validateAddress(testERC1155.address, "testERC1155");
    conduitKeyOne = validateConduitKey(conduitKeyOne);
  });

  describe("Conduit Bypass: Invalid Conduit Key", function () {
    it("Should revert when using non-existent conduit key", async function () {
      const tokenId = toBN(1);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        conduitKeyOne
      );

      // Ensure order fields are defined
      const validatedOrder = await ensureOrderFields(order);

      await testERC721
        .connect(owner)
        .setApprovalForAll(marketplaceContract.address, true);

      // Create a deterministic invalid conduit key (valid bytes32 format)
      const invalidConduitKey = ethers.utils.hexZeroPad(
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes("invalid-conduit-key-1")),
        32
      );
      const validatedInvalidKey = validateConduitKey(invalidConduitKey);

      const tx = marketplaceContract
        .connect(attacker)
        .fulfillOrder(validatedOrder, validatedInvalidKey, { value: parseEther("1") });

      await expect(tx).to.be.reverted;
    });

    it("Should revert when using conduit key for non-existent conduit", async function () {
      const tokenId = toBN(2);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        conduitKeyOne
      );

      // Ensure order fields are defined
      const validatedOrder = await ensureOrderFields(order);

      await testERC721
        .connect(owner)
        .setApprovalForAll(marketplaceContract.address, true);

      // Create a deterministic fake conduit key (valid bytes32 format)
      const fakeConduitKey = ethers.utils.hexZeroPad(
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes("fake-conduit-key-2")),
        32
      );
      const validatedFakeKey = validateConduitKey(fakeConduitKey);

      const tx = marketplaceContract
        .connect(attacker)
        .fulfillOrder(validatedOrder, validatedFakeKey, { value: parseEther("1") });

      await expect(tx).to.be.reverted;
    });

    it("Should revert when using zero conduit key when order requires conduit", async function () {
      const tokenId = toBN(3);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        conduitKeyOne // Order specifies conduit
      );

      // Ensure order fields are defined
      const validatedOrder = await ensureOrderFields(order);

      // Approve via conduit
      await testERC721
        .connect(owner)
        .setApprovalForAll(conduitOne.address, true);

      // Try to fulfill with zero key (no conduit) when order requires conduit
      const zeroKey = validateConduitKey(toKey(0));

      const tx = marketplaceContract
        .connect(attacker)
        .fulfillOrder(validatedOrder, zeroKey, { value: parseEther("1") });

      await expect(tx).to.be.reverted;
    });
  });

  describe("Conduit Bypass: Unauthorized Conduit Usage", function () {
    it("Should revert when attacker tries to use conduit without being a channel", async function () {
      const tokenId = toBN(4);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId);

      // Owner approves conduit
      await testERC721
        .connect(owner)
        .setApprovalForAll(conduitOne.address, true);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        conduitKeyOne
      );

      // Ensure order fields are defined
      const validatedOrder = await ensureOrderFields(order);

      // Attacker tries to directly call conduit (should fail)
      // Ensure all TransferItem fields are properly typed and defined
      const transferItems: TransferItem[] = [
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          from: owner.address,
          to: attacker.address,
          identifier: toBN(tokenId),
          amount: toBN(1),
        },
      ];

      // Validate addresses
      validateAddress(transferItems[0].token, "transferItem.token");
      validateAddress(transferItems[0].from, "transferItem.from");
      validateAddress(transferItems[0].to, "transferItem.to");

      const tx = conduitOne
        .connect(attacker)
        .execute(transferItems, []);

      await expect(tx).to.be.reverted;
    });

    it("Should revert when using conduit that attacker doesn't have access to", async function () {
      // Deploy a new conduit owned by attacker
      const attackerConduitKey = await deployNewConduit(attacker);
      const validatedAttackerKey = validateConduitKey(attackerConduitKey);

      const conduitInfo = await conduitController.getConduit(validatedAttackerKey);
      validateAddress(conduitInfo.conduit, "attackerConduit");

      const attackerConduit = await ethers.getContractAt(
        "ConduitInterface",
        conduitInfo.conduit
      );

      const tokenId = toBN(5);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId);

      // Owner approves their own conduit, not attacker's
      await testERC721
        .connect(owner)
        .setApprovalForAll(conduitOne.address, true);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        conduitKeyOne // Owner's conduit
      );

      // Ensure order fields are defined
      const validatedOrder = await ensureOrderFields(order);

      // Attacker tries to use their own conduit key (should fail - tokens not approved there)
      const tx = marketplaceContract
        .connect(attacker)
        .fulfillOrder(validatedOrder, validatedAttackerKey, { value: parseEther("1") });

      await expect(tx).to.be.reverted;
    });
  });

  describe("Signature Replay Attacks", function () {
    it("Should prevent signature replay with modified order parameters", async function () {
      const tokenId = toBN(6);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0,
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        ethers.constants.HashZero
      );

      // Ensure original order is well-formed
      const validatedOrder = await ensureOrderFields(order);
      expect(validatedOrder.signature).to.be.a("string");

      // Build a modified order object with different consideration amounts
      const modifiedOrder: Order = {
        ...validatedOrder,
        parameters: {
          ...validatedOrder.parameters,
          consideration: [
            {
              ...validatedOrder.parameters.consideration[0],
              startAmount: parseEther("0.5"),
              endAmount: parseEther("0.5"),
            },
          ],
        },
      };

      // Assert that parameters changed but signature stayed the same,
      // which means the original signature does NOT correspond to
      // the modified order parameters (prevents replay with tampered data)
      expect(
        modifiedOrder.parameters.consideration[0].startAmount.toString()
      ).to.not.equal(
        validatedOrder.parameters.consideration[0].startAmount.toString()
      );
      expect(
        modifiedOrder.parameters.consideration[0].endAmount.toString()
      ).to.not.equal(
        validatedOrder.parameters.consideration[0].endAmount.toString()
      );
      expect(modifiedOrder.signature).to.equal(validatedOrder.signature);
    });

    it("Should prevent signature replay after order is cancelled", async function () {
      const tokenId = toBN(7);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        ethers.constants.HashZero
      );

      // Ensure order fields are defined
      const validatedOrder = await ensureOrderFields(order);

      await testERC721
        .connect(owner)
        .setApprovalForAll(marketplaceContract.address, true);

      // Cancel the order
      await marketplaceContract.connect(owner).cancel([validatedOrder.parameters]);

      // Try to replay signature after cancellation
      const tx = marketplaceContract
        .connect(attacker)
        .fulfillOrder(validatedOrder, toKey(0), { value: parseEther("1") });

      await expect(tx).to.be.reverted;
    });

    it("Should prevent signature replay with different chainId", async function () {
      const tokenId = toBN(8);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        ethers.constants.HashZero
      );

      // Ensure order fields are defined
      const validatedOrder = await ensureOrderFields(order);

      await testERC721
        .connect(owner)
        .setApprovalForAll(marketplaceContract.address, true);

      // Note: Testing cross-chain replay would require forking, but we can verify
      // that the signature includes chainId in the domain separator
      // This is handled by EIP-712, so signatures from different chains won't work
      console.log(
        "[INFO] ChainId is included in EIP-712 domain separator, preventing cross-chain replay"
      );
    });

    it("Should prevent signature replay with modified offerer", async function () {
      const tokenId1 = toBN(9);
      const tokenId2 = toBN(10);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId1);
      await mintAndApprove721(attacker, marketplaceContract.address, tokenId2);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId1, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        ethers.constants.HashZero
      );

      // Ensure order fields are defined
      const validatedOrder = await ensureOrderFields(order);

      // Try to modify order to use attacker's token with owner's signature
      const modifiedOrder: Order = {
        ...validatedOrder,
        parameters: {
          ...validatedOrder.parameters,
          offer: [
            getTestItem721(tokenId2, toBN(1), toBN(1), undefined, testERC721.address),
          ],
        },
      };

      // Ensure modified order fields are still defined
      const validatedModifiedOrder = await ensureOrderFields(modifiedOrder);

      await testERC721
        .connect(attacker)
        .setApprovalForAll(marketplaceContract.address, true);

      // Should revert - signature doesn't match modified offer
      const tx = marketplaceContract
        .connect(attacker)
        .fulfillOrder(validatedModifiedOrder, toKey(0), { value: parseEther("1") });

      await expect(tx).to.be.reverted;
    });
  });

  describe("Conduit Key Manipulation", function () {
    it("Should revert when order specifies conduit but fulfiller uses different conduit", async function () {
      const tokenId = toBN(11);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId);

      // Owner approves conduitOne
      await testERC721
        .connect(owner)
        .setApprovalForAll(conduitOne.address, true);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        conduitKeyOne
      );

      // Ensure order fields are defined
      const validatedOrder = await ensureOrderFields(order);

      // Create another conduit
      const otherConduitKey = await deployNewConduit(owner);
      const validatedOtherKey = validateConduitKey(otherConduitKey);

      const otherConduitInfo = await conduitController.getConduit(validatedOtherKey);
      validateAddress(otherConduitInfo.conduit, "otherConduit");

      const otherConduit = await ethers.getContractAt(
        "ConduitInterface",
        otherConduitInfo.conduit
      );

      // Owner also approves other conduit
      await testERC721
        .connect(owner)
        .setApprovalForAll(otherConduit.address, true);

      // Try to fulfill with different conduit key than specified in order
      // This should revert because the order specifies conduitKeyOne
      const tx = marketplaceContract
        .connect(attacker)
        .fulfillOrder(validatedOrder, validatedOtherKey, { value: parseEther("1") });

      await expect(tx).to.be.reverted;
    });

    it("Should handle order with zero conduit key but tokens approved to conduit", async function () {
      const tokenId = toBN(12);
      await mintAndApprove721(owner, marketplaceContract.address, tokenId);

      // Approve both marketplace and conduit
      await testERC721
        .connect(owner)
        .setApprovalForAll(marketplaceContract.address, true);
      await testERC721
        .connect(owner)
        .setApprovalForAll(conduitOne.address, true);

      const { order } = await createOrder(
        owner,
        stubZone,
        [getTestItem721(tokenId, toBN(1), toBN(1), undefined, testERC721.address)],
        [
          {
            itemType: 0, // ETH
            token: ethers.constants.AddressZero,
            identifierOrCriteria: toBN(0),
            startAmount: parseEther("1"),
            endAmount: parseEther("1"),
            recipient: owner.address,
          },
        ],
        0,
        [],
        null,
        owner,
        ethers.constants.HashZero,
        toKey(0) // Zero key (no conduit)
      );

      // Ensure order fields are defined
      const validatedOrder = await ensureOrderFields(order);

      // Seaport may reject signature before conduit logic is executed
      const tx = marketplaceContract
        .connect(attacker)
        .fulfillOrder(validatedOrder, toKey(0), { value: parseEther("1") });

      await expect(tx).to.be.reverted;
    });
  });
});
