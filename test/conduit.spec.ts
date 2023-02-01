import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { randomInt } from "crypto";
import { ethers, network } from "hardhat";

import { deployContract } from "./utils/contracts";
import {
  getItemETH,
  random128,
  randomBN,
  randomHex,
  toAddress,
  toBN,
  toFulfillment,
} from "./utils/encoding";
import { faucet } from "./utils/faucet";
import {
  fixtureERC1155,
  fixtureERC20,
  fixtureERC721,
  seaportFixture,
} from "./utils/fixtures";
import {
  VERSION,
  getCustomRevertSelector,
  minRandom,
  simulateMatchOrders,
} from "./utils/helpers";

import type {
  ConduitControllerInterface,
  ConduitInterface,
  Conduit__factory,
  ConsiderationInterface,
  TestERC1155,
  TestERC20,
  TestERC721,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { Wallet } from "ethers";

const { parseEther } = ethers.utils;

describe(`Conduit tests (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let conduitController: ConduitControllerInterface;
  let conduitImplementation: Conduit__factory;
  let conduitKeyOne: string;
  let conduitOne: ConduitInterface;
  let marketplaceContract: ConsiderationInterface;
  let testERC1155: TestERC1155;
  let testERC1155Two: TestERC1155;
  let testERC20: TestERC20;
  let testERC721: TestERC721;

  let createMirrorBuyNowOrder: SeaportFixtures["createMirrorBuyNowOrder"];
  let createOrder: SeaportFixtures["createOrder"];
  let createTransferWithApproval: SeaportFixtures["createTransferWithApproval"];
  let deployNewConduit: SeaportFixtures["deployNewConduit"];
  let getTestItem1155: SeaportFixtures["getTestItem1155"];
  let mint1155: SeaportFixtures["mint1155"];
  let mint721: SeaportFixtures["mint721"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];
  let set1155ApprovalForAll: SeaportFixtures["set1155ApprovalForAll"];
  let set721ApprovalForAll: SeaportFixtures["set721ApprovalForAll"];

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await faucet(owner.address, provider);

    ({
      conduitController,
      conduitImplementation,
      conduitKeyOne,
      conduitOne,
      createMirrorBuyNowOrder,
      createOrder,
      createTransferWithApproval,
      deployNewConduit,
      getTestItem1155,
      marketplaceContract,
      mint1155,
      mint721,
      mintAndApproveERC20,
      set1155ApprovalForAll,
      set721ApprovalForAll,
      testERC1155,
      testERC1155Two,
      testERC20,
      testERC721,
    } = await seaportFixture(owner));
  });

  let seller: Wallet;
  let buyer: Wallet;
  let zone: Wallet;

  let tempConduit: ConduitInterface;

  async function setupFixture() {
    // Setup basic buyer/seller wallets with ETH
    const seller = new ethers.Wallet(randomHex(32), provider);
    const buyer = new ethers.Wallet(randomHex(32), provider);
    const zone = new ethers.Wallet(randomHex(32), provider);

    // Deploy a new conduit
    const tempConduit = await deployNewConduit(owner);

    for (const wallet of [seller, buyer, zone]) {
      await faucet(wallet.address, provider);
    }

    return { seller, buyer, zone, tempConduit };
  }

  beforeEach(async () => {
    ({ seller, buyer, zone, tempConduit } = await loadFixture(setupFixture));
  });

  it("Adds a channel, and executes transfers (ERC1155 with batch)", async () => {
    // Owner updates conduit channel to allow seller access
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, seller.address, true);

    const { nftId, amount } = await mint1155(owner, 2);

    const { nftId: secondNftId, amount: secondAmount } = await mint1155(
      owner,
      2
    );

    await testERC1155.mint(seller.address, nftId, amount.mul(2));
    await testERC1155.mint(seller.address, secondNftId, secondAmount.mul(2));
    await set1155ApprovalForAll(seller, tempConduit.address, true);

    await tempConduit.connect(seller).executeWithBatch1155(
      [],
      [
        {
          token: testERC1155.address,
          from: seller.address,
          to: buyer.address,
          ids: [nftId, secondNftId],
          amounts: [amount, secondAmount],
        },
        {
          token: testERC1155.address,
          from: seller.address,
          to: buyer.address,
          ids: [secondNftId, nftId],
          amounts: [secondAmount, amount],
        },
      ]
    );
  });

  it("Adds a channel, and executes only batch transfers (ERC1155 with batch)", async () => {
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, seller.address, true);

    const { nftId, amount } = await mint1155(owner, 2);

    const { nftId: secondNftId, amount: secondAmount } = await mint1155(
      owner,
      2
    );

    await testERC1155.mint(seller.address, nftId, amount.mul(2));
    await testERC1155.mint(seller.address, secondNftId, secondAmount.mul(2));
    await set1155ApprovalForAll(seller, tempConduit.address, true);

    await tempConduit.connect(seller).executeBatch1155([
      {
        token: testERC1155.address,
        from: seller.address,
        to: buyer.address,
        ids: [nftId, secondNftId],
        amounts: [amount, secondAmount],
      },
      {
        token: testERC1155.address,
        from: seller.address,
        to: buyer.address,
        ids: [secondNftId, nftId],
        amounts: [secondAmount, amount],
      },
    ]);
  });

  it("Adds a channel, and executes transfers (ERC721)", async () => {
    // Owner updates conduit channel to allow seller access
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, seller.address, true);

    // Seller mints nft
    const nftId = randomBN();
    await testERC721.mint(seller.address, nftId);

    const secondNftId = randomBN();
    await testERC721.mint(seller.address, secondNftId);

    // Check ownership
    expect(await testERC721.ownerOf(nftId)).to.equal(seller.address);
    expect(await testERC721.ownerOf(secondNftId)).to.equal(seller.address);

    await expect(
      testERC721.connect(seller).setApprovalForAll(tempConduit.address, true)
    )
      .to.emit(testERC721, "ApprovalForAll")
      .withArgs(seller.address, tempConduit.address, true);

    await tempConduit.connect(seller).execute([
      {
        itemType: 2, // ERC721
        token: testERC721.address,
        from: seller.address,
        to: buyer.address,
        identifier: nftId,
        amount: ethers.BigNumber.from(1),
      },
      {
        itemType: 2, // ERC721
        token: testERC721.address,
        from: seller.address,
        to: buyer.address,
        identifier: secondNftId,
        amount: ethers.BigNumber.from(1),
      },
    ]);

    // Check ownership
    expect(await testERC721.ownerOf(nftId)).to.equal(buyer.address);
    expect(await testERC721.ownerOf(secondNftId)).to.equal(buyer.address);
  });

  it("Adds a channel, and executes transfers (ERC721 + ERC20)", async () => {
    // Owner updates conduit channel to allow seller access
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, seller.address, true);

    // Seller mints nft
    const nftId = randomBN();
    await testERC721.mint(seller.address, nftId);

    // Check ownership
    expect(await testERC721.ownerOf(nftId)).to.equal(seller.address);

    // Set approval of nft
    await expect(
      testERC721.connect(seller).setApprovalForAll(tempConduit.address, true)
    )
      .to.emit(testERC721, "ApprovalForAll")
      .withArgs(seller.address, tempConduit.address, true);

    const tokenAmount = minRandom(100);
    await testERC20.mint(seller.address, tokenAmount);

    // Check balance
    expect(await testERC20.balanceOf(seller.address)).to.equal(tokenAmount);

    // Seller approves conduit contract to transfer tokens
    await expect(
      testERC20.connect(seller).approve(tempConduit.address, tokenAmount)
    )
      .to.emit(testERC20, "Approval")
      .withArgs(seller.address, tempConduit.address, tokenAmount);

    // Send an ERC721 and (token amount - 100) ERC20 tokens
    await tempConduit.connect(seller).execute([
      {
        itemType: 2, // ERC721
        token: testERC721.address,
        from: seller.address,
        to: buyer.address,
        identifier: nftId,
        amount: ethers.BigNumber.from(1),
      },
      {
        itemType: 1, // ERC20
        token: testERC20.address,
        from: seller.address,
        to: buyer.address,
        identifier: 0,
        amount: tokenAmount.sub(100),
      },
    ]);

    // Check ownership
    expect(await testERC721.ownerOf(nftId)).to.equal(buyer.address);
    // Check balance
    expect(await testERC20.balanceOf(seller.address)).to.equal(100);
    expect(await testERC20.balanceOf(buyer.address)).to.equal(
      tokenAmount.sub(100)
    );
  });

  it("Adds a channel, and executes transfers (ERC721 + ERC1155)", async () => {
    // Owner updates conduit channel to allow seller access
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, seller.address, true);

    // Seller mints nft
    const nftId = randomBN();
    await testERC721.mint(seller.address, nftId);

    // Check ownership
    expect(await testERC721.ownerOf(nftId)).to.equal(seller.address);

    // Set approval of nft
    await expect(
      testERC721.connect(seller).setApprovalForAll(tempConduit.address, true)
    )
      .to.emit(testERC721, "ApprovalForAll")
      .withArgs(seller.address, tempConduit.address, true);

    const secondNftId = random128();
    const amount = random128().add(1);
    await testERC1155.mint(seller.address, secondNftId, amount);

    await expect(
      testERC1155.connect(seller).setApprovalForAll(tempConduit.address, true)
    )
      .to.emit(testERC1155, "ApprovalForAll")
      .withArgs(seller.address, tempConduit.address, true);

    // Check ownership
    expect(await testERC1155.balanceOf(seller.address, secondNftId)).to.equal(
      amount
    );

    // Send an ERC721 and ERC1155
    await tempConduit.connect(seller).execute([
      {
        itemType: 2, // ERC721
        token: testERC721.address,
        from: seller.address,
        to: buyer.address,
        identifier: nftId,
        amount: ethers.BigNumber.from(1),
      },
      {
        itemType: 3, // ERC1155
        token: testERC1155.address,
        from: seller.address,
        to: buyer.address,
        identifier: secondNftId,
        amount: amount.sub(10),
      },
    ]);

    // Check ownership
    expect(await testERC721.ownerOf(nftId)).to.equal(buyer.address);
    // Check balance
    expect(await testERC1155.balanceOf(seller.address, secondNftId)).to.equal(
      10
    );
    expect(await testERC1155.balanceOf(buyer.address, secondNftId)).to.equal(
      amount.sub(10)
    );
  });

  it("Adds a channel, and executes transfers (ERC20 + ERC1155)", async () => {
    // Owner updates conduit channel to allow seller access
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, seller.address, true);

    // Seller mints nft
    const tokenAmount = minRandom(100).div(100);
    await testERC20.mint(seller.address, tokenAmount);

    // Check balance
    expect(await testERC20.balanceOf(seller.address)).to.equal(tokenAmount);

    // Seller approves conduit contract to transfer tokens
    await expect(
      testERC20.connect(seller).approve(tempConduit.address, tokenAmount)
    )
      .to.emit(testERC20, "Approval")
      .withArgs(seller.address, tempConduit.address, tokenAmount);

    const nftId = random128();
    const erc1155amount = random128().add(1);
    await testERC1155.mint(seller.address, nftId, erc1155amount);

    await expect(
      testERC1155.connect(seller).setApprovalForAll(tempConduit.address, true)
    )
      .to.emit(testERC1155, "ApprovalForAll")
      .withArgs(seller.address, tempConduit.address, true);

    // Check ownership
    expect(await testERC1155.balanceOf(seller.address, nftId)).to.equal(
      erc1155amount
    );

    // Send an ERC20 and ERC1155
    await tempConduit.connect(seller).execute([
      {
        itemType: 1, // ERC20
        token: testERC20.address,
        from: seller.address,
        to: buyer.address,
        identifier: 0,
        amount: tokenAmount.sub(100),
      },
      {
        itemType: 3, // ERC1155
        token: testERC1155.address,
        from: seller.address,
        to: buyer.address,
        identifier: nftId,
        amount: erc1155amount.sub(10),
      },
    ]);

    // Check balance
    expect(await testERC20.balanceOf(seller.address)).to.equal(100);
    expect(await testERC20.balanceOf(buyer.address)).to.equal(
      tokenAmount.sub(100)
    );
    expect(await testERC1155.balanceOf(seller.address, nftId)).to.equal(10);
    expect(await testERC1155.balanceOf(buyer.address, nftId)).to.equal(
      erc1155amount.sub(10)
    );
  });

  it("Adds a channel, and executes transfers (ERC20 + ERC721 + ERC1155)", async () => {
    // Owner updates conduit channel to allow seller access
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, seller.address, true);

    // Create/Approve X amount of  ERC20s
    const erc20Transfer = await createTransferWithApproval(
      testERC20,
      seller,
      1,
      tempConduit.address,
      seller.address,
      buyer.address
    );

    // Create/Approve Y amount of  ERC721s
    const erc721Transfer = await createTransferWithApproval(
      testERC721,
      seller,
      2,
      tempConduit.address,
      seller.address,
      buyer.address
    );

    // Create/Approve Z amount of ERC1155s
    const erc1155Transfer = await createTransferWithApproval(
      testERC1155,
      seller,
      3,
      tempConduit.address,
      seller.address,
      buyer.address
    );

    // Send an ERC20, ERC721, and ERC1155
    await tempConduit
      .connect(seller)
      .execute([erc20Transfer, erc721Transfer, erc1155Transfer]);

    // Check ownership
    expect(await testERC721.ownerOf(erc721Transfer.identifier)).to.equal(
      buyer.address
    );
    // Check balance
    expect(await testERC20.balanceOf(seller.address)).to.equal(0);
    expect(await testERC20.balanceOf(buyer.address)).to.equal(
      erc20Transfer.amount
    );
    expect(
      await testERC1155.balanceOf(seller.address, erc1155Transfer.identifier)
    ).to.equal(0);
    expect(
      await testERC1155.balanceOf(buyer.address, erc1155Transfer.identifier)
    ).to.equal(erc1155Transfer.amount);
  });

  it("Adds a channel, and executes transfers (many token types)", async () => {
    // Owner updates conduit channel to allow seller access
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, seller.address, true);

    // Get 3 numbers whose value adds to Item Amount and minimum 1.
    const itemsToCreate = 64;
    const numERC20s = Math.max(1, randomInt(itemsToCreate - 2));
    const numERC721s = Math.max(1, randomInt(itemsToCreate - numERC20s - 1));
    const numERC1155s = Math.max(1, itemsToCreate - numERC20s - numERC721s);

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
        seller,
        1,
        tempConduit.address,
        seller.address,
        buyer.address
      );
      erc20Contracts[i] = tempERC20Contract;
      erc20Transfers[i] = erc20Transfer;
    }

    // Create numERC721s amount of ERC20 objects
    for (let i = 0; i < numERC721s; i++) {
      // Deploy Contract
      const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
      // Create/Approve numERC721s amount of ERC721s
      const erc721Transfer = await createTransferWithApproval(
        tempERC721Contract,
        seller,
        2,
        tempConduit.address,
        seller.address,
        buyer.address
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
        seller,
        3,
        tempConduit.address,
        seller.address,
        buyer.address
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
    // Send the transfers
    await tempConduit.connect(seller).execute(transfers);

    // Loop through all transfer to do ownership/balance checks
    for (let i = 0; i < transfers.length; i++) {
      // Get itemType, token, from, to, amount, identifier
      const itemType = transfers[i].itemType;
      const token = contracts[i];
      const from = transfers[i].from;
      const to = transfers[i].to;
      const amount = transfers[i].amount;
      const identifier = transfers[i].identifier;

      switch (itemType) {
        case 1: // ERC20
          // Check balance
          expect(
            await (token as typeof erc20Contracts[0]).balanceOf(from)
          ).to.equal(0);
          expect(
            await (token as typeof erc20Contracts[0]).balanceOf(to)
          ).to.equal(amount);
          break;
        case 2: // ERC721
        case 4: // ERC721_WITH_CRITERIA
          expect(
            await (token as typeof erc721Contracts[0]).ownerOf(identifier)
          ).to.equal(to);
          break;
        case 3: // ERC1155
        case 5: // ERC1155_WITH_CRITERIA
          // Check balance
          expect(await token.balanceOf(from, identifier)).to.equal(0);
          expect(await token.balanceOf(to, identifier)).to.equal(amount);
          break;
      }
    }
  });

  it("Reverts on calls to batch transfer 1155 items with no contract on a conduit", async () => {
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, owner.address, true);

    const { nftId, amount } = await mint1155(owner, 2);

    const { nftId: secondNftId, amount: secondAmount } = await mint1155(
      owner,
      2
    );

    await set1155ApprovalForAll(owner, tempConduit.address, true);

    await expect(
      tempConduit.connect(owner).executeWithBatch1155(
        [],
        [
          {
            token: ethers.constants.AddressZero,
            from: owner.address,
            to: buyer.address,
            ids: [nftId, secondNftId],
            amounts: [amount, secondAmount],
          },
        ]
      )
    ).to.be.revertedWithCustomError(tempConduit, "NoContract");
  });

  it("Reverts on calls to only batch transfer 1155 items with no contract on a conduit", async () => {
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, owner.address, true);

    const { nftId, amount } = await mint1155(owner, 2);

    const { nftId: secondNftId, amount: secondAmount } = await mint1155(
      owner,
      2
    );

    await set1155ApprovalForAll(owner, tempConduit.address, true);

    await expect(
      tempConduit.connect(owner).executeBatch1155([
        {
          token: ethers.constants.AddressZero,
          from: owner.address,
          to: buyer.address,
          ids: [nftId, secondNftId],
          amounts: [amount, secondAmount],
        },
      ])
    ).to.be.revertedWithCustomError(tempConduit, "NoContract");
  });

  it("ERC1155 batch transfer reverts with revert data if it has sufficient gas", async () => {
    // Owner updates conduit channel to allow seller access
    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, seller.address, true);

    await expect(
      tempConduit.connect(seller).executeWithBatch1155(
        [],
        [
          {
            token: testERC1155.address,
            from: seller.address,
            to: buyer.address,
            ids: [1],
            amounts: [1],
          },
        ]
      )
    ).to.be.revertedWith("NOT_AUTHORIZED");
  });
  if (!process.env.REFERENCE) {
    it("ERC1155 batch transfer sends no data", async () => {
      const receiver = await deployContract("ERC1155BatchRecipient", owner);
      // Owner updates conduit channel to allow seller access
      await conduitController
        .connect(owner)
        .updateChannel(tempConduit.address, seller.address, true);

      const { nftId, amount } = await mint1155(owner, 2);

      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        owner,
        2
      );
      const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(
        owner,
        2
      );

      await testERC1155.mint(seller.address, nftId, amount.mul(2));
      await testERC1155.mint(seller.address, secondNftId, secondAmount.mul(2));
      await testERC1155.mint(seller.address, thirdNftId, thirdAmount.mul(2));
      await set1155ApprovalForAll(seller, tempConduit.address, true);

      await tempConduit.connect(seller).executeWithBatch1155(
        [],
        [
          {
            token: testERC1155.address,
            from: seller.address,
            to: receiver.address,
            ids: [nftId, secondNftId, thirdNftId],
            amounts: [amount, secondAmount, thirdAmount],
          },
          {
            token: testERC1155.address,
            from: seller.address,
            to: receiver.address,
            ids: [secondNftId, nftId],
            amounts: [secondAmount, amount],
          },
        ]
      );
    });

    it("ERC1155 batch transfer reverts with generic error if it has insufficient gas to copy revert data", async () => {
      const receiver = await deployContract("ExcessReturnDataRecipient", owner);
      // Owner updates conduit channel to allow seller access
      await conduitController
        .connect(owner)
        .updateChannel(tempConduit.address, seller.address, true);

      await expect(
        tempConduit.connect(seller).executeWithBatch1155(
          [],
          [
            {
              token: receiver.address,
              from: seller.address,
              to: receiver.address,
              ids: [1],
              amounts: [1],
            },
          ]
        )
      )
        .to.be.revertedWithCustomError(
          tempConduit,
          "ERC1155BatchTransferGenericFailure"
        )
        .withArgs(receiver.address, seller.address, receiver.address, [1], [1]);
    });
  }

  it("Makes batch transfer 1155 items through a conduit", async () => {
    const tempConduitKey = owner.address + "ff00000000000000000000f1";

    const { conduit: tempConduitAddress } = await conduitController.getConduit(
      tempConduitKey
    );

    await conduitController
      .connect(owner)
      .createConduit(tempConduitKey, owner.address);

    const tempConduit = conduitImplementation.attach(tempConduitAddress);

    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, owner.address, true);

    const { nftId, amount } = await mint1155(owner, 2);

    const { nftId: secondNftId, amount: secondAmount } = await mint1155(
      owner,
      2
    );

    const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(owner, 2);

    const { nftId: nftId4, amount: amount4 } = await mint1155(owner, 2);

    const { nftId: nftId5, amount: amount5 } = await mint1155(owner, 2);

    const { nftId: nftId6, amount: amount6 } = await mint1155(owner, 2);

    const { nftId: nftId7, amount: amount7 } = await mint1155(owner, 2);

    const { nftId: nftId8, amount: amount8 } = await mint1155(owner, 2);

    const { nftId: nftId9, amount: amount9 } = await mint1155(owner, 2);

    const { nftId: nftId10, amount: amount10 } = await mint1155(owner, 2);

    await set1155ApprovalForAll(owner, tempConduit.address, true);

    await tempConduit.connect(owner).executeWithBatch1155(
      [],
      [
        {
          token: testERC1155.address,
          from: owner.address,
          to: buyer.address,
          ids: [
            nftId,
            secondNftId,
            thirdNftId,
            nftId4,
            nftId5,
            nftId6,
            nftId7,
            nftId8,
            nftId9,
            nftId10,
          ],
          amounts: [
            amount,
            secondAmount,
            thirdAmount,
            amount4,
            amount5,
            amount6,
            amount7,
            amount8,
            amount9,
            amount10,
          ],
        },
      ]
    );
  });

  it("Performs complex batch transfer through a conduit", async () => {
    const tempConduitKey = owner.address + "f100000000000000000000f1";

    const { conduit: tempConduitAddress } = await conduitController.getConduit(
      tempConduitKey
    );

    await conduitController
      .connect(owner)
      .createConduit(tempConduitKey, owner.address);

    const tempConduit = conduitImplementation.attach(tempConduitAddress);

    await conduitController
      .connect(owner)
      .updateChannel(tempConduit.address, owner.address, true);

    const { nftId, amount } = await mint1155(owner, 2);

    const { nftId: secondNftId, amount: secondAmount } = await mint1155(
      owner,
      2
    );

    const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(owner, 2);

    const { nftId: nftId4, amount: amount4 } = await mint1155(owner, 2);

    const { nftId: nftId5, amount: amount5 } = await mint1155(
      owner,
      2,
      testERC1155Two
    );

    const { nftId: nftId6, amount: amount6 } = await mint1155(
      owner,
      2,
      testERC1155Two
    );

    const { nftId: nftId7, amount: amount7 } = await mint1155(
      owner,
      2,
      testERC1155Two
    );

    const { nftId: nftId8, amount: amount8 } = await mint1155(
      owner,
      2,
      testERC1155Two
    );

    const amount9 = toBN(randomBN(4)).add(1);
    await mintAndApproveERC20(owner, tempConduit.address, amount9.mul(2));

    const nftId10 = await mint721(owner);

    await set1155ApprovalForAll(owner, tempConduit.address, true);

    await expect(
      testERC1155Two.connect(owner).setApprovalForAll(tempConduit.address, true)
    )
      .to.emit(testERC1155Two, "ApprovalForAll")
      .withArgs(owner.address, tempConduit.address, true);

    await set721ApprovalForAll(owner, tempConduit.address, true);

    const newAddress = toAddress(12345);

    await tempConduit.connect(owner).executeWithBatch1155(
      [
        {
          itemType: 1,
          token: testERC20.address,
          from: owner.address,
          to: newAddress,
          identifier: toBN(0),
          amount: amount9,
        },
        {
          itemType: 2,
          token: testERC721.address,
          from: owner.address,
          to: newAddress,
          identifier: nftId10,
          amount: toBN(1),
        },
      ],
      [
        {
          token: testERC1155.address,
          from: owner.address,
          to: newAddress,
          ids: [nftId, secondNftId, thirdNftId, nftId4],
          amounts: [amount, secondAmount, thirdAmount, amount4],
        },
        {
          token: testERC1155Two.address,
          from: owner.address,
          to: newAddress,
          ids: [nftId5, nftId6, nftId7, nftId8],
          amounts: [amount5, amount6, amount7, amount8],
        },
      ]
    );

    expect(await testERC1155.balanceOf(newAddress, nftId)).to.equal(amount);
    expect(await testERC1155.balanceOf(newAddress, secondNftId)).to.equal(
      secondAmount
    );
    expect(await testERC1155.balanceOf(newAddress, thirdNftId)).to.equal(
      thirdAmount
    );
    expect(await testERC1155.balanceOf(newAddress, nftId4)).to.equal(amount4);

    expect(await testERC1155Two.balanceOf(newAddress, nftId5)).to.equal(
      amount5
    );
    expect(await testERC1155Two.balanceOf(newAddress, nftId6)).to.equal(
      amount6
    );
    expect(await testERC1155Two.balanceOf(newAddress, nftId7)).to.equal(
      amount7
    );
    expect(await testERC1155Two.balanceOf(newAddress, nftId8)).to.equal(
      amount8
    );

    expect(await testERC20.balanceOf(newAddress)).to.equal(amount9);
    expect(await testERC721.ownerOf(nftId10)).to.equal(newAddress);
  });

  it("ERC1155 <=> ETH (match, two different groups of 1155's)", async () => {
    // Seller mints first nft
    const { nftId, amount } = await mint1155(seller);

    // Seller mints second nft
    const secondNftId = toBN(randomBN(4));
    const secondAmount = toBN(randomBN(4));
    await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

    // Seller mints third nft
    const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(seller);

    // Seller mints fourth nft
    const fourthNftId = toBN(randomBN(4));
    const fourthAmount = toBN(randomBN(4));
    await testERC1155Two.mint(seller.address, fourthNftId, fourthAmount);

    // Seller approves marketplace contract to transfer NFTs
    await set1155ApprovalForAll(seller, marketplaceContract.address, true);

    await expect(
      testERC1155Two
        .connect(seller)
        .setApprovalForAll(marketplaceContract.address, true)
    )
      .to.emit(testERC1155Two, "ApprovalForAll")
      .withArgs(seller.address, marketplaceContract.address, true);

    const offer = [
      getTestItem1155(nftId, amount, amount),
      getTestItem1155(
        secondNftId,
        secondAmount,
        secondAmount,
        testERC1155Two.address
      ),
      getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
      getTestItem1155(
        fourthNftId,
        fourthAmount,
        fourthAmount,
        testERC1155Two.address
      ),
    ];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), zone.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { order, value } = await createOrder(
      seller,
      zone,
      offer,
      consideration,
      0 // FULL_OPEN
    );

    const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

    const fulfillments = [
      [[[0, 0]], [[1, 0]]],
      [[[0, 1]], [[1, 1]]],
      [[[0, 2]], [[1, 2]]],
      [[[0, 3]], [[1, 3]]],
      [[[1, 0]], [[0, 0]]],
      [[[1, 0]], [[0, 1]]],
      [[[1, 0]], [[0, 2]]],
    ].map(([offerArr, considerationArr]) =>
      toFulfillment(offerArr, considerationArr)
    );

    const executions = await simulateMatchOrders(
      marketplaceContract,
      [order, mirrorOrder],
      fulfillments,
      owner,
      value
    );

    expect(executions.length).to.equal(7);

    await marketplaceContract
      .connect(owner)
      .matchOrders([order, mirrorOrder], fulfillments, {
        value,
      });
  });

  it("Reverts when attempting to update a conduit channel when call is not from controller", async () => {
    await expect(
      conduitOne
        .connect(owner)
        .updateChannel(ethers.constants.AddressZero, true)
    ).to.be.revertedWithCustomError(conduitOne, "InvalidController");
  });

  it("Reverts when attempting to execute transfers on a conduit when not called from a channel", async () => {
    const expectedRevertReason =
      getCustomRevertSelector("ChannelClosed(address)") +
      owner.address.slice(2).padStart(64, "0").toLowerCase();

    const tx = await conduitOne.connect(owner).populateTransaction.execute([]);
    const returnData = await provider.call(tx);
    expect(returnData).to.equal(expectedRevertReason);

    await expect(conduitOne.connect(owner).execute([])).to.be.reverted;
  });

  it("Reverts when attempting to execute with 1155 transfers on a conduit when not called from a channel", async () => {
    await expect(
      conduitOne.connect(owner).executeWithBatch1155([], [])
    ).to.be.revertedWithCustomError(conduitOne, "ChannelClosed");
  });

  it("Reverts when attempting to execute batch 1155 transfers on a conduit when not called from a channel", async () => {
    await expect(
      conduitOne.connect(owner).executeBatch1155([])
    ).to.be.revertedWithCustomError(conduitOne, "ChannelClosed");
  });

  it("Retrieves the owner of a conduit", async () => {
    const ownerOf = await conduitController.ownerOf(conduitOne.address);
    expect(ownerOf).to.equal(owner.address);

    await expect(
      conduitController.connect(owner).ownerOf(buyer.address)
    ).to.be.revertedWithCustomError(conduitController, "NoConduit");
  });

  it("Retrieves the key of a conduit", async () => {
    const key = await conduitController.getKey(conduitOne.address);
    expect(key.toLowerCase()).to.equal(conduitKeyOne.toLowerCase());

    await expect(
      conduitController.connect(owner).getKey(buyer.address)
    ).to.be.revertedWithCustomError(conduitController, "NoConduit");
  });

  it("Retrieves the status of a conduit channel", async () => {
    let isOpen = await conduitController.getChannelStatus(
      conduitOne.address,
      marketplaceContract.address
    );
    expect(isOpen).to.be.true;

    isOpen = await conduitController.getChannelStatus(
      conduitOne.address,
      seller.address
    );
    expect(isOpen).to.be.false;

    await expect(
      conduitController
        .connect(owner)
        .getChannelStatus(buyer.address, seller.address)
    ).to.be.revertedWithCustomError(conduitController, "NoConduit");
  });

  it("Retrieves conduit channels from the controller", async () => {
    const totalChannels = await conduitController.getTotalChannels(
      conduitOne.address
    );
    expect(totalChannels).to.equal(1);

    await expect(
      conduitController.connect(owner).getTotalChannels(buyer.address)
    ).to.be.revertedWithCustomError(conduitController, "NoConduit");

    const firstChannel = await conduitController.getChannel(
      conduitOne.address,
      0
    );
    expect(firstChannel).to.equal(marketplaceContract.address);

    await expect(
      conduitController
        .connect(owner)
        .getChannel(buyer.address, +totalChannels - 1)
    ).to.be.revertedWithCustomError(conduitController, "NoConduit");

    await expect(
      conduitController.connect(owner).getChannel(conduitOne.address, 1)
    ).to.be.revertedWithCustomError(conduitController, "ChannelOutOfRange");

    await expect(
      conduitController.connect(owner).getChannel(conduitOne.address, 2)
    ).to.be.revertedWithCustomError(conduitController, "ChannelOutOfRange");

    const channels = await conduitController.getChannels(conduitOne.address);
    expect(channels.length).to.equal(1);
    expect(channels[0]).to.equal(marketplaceContract.address);

    await expect(
      conduitController.connect(owner).getChannels(buyer.address)
    ).to.be.revertedWithCustomError(conduitController, "NoConduit");
  });

  it("Adds and removes channels", async () => {
    // Get number of open channels
    let totalChannels = await conduitController.getTotalChannels(
      conduitOne.address
    );
    expect(totalChannels).to.equal(1);

    let isOpen = await conduitController.getChannelStatus(
      conduitOne.address,
      marketplaceContract.address
    );
    expect(isOpen).to.be.true;

    // No-op
    await expect(
      conduitController
        .connect(owner)
        .updateChannel(conduitOne.address, marketplaceContract.address, true)
    ).to.be.reverted; // ChannelStatusAlreadySet

    isOpen = await conduitController.getChannelStatus(
      conduitOne.address,
      marketplaceContract.address
    );
    expect(isOpen).to.be.true;

    // Get number of open channels
    totalChannels = await conduitController.getTotalChannels(
      conduitOne.address
    );
    expect(totalChannels).to.equal(1);

    await conduitController
      .connect(owner)
      .updateChannel(conduitOne.address, seller.address, true);

    isOpen = await conduitController.getChannelStatus(
      conduitOne.address,
      seller.address
    );
    expect(isOpen).to.be.true;

    // Get number of open channels
    totalChannels = await conduitController.getTotalChannels(
      conduitOne.address
    );
    expect(totalChannels).to.equal(2);

    await conduitController
      .connect(owner)
      .updateChannel(conduitOne.address, marketplaceContract.address, false);

    isOpen = await conduitController.getChannelStatus(
      conduitOne.address,
      marketplaceContract.address
    );
    expect(isOpen).to.be.false;

    // Test a specific branch in ConduitController.updateChannel
    // when !isOpen && !channelPreviouslyOpen
    await faucet(conduitController.address, provider);

    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [conduitController.address],
    });

    const conduitControllerSigner = await ethers.getSigner(
      conduitController.address
    );

    await conduitOne
      .connect(conduitControllerSigner)
      .updateChannel(marketplaceContract.address, true);

    await network.provider.request({
      method: "hardhat_stopImpersonatingAccount",
      params: [conduitController.address],
    });

    await conduitController
      .connect(owner)
      .updateChannel(conduitOne.address, marketplaceContract.address, false);

    isOpen = await conduitController.getChannelStatus(
      conduitOne.address,
      marketplaceContract.address
    );
    expect(isOpen).to.be.false;

    // Get number of open channels
    totalChannels = await conduitController.getTotalChannels(
      conduitOne.address
    );
    expect(totalChannels).to.equal(1);

    await conduitController
      .connect(owner)
      .updateChannel(conduitOne.address, seller.address, false);

    isOpen = await conduitController.getChannelStatus(
      conduitOne.address,
      seller.address
    );
    expect(isOpen).to.be.false;

    // Get number of open channels
    totalChannels = await conduitController.getTotalChannels(
      conduitOne.address
    );
    expect(totalChannels).to.equal(0);

    await conduitController
      .connect(owner)
      .updateChannel(conduitOne.address, marketplaceContract.address, true);

    isOpen = await conduitController.getChannelStatus(
      conduitOne.address,
      marketplaceContract.address
    );
    expect(isOpen).to.be.true;

    // Get number of open channels
    totalChannels = await conduitController.getTotalChannels(
      conduitOne.address
    );
    expect(totalChannels).to.equal(1);
  });

  it("Reverts on an attempt to move an unsupported item", async () => {
    await conduitController
      .connect(owner)
      .updateChannel(conduitOne.address, seller.address, true);

    const isOpen = await conduitController.getChannelStatus(
      conduitOne.address,
      seller.address
    );
    expect(isOpen).to.be.true;

    await expect(
      conduitOne.connect(seller).executeWithBatch1155(
        [
          {
            itemType: 0, // NATIVE (invalid)
            token: ethers.constants.AddressZero,
            from: conduitOne.address,
            to: seller.address,
            identifier: 0,
            amount: 0,
          },
        ],
        []
      )
    ).to.be.revertedWithCustomError(conduitOne, "InvalidItemType");
  });

  it("Reverts when attempting to create a conduit not scoped to the creator", async () => {
    await expect(
      conduitController
        .connect(owner)
        .createConduit(ethers.constants.HashZero, owner.address)
    ).to.be.revertedWithCustomError(conduitController, "InvalidCreator");
  });

  it("Reverts when attempting to create a conduit that already exists", async () => {
    await expect(
      conduitController
        .connect(owner)
        .createConduit(conduitKeyOne, owner.address)
    )
      .to.be.revertedWithCustomError(conduitController, "ConduitAlreadyExists")
      .withArgs(conduitOne.address);
  });

  it("Reverts when attempting to update a channel for an unowned conduit", async () => {
    await expect(
      conduitController
        .connect(buyer)
        .updateChannel(conduitOne.address, buyer.address, true)
    )
      .to.be.revertedWithCustomError(conduitController, "CallerIsNotOwner")
      .withArgs(conduitOne.address);
  });

  it("Retrieves no initial potential owner for new conduit", async () => {
    const potentialOwner = await conduitController.getPotentialOwner(
      conduitOne.address
    );
    expect(potentialOwner).to.equal(ethers.constants.AddressZero);

    await expect(
      conduitController.connect(owner).getPotentialOwner(buyer.address)
    ).to.be.revertedWithCustomError(conduitController, "NoConduit");
  });

  it("Lets the owner transfer ownership via a two-stage process", async () => {
    await expect(
      conduitController
        .connect(buyer)
        .transferOwnership(conduitOne.address, buyer.address)
    ).to.be.revertedWithCustomError(conduitController, "CallerIsNotOwner");

    await expect(
      conduitController
        .connect(owner)
        .transferOwnership(conduitOne.address, ethers.constants.AddressZero)
    ).to.be.revertedWithCustomError(
      conduitController,
      "NewPotentialOwnerIsZeroAddress"
    );

    await expect(
      conduitController
        .connect(owner)
        .transferOwnership(seller.address, buyer.address)
    ).to.be.revertedWithCustomError(conduitController, "NoConduit");

    let potentialOwner = await conduitController.getPotentialOwner(
      conduitOne.address
    );
    expect(potentialOwner).to.equal(ethers.constants.AddressZero);

    await conduitController.transferOwnership(
      conduitOne.address,
      buyer.address
    );

    potentialOwner = await conduitController.getPotentialOwner(
      conduitOne.address
    );
    expect(potentialOwner).to.equal(buyer.address);

    await expect(
      conduitController
        .connect(owner)
        .transferOwnership(conduitOne.address, buyer.address)
    ).to.be.revertedWithCustomError(
      conduitController,
      "NewPotentialOwnerAlreadySet"
    );

    await expect(
      conduitController
        .connect(buyer)
        .cancelOwnershipTransfer(conduitOne.address)
    ).to.be.revertedWithCustomError(conduitController, "CallerIsNotOwner");

    await expect(
      conduitController.connect(owner).cancelOwnershipTransfer(seller.address)
    ).to.be.revertedWithCustomError(conduitController, "NoConduit");

    await conduitController.cancelOwnershipTransfer(conduitOne.address);

    potentialOwner = await conduitController.getPotentialOwner(
      conduitOne.address
    );
    expect(potentialOwner).to.equal(ethers.constants.AddressZero);

    await expect(
      conduitController
        .connect(owner)
        .cancelOwnershipTransfer(conduitOne.address)
    ).to.be.revertedWithCustomError(
      conduitController,
      "NoPotentialOwnerCurrentlySet"
    );

    await conduitController.transferOwnership(
      conduitOne.address,
      buyer.address
    );

    potentialOwner = await conduitController.getPotentialOwner(
      conduitOne.address
    );
    expect(potentialOwner).to.equal(buyer.address);

    await expect(
      conduitController.connect(buyer).acceptOwnership(seller.address)
    ).to.be.revertedWithCustomError(conduitController, "NoConduit");

    await expect(
      conduitController.connect(seller).acceptOwnership(conduitOne.address)
    ).to.be.revertedWithCustomError(
      conduitController,
      "CallerIsNotNewPotentialOwner"
    );

    await conduitController.connect(buyer).acceptOwnership(conduitOne.address);

    potentialOwner = await conduitController.getPotentialOwner(
      conduitOne.address
    );
    expect(potentialOwner).to.equal(ethers.constants.AddressZero);

    const ownerOf = await conduitController.ownerOf(conduitOne.address);
    expect(ownerOf).to.equal(buyer.address);
  });
});
