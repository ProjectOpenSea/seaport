import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import {
  CROSS_CHAIN_SEAPORT_ADDRESS,
  ConduitIssue,
  ConsiderationIssue,
  CreatorFeeIssue,
  EIP_712_ORDER_TYPE,
  EMPTY_BYTES32,
  ERC1155Issue,
  ERC20Issue,
  ERC721Issue,
  GenericIssue,
  ItemType,
  MerkleIssue,
  NULL_ADDRESS,
  NativeIssue,
  OPENSEA_CONDUIT_ADDRESS,
  OPENSEA_CONDUIT_KEY,
  OfferIssue,
  OrderType,
  PrimaryFeeIssue,
  SignatureIssue,
  StatusIssue,
  THIRTY_MINUTES,
  TimeIssue,
  WEEKS_26,
  ZoneIssue,
  ContractOffererIssue,
} from "./order-validator-constants";

import {
  ConsiderationInterface,
  SeaportValidator,
  TestContractOfferer,
  TestERC1155,
  TestERC721,
  TestInvalidContractOfferer165,
  TestInvalidZone,
  TestZone,
} from "../typechain-types";
import type { OrderComponentsStruct } from "../typechain-types/contracts/interfaces/ConsiderationInterface";
import type {
  OrderParametersStruct,
  OrderStruct,
  ValidationConfigurationStruct,
  ZoneParametersStruct,
} from "../typechain-types/contracts/order-validator/SeaportValidator.sol/SeaportValidator";
import type { TestERC20 } from "../typechain-types/contracts/test/TestERC20";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Validate Orders", function () {
  const feeRecipient = "0x0000000000000000000000000000000000000FEE";
  const coder = new ethers.utils.AbiCoder();
  let baseOrderParameters: OrderParametersStruct;
  let zoneParameters: ZoneParametersStruct;
  let validator: SeaportValidator;
  let seaport: ConsiderationInterface;
  let owner: SignerWithAddress;
  let otherAccounts: SignerWithAddress[];
  let erc721_1: TestERC721;
  let erc721_2: TestERC721;
  let erc1155_1: TestERC1155;
  let erc20_1: TestERC20;

  before(async function () {
    seaport = await ethers.getContractAt(
      "ConsiderationInterface",
      CROSS_CHAIN_SEAPORT_ADDRESS
    );
  });

  async function deployFixture() {
    const [owner, ...otherAccounts] = await ethers.getSigners();

    const Validator = await ethers.getContractFactory("SeaportValidator");

    const TestERC721Factory = await ethers.getContractFactory("TestERC721");
    const TestERC1155Factory = await ethers.getContractFactory("TestERC1155");
    const TestERC20Factory = await ethers.getContractFactory("TestERC20");

    const validator = await Validator.deploy();

    // const ViewOnlyValidator = await ethers.getContractFactory("SeaportValidatorViewOnlyInterface");

    const erc721_1 = await TestERC721Factory.deploy();
    const erc721_2 = await TestERC721Factory.deploy();
    const erc1155_1 = await TestERC1155Factory.deploy();
    const erc20_1 = await TestERC20Factory.deploy();

    return {
      validator,
      owner,
      otherAccounts,
      erc721_1,
      erc721_2,
      erc1155_1,
      erc20_1,
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

    zoneParameters = {
      orderHash: EMPTY_BYTES32,
      fulfiller: feeRecipient,
      offerer: baseOrderParameters.offerer,
      offer: [],
      consideration: [],
      extraData: [],
      orderHashes: [],
      startTime: baseOrderParameters.startTime,
      endTime: baseOrderParameters.endTime,
      zoneHash: baseOrderParameters.zoneHash,
    };
  });

  describe("Validate Time", function () {
    beforeEach(function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "2",
          startAmount: "1",
          endAmount: "1",
        },
      ];
    });

    it("Order expired", async function () {
      baseOrderParameters.endTime = 1000;

      expect(
        await validator.validateTime(
          baseOrderParameters,
          THIRTY_MINUTES,
          WEEKS_26
        )
      ).to.include.deep.ordered.members([[TimeIssue.Expired], []]);
    });

    it("Order not yet active", async function () {
      baseOrderParameters.startTime = baseOrderParameters.endTime;
      baseOrderParameters.endTime = ethers.BigNumber.from(
        baseOrderParameters.startTime
      ).add(10000);

      expect(
        await validator.validateTime(
          baseOrderParameters,
          THIRTY_MINUTES,
          WEEKS_26
        )
      ).to.include.deep.ordered.members([[], [TimeIssue.NotActive]]);
    });

    it("Success", async function () {
      expect(
        await validator.validateTime(
          baseOrderParameters,
          THIRTY_MINUTES,
          WEEKS_26
        )
      ).to.include.deep.ordered.members([[], []]);
    });

    it("End time must be after start", async function () {
      baseOrderParameters.startTime = ethers.BigNumber.from(
        baseOrderParameters.endTime
      ).add(100);

      expect(
        await validator.validateTime(
          baseOrderParameters,
          THIRTY_MINUTES,
          WEEKS_26
        )
      ).to.include.deep.ordered.members([
        [TimeIssue.EndTimeBeforeStartTime],
        [],
      ]);
    });

    it("Duration less than 10 minutes", async function () {
      baseOrderParameters.startTime = Math.round(
        Date.now() / 1000 - 1000
      ).toString();
      baseOrderParameters.endTime = Math.round(
        Date.now() / 1000 + 10
      ).toString();

      expect(
        await validator.validateTime(
          baseOrderParameters,
          THIRTY_MINUTES,
          WEEKS_26
        )
      ).to.include.deep.ordered.members([[], [TimeIssue.ShortOrder]]);
    });

    it("Expire in over 30 weeks", async function () {
      baseOrderParameters.endTime = Math.round(
        Date.now() / 1000 + 60 * 60 * 24 * 7 * 35
      ).toString();
      expect(
        await validator.validateTime(
          baseOrderParameters,
          THIRTY_MINUTES,
          WEEKS_26
        )
      ).to.include.deep.ordered.members([[], [TimeIssue.DistantExpiration]]);
    });
  });

  describe("Validate Offer Items", function () {
    it("Zero offer items", async function () {
      expect(
        await validator.validateOfferItems(baseOrderParameters)
      ).to.include.deep.ordered.members([[OfferIssue.ZeroItems], []]);
    });

    it("duplicate offer items", async function () {
      await erc20_1.mint(owner.address, "1000");
      await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, "1000");

      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
        },
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "2",
          endAmount: "2",
        },
      ];

      expect(
        await validator.validateOfferItems(baseOrderParameters)
      ).to.include.deep.ordered.members([
        [OfferIssue.DuplicateItem],
        [OfferIssue.MoreThanOneItem],
      ]);
    });

    it("invalid conduit key", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC721,
          token: erc20_1.address,
          identifierOrCriteria: "2",
          startAmount: "1",
          endAmount: "1",
        },
      ];
      baseOrderParameters.conduitKey = "0x1" + "0".repeat(63);
      expect(
        await validator.validateOfferItemApprovalAndBalance(
          baseOrderParameters,
          0
        )
      ).to.include.deep.ordered.members([[ConduitIssue.KeyInvalid], []]);
    });

    it("more than one offer items", async function () {
      await erc20_1.mint(owner.address, "4");
      await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, "4");
      await erc721_1.mint(owner.address, "4");
      await erc721_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, "4");

      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
        },
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "4",
          startAmount: "1",
          endAmount: "1",
        },
      ];

      expect(
        await validator.validateOfferItems(baseOrderParameters)
      ).to.include.deep.ordered.members([[], [OfferIssue.MoreThanOneItem]]);
    });

    it("invalid item", async function () {
      baseOrderParameters.offer = [
        {
          itemType: 6,
          token: NULL_ADDRESS,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
        },
      ];

      await expect(validator.validateOfferItems(baseOrderParameters)).to.be
        .reverted;
    });

    describe("ERC721", function () {
      it("No approval", async function () {
        await erc721_1.mint(owner.address, 2);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC721Issue.NotApproved], []]);
      });

      it("Not owner", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC721Issue.NotOwner, ERC721Issue.NotApproved],
          [],
        ]);

        await erc721_1.mint(otherAccounts[0].address, 2);
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC721Issue.NotOwner, ERC721Issue.NotApproved],
          [],
        ]);
      });

      it("Set approval for all", async function () {
        await erc721_1.mint(owner.address, 2);
        await erc721_1.setApprovalForAll(CROSS_CHAIN_SEAPORT_ADDRESS, true);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], []]);
      });

      it("Set approval for one", async function () {
        await erc721_1.mint(owner.address, 2);
        await erc721_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 2);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], []]);
      });

      it("Invalid token: contract", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: erc20_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC721Issue.InvalidToken], []]);
      });

      it("Invalid token: null address", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: NULL_ADDRESS,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC721Issue.InvalidToken], []]);
      });

      it("Invalid token: eoa", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: otherAccounts[2].address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC721Issue.InvalidToken], []]);
      });

      it("Amount not one", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "2",
            endAmount: "1",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC721Issue.AmountNotOne],
          [OfferIssue.AmountStepLarge],
        ]);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "2",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC721Issue.AmountNotOne],
          [OfferIssue.AmountStepLarge],
        ]);
      });

      it("ERC721 Criteria offer", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], []]);
      });

      it("ERC721 Criteria offer invalid token", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: erc1155_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC721Issue.InvalidToken], []]);
      });

      it("ERC721 Criteria offer multiple", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "2",
            endAmount: "1",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC721Issue.CriteriaNotPartialFill],
          [OfferIssue.AmountStepLarge],
        ]);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "2",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC721Issue.CriteriaNotPartialFill],
          [OfferIssue.AmountStepLarge],
        ]);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "2",
            endAmount: "2",
          },
        ];
        baseOrderParameters.orderType = OrderType.PARTIAL_OPEN;

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], []]);
      });
    });

    describe("ERC1155", function () {
      it("No approval", async function () {
        await erc1155_1.mint(owner.address, 2, 1);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC1155,
            token: erc1155_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC1155Issue.NotApproved], []]);
      });

      it("Insufficient amount", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC1155,
            token: erc1155_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC1155Issue.NotApproved, ERC1155Issue.InsufficientBalance],
          [],
        ]);
      });

      it("Invalid contract", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC1155,
            token: erc20_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC1155Issue.InvalidToken], []]);
      });

      it("Success", async function () {
        await erc1155_1.mint(owner.address, 2, 1);
        await erc1155_1.setApprovalForAll(CROSS_CHAIN_SEAPORT_ADDRESS, true);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC1155,
            token: erc1155_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], []]);
      });

      it("ERC1155 Criteria offer", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC1155_WITH_CRITERIA,
            token: erc1155_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], []]);
      });

      it("ERC1155 Criteria offer invalid token", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC1155_WITH_CRITERIA,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC1155Issue.InvalidToken], []]);
      });

      it("ERC1155 Criteria offer multiple", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC1155_WITH_CRITERIA,
            token: erc1155_1.address,
            identifierOrCriteria: "2",
            startAmount: "2000000000000000000",
            endAmount: "1000000000000000000",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], []]);
      });
    });

    describe("ERC20", function () {
      it("No approval", async function () {
        await erc20_1.mint(owner.address, 2000);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "0",
            startAmount: "1000",
            endAmount: "1000",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC20Issue.InsufficientAllowance],
          [],
        ]);
      });

      it("Insufficient amount", async function () {
        await erc20_1.mint(owner.address, 900);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "0",
            startAmount: "1000",
            endAmount: "1000",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC20Issue.InsufficientAllowance, ERC20Issue.InsufficientBalance],
          [],
        ]);
      });

      it("Invalid contract", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC20,
            token: erc1155_1.address,
            identifierOrCriteria: "0",
            startAmount: "1000",
            endAmount: "1000",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC20Issue.InvalidToken], []]);
      });

      it("Non zero identifier", async function () {
        await erc20_1.mint(owner.address, 2000);
        await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 1000);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "1",
            startAmount: "1000",
            endAmount: "1000",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC20Issue.IdentifierNonZero], []]);
      });

      it("Success", async function () {
        await erc20_1.mint(owner.address, 2000);
        await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 1000);

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "0",
            startAmount: "1000",
            endAmount: "1000",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], []]);
      });
    });

    describe("Native", function () {
      it("Token address", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.NATIVE,
            token: erc1155_1.address,
            identifierOrCriteria: "0",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[NativeIssue.TokenAddress], []]);
      });

      it("Identifier", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.NATIVE,
            token: NULL_ADDRESS,
            identifierOrCriteria: "1",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [NativeIssue.IdentifierNonZero],
          [],
        ]);
      });

      it("Native offer warning", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.NATIVE,
            token: NULL_ADDRESS,
            identifierOrCriteria: "0",
            startAmount: "1",
            endAmount: "1",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], [OfferIssue.NativeItem]]);
      });

      it("Insufficient balance", async function () {
        baseOrderParameters.offerer = feeRecipient;

        baseOrderParameters.offer = [
          {
            itemType: ItemType.NATIVE,
            token: NULL_ADDRESS,
            identifierOrCriteria: "0",
            startAmount: "1",
            endAmount: "1",
          },
        ];

        expect(
          await validator.validateOfferItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [NativeIssue.InsufficientBalance],
          [OfferIssue.NativeItem],
        ]);
      });
    });

    describe("Velocity", function () {
      it("Velocity > 5% && < 50%", async function () {
        // 1 hour duration
        baseOrderParameters.startTime = Math.round(
          Date.now() / 1000 - 600
        ).toString();
        baseOrderParameters.endTime = Math.round(
          Date.now() / 1000 + 3000
        ).toString();

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "0",
            startAmount: "89000000000000000000", // 89e18
            endAmount: "100000000000000000000", // 100e18
          },
        ];

        expect(
          await validator.validateOfferItemParameters(baseOrderParameters, 0)
        ).to.include.deep.ordered.members([
          [],
          [OfferIssue.AmountVelocityHigh],
        ]);
      });

      it("Velocity > 50%", async function () {
        // 30 min duration
        baseOrderParameters.startTime = Math.round(
          Date.now() / 1000 - 600
        ).toString();
        baseOrderParameters.endTime = Math.round(
          Date.now() / 1000 + 1200
        ).toString();

        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "0",
            startAmount: "49000000000000000000", // 49e18
            endAmount: "100000000000000000000", // 100e18
          },
        ];

        expect(
          await validator.validateOfferItemParameters(baseOrderParameters, 0)
        ).to.include.deep.ordered.members([
          [OfferIssue.AmountVelocityHigh],
          [],
        ]);
      });
    });
  });

  describe("Validate Consideration Items", function () {
    it("Zero consideration items", async function () {
      expect(
        await validator.validateConsiderationItems(baseOrderParameters)
      ).to.include.deep.ordered.members([[], [ConsiderationIssue.ZeroItems]]);
    });

    it("Null recipient", async function () {
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
          recipient: NULL_ADDRESS,
        },
      ];

      expect(
        await validator.validateConsiderationItems(baseOrderParameters)
      ).to.include.deep.ordered.members([
        [ConsiderationIssue.NullRecipient],
        [],
      ]);
    });

    it("Consideration amount zero", async function () {
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "0",
          endAmount: "0",
          recipient: owner.address,
        },
      ];

      expect(
        await validator.validateConsiderationItems(baseOrderParameters)
      ).to.include.deep.ordered.members([[ConsiderationIssue.AmountZero], []]);
    });

    it("Invalid consideration item type", async function () {
      baseOrderParameters.consideration = [
        {
          itemType: 6,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "0",
          endAmount: "0",
          recipient: owner.address,
        },
      ];

      await expect(validator.validateConsiderationItems(baseOrderParameters)).to
        .be.reverted;
    });

    it("Duplicate consideration item", async function () {
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000000000000000000",
          endAmount: "100000000000000000000",
          recipient: owner.address,
        },
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "100000000000000000000",
          endAmount: "1000000000000000000",
          recipient: owner.address,
        },
      ];

      expect(
        await validator.validateConsiderationItems(baseOrderParameters)
      ).to.include.deep.ordered.members([
        [],
        [ConsiderationIssue.DuplicateItem],
      ]);
    });

    it("Consideration item has large steps", async function () {
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "100",
          endAmount: "200",
          recipient: owner.address,
        },
      ];

      expect(
        await validator.validateConsiderationItemParameters(
          baseOrderParameters,
          0
        )
      ).to.include.deep.ordered.members([
        [],
        [ConsiderationIssue.AmountStepLarge],
      ]);
    });

    describe("ERC721", function () {
      it("ERC721 consideration not one", async function () {
        await erc721_1.mint(otherAccounts[0].address, 2);

        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "2",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC721Issue.AmountNotOne],
          [ConsiderationIssue.AmountStepLarge],
        ]);

        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "2",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [ERC721Issue.AmountNotOne],
          [ConsiderationIssue.AmountStepLarge],
        ]);
      });

      it("ERC721 consideration DNE", async function () {
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC721Issue.IdentifierDNE], []]);
      });

      it("ERC721 invalid token", async function () {
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC721,
            token: erc1155_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC721Issue.InvalidToken], []]);
      });

      it("ERC721 criteria invalid token", async function () {
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: erc1155_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC721Issue.InvalidToken], []]);
      });

      it("ERC721 criteria success", async function () {
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], []]);
      });
    });

    describe("ERC1155", function () {
      it("ERC1155 invalid token", async function () {
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC1155,
            token: erc721_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC1155Issue.InvalidToken], []]);
      });

      it("success", async function () {
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC1155,
            token: erc1155_1.address,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[], []]);
      });
    });

    describe("ERC20", function () {
      it("ERC20 invalid token", async function () {
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC20,
            token: erc1155_1.address,
            identifierOrCriteria: "0",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC20Issue.InvalidToken], []]);
      });

      it("ERC20 non zero id", async function () {
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "1",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[ERC20Issue.IdentifierNonZero], []]);
      });
    });

    describe("Native", function () {
      it("Native invalid token", async function () {
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.NATIVE,
            token: erc1155_1.address,
            identifierOrCriteria: "0",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([[NativeIssue.TokenAddress], []]);
      });

      it("Native non-zero id", async function () {
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.NATIVE,
            token: NULL_ADDRESS,
            identifierOrCriteria: "2",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItems(baseOrderParameters)
        ).to.include.deep.ordered.members([
          [NativeIssue.IdentifierNonZero],
          [],
        ]);
      });
    });

    describe("Velocity", function () {
      it("Velocity > 5% && < 50%", async function () {
        // 1 hour duration
        baseOrderParameters.startTime = Math.round(
          Date.now() / 1000 - 600
        ).toString();
        baseOrderParameters.endTime = Math.round(
          Date.now() / 1000 + 3000
        ).toString();

        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "0",
            startAmount: "89000000000000000000", // 89e18
            endAmount: "100000000000000000000", // 100e18
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItemParameters(
            baseOrderParameters,
            0
          )
        ).to.include.deep.ordered.members([
          [],
          [ConsiderationIssue.AmountVelocityHigh],
        ]);
      });

      it("Velocity > 50%", async function () {
        // 30 min duration
        baseOrderParameters.startTime = Math.round(
          Date.now() / 1000 - 600
        ).toString();
        baseOrderParameters.endTime = Math.round(
          Date.now() / 1000 + 1200
        ).toString();

        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "0",
            startAmount: "49000000000000000000", // 49e18
            endAmount: "100000000000000000000", // 100e18
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateConsiderationItemParameters(
            baseOrderParameters,
            0
          )
        ).to.include.deep.ordered.members([
          [ConsiderationIssue.AmountVelocityHigh],
          [],
        ]);
      });
    });
  });

  describe("Private Sale", function () {
    it("Successful private sale", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: feeRecipient, // Arbitrary recipient
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          0,
          false
        )
      ).to.include.deep.ordered.members([[], [ConsiderationIssue.PrivateSale]]);
    });

    it("success with all fees", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC721,
          token: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
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
          recipient: "0xAAe7aC476b117bcCAfE2f05F582906be44bc8FF1", // BAYC fee recipient
        },
        {
          itemType: ItemType.ERC721,
          token: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: feeRecipient,
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          feeRecipient,
          "250",
          true
        )
      ).to.include.deep.ordered.members([[], [ConsiderationIssue.PrivateSale]]);
    });

    it("Private sale extra consideration item", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: feeRecipient, // Arbitrary recipient
        },
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          0,
          false
        )
      ).to.include.deep.ordered.members([
        [ConsiderationIssue.ExtraItems],
        [ConsiderationIssue.PrivateSale],
      ]);
    });

    it("Private sale to self", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          0,
          false
        )
      ).to.include.deep.ordered.members([
        [ConsiderationIssue.PrivateSaleToSelf],
        [],
      ]);
    });

    it("Private sale mismatch", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
        {
          itemType: ItemType.ERC20,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: feeRecipient,
        },
      ];
      console.log("first call");
      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          0,
          false
        )
      ).to.include.deep.ordered.members([[ConsiderationIssue.ExtraItems], []]);

      baseOrderParameters.consideration[1] = {
        itemType: ItemType.ERC721,
        token: erc20_1.address,
        identifierOrCriteria: "1",
        startAmount: "1",
        endAmount: "1",
        recipient: feeRecipient,
      };
      console.log("second call");
      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          0,
          false
        )
      ).to.include.deep.ordered.members([[ConsiderationIssue.ExtraItems], []]);

      baseOrderParameters.consideration[1] = {
        itemType: ItemType.ERC721,
        token: erc721_1.address,
        identifierOrCriteria: "2",
        startAmount: "1",
        endAmount: "1",
        recipient: feeRecipient,
      };
      console.log("third call");
      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          0,
          false
        )
      ).to.include.deep.ordered.members([[ConsiderationIssue.ExtraItems], []]);

      baseOrderParameters.consideration[1] = {
        itemType: ItemType.ERC721,
        token: erc721_1.address,
        identifierOrCriteria: "1",
        startAmount: "2",
        endAmount: "1",
        recipient: feeRecipient,
      };
      console.log("fourth call");
      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          0,
          false
        )
      ).to.include.deep.ordered.members([[ConsiderationIssue.ExtraItems], []]);

      baseOrderParameters.consideration[1] = {
        itemType: ItemType.ERC721,
        token: erc721_1.address,
        identifierOrCriteria: "1",
        startAmount: "1",
        endAmount: "2",
        recipient: feeRecipient,
      };
      console.log("fifth call");
      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          0,
          false
        )
      ).to.include.deep.ordered.members([[ConsiderationIssue.ExtraItems], []]);
    });

    it("private sale for an offer", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
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
          startAmount: "1",
          endAmount: "1",
          recipient: feeRecipient, // Arbitrary recipient
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          0,
          false
        )
      ).to.include.deep.ordered.members([[ConsiderationIssue.ExtraItems], []]);
    });

    it("incorrect creator fees setting", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC721,
          token: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
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
          itemType: ItemType.ERC721,
          token: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: feeRecipient,
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          feeRecipient,
          "250",
          true
        )
      ).to.include.deep.ordered.members([[CreatorFeeIssue.ItemType], []]);
    });
  });

  describe("Validate Zone", function () {
    let testZone: TestZone;
    let testInvalidZone: TestInvalidZone;
    beforeEach(async function () {
      const TestZone = await ethers.getContractFactory("TestZone");
      testZone = await TestZone.deploy();

      const TestInvalidZone = await ethers.getContractFactory(
        "TestInvalidZone"
      );
      testInvalidZone = await TestInvalidZone.deploy();
    });

    it("No zone", async function () {
      baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
      expect(
        await validator.isValidZone(baseOrderParameters)
      ).to.include.deep.ordered.members([[ZoneIssue.NotSet], []]);
    });

    it("Eoa zone", async function () {
      baseOrderParameters.zone = otherAccounts[1].address;
      baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
      expect(
        await validator.isValidZone(baseOrderParameters)
      ).to.include.deep.ordered.members([[], []]);
    });

    it("success", async function () {
      baseOrderParameters.zone = testZone.address;
      baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
      expect(
        await validator.isValidZone(baseOrderParameters)
      ).to.include.deep.ordered.members([[], []]);
    });

    it("invalid magic value", async function () {
      baseOrderParameters.zone = testZone.address;
      baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
      zoneParameters.zoneHash = coder.encode(["uint256"], [3]);
      expect(
        await validator.validateOrderWithZone(
          baseOrderParameters,
          zoneParameters
        )
      ).to.include.deep.ordered.members([[], [ZoneIssue.RejectedOrder]]);
    });

    it("zone revert", async function () {
      baseOrderParameters.zone = testZone.address;
      baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
      zoneParameters.zoneHash = coder.encode(["uint256"], [1]);
      expect(
        await validator.validateOrderWithZone(
          baseOrderParameters,
          zoneParameters
        )
      ).to.include.deep.ordered.members([[], [ZoneIssue.RejectedOrder]]);
    });

    it("zone revert2", async function () {
      baseOrderParameters.zone = testZone.address;
      baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
      zoneParameters.zoneHash = coder.encode(["uint256"], [2]);
      expect(
        await validator.validateOrderWithZone(
          baseOrderParameters,
          zoneParameters
        )
      ).to.include.deep.ordered.members([[], [ZoneIssue.RejectedOrder]]);
    });

    it("not a zone", async function () {
      baseOrderParameters.zone = validator.address;
      baseOrderParameters.orderType = OrderType.FULL_RESTRICTED;
      baseOrderParameters.zoneHash = coder.encode(["uint256"], [1]);
      expect(
        await validator.isValidZone(baseOrderParameters)
      ).to.include.deep.ordered.members([[ZoneIssue.InvalidZone], []]);
    });

    it("zone not checked on open order", async function () {
      baseOrderParameters.zone = validator.address;
      baseOrderParameters.zoneHash = coder.encode(["uint256"], [1]);
      expect(
        await validator.isValidZone(baseOrderParameters)
      ).to.include.deep.ordered.members([[], []]);
    });
  });

  describe("Conduit Validation", function () {
    it("null conduit", async function () {
      // null conduit key points to seaport
      expect(
        await validator.getApprovalAddress(EMPTY_BYTES32)
      ).to.include.deep.ordered.members([
        CROSS_CHAIN_SEAPORT_ADDRESS,
        [[], []],
      ]);
    });

    it("valid conduit key", async function () {
      expect(
        await validator.getApprovalAddress(OPENSEA_CONDUIT_KEY)
      ).to.include.deep.ordered.members([OPENSEA_CONDUIT_ADDRESS, [[], []]]);
    });

    it("invalid conduit key", async function () {
      expect(
        await validator.getApprovalAddress(
          "0x0000000000000000000000000000000000000000000000000000000000000099"
        )
      ).to.include.deep.ordered.members([
        NULL_ADDRESS,
        [[ConduitIssue.KeyInvalid], []],
      ]);
    });

    it("isValidConduit valid", async function () {
      expect(
        await validator.isValidConduit(OPENSEA_CONDUIT_KEY)
      ).to.include.deep.ordered.members([[], []]);
    });

    it("isValidConduit invalid", async function () {
      expect(
        await validator.isValidConduit(
          "0x0000000000000000000000000000000000000000000000000000000000000099"
        )
      ).to.include.deep.ordered.members([[ConduitIssue.KeyInvalid], []]);
    });
  });

  describe("Merkle", function () {
    it("Create root", async function () {
      const input = [...Array(5).keys()].sort((a, b) => {
        return ethers.utils.keccak256(
          ethers.utils.hexZeroPad(ethers.utils.hexlify(a), 32)
        ) >
          ethers.utils.keccak256(
            ethers.utils.hexZeroPad(ethers.utils.hexlify(b), 32)
          )
          ? 1
          : -1;
      });

      const res = await validator.getMerkleRoot(input);
      expect(res.merkleRoot).to.equal(
        "0x91bcc50c5289d8945a178a27e28c83c68df8043d45285db1eddc140f73ac2c83"
      );
    });

    it("Create proof", async function () {
      const input = [...Array(5).keys()].sort((a, b) => {
        return ethers.utils.keccak256(
          ethers.utils.hexZeroPad(ethers.utils.hexlify(a), 32)
        ) >
          ethers.utils.keccak256(
            ethers.utils.hexZeroPad(ethers.utils.hexlify(b), 32)
          )
          ? 1
          : -1;
      });

      const res = await validator.getMerkleProof(input, 0);
      expect(res.merkleProof).to.deep.equal([
        "0x405787fa12a823e0f2b7631cc41b3ba8828b3321ca811111fa75cd3aa3bb5ace",
        "0xb4ac32458d01ec09d972c820893c530c5aca86752a8c02e2499f60b968613ded",
        "0xc2575a0e9e593c00f959f8c92f12db2869c3395a3b0502d05e2516446f71f85b",
      ]);
    });

    it("Create proof: invalid index", async function () {
      const input = [...Array(5).keys()].sort((a, b) => {
        return ethers.utils.keccak256(
          ethers.utils.hexZeroPad(ethers.utils.hexlify(a), 32)
        ) >
          ethers.utils.keccak256(
            ethers.utils.hexZeroPad(ethers.utils.hexlify(b), 32)
          )
          ? 1
          : -1;
      });

      [input[0], input[1]] = [input[1], input[0]];

      const res = await validator.getMerkleProof(input, 8);
      expect(res.errorsAndWarnings).to.include.deep.ordered.members([
        [MerkleIssue.Unsorted],
        [],
      ]);
    });

    it("Create proof: 1 leaf", async function () {
      const input = [2];
      const res = await validator.getMerkleProof(input, 0);
      expect(res.errorsAndWarnings).to.include.deep.ordered.members([
        [MerkleIssue.SingleLeaf],
        [],
      ]);
    });

    it("Create root: incorrect order", async function () {
      const input = [...Array(5).keys()];

      const res = await validator.getMerkleRoot(input);
      expect(res.merkleRoot).to.equal(EMPTY_BYTES32);
      expect(res.errorsAndWarnings).to.include.deep.ordered.members([
        [MerkleIssue.Unsorted],
        [],
      ]);
    });

    it("Create root: 1 leaf", async function () {
      const input = [2];
      const res = await validator.getMerkleRoot(input);
      expect(res.errorsAndWarnings).to.include.deep.ordered.members([
        [MerkleIssue.SingleLeaf],
        [],
      ]);
    });

    it("Sort tokens", async function () {
      const input = [...Array(5).keys()];

      const sortedInput = await validator.sortMerkleTokens(input);
      expect(sortedInput).to.deep.equal([0, 2, 4, 1, 3]);
    });

    it("Sort tokens 2", async function () {
      const input = [...Array(5).keys()];

      const sortedInput = await validator.sortMerkleTokens(input);
      const sortedInput2 = await validator.sortMerkleTokens(sortedInput);
      expect(sortedInput2).to.deep.equal([0, 2, 4, 1, 3]);
    });

    it("Verify merkle proof", async function () {
      const input = [...Array(10).keys()].sort((a, b) => {
        return ethers.utils.keccak256(
          ethers.utils.hexZeroPad(ethers.utils.hexlify(a), 32)
        ) >
          ethers.utils.keccak256(
            ethers.utils.hexZeroPad(ethers.utils.hexlify(b), 32)
          )
          ? 1
          : -1;
      });

      const merkleRoot = (await validator.getMerkleRoot(input)).merkleRoot;
      const merkleProof = (await validator.getMerkleProof(input, 2))
        .merkleProof;
      expect(
        await validator.verifyMerkleProof(merkleRoot, merkleProof, input[2])
      ).to.equal(true);
    });

    it("Invalid merkle proof", async function () {
      const input = [...Array(10).keys()].sort((a, b) => {
        return ethers.utils.keccak256(
          ethers.utils.hexZeroPad(ethers.utils.hexlify(a), 32)
        ) >
          ethers.utils.keccak256(
            ethers.utils.hexZeroPad(ethers.utils.hexlify(b), 32)
          )
          ? 1
          : -1;
      });

      const merkleRoot = (await validator.getMerkleRoot(input)).merkleRoot;
      const merkleProof = (await validator.getMerkleProof(input, 1))
        .merkleProof;
      expect(
        await validator.verifyMerkleProof(merkleRoot, merkleProof, input[2])
      ).to.equal(false);
    });
  }).timeout(60000);

  describe("Validate Status", function () {
    it("fully filled", async function () {
      await erc20_1.mint(otherAccounts[0].address, 2000);
      await erc20_1
        .connect(otherAccounts[0])
        .approve(CROSS_CHAIN_SEAPORT_ADDRESS, 2000);

      baseOrderParameters.offerer = otherAccounts[0].address;
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];

      const order: OrderStruct = await signOrder(
        baseOrderParameters,
        otherAccounts[0]
      );

      await seaport.fulfillOrder(order, EMPTY_BYTES32);

      expect(
        await validator.validateOrderStatus(baseOrderParameters)
      ).to.include.deep.ordered.members([[StatusIssue.FullyFilled], []]);
    });

    it("Order Cancelled", async function () {
      await erc20_1.mint(owner.address, 1000);
      await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 1000);

      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];

      await seaport.cancel([
        await getOrderComponents(baseOrderParameters, owner),
      ]);

      expect(
        await validator.validateOrderStatus(baseOrderParameters)
      ).to.include.deep.ordered.members([[StatusIssue.Cancelled], []]);
    });
  });

  describe("Fee", function () {
    describe("Primary Fee", function () {
      it("success offer", async function () {
        const feeRecipient = "0x0000000000000000000000000000000000000FEE";
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

      it("success listing", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "1",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "0",
            startAmount: "1000",
            endAmount: "1000",
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

      it("mismatch", async function () {
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
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            feeRecipient,
            "250",
            true
          )
        ).to.include.deep.ordered.members([[PrimaryFeeIssue.Recipient], []]);

        baseOrderParameters.consideration[1] = {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "24",
          endAmount: "25",
          recipient: feeRecipient,
        };

        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            feeRecipient,
            "250",
            true
          )
        ).to.include.deep.ordered.members([[PrimaryFeeIssue.StartAmount], []]);

        baseOrderParameters.consideration[1] = {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "24",
          recipient: feeRecipient,
        };

        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            feeRecipient,
            "250",
            true
          )
        ).to.include.deep.ordered.members([[PrimaryFeeIssue.EndAmount], []]);

        baseOrderParameters.consideration[1] = {
          itemType: ItemType.ERC20,
          token: erc721_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "25",
          recipient: feeRecipient,
        };
        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            feeRecipient,
            "250",
            true
          )
        ).to.include.deep.ordered.members([[PrimaryFeeIssue.Token], []]);

        baseOrderParameters.consideration[1] = {
          itemType: ItemType.NATIVE,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "25",
          recipient: feeRecipient,
        };
        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            feeRecipient,
            "250",
            true
          )
        ).to.include.deep.ordered.members([[PrimaryFeeIssue.ItemType], []]);
      });

      it("Primary fee missing", async function () {
        baseOrderParameters.offer = [
          {
            itemType: ItemType.ERC721,
            token: erc721_1.address,
            identifierOrCriteria: "1",
            startAmount: "1",
            endAmount: "1",
          },
        ];
        baseOrderParameters.consideration = [
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "0",
            startAmount: "1000",
            endAmount: "1000",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            feeRecipient,
            "250",
            true
          )
        ).to.include.deep.ordered.members([[PrimaryFeeIssue.Missing], []]);
      });
    });

    describe("Creator Fee", function () {
      it("success: with primary fee (creator fee engine)", async function () {
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
            token: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
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
            recipient: "0xAAe7aC476b117bcCAfE2f05F582906be44bc8FF1", // BAYC fee recipient
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

      it("success: with primary fee (2981)", async function () {
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
            token: "0x23581767a106ae21c074b2276D25e5C3e136a68b",
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
            startAmount: "50",
            endAmount: "50",
            recipient: "0xd1d507b688b518d2b7a4f65007799a5e9d80e974", // Moonbird fee recipient
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

      it("success: without primary fee", async function () {
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
            token: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
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
            recipient: "0xAAe7aC476b117bcCAfE2f05F582906be44bc8FF1", // BAYC fee recipient
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

      it("missing creator fee consideration item", async function () {
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
            token: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
            identifierOrCriteria: "1",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
        ];

        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            NULL_ADDRESS,
            "0",
            true
          )
        ).to.include.deep.ordered.members([[CreatorFeeIssue.Missing], []]);
      });

      it("mismatch", async function () {
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
            token: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D", // BAYC
            identifierOrCriteria: "1",
            startAmount: "1",
            endAmount: "1",
            recipient: owner.address,
          },
          {
            itemType: ItemType.ERC20,
            token: erc20_1.address,
            identifierOrCriteria: "0",
            startAmount: "0",
            endAmount: "25",
            recipient: "0xAAe7aC476b117bcCAfE2f05F582906be44bc8FF1", // BAYC fee recipient
          },
        ];

        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            NULL_ADDRESS,
            "0",
            true
          )
        ).to.include.deep.ordered.members([[CreatorFeeIssue.StartAmount], []]);

        baseOrderParameters.consideration[1] = {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "0",
          recipient: "0xAAe7aC476b117bcCAfE2f05F582906be44bc8FF1", // BAYC fee recipient
        };

        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            NULL_ADDRESS,
            "0",
            true
          )
        ).to.include.deep.ordered.members([[CreatorFeeIssue.EndAmount], []]);

        baseOrderParameters.consideration[1] = {
          itemType: ItemType.ERC20,
          token: erc1155_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "25",
          recipient: "0xAAe7aC476b117bcCAfE2f05F582906be44bc8FF1", // BAYC fee recipient
        };

        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            NULL_ADDRESS,
            "0",
            true
          )
        ).to.include.deep.ordered.members([[CreatorFeeIssue.Token], []]);

        baseOrderParameters.consideration[1] = {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "25",
          recipient: feeRecipient,
        };

        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            NULL_ADDRESS,
            "0",
            true
          )
        ).to.include.deep.ordered.members([[CreatorFeeIssue.Recipient], []]);

        baseOrderParameters.consideration[1] = {
          itemType: ItemType.ERC721,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "25",
          endAmount: "25",
          recipient: "0xAAe7aC476b117bcCAfE2f05F582906be44bc8FF1", // BAYC fee recipient
        };
        expect(
          await validator.validateStrictLogic(
            baseOrderParameters,
            NULL_ADDRESS,
            "0",
            true
          )
        ).to.include.deep.ordered.members([[CreatorFeeIssue.ItemType], []]);
      });
    });

    it("Both items are payment", async function () {
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
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
          recipient: owner.address,
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          "0",
          true
        )
      ).to.include.deep.ordered.members([
        [GenericIssue.InvalidOrderFormat],
        [],
      ]);
    });

    it("Both items are nft", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "0",
          startAmount: "1",
          endAmount: "1",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC1155,
          token: erc1155_1.address,
          identifierOrCriteria: "0",
          startAmount: "2",
          endAmount: "2",
          recipient: owner.address,
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          NULL_ADDRESS,
          "0",
          true
        )
      ).to.include.deep.ordered.members([
        [GenericIssue.InvalidOrderFormat],
        [],
      ]);
    });

    it("Fees uncheckable with required primary fee", async function () {
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
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
          recipient: owner.address,
        },
      ];

      expect(
        await validator.validateStrictLogic(
          baseOrderParameters,
          feeRecipient,
          "250",
          true
        )
      ).to.include.deep.ordered.members([
        [GenericIssue.InvalidOrderFormat],
        [],
      ]);
    });
  });

  describe("Validate Signature", function () {
    it("1271: success", async function () {
      const factoryErc1271 = await ethers.getContractFactory("TestERC1271");
      const erc1271 = await factoryErc1271.deploy(owner.address);

      baseOrderParameters.offerer = erc1271.address;
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];

      const order = await signOrder(baseOrderParameters, owner);
      expect(
        await validator.callStatic.validateSignature(order)
      ).to.include.deep.ordered.members([[], []]);
    });

    it("1271: failure", async function () {
      const factoryErc1271 = await ethers.getContractFactory("TestERC1271");
      const erc1271 = await factoryErc1271.deploy(owner.address);

      baseOrderParameters.offerer = erc1271.address;
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];

      const order = await signOrder(baseOrderParameters, otherAccounts[0]);
      expect(
        await validator.callStatic.validateSignature(order)
      ).to.include.deep.ordered.members([[SignatureIssue.Invalid], []]);
    });

    it("1271: failure 2", async function () {
      const factoryErc1271 = await ethers.getContractFactory("TestERC1271");
      const erc1271 = await factoryErc1271.deploy(owner.address);

      baseOrderParameters.offerer = erc1271.address;
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];

      const order = await signOrder(baseOrderParameters, otherAccounts[0]);
      let sig: string = String(order.signature);
      sig = sig.substring(0, sig.length - 6) + "0".repeat(6);
      order.signature = sig;

      expect(
        await validator.callStatic.validateSignature(order)
      ).to.include.deep.ordered.members([[SignatureIssue.Invalid], []]);
    });

    it("712: success", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];

      const order = await signOrder(baseOrderParameters, owner);
      expect(
        await validator.connect(owner).callStatic.validateSignature(order)
      ).to.include.deep.ordered.members([[], []]);
    });

    it("712: incorrect consideration items", async function () {
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
      ];

      const order = await signOrder(baseOrderParameters, owner);

      expect(
        await validator.callStatic.validateSignature(order)
      ).to.include.deep.ordered.members([
        [SignatureIssue.Invalid],
        [SignatureIssue.OriginalConsiderationItems],
      ]);
    });

    it("712: counter too low", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];

      const order = await signOrder(baseOrderParameters, owner);

      await seaport.incrementCounter();

      expect(
        await validator.callStatic.validateSignatureWithCounter(order, 0)
      ).to.include.deep.ordered.members([[SignatureIssue.LowCounter], []]);
    });

    it("712: counter high counter", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];

      const order = await signOrder(baseOrderParameters, owner, 4);

      expect(
        await validator.callStatic.validateSignatureWithCounter(order, 4)
      ).to.include.deep.ordered.members([[SignatureIssue.HighCounter], []]);
    });

    it("712: failure", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];

      const order = { parameters: baseOrderParameters, signature: "0x" };

      expect(
        await validator.callStatic.validateSignature(order)
      ).to.include.deep.ordered.members([[SignatureIssue.Invalid], []]);
    });

    it("Validate on-chain", async function () {
      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
      ];

      const order = { parameters: baseOrderParameters, signature: "0x" };

      await seaport.validate([order]);

      expect(
        await validator.callStatic.validateSignature(order)
      ).to.include.deep.ordered.members([[], []]);
    });
  });

  describe("Validate Contract Offerer", function () {
    let contractOfferer: TestContractOfferer;
    let invalidContractOfferer: TestInvalidContractOfferer165;
    beforeEach(async function () {
      const ContractOffererFactory = await ethers.getContractFactory(
        "TestContractOfferer"
      );
      const InvalidCOntractOffererFactory = await ethers.getContractFactory(
        "TestInvalidContractOfferer165"
      );
      contractOfferer = await ContractOffererFactory.deploy(seaport.address);
      invalidContractOfferer = await InvalidCOntractOffererFactory.deploy(
        seaport.address
      );
    });
    it("success", async function () {
      expect(
        await validator.callStatic.validateContractOfferer(
          contractOfferer.address
        )
      ).to.include.deep.ordered.members([[], []]);
    });
    it("failure", async function () {
      expect(
        await validator.callStatic.validateContractOfferer(
          invalidContractOfferer.address
        )
      ).to.include.deep.ordered.members([
        [ContractOffererIssue.InvalidContractOfferer],
        [],
      ]);
    });
  });

  describe("Full Scope", function () {
    it("success: validate", async function () {
      await erc721_1.mint(otherAccounts[0].address, 1);
      await erc20_1.mint(owner.address, 1000);
      await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 1000);

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
      ];
      baseOrderParameters.totalOriginalConsiderationItems = 1;

      const order: OrderStruct = {
        parameters: baseOrderParameters,
        signature: "0x",
      };

      await seaport.validate([order]);

      expect(
        await validator.callStatic.isValidOrder(order)
      ).to.include.deep.ordered.members([[], []]);
    });

    it("success: sig", async function () {
      await erc721_1.mint(otherAccounts[0].address, 1);
      await erc20_1.mint(owner.address, 1000);
      await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 1000);

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
      ];
      baseOrderParameters.totalOriginalConsiderationItems = 1;

      const order: OrderStruct = await signOrder(baseOrderParameters, owner);

      expect(
        await validator.callStatic.isValidOrder(order)
      ).to.include.deep.ordered.members([[], []]);
    });

    it("Full scope: all fees", async function () {
      await erc721_1.mint(otherAccounts[0].address, 1);
      await erc20_1.mint(owner.address, 1000);
      await erc20_1.approve(OPENSEA_CONDUIT_ADDRESS, 1000);

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
          token: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
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
          recipient: "0xAAe7aC476b117bcCAfE2f05F582906be44bc8FF1", // BAYC fee recipient
        },
      ];
      WEEKS_26;
      baseOrderParameters.conduitKey = OPENSEA_CONDUIT_KEY;
      baseOrderParameters.totalOriginalConsiderationItems = 3;

      const order = await signOrder(baseOrderParameters, owner);

      const validationConfiguration: ValidationConfigurationStruct = {
        primaryFeeRecipient: feeRecipient,
        primaryFeeBips: 250,
        checkCreatorFee: true,
        skipStrictValidation: false,
        shortOrderDuration: THIRTY_MINUTES,
        distantOrderExpiration: WEEKS_26,
      };

      expect(
        await validator.callStatic.isValidOrderWithConfiguration(
          validationConfiguration,
          order
        )
      ).to.include.deep.ordered.members([[], []]);
    });

    it("Full scope: skip strict validation", async function () {
      await erc721_1.mint(otherAccounts[0].address, 1);
      await erc721_1.mint(owner.address, 2);
      await erc721_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 2);
      await erc20_1.mint(owner.address, 1000);
      await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 1000);

      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "1000",
          endAmount: "1000",
        },
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "2",
          startAmount: "1",
          endAmount: "1",
        },
      ];
      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC721,
          token: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
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
          recipient: "0xAAe7aC476b117bcCAfE2f05F582906be44bc8FF1", // BAYC fee recipient
        },
      ];
      baseOrderParameters.totalOriginalConsiderationItems = 3;

      const order = await signOrder(baseOrderParameters, owner);

      const validationConfiguration: ValidationConfigurationStruct = {
        primaryFeeRecipient: NULL_ADDRESS,
        primaryFeeBips: 0,
        checkCreatorFee: false,
        skipStrictValidation: true,
        shortOrderDuration: THIRTY_MINUTES,
        distantOrderExpiration: WEEKS_26,
      };

      expect(
        await validator.callStatic.isValidOrderWithConfiguration(
          validationConfiguration,
          order
        )
      ).to.include.deep.ordered.members([[], [OfferIssue.MoreThanOneItem]]);
    });

    it("No primary fee when 0", async function () {
      await erc721_1.mint(otherAccounts[0].address, 1);
      await erc20_1.mint(owner.address, 1000);
      await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 1000);

      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "39",
          endAmount: "39",
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
      ];
      baseOrderParameters.totalOriginalConsiderationItems = 1;

      const order: OrderStruct = await signOrder(baseOrderParameters, owner);

      const validationConfiguration: ValidationConfigurationStruct = {
        primaryFeeRecipient: feeRecipient,
        primaryFeeBips: 250,
        checkCreatorFee: true,
        skipStrictValidation: false,
        shortOrderDuration: THIRTY_MINUTES,
        distantOrderExpiration: WEEKS_26,
      };

      expect(
        await validator.callStatic.isValidOrderWithConfiguration(
          validationConfiguration,
          order
        )
      ).to.include.deep.ordered.members([[], []]);
    });

    it("no sig", async function () {
      await erc721_1.mint(otherAccounts[0].address, 1);
      await erc20_1.mint(owner.address, 1000);
      await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 1000);

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
      ];
      baseOrderParameters.totalOriginalConsiderationItems = 1;

      const order: OrderStruct = {
        parameters: baseOrderParameters,
        signature: "0x",
      };

      expect(
        await validator.callStatic.isValidOrder(order)
      ).to.include.deep.ordered.members([[SignatureIssue.Invalid], []]);
    });

    it("no offer", async function () {
      await erc721_1.mint(otherAccounts[0].address, 1);
      await erc20_1.mint(owner.address, 1000);
      await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 1000);

      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC721,
          token: erc721_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
      ];
      baseOrderParameters.totalOriginalConsiderationItems = 1;

      const order: OrderStruct = {
        parameters: baseOrderParameters,
        signature: "0x",
      };

      expect(
        await validator.callStatic.isValidOrder(order)
      ).to.include.deep.ordered.members([
        [
          OfferIssue.ZeroItems,
          SignatureIssue.Invalid,
          GenericIssue.InvalidOrderFormat,
        ],
        [],
      ]);
    });

    it("zero offer amount and invalid consideration token", async function () {
      await erc721_1.mint(otherAccounts[0].address, 1);
      await erc20_1.mint(owner.address, 1000);
      await erc20_1.approve(CROSS_CHAIN_SEAPORT_ADDRESS, 1000);

      baseOrderParameters.offer = [
        {
          itemType: ItemType.ERC20,
          token: erc20_1.address,
          identifierOrCriteria: "0",
          startAmount: "0",
          endAmount: "0",
        },
      ];

      baseOrderParameters.consideration = [
        {
          itemType: ItemType.ERC721,
          token: erc20_1.address,
          identifierOrCriteria: "1",
          startAmount: "1",
          endAmount: "1",
          recipient: owner.address,
        },
      ];
      baseOrderParameters.totalOriginalConsiderationItems = 1;

      const order: OrderStruct = {
        parameters: baseOrderParameters,
        signature: "0x",
      };

      expect(
        await validator.callStatic.isValidOrder(order)
      ).to.include.deep.ordered.members([
        [
          OfferIssue.AmountZero,
          ERC721Issue.InvalidToken,
          SignatureIssue.Invalid,
        ],
        [],
      ]);
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
        version: "1.4",
        chainId: "31337",
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
