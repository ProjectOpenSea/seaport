import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import {
  CROSS_CHAIN_SEAPORT_ADDRESS,
  ConsiderationIssue,
  EIP_712_ORDER_TYPE,
  EMPTY_BYTES32,
  ItemType,
  NULL_ADDRESS,
  OrderType,
} from "./order-validator-constants";

import type {
  ConsiderationInterface,
  SeaportValidator,
  TestERC1155,
  TestERC721Fee,
  TestERC721Funky,
} from "../typechain-types";
import type { OrderComponentsStruct } from "../typechain-types/contracts/interfaces/ConsiderationInterface";
import type {
  OrderParametersStruct,
  OrderStruct,
} from "../typechain-types/contracts/order-validator/SeaportValidator.sol/SeaportValidator";
import type { TestERC20 } from "../typechain-types/contracts/test/TestERC20";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Validate Orders (Arbitrum)", function () {
  const feeRecipient = "0x0000000000000000000000000000000000000FEE";
  const coder = new ethers.utils.AbiCoder();
  let baseOrderParameters: OrderParametersStruct;
  let validator: SeaportValidator;
  let seaport: ConsiderationInterface;
  let owner: SignerWithAddress;
  let otherAccounts: SignerWithAddress[];
  let erc721_1: TestERC721Fee;
  let erc721_2: TestERC721Fee;
  let erc1155_1: TestERC1155;
  let erc20_1: TestERC20;
  let erc721_funky: TestERC721Funky;

  before(async function () {
    seaport = await ethers.getContractAt(
      "ConsiderationInterface",
      CROSS_CHAIN_SEAPORT_ADDRESS
    );
  });

  async function deployFixture() {
    const [owner, ...otherAccounts] = await ethers.getSigners();

    const Validator = await ethers.getContractFactory("SeaportValidator");
    const TestERC721Factory = await ethers.getContractFactory("TestERC721Fee");
    const TestERC1155Factory = await ethers.getContractFactory("TestERC1155");
    const TestERC20Factory = await ethers.getContractFactory("TestERC20");
    const TestERC721FunkyFactory = await ethers.getContractFactory(
      "TestERC721Funky"
    );

    const validator = await Validator.deploy();

    const erc721_1 = await TestERC721Factory.deploy();
    const erc721_2 = await TestERC721Factory.deploy();
    const erc1155_1 = await TestERC1155Factory.deploy();
    const erc20_1 = await TestERC20Factory.deploy();
    const erc721_funky = await TestERC721FunkyFactory.deploy();

    return {
      validator,
      owner,
      otherAccounts,
      erc721_1,
      erc721_2,
      erc1155_1,
      erc20_1,
      erc721_funky,
    };
  }

  beforeEach(async function () {
    const res = await loadFixture(deployFixture);
    validator = res.validator;
    owner = res.owner;
    otherAccounts = res.otherAccounts;
    erc721_1 = res.erc721_1;
    erc721_2 = res.erc721_2;
    erc1155_1 = res.erc1155_1;
    erc20_1 = res.erc20_1;
    erc721_funky = res.erc721_funky;

    baseOrderParameters = {
      offerer: owner.address,
      zone: NULL_ADDRESS,
      orderType: OrderType.FULL_OPEN,
      startTime: "0",
      endTime: Math.round(Date.now() / 1000 + 4000).toString(),
      salt: "0",
      totalOriginalConsiderationItems: 0,
      offer: [],
      consideration: [],
      zoneHash: EMPTY_BYTES32,
      conduitKey: EMPTY_BYTES32,
    };
  });

  describe("Check Creator Fees", function () {
    // We are checking creator fees solely based on EIP2981 here

    it("Check creator fees success", async function () {
      // Enable creator fees on token
      await erc721_1.setCreatorFeeEnabled(true);

      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "25",
          recipient: feeRecipient,
        },
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "25",
          recipient: "0x000000000000000000000000000000000000FEE2",
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          feeRecipient,
          "250",
          true
        )
      ).to.include.deep.ordered.members([[], []]);
    });

    it("Check creator fees reverts", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "25",
          recipient: "0x000000000000000000000000000000000000FEE2",
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          "0",
          true
        )
      ).to.include.deep.ordered.members([[ConsiderationIssue.ExtraItems], []]);
    });

    it("Check creator fees returns unexpected value", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC721,
          token: erc721_funky.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "25",
          recipient: "0x000000000000000000000000000000000000FEE2",
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          "0",
          true
        )
      ).to.include.deep.ordered.members([[ConsiderationIssue.ExtraItems], []]);
    });

    it("Check creator fees second reverts", async function () {
      await erc721_1.setCreatorFeeEnabled(true);
      await erc721_1.setMinTransactionPrice(10);

      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "0",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "0",
          recipient: "0x000000000000000000000000000000000000FEE2",
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          "0",
          true
        )
      ).to.include.deep.ordered.members([[], []]);
    });
  });

  async function signOrder(
    orderParameters: OrderParametersStruct,
    signer: SignerWithAddress,
    counter?: number
  ): Promise<OrderStruct> {
    const sig = await signer._signTypedData(
      {
        name: "Seaport",
        version: "1.1",
        chainId: "1",
        verifyingContract: seaport.address,
      },
      EIP_712_ORDER_TYPE,
      await getOrderComponents(orderParameters, signer, counter)
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
      counter: counter ?? (await seaport.getCounter(signer.address)),
    };
  }
});
