import { expect } from "chai";
import { randomInt } from "crypto";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import {
  fixtureERC1155,
  fixtureERC20,
  fixtureERC721,
  seaportFixture,
} from "./utils/fixtures";
import { VERSION } from "./utils/helpers";
import { faucet } from "./utils/impersonate";

import type {
  ConduitControllerInterface,
  ConduitInterface,
  EIP1271Wallet,
  EIP1271Wallet__factory,
  TransferHelper,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { BigNumber, Wallet } from "ethers";

describe(`TransferHelper tests (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let conduitController: ConduitControllerInterface;
  let EIP1271WalletFactory: EIP1271Wallet__factory;

  let createTransferWithApproval: SeaportFixtures["createTransferWithApproval"];
  let deployNewConduit: SeaportFixtures["deployNewConduit"];

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await faucet(owner.address, provider);

    ({
      EIP1271WalletFactory,
      conduitController,
      deployNewConduit,
      createTransferWithApproval,
    } = await seaportFixture(owner));
  });

  let sender: Wallet;
  let recipient: Wallet;
  let zone: Wallet;

  let alice: Wallet;
  let bob: Wallet;
  let cal: Wallet;

  let senderContract: EIP1271Wallet;
  let recipientContract: EIP1271Wallet;

  let tempConduit: ConduitInterface;
  let tempConduitKey: string;
  let tempTransferHelper: TransferHelper;

  interface Transfer {
    itemType: 0 | 1 | 2 | 3 | 4 | 5;
    token: string;
    from: string;
    to: string;
    identifier: BigNumber;
    amount: BigNumber;
  }

  interface TransferWithRecipient {
    itemType: 0 | 1 | 2 | 3 | 4 | 5;
    token: string;
    identifier: BigNumber;
    amount: BigNumber;
    recipient: string;
  }

  function createTransferWithRecipient(
    transfer: Transfer
  ): TransferWithRecipient {
    return {
      itemType: transfer.itemType,
      token: transfer.token,
      identifier: transfer.identifier,
      amount: transfer.amount,
      recipient: transfer.to,
    };
  }

  beforeEach(async () => {
    // Setup basic buyer/seller wallets with ETH
    sender = new ethers.Wallet(randomHex(32), provider);
    recipient = new ethers.Wallet(randomHex(32), provider);
    zone = new ethers.Wallet(randomHex(32), provider);

    alice = new ethers.Wallet(randomHex(32), provider);
    bob = new ethers.Wallet(randomHex(32), provider);
    cal = new ethers.Wallet(randomHex(32), provider);

    senderContract = await EIP1271WalletFactory.deploy(sender.address);
    recipientContract = await EIP1271WalletFactory.deploy(recipient.address);

    tempConduitKey = owner.address + randomHex(12).slice(2);
    tempConduit = await deployNewConduit(owner, tempConduitKey);

    for (const wallet of [
      sender,
      recipient,
      zone,
      senderContract,
      recipientContract,
    ]) {
      await faucet(wallet.address, provider);
    }

    // Deploy a new TransferHelper with the tempConduitController address
    const transferHelperFactory = await ethers.getContractFactory(
      "TransferHelper"
    );
    tempTransferHelper = await transferHelperFactory.deploy(
      conduitController.address
    );

    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, tempTransferHelper.address, true);
  });

  it("Executes transfers (many token types) with a conduit", async () => {
    // Get 3 Numbers that's value adds to Item Amount and minimum 1.
    const itemsToCreate = 10;
    const numERC20s = Math.max(1, randomInt(itemsToCreate - 2));
    const numEC721s = Math.max(1, randomInt(itemsToCreate - numERC20s - 1));
    const numERC1155s = Math.max(1, itemsToCreate - numERC20s - numEC721s);

    const erc20Contracts = [];
    const erc20Transfers = [];

    const erc721Contracts = [];
    const erc721Transfers = [];

    const erc1155Contracts = [];
    const erc1155Transfers = [];

    // Create numERC20s amount of ERC20 objects
    for (let i = 0; i < numERC20s; i++) {
      // Deploy Contract
      const { testERC20: tempERC20Contract } = await fixtureERC20(owner);
      // Create/Approve X amount of  ERC20s
      const erc20Transfer = await createTransferWithApproval(
        tempERC20Contract,
        sender,
        1,
        tempConduit.address,
        sender.address,
        recipient.address
      );
      erc20Contracts[i] = tempERC20Contract;
      erc20Transfers[i] = erc20Transfer;
    }

    // Create numEC721s amount of ERC20 objects
    for (let i = 0; i < numEC721s; i++) {
      // Deploy Contract
      const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
      // Create/Approve numEC721s amount of  ERC721s
      const erc721Transfer = await createTransferWithApproval(
        tempERC721Contract,
        sender,
        2,
        tempConduit.address,
        sender.address,
        recipient.address
      );
      erc721Contracts[i] = tempERC721Contract;
      erc721Transfers[i] = erc721Transfer;
    }

    // Create numERC1155s amount of ERC1155 objects
    for (let i = 0; i < numERC1155s; i++) {
      // Deploy Contract
      const { testERC1155: tempERC1155Contract } = await fixtureERC1155(owner);
      // Create/Approve numERC1155s amount of ERC1155s
      const erc1155Transfer = await createTransferWithApproval(
        tempERC1155Contract,
        sender,
        3,
        tempConduit.address,
        sender.address,
        recipient.address
      );
      erc1155Contracts[i] = tempERC1155Contract;
      erc1155Transfers[i] = erc1155Transfer;
    }

    const transfers = [
      ...erc20Transfers,
      ...erc721Transfers,
      ...erc1155Transfers,
    ];
    const contracts = [
      ...erc20Contracts,
      ...erc721Contracts,
      ...erc1155Contracts,
    ];
    // Send the bulk transfers
    await tempTransferHelper
      .connect(sender)
      .bulkTransfer(transfers, recipient.address, tempConduitKey);
    // Loop through all transfer to do ownership/balance checks
    for (let i = 0; i < transfers.length; i++) {
      // Get Itemtype, token, amount, identifier
      const { itemType, amount, identifier } = transfers[i];
      const token = contracts[i];

      switch (itemType) {
        case 1: // ERC20
          // Check balance
          expect(
            await (token as typeof erc20Contracts[0]).balanceOf(sender.address)
          ).to.equal(0);
          expect(
            await (token as typeof erc20Contracts[0]).balanceOf(
              recipient.address
            )
          ).to.equal(amount);
          break;
        case 2: // ERC721
        case 4: // ERC721_WITH_CRITERIA
          expect(
            await (token as typeof erc721Contracts[0]).ownerOf(identifier)
          ).to.equal(recipient.address);
          break;
        case 3: // ERC1155
        case 5: // ERC1155_WITH_CRITERIA
          // Check balance
          expect(await token.balanceOf(sender.address, identifier)).to.equal(0);
          expect(await token.balanceOf(recipient.address, identifier)).to.equal(
            amount
          );
          break;
      }
    }
  });

  it("Executes transfers (many token types) without a conduit", async () => {
    // Get 3 Numbers that's value adds to Item Amount and minimum 1.
    const itemsToCreate = 10;
    const numERC20s = Math.max(1, randomInt(itemsToCreate - 2));
    const numEC721s = Math.max(1, randomInt(itemsToCreate - numERC20s - 1));
    const numERC1155s = Math.max(1, itemsToCreate - numERC20s - numEC721s);

    const erc20Contracts = [];
    const erc20Transfers = [];

    const erc721Contracts = [];
    const erc721Transfers = [];

    const erc1155Contracts = [];
    const erc1155Transfers = [];

    // Create numERC20s amount of ERC20 objects
    for (let i = 0; i < numERC20s; i++) {
      // Deploy Contract
      const { testERC20: tempERC20Contract } = await fixtureERC20(owner);
      // Create/Approve X amount of  ERC20s
      const erc20Transfer = await createTransferWithApproval(
        tempERC20Contract,
        sender,
        1,
        tempTransferHelper.address,
        sender.address,
        recipient.address
      );
      erc20Contracts[i] = tempERC20Contract;
      erc20Transfers[i] = erc20Transfer;
    }

    // Create numEC721s amount of ERC721 objects
    for (let i = 0; i < numEC721s; i++) {
      // Deploy Contract
      const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
      // Create/Approve numEC721s amount of  ERC721s
      const erc721Transfer = await createTransferWithApproval(
        tempERC721Contract,
        sender,
        2,
        tempTransferHelper.address,
        sender.address,
        recipient.address
      );
      erc721Contracts[i] = tempERC721Contract;
      erc721Transfers[i] = erc721Transfer;
    }

    // Create numERC1155s amount of ERC1155 objects
    for (let i = 0; i < numERC1155s; i++) {
      // Deploy Contract
      const { testERC1155: tempERC1155Contract } = await fixtureERC1155(owner);
      // Create/Approve numERC1155s amount of ERC1155s
      const erc1155Transfer = await createTransferWithApproval(
        tempERC1155Contract,
        sender,
        3,
        tempTransferHelper.address,
        sender.address,
        recipient.address
      );
      erc1155Contracts[i] = tempERC1155Contract;
      erc1155Transfers[i] = erc1155Transfer;
    }

    const transfers = [
      ...erc20Transfers,
      ...erc721Transfers,
      ...erc1155Transfers,
    ];
    const contracts = [
      ...erc20Contracts,
      ...erc721Contracts,
      ...erc1155Contracts,
    ];
    // Send the bulk transfers
    await tempTransferHelper
      .connect(sender)
      .bulkTransfer(
        transfers,
        recipient.address,
        ethers.utils.formatBytes32String("")
      );
    // Loop through all transfer to do ownership/balance checks
    for (let i = 0; i < transfers.length; i++) {
      // Get Itemtype, token, amount, identifier
      const { itemType, amount, identifier } = transfers[i];
      const token = contracts[i];

      switch (itemType) {
        case 1: // ERC20
          // Check balance
          expect(
            await (token as typeof erc20Contracts[0]).balanceOf(sender.address)
          ).to.equal(0);
          expect(
            await (token as typeof erc20Contracts[0]).balanceOf(
              recipient.address
            )
          ).to.equal(amount);
          break;
        case 2: // ERC721
        case 4: // ERC721_WITH_CRITERIA
          expect(
            await (token as typeof erc721Contracts[0]).ownerOf(identifier)
          ).to.equal(recipient.address);
          break;
        case 3: // ERC1155
        case 5: // ERC1155_WITH_CRITERIA
          // Check balance
          expect(await token.balanceOf(sender.address, identifier)).to.equal(0);
          expect(await token.balanceOf(recipient.address, identifier)).to.equal(
            amount
          );
          break;
      }
    }
  });

  it("Executes transfers with multiple recipients (many token types) with a conduit", async () => {
    // Get 3 Numbers that's value adds to Item Amount and minimum 1.
    const itemsToCreate = 10;
    const numERC20s = Math.max(1, randomInt(itemsToCreate - 2));
    const numEC721s = Math.max(1, randomInt(itemsToCreate - numERC20s - 1));
    const numERC1155s = Math.max(1, itemsToCreate - numERC20s - numEC721s);

    const erc20Contracts = [];
    const erc20Transfers = [];

    const erc721Contracts = [];
    const erc721Transfers = [];

    const erc1155Contracts = [];
    const erc1155Transfers = [];

    const recipients = [
      recipient.address,
      alice.address,
      bob.address,
      cal.address,
    ];

    // Create numERC20s amount of ERC20 objects
    for (let i = 0; i < numERC20s; i++) {
      // Deploy Contract
      const { testERC20: tempERC20Contract } = await fixtureERC20(owner);
      // Create/Approve X amount of  ERC20s
      const erc20Transfer = await createTransferWithApproval(
        tempERC20Contract,
        sender,
        1,
        tempConduit.address,
        sender.address,
        recipients[i % 4]
      );
      erc20Contracts[i] = tempERC20Contract;
      erc20Transfers[i] = erc20Transfer;
    }

    // Create numEC721s amount of ERC20 objects
    for (let i = 0; i < numEC721s; i++) {
      // Deploy Contract
      const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
      // Create/Approve numEC721s amount of  ERC721s
      const erc721Transfer = await createTransferWithApproval(
        tempERC721Contract,
        sender,
        2,
        tempConduit.address,
        sender.address,
        recipients[i % 4]
      );
      erc721Contracts[i] = tempERC721Contract;
      erc721Transfers[i] = erc721Transfer;
    }

    // Create numERC1155s amount of ERC1155 objects
    for (let i = 0; i < numERC1155s; i++) {
      // Deploy Contract
      const { testERC1155: tempERC1155Contract } = await fixtureERC1155(owner);
      // Create/Approve numERC1155s amount of ERC1155s
      const erc1155Transfer = await createTransferWithApproval(
        tempERC1155Contract,
        sender,
        3,
        tempConduit.address,
        sender.address,
        recipients[i % 4]
      );

      erc1155Contracts[i] = tempERC1155Contract;
      erc1155Transfers[i] = erc1155Transfer;
    }

    const transfers = [
      ...erc20Transfers,
      ...erc721Transfers,
      ...erc1155Transfers,
    ];
    const contracts = [
      ...erc20Contracts,
      ...erc721Contracts,
      ...erc1155Contracts,
    ];

    const transfersWithRecipients = [];

    for (let i = 0; i < transfers.length; i++) {
      transfersWithRecipients[i] = createTransferWithRecipient(transfers[i]);
    }
    // Send the bulk transfers
    await tempTransferHelper
      .connect(sender)
      .bulkTransferToMultipleRecipients(
        transfersWithRecipients,
        tempConduitKey
      );
    // Loop through all transfer to do ownership/balance checks
    for (let i = 0; i < transfersWithRecipients.length; i++) {
      // Get Itemtype, token, amount, identifier
      const { itemType, amount, identifier } = transfers[i];
      const token = contracts[i];

      switch (itemType) {
        case 1: // ERC20
          // Check balance
          expect(
            await (token as typeof erc20Contracts[0]).balanceOf(sender.address)
          ).to.equal(0);
          expect(
            await (token as typeof erc20Contracts[0]).balanceOf(
              transfersWithRecipients[i].recipient
            )
          ).to.equal(amount);
          break;
        case 2: // ERC721
        case 4: // ERC721_WITH_CRITERIA
          expect(
            await (token as typeof erc721Contracts[0]).ownerOf(identifier)
          ).to.equal(transfersWithRecipients[i].recipient);
          break;
        case 3: // ERC1155
        case 5: // ERC1155_WITH_CRITERIA
          // Check balance
          expect(await token.balanceOf(sender.address, identifier)).to.equal(0);
          expect(
            await token.balanceOf(
              transfersWithRecipients[i].recipient,
              identifier
            )
          ).to.equal(amount);
          break;
      }
    }
  });

  it("Executes transfers with multiple recipients (many token types) without a conduit", async () => {
    // Get 3 Numbers that's value adds to Item Amount and minimum 1.
    const itemsToCreate = 10;
    const numERC20s = Math.max(1, randomInt(itemsToCreate - 2));
    const numEC721s = Math.max(1, randomInt(itemsToCreate - numERC20s - 1));
    const numERC1155s = Math.max(1, itemsToCreate - numERC20s - numEC721s);

    const erc20Contracts = [];
    const erc20Transfers = [];

    const erc721Contracts = [];
    const erc721Transfers = [];

    const erc1155Contracts = [];
    const erc1155Transfers = [];

    const recipients = [
      recipient.address,
      alice.address,
      bob.address,
      cal.address,
    ];

    // Create numERC20s amount of ERC20 objects
    for (let i = 0; i < numERC20s; i++) {
      // Deploy Contract
      const { testERC20: tempERC20Contract } = await fixtureERC20(owner);
      // Create/Approve X amount of ERC20s
      const erc20Transfer = await createTransferWithApproval(
        tempERC20Contract,
        sender,
        1,
        tempTransferHelper.address,
        sender.address,
        recipients[i % 4]
      );
      erc20Contracts[i] = tempERC20Contract;
      erc20Transfers[i] = erc20Transfer;
    }

    // Create numEC721s amount of ERC721 objects
    for (let i = 0; i < numEC721s; i++) {
      // Deploy Contract
      const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
      // Create/Approve numEC721s amount of  ERC721s
      const erc721Transfer = await createTransferWithApproval(
        tempERC721Contract,
        sender,
        2,
        tempTransferHelper.address,
        sender.address,
        recipients[i % 4]
      );
      erc721Contracts[i] = tempERC721Contract;
      erc721Transfers[i] = erc721Transfer;
    }

    // Create numERC1155s amount of ERC1155 objects
    for (let i = 0; i < numERC1155s; i++) {
      // Deploy Contract
      const { testERC1155: tempERC1155Contract } = await fixtureERC1155(owner);
      // Create/Approve numERC1155s amount of ERC1155s
      const erc1155Transfer = await createTransferWithApproval(
        tempERC1155Contract,
        sender,
        3,
        tempTransferHelper.address,
        sender.address,
        recipients[i % 4]
      );

      erc1155Contracts[i] = tempERC1155Contract;
      erc1155Transfers[i] = erc1155Transfer;
    }

    const transfers = [
      ...erc20Transfers,
      ...erc721Transfers,
      ...erc1155Transfers,
    ];
    const contracts = [
      ...erc20Contracts,
      ...erc721Contracts,
      ...erc1155Contracts,
    ];

    const transfersWithRecipients = [];

    for (let i = 0; i < transfers.length; i++) {
      transfersWithRecipients[i] = createTransferWithRecipient(transfers[i]);
    }

    // Send the bulk transfers
    await tempTransferHelper
      .connect(sender)
      .bulkTransferToMultipleRecipients(
        transfersWithRecipients,
        ethers.utils.formatBytes32String("")
      );
    // Loop through all transfer to do ownership/balance checks
    for (let i = 0; i < transfersWithRecipients.length; i++) {
      // Get Itemtype, token, amount, identifier
      const { itemType, amount, identifier } = transfers[i];
      const token = contracts[i];

      switch (itemType) {
        case 1: // ERC20
          // Check balance
          expect(
            await (token as typeof erc20Contracts[0]).balanceOf(sender.address)
          ).to.equal(0);
          expect(
            await (token as typeof erc20Contracts[0]).balanceOf(
              transfersWithRecipients[i].recipient
            )
          ).to.equal(amount);
          break;
        case 2: // ERC721
        case 4: // ERC721_WITH_CRITERIA
          expect(
            await (token as typeof erc721Contracts[0]).ownerOf(identifier)
          ).to.equal(transfersWithRecipients[i].recipient);
          break;
        case 3: // ERC1155
        case 5: // ERC1155_WITH_CRITERIA
          // Check balance
          expect(await token.balanceOf(sender.address, identifier)).to.equal(0);
          expect(
            await token.balanceOf(
              transfersWithRecipients[i].recipient,
              identifier
            )
          ).to.equal(amount);
          break;
      }
    }
  });

  it("Executes ERC721 transfers to a contract recipient without a conduit", async () => {
    // Deploy recipient contract
    const erc721RecipientFactory = await ethers.getContractFactory(
      "ERC721ReceiverMock"
    );
    const erc721Recipient = await erc721RecipientFactory.deploy(
      Buffer.from("150b7a02", "hex"),
      0
    );

    const erc721Contracts = [];
    const erc721Transfers = [];

    // Create 5 ERC721 objects
    for (let i = 0; i < 5; i++) {
      // Deploy Contract
      const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
      // Create/Approve numEC721s amount of  ERC721s
      const erc721Transfer = await createTransferWithApproval(
        tempERC721Contract,
        sender,
        2,
        tempTransferHelper.address,
        sender.address,
        recipient.address
      );
      erc721Contracts[i] = tempERC721Contract;
      erc721Transfers[i] = erc721Transfer;
    }

    // Send the bulk transfers
    await tempTransferHelper
      .connect(sender)
      .bulkTransfer(
        erc721Transfers,
        erc721Recipient.address,
        ethers.utils.formatBytes32String("")
      );

    // Loop through all transfer to do ownership/balance checks
    for (let i = 0; i < 5; i++) {
      // Get identifier and ERC721 token contract
      const { identifier } = erc721Transfers[i];
      const token = erc721Contracts[i];

      expect(
        await (token as typeof erc721Contracts[0]).ownerOf(identifier)
      ).to.equal(erc721Recipient.address);
    }
  });

  it("Reverts on native token transfers", async () => {
    const ethTransferHelperItems = [
      {
        itemType: 0,
        token: ethers.constants.AddressZero,
        identifier: 0,
        amount: 10,
      },
      {
        itemType: 0,
        token: ethers.constants.AddressZero,
        identifier: 0,
        amount: 20,
      },
    ];
    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(
          ethTransferHelperItems,
          recipient.address,
          ethers.utils.formatBytes32String("")
        )
    ).to.be.revertedWith("InvalidItemType");
  });

  it("Reverts on invalid ERC20 identifier", async () => {
    const erc20TransferHelperItems = [
      {
        itemType: 1,
        token: ethers.constants.AddressZero,
        identifier: 5,
        amount: 10,
      },
      {
        itemType: 1,
        token: ethers.constants.AddressZero,
        identifier: 4,
        amount: 20,
      },
    ];
    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(
          erc20TransferHelperItems,
          recipient.address,
          ethers.utils.formatBytes32String("")
        )
    ).to.be.revertedWith("InvalidERC20Identifier");
  });

  it("Reverts on invalid ERC721 transfer amount", async () => {
    // Deploy Contract
    const { testERC721: tempERC721Contract } = await fixtureERC721(owner);

    const erc721TransferHelperItems = [
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 1,
        amount: 10,
      },
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 2,
        amount: 20,
      },
    ];
    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(
          erc721TransferHelperItems,
          recipient.address,
          ethers.utils.formatBytes32String("")
        )
    ).to.be.revertedWith("InvalidERC721TransferAmount");
  });

  it("Reverts on invalid ERC721 recipient", async () => {
    // Deploy Contract
    const { testERC721: tempERC721Contract } = await fixtureERC721(owner);

    const erc721TransferHelperItems = [
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 1,
        amount: 1,
      },
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 2,
        amount: 1,
      },
    ];
    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(
          erc721TransferHelperItems,
          tempERC721Contract.address,
          ethers.utils.formatBytes32String("")
        )
    ).to.be.revertedWith(
      `ERC721ReceiverErrorRevertBytes("0x", "${tempERC721Contract.address}", "${sender.address}", 1)`
    );
  });

  it("Reverts on invalid function selector", async () => {
    const invalidRecipientFactory = await ethers.getContractFactory(
      "InvalidERC721Recipient"
    );
    const invalidRecipient = await invalidRecipientFactory.deploy();

    const { testERC721: tempERC721Contract } = await fixtureERC721(owner);

    const erc721TransferHelperItems = [
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 1,
        amount: 1,
      },
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 2,
        amount: 1,
      },
    ];
    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(
          erc721TransferHelperItems,
          invalidRecipient.address,
          ethers.utils.formatBytes32String("")
        )
    ).to.be.revertedWith(
      `InvalidERC721Recipient("${invalidRecipient.address}")`
    );
  });

  it("Reverts on nonexistent conduit", async () => {
    // Deploy ERC721 Contract
    const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
    // Deploy ERC20 Contract
    const { testERC20: tempERC20Contract } = await fixtureERC20(owner);

    const transferHelperItems = [
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 1,
        amount: 1,
      },
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 2,
        amount: 1,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 10,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 20,
      },
    ];
    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(
          transferHelperItems,
          recipient.address,
          ethers.utils.formatBytes32String("0xabc")
        )
    ).to.be.reverted;
  });

  it("Reverts on error in ERC721 receiver", async () => {
    // Deploy ERC721 Contract
    const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
    // Deploy ERC20 Contract
    const { testERC20: tempERC20Contract } = await fixtureERC20(owner);

    // Deploy mock ERC721 receiver
    const mockERC721ReceiverFactory = await ethers.getContractFactory(
      "ERC721ReceiverMock"
    );
    const mockERC721Receiver = await mockERC721ReceiverFactory.deploy(
      Buffer.from("abcd0000", "hex"),
      1
    );

    const transferHelperItems = [
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 1,
        amount: 1,
      },
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 2,
        amount: 1,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 10,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 20,
      },
    ];
    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(
          transferHelperItems,
          mockERC721Receiver.address,
          ethers.utils.formatBytes32String("")
        )
    ).to.be.revertedWith("ERC721ReceiverMock: reverting");
  });

  it("Reverts with custom error in conduit", async () => {
    // Deploy ERC721 Contract
    const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
    // Deploy ERC20 Contract
    const { testERC20: tempERC20Contract } = await fixtureERC20(owner);

    const transferHelperItems = [
      // Invalid item type
      {
        itemType: 0,
        token: ethers.constants.AddressZero,
        identifier: 0,
        amount: 1,
      },
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 2,
        amount: 1,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 10,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 20,
      },
    ];

    const invalidItemTypeErrorSelector = ethers.utils
      .id("InvalidItemType()")
      .slice(0, 10);

    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(transferHelperItems, recipient.address, tempConduitKey)
    ).to.be.revertedWith(
      `ConduitErrorRevertBytes("${invalidItemTypeErrorSelector}", "${tempConduitKey.toLowerCase()}", "${
        tempConduit.address
      }")`
    );
  });

  it("Reverts with bubbled up string error from call to conduit", async () => {
    // Deploy ERC721 Contract
    const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
    // Deploy ERC20 Contract
    const { testERC20: tempERC20Contract } = await fixtureERC20(owner);

    // Call will revert since ERC721 tokens have not been minted
    const transferHelperItems = [
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 1,
        amount: 1,
      },
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 2,
        amount: 1,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 10,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 20,
      },
    ];

    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(transferHelperItems, recipient.address, tempConduitKey)
    ).to.be.revertedWith(
      `ConduitErrorRevertString("WRONG_FROM", "${tempConduitKey.toLowerCase()}", "${
        tempConduit.address
      }")`
    );
  });

  it("Reverts when no revert string is returned from call to conduit", async () => {
    // Deploy ERC1155 Contract
    const { testERC1155: tempERC1155Contract } = await fixtureERC1155(owner);

    await tempERC1155Contract.connect(owner).mint(sender.address, 0, 100);

    const mockConduitControllerFactory = await ethers.getContractFactory(
      "ConduitControllerMock"
    );
    const mockConduitController = await mockConduitControllerFactory.deploy(
      1 // ConduitMockRevertNoReason
    );

    const mockTransferHelperFactory = await ethers.getContractFactory(
      "TransferHelper"
    );
    const mockTransferHelper = await mockTransferHelperFactory.deploy(
      mockConduitController.address
    );
    const mockConduitKey = owner.address + randomHex(12).slice(2);

    // Deploy the mock conduit through the mock conduit controller
    await mockConduitController
      .connect(owner)
      .createConduit(mockConduitKey, owner.address);

    const mockConduitAddress = (
      await mockConduitController.getConduit(mockConduitKey)
    )[0];

    await tempERC1155Contract
      .connect(sender)
      .setApprovalForAll(mockConduitAddress, true);

    const transferHelperItems = Array.from(Array(11)).map(() => ({
      itemType: 3,
      token: tempERC1155Contract.address,
      identifier: 0,
      amount: 10,
    }));

    await expect(
      mockTransferHelper
        .connect(sender)
        .bulkTransfer(transferHelperItems, recipient.address, mockConduitKey)
    ).to.be.revertedWith(
      `ConduitErrorRevertBytes("0x", "${mockConduitKey.toLowerCase()}", "${mockConduitAddress}")`
    );
  });

  it("Reverts with bubbled up panic error from call to conduit", async () => {
    // Deploy mock ERC20
    const mockERC20PanicFactory = await ethers.getContractFactory(
      "TestERC20Panic"
    );
    const mockERC20Panic = await mockERC20PanicFactory.deploy();

    const transferHelperItems = [
      {
        itemType: 1,
        token: mockERC20Panic.address,
        identifier: 0,
        amount: 10,
      },
      {
        itemType: 1,
        token: mockERC20Panic.address,
        identifier: 0,
        amount: 20,
      },
    ];

    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(transferHelperItems, recipient.address, tempConduitKey)
    ).to.be.reverted;
  });

  it("Reverts with invalid magic value returned by call to conduit", async () => {
    // Deploy ERC20 Contract
    const { testERC20: tempERC20Contract } = await fixtureERC20(owner);

    await tempERC20Contract.connect(owner).mint(sender.address, 100);

    const mockConduitControllerFactory = await ethers.getContractFactory(
      "ConduitControllerMock"
    );
    const mockConduitController = await mockConduitControllerFactory.deploy(
      2 // ConduitMockInvalidMagic
    );

    const mockTransferHelperFactory = await ethers.getContractFactory(
      "TransferHelper"
    );
    const mockTransferHelper = await mockTransferHelperFactory.deploy(
      mockConduitController.address
    );
    const mockConduitKey = owner.address + randomHex(12).slice(2);

    // Deploy the mock conduit through the mock conduit controller
    await mockConduitController
      .connect(owner)
      .createConduit(mockConduitKey, owner.address);

    const mockConduitAddress = (
      await mockConduitController.getConduit(mockConduitKey)
    )[0];

    await tempERC20Contract.connect(sender).approve(mockConduitAddress, 100);

    const transferHelperItems = [
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 10,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 20,
      },
    ];

    await expect(
      mockTransferHelper
        .connect(sender)
        .bulkTransfer(transferHelperItems, recipient.address, mockConduitKey)
    ).to.be.revertedWith(
      `InvalidConduit("${mockConduitKey.toLowerCase()}", "${mockConduitAddress}")`
    );
  });

  it("Reverts when data length is greater than 0 and less than 256", async () => {
    // Deploy ERC20 Contract
    const { testERC20: tempERC20Contract } = await fixtureERC20(owner);

    await tempERC20Contract.connect(owner).mint(sender.address, 100);

    const mockConduitControllerFactory = await ethers.getContractFactory(
      "ConduitControllerMock"
    );
    const mockConduitController = await mockConduitControllerFactory.deploy(
      3 // ConduitMockRevertBytes
    );

    const mockTransferHelperFactory = await ethers.getContractFactory(
      "TransferHelper"
    );
    const mockTransferHelper = await mockTransferHelperFactory.deploy(
      mockConduitController.address
    );
    const mockConduitKey = owner.address + randomHex(12).slice(2);

    // Deploy the mock conduit through the mock conduit controller
    await mockConduitController
      .connect(owner)
      .createConduit(mockConduitKey, owner.address);

    const mockConduitAddress = (
      await mockConduitController.getConduit(mockConduitKey)
    )[0];
    await tempERC20Contract.connect(sender).approve(mockConduitAddress, 100);

    const transferHelperItems = [
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 10,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 20,
      },
    ];

    const customErrorSelector = ethers.utils.id("CustomError()").slice(0, 10);

    await expect(
      mockTransferHelper
        .connect(sender)
        .bulkTransfer(transferHelperItems, recipient.address, mockConduitKey)
    ).to.be.revertedWith(
      `ConduitErrorRevertBytes("${customErrorSelector}", "${mockConduitKey.toLowerCase()}", "${mockConduitAddress}")`
    );
  });

  it("Reverts when recipient is the null address (with conduit)", async () => {
    // Deploy ERC721 Contract
    const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
    // Deploy ERC20 Contract
    const { testERC20: tempERC20Contract } = await fixtureERC20(owner);

    const transferHelperItems = [
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 1,
        amount: 1,
      },
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 2,
        amount: 1,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 10,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 20,
      },
    ];
    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(
          transferHelperItems,
          ethers.constants.AddressZero,
          tempConduitKey
        )
    ).to.be.revertedWith("RecipientCannotBeZero()");
  });

  it("Reverts when recipient is the null address (without conduit)", async () => {
    // Deploy ERC721 Contract
    const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
    // Deploy ERC20 Contract
    const { testERC20: tempERC20Contract } = await fixtureERC20(owner);

    const transferHelperItems = [
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 1,
        amount: 1,
      },
      {
        itemType: 2,
        token: tempERC721Contract.address,
        identifier: 2,
        amount: 1,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 10,
      },
      {
        itemType: 1,
        token: tempERC20Contract.address,
        identifier: 0,
        amount: 20,
      },
    ];
    await expect(
      tempTransferHelper
        .connect(sender)
        .bulkTransfer(
          transferHelperItems,
          ethers.constants.AddressZero,
          ethers.utils.formatBytes32String("")
        )
    ).to.be.revertedWith("RecipientCannotBeZero()");
  });
});
