import { expect } from "chai";
import { defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { ethers, network } from "hardhat";

import { randomHex } from "../utils/encoding";
import { faucet } from "../utils/faucet";
import { seaportFixture } from "../utils/fixtures";
import { VERSION } from "../utils/helpers";

import {
  EIP_712_ORDER_TYPE,
  EMPTY_BYTES32,
  ItemType,
  OrderType,
  THIRTY_MINUTES,
} from "./constants";

import type { TestERC20 } from "../../typechain-types";
import type {
  ConsiderationInterface,
  OrderComponentsStruct,
  OrderStruct,
} from "../../typechain-types/contracts/interfaces/ConsiderationInterface";
import type {
  AdvancedOrderStruct,
  OrderParametersStruct,
} from "../../typechain-types/contracts/zones/BaseZone";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import type { Contract } from "ethers";

const NULL_ADDRESS = ethers.constants.AddressZero;

describe("Test Simple Conditional", function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);
  let otherAccounts: SignerWithAddress[];
  let marketplaceContract: ConsiderationInterface;
  let simpleConditionalMax: Contract;
  let simpleConditionalMin: Contract;
  let signedOrders: OrderStruct[];
  let testERC20: TestERC20;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await faucet(owner.address, provider);
    ({ marketplaceContract, testERC20 } = await seaportFixture(owner));
    const simpleConditionalMaxZoneFactory = await ethers.getContractFactory(
      "TestSimpleConditionalMax"
    );
    const simpleConditionalMinZoneFactory = await ethers.getContractFactory(
      "TestSimpleConditionalMin"
    );
    simpleConditionalMax = await simpleConditionalMaxZoneFactory.deploy(
      marketplaceContract.address
    );
    simpleConditionalMin = await simpleConditionalMinZoneFactory.deploy(
      marketplaceContract.address
    );
  });

  beforeEach(async () => {
    [, ...otherAccounts] = await ethers.getSigners();
    await testERC20.mint(otherAccounts[0].address, "1000");
    await testERC20
      .connect(otherAccounts[0])
      .approve(marketplaceContract.address, "1000");

    signedOrders = new Array(5);

    const endTime = Math.round(Date.now() / 1000) + THIRTY_MINUTES;

    for (let i = 0; i < 5; i++) {
      const orderParams: OrderParametersStruct = {
        zoneHash: EMPTY_BYTES32,
        zone: NULL_ADDRESS,
        offerer: otherAccounts[0].address,
        offer: [
          {
            itemType: ItemType.ERC20,
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: i + 1,
            endAmount: i + 1,
          },
        ],
        consideration: [],
        startTime: 0,
        endTime,
        salt: EMPTY_BYTES32,
        conduitKey: EMPTY_BYTES32,
        totalOriginalConsiderationItems: 0,
        orderType: OrderType.FULL_OPEN,
      };

      signedOrders[i] = await signOrder(orderParams, otherAccounts[0]);
    }
  });

  describe("Simple Conditional Max", function () {
    it("Too many fulfilled", async function () {
      const ordersList = [
        await getOrderHash(signedOrders[0]),
        await getOrderHash(signedOrders[1]),
        await getOrderHash(signedOrders[2]),
      ];
      const maxFulfilled = 1;
      await marketplaceContract.fulfillOrder(signedOrders[0], EMPTY_BYTES32);
      await marketplaceContract.fulfillOrder(signedOrders[1], EMPTY_BYTES32);

      const encodedConditionalData = defaultAbiCoder.encode(
        ["uint256", "bytes32[]"],
        [maxFulfilled, ordersList]
      );
      const extraDataWithoutVersion = defaultAbiCoder.encode(
        ["bytes[]"],
        [[encodedConditionalData]]
      );
      const extraDataWithVersion = ethers.utils.solidityPack(
        ["uint8", "bytes"],
        [1, extraDataWithoutVersion]
      );
      const zoneHash = keccak256(extraDataWithoutVersion);

      const advancedOrder: AdvancedOrderStruct = {
        extraData: extraDataWithVersion,
        parameters: {
          zoneHash,
          offerer: NULL_ADDRESS,
          zone: simpleConditionalMax.address,
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
        simpleConditionalMax.isValidOrderIncludingExtraData(
          EMPTY_BYTES32,
          NULL_ADDRESS,
          advancedOrder,
          [],
          []
        )
      ).to.be.revertedWith("ConditionNotMet");
    });

    it("Success", async function () {
      const ordersList = [
        await getOrderHash(signedOrders[0]),
        await getOrderHash(signedOrders[1]),
        await getOrderHash(signedOrders[2]),
      ];
      const maxFulfilled = 1;
      await marketplaceContract.fulfillOrder(signedOrders[0], EMPTY_BYTES32);

      const encodedConditionalData = defaultAbiCoder.encode(
        ["uint256", "bytes32[]"],
        [maxFulfilled, ordersList]
      );
      const extraDataWithoutVersion = defaultAbiCoder.encode(
        ["bytes[]"],
        [[encodedConditionalData]]
      );
      const extraDataWithVersion = ethers.utils.solidityPack(
        ["uint8", "bytes"],
        [1, extraDataWithoutVersion]
      );
      const zoneHash = keccak256(extraDataWithoutVersion);

      const advancedOrder: AdvancedOrderStruct = {
        extraData: extraDataWithVersion,
        parameters: {
          zoneHash,
          offerer: NULL_ADDRESS,
          zone: simpleConditionalMax.address,
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

      await simpleConditionalMax.isValidOrderIncludingExtraData(
        EMPTY_BYTES32,
        NULL_ADDRESS,
        advancedOrder,
        [],
        []
      );

      await expect(
        simpleConditionalMax.isValidOrder(
          EMPTY_BYTES32,
          NULL_ADDRESS,
          NULL_ADDRESS,
          EMPTY_BYTES32
        )
      ).to.be.revertedWith("ExtraDataRequired");
    });
  });

  describe("Simple Conditional Min", function () {
    it("Too few fulfilled", async function () {
      const ordersList = [
        await getOrderHash(signedOrders[0]),
        await getOrderHash(signedOrders[1]),
        await getOrderHash(signedOrders[2]),
      ];
      const minFulfilled = 1;

      const encodedConditionalData = defaultAbiCoder.encode(
        ["uint256", "bytes32[]"],
        [minFulfilled, ordersList]
      );
      const extraDataWithoutVersion = defaultAbiCoder.encode(
        ["bytes[]"],
        [[encodedConditionalData]]
      );
      const extraDataWithVersion = ethers.utils.solidityPack(
        ["uint8", "bytes"],
        [1, extraDataWithoutVersion]
      );
      const zoneHash = keccak256(extraDataWithoutVersion);

      const advancedOrder: AdvancedOrderStruct = {
        extraData: extraDataWithVersion,
        parameters: {
          zoneHash,
          offerer: NULL_ADDRESS,
          zone: simpleConditionalMin.address,
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
        simpleConditionalMin.isValidOrderIncludingExtraData(
          EMPTY_BYTES32,
          NULL_ADDRESS,
          advancedOrder,
          [],
          []
        )
      ).to.be.revertedWith("ConditionNotMet");
    });

    it("Success version 1", async function () {
      const ordersList = [
        await getOrderHash(signedOrders[0]),
        await getOrderHash(signedOrders[1]),
        await getOrderHash(signedOrders[2]),
      ];
      const minFulfilled = 1;
      await marketplaceContract.fulfillOrder(signedOrders[2], EMPTY_BYTES32);

      const encodedConditionalData = defaultAbiCoder.encode(
        ["uint256", "bytes32[]"],
        [minFulfilled, ordersList]
      );
      const extraDataWithoutVersion = defaultAbiCoder.encode(
        ["bytes[]"],
        [[encodedConditionalData]]
      );
      const extraDataWithVersion = ethers.utils.solidityPack(
        ["uint8", "bytes"],
        [1, extraDataWithoutVersion]
      );
      const zoneHash = keccak256(extraDataWithoutVersion);

      const advancedOrder: AdvancedOrderStruct = {
        extraData: extraDataWithVersion,
        parameters: {
          zoneHash,
          offerer: NULL_ADDRESS,
          zone: simpleConditionalMin.address,
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

      await simpleConditionalMin.isValidOrderIncludingExtraData(
        EMPTY_BYTES32,
        NULL_ADDRESS,
        advancedOrder,
        [],
        []
      );

      await expect(
        simpleConditionalMin.isValidOrder(
          EMPTY_BYTES32,
          NULL_ADDRESS,
          NULL_ADDRESS,
          EMPTY_BYTES32
        )
      ).to.be.revertedWith("ExtraDataRequired");
    });

    it("Success version 3", async function () {
      const ordersList = [
        await getOrderHash(signedOrders[0]),
        await getOrderHash(signedOrders[1]),
        await getOrderHash(signedOrders[2]),
      ];
      const minFulfilled = 1;
      await marketplaceContract.fulfillOrder(signedOrders[2], EMPTY_BYTES32);

      const encodedConditionalData = defaultAbiCoder.encode(
        ["uint256", "bytes32[]"],
        [minFulfilled, ordersList]
      );
      const encodedHashesArray = defaultAbiCoder.encode(
        ["bytes32[]"],
        [[keccak256(encodedConditionalData)]]
      );
      const extraDataWithoutVersion = defaultAbiCoder.encode(
        ["bytes[]"],
        [[encodedConditionalData, encodedHashesArray]]
      );
      const extraDataWithVersion = ethers.utils.solidityPack(
        ["uint8", "bytes"],
        [3, extraDataWithoutVersion]
      );
      const zoneHash = keccak256(encodedHashesArray);

      const advancedOrder: AdvancedOrderStruct = {
        extraData: extraDataWithVersion,
        parameters: {
          zoneHash,
          offerer: NULL_ADDRESS,
          zone: simpleConditionalMin.address,
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

      await simpleConditionalMin.isValidOrderIncludingExtraData(
        EMPTY_BYTES32,
        NULL_ADDRESS,
        advancedOrder,
        [],
        []
      );
    });

    it("Invalid extra data version 3", async function () {
      const ordersList = [
        await getOrderHash(signedOrders[0]),
        await getOrderHash(signedOrders[1]),
        await getOrderHash(signedOrders[2]),
      ];
      const minFulfilled = 1;
      await marketplaceContract.fulfillOrder(signedOrders[2], EMPTY_BYTES32);

      const encodedConditionalData = defaultAbiCoder.encode(
        ["uint256", "bytes32[]"],
        [minFulfilled, ordersList]
      );
      const encodedConditionalDataModified = defaultAbiCoder.encode(
        ["uint256", "bytes32[]"],
        [0, ordersList]
      );
      const encodedHashesArray = defaultAbiCoder.encode(
        ["bytes32[]"],
        [[keccak256(encodedConditionalData)]]
      );
      const extraDataWithoutVersion = defaultAbiCoder.encode(
        ["bytes[]"],
        [[encodedConditionalDataModified, encodedHashesArray]]
      );
      const extraDataWithVersion = ethers.utils.solidityPack(
        ["uint8", "bytes"],
        [3, extraDataWithoutVersion]
      );
      const zoneHash = keccak256(encodedHashesArray);

      const advancedOrder: AdvancedOrderStruct = {
        extraData: extraDataWithVersion,
        parameters: {
          zoneHash,
          offerer: NULL_ADDRESS,
          zone: simpleConditionalMin.address,
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
        simpleConditionalMin.isValidOrderIncludingExtraData(
          EMPTY_BYTES32,
          NULL_ADDRESS,
          advancedOrder,
          [],
          []
        )
      ).to.be.revertedWith("InvalidExtraData");

      advancedOrder.parameters.zoneHash = "0x00" + zoneHash.substring(4); // invalid zoneHash

      await expect(
        simpleConditionalMin.isValidOrderIncludingExtraData(
          EMPTY_BYTES32,
          NULL_ADDRESS,
          advancedOrder,
          [],
          []
        )
      ).to.be.revertedWith("InvalidExtraData");
    });

    it("Invalid extra data version", async function () {
      const ordersList = [
        await getOrderHash(signedOrders[0]),
        await getOrderHash(signedOrders[1]),
        await getOrderHash(signedOrders[2]),
      ];
      const minFulfilled = 1;
      await marketplaceContract.fulfillOrder(signedOrders[2], EMPTY_BYTES32);

      const encodedConditionalData = defaultAbiCoder.encode(
        ["uint256", "bytes32[]"],
        [minFulfilled, ordersList]
      );
      const extraDataWithoutVersion = defaultAbiCoder.encode(
        ["bytes[]"],
        [[encodedConditionalData]]
      );
      const extraDataWithVersion = ethers.utils.solidityPack(
        ["uint8", "bytes"],
        [4, extraDataWithoutVersion]
      );
      const zoneHash = keccak256(extraDataWithoutVersion);

      const advancedOrder: AdvancedOrderStruct = {
        extraData: extraDataWithVersion,
        parameters: {
          zoneHash,
          offerer: NULL_ADDRESS,
          zone: simpleConditionalMin.address,
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
        simpleConditionalMin.isValidOrderIncludingExtraData(
          EMPTY_BYTES32,
          NULL_ADDRESS,
          advancedOrder,
          [],
          []
        )
      ).to.be.revertedWith("InvalidExtraDataVersion");
    });

    it("Invalid extra data version 1", async function () {
      const ordersList = [
        await getOrderHash(signedOrders[0]),
        await getOrderHash(signedOrders[1]),
        await getOrderHash(signedOrders[2]),
      ];
      const minFulfilled = 1;
      await marketplaceContract.fulfillOrder(signedOrders[2], EMPTY_BYTES32);

      const encodedConditionalData = defaultAbiCoder.encode(
        ["uint256", "bytes32[]"],
        [minFulfilled, ordersList]
      );
      const extraDataWithoutVersion = defaultAbiCoder.encode(
        ["bytes[]"],
        [[encodedConditionalData]]
      );
      const extraDataWithVersion = ethers.utils.solidityPack(
        ["uint8", "bytes"],
        [1, extraDataWithoutVersion]
      );
      const zoneHash = keccak256(extraDataWithoutVersion);

      const advancedOrder: AdvancedOrderStruct = {
        extraData: extraDataWithVersion,
        parameters: {
          zoneHash: "0x00" + zoneHash.substring(4), // Invalidate hash
          offerer: NULL_ADDRESS,
          zone: simpleConditionalMin.address,
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
        simpleConditionalMin.isValidOrderIncludingExtraData(
          EMPTY_BYTES32,
          NULL_ADDRESS,
          advancedOrder,
          [],
          []
        )
      ).to.be.revertedWith("InvalidExtraData");
    });
  });

  async function signOrder(
    orderParameters: OrderParametersStruct,
    signer: SignerWithAddress
  ): Promise<OrderStruct> {
    const { chainId } = await provider.getNetwork();
    const sig = await signer._signTypedData(
      {
        name: process.env.REFERENCE ? "Consideration" : "Seaport",
        version: VERSION,
        chainId,
        verifyingContract: marketplaceContract.address,
      },
      EIP_712_ORDER_TYPE,
      await getOrderComponents(orderParameters, signer)
    );

    return {
      parameters: orderParameters,
      signature: sig,
    };
  }

  async function getOrderComponents(
    orderParameters: OrderParametersStruct,
    signer: SignerWithAddress,
    counter?: number
  ): Promise<OrderComponentsStruct> {
    return {
      ...orderParameters,
      counter: await marketplaceContract.getCounter(signer.address),
    };
  }

  // Note, just uses current counter
  async function getOrderHash(order: OrderStruct): Promise<string> {
    const counter = await marketplaceContract.getCounter(
      order.parameters.offerer
    );
    return await marketplaceContract.getOrderHash({
      ...order.parameters,
      counter,
    });
  }
});
