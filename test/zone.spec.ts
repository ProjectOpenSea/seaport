import { expect } from "chai";
import { ethers, network } from "hardhat";

import { merkleTree } from "./utils/criteria";
import {
  buildResolver,
  getItemETH,
  randomHex,
  toAddress,
  toBN,
  toFulfillment,
  toKey,
} from "./utils/encoding";
import { decodeEvents } from "./utils/events";
import { faucet } from "./utils/faucet";
import { seaportFixture } from "./utils/fixtures";
import { VERSION } from "./utils/helpers";

import type {
  ConsiderationInterface,
  EIP1271Wallet,
  EIP1271Wallet__factory,
  TestERC721,
  TestZone,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { Contract, Wallet } from "ethers";

const { parseEther } = ethers.utils;

describe(`Zone - PausableZone (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let EIP1271WalletFactory: EIP1271Wallet__factory;
  let marketplaceContract: ConsiderationInterface;
  let stubZone: TestZone;
  let testERC721: TestERC721;

  let checkExpectedEvents: SeaportFixtures["checkExpectedEvents"];
  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let getTestItem721WithCriteria: SeaportFixtures["getTestItem721WithCriteria"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
  let withBalanceChecks: SeaportFixtures["withBalanceChecks"];

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await faucet(owner.address, provider);

    ({
      checkExpectedEvents,
      createOrder,
      EIP1271WalletFactory,
      getTestItem721,
      getTestItem721WithCriteria,
      marketplaceContract,
      mintAndApprove721,
      stubZone,
      testERC721,
      withBalanceChecks,
    } = await seaportFixture(owner));
  });

  let buyer: Wallet;
  let seller: Wallet;

  let buyerContract: EIP1271Wallet;
  let sellerContract: EIP1271Wallet;

  beforeEach(async () => {
    // Setup basic buyer/seller wallets with ETH
    seller = new ethers.Wallet(randomHex(32), provider);
    buyer = new ethers.Wallet(randomHex(32), provider);

    sellerContract = await EIP1271WalletFactory.deploy(seller.address);
    buyerContract = await EIP1271WalletFactory.deploy(buyer.address);

    for (const wallet of [seller, buyer, sellerContract, buyerContract]) {
      await faucet(wallet.address, provider);
    }
  });

  /** Create zone and get zone address */
  async function createZone(pausableZoneController: Contract, salt?: string) {
    const tx = await pausableZoneController.createZone(salt ?? randomHex());

    const zoneContract = await ethers.getContractFactory("PausableZone", owner);

    const events = await decodeEvents(tx, [
      { eventName: "ZoneCreated", contract: pausableZoneController },
      { eventName: "Unpaused", contract: zoneContract as any },
    ]);
    expect(events.length).to.be.equal(2);

    const [unpauseEvent, zoneCreatedEvent] = events;
    expect(unpauseEvent.eventName).to.equal("Unpaused");
    expect(zoneCreatedEvent.eventName).to.equal("ZoneCreated");

    return zoneCreatedEvent.data.zone as string;
  }

  it("Fulfills an order with a pausable zone", async () => {
    const pausableDeployer = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const deployer = await pausableDeployer.deploy(owner.address);

    const zoneAddr = await createZone(deployer);

    // create basic order using pausable as zone
    // execute basic 721 <=> ETH order
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { order, orderHash, value } = await createOrder(
      seller,
      zoneAddr,
      offer,
      consideration,
      2 // FULL_RESTRICTED
    );

    await withBalanceChecks([order], 0, undefined, async () => {
      const tx = await marketplaceContract
        .connect(buyer)
        .fulfillOrder(order, toKey(0), {
          value,
        });

      const receipt = await tx.wait();
      await checkExpectedEvents(tx, receipt, [
        {
          order,
          orderHash,
          fulfiller: buyer.address,
          fulfillerConduitKey: toKey(0),
        },
      ]);
      return receipt;
    });
  });

  it("Fulfills an advanced order with criteria with a pausable zone", async () => {
    const pausableZoneController = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZone = await pausableZoneController.deploy(owner.address);

    const zoneAddr = await createZone(pausableZone);

    // create basic order using pausable as zone
    // execute basic 721 <=> ETH order
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const { root, proofs } = merkleTree([nftId]);

    const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const criteriaResolvers = [
      buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
    ];

    const { order, orderHash, value } = await createOrder(
      seller,
      zoneAddr,
      offer,
      consideration,
      2, // FULL_RESTRICTED
      criteriaResolvers
    );

    await withBalanceChecks([order], 0, criteriaResolvers, async () => {
      const tx = await marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          order,
          criteriaResolvers,
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        );

      const receipt = await tx.wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: buyer.address,
            fulfillerConduitKey: toKey(0),
          },
        ],
        undefined,
        criteriaResolvers
      );
      return receipt;
    });
  });

  it("Fulfills an order with executeMatchOrders", async () => {
    // Create Pausable Zone Controller
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    // Deploy Pausable Zone
    const zoneAddr = await createZone(pausableZoneController);

    // Mint NFTs for use in orders
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);
    const secondNFTId = await mintAndApprove721(
      buyer,
      marketplaceContract.address
    );
    const thirdNFTId = await mintAndApprove721(
      owner,
      marketplaceContract.address
    );

    // Define orders
    const offerOne = [
      getTestItem721(nftId, toBN(1), toBN(1), undefined, testERC721.address),
    ];
    const considerationOne = [
      getTestItem721(
        secondNFTId,
        toBN(1),
        toBN(1),
        seller.address,
        testERC721.address
      ),
    ];
    const { order: orderOne, orderHash: orderHashOne } = await createOrder(
      seller,
      zoneAddr,
      offerOne,
      considerationOne,
      2
    );

    const offerTwo = [
      getTestItem721(
        secondNFTId,
        toBN(1),
        toBN(1),
        undefined,
        testERC721.address
      ),
    ];
    const considerationTwo = [
      getTestItem721(
        thirdNFTId,
        toBN(1),
        toBN(1),
        buyer.address,
        testERC721.address
      ),
    ];
    const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
      buyer,
      zoneAddr,
      offerTwo,
      considerationTwo,
      2
    );

    const offerThree = [
      getTestItem721(
        thirdNFTId,
        toBN(1),
        toBN(1),
        undefined,
        testERC721.address
      ),
    ];
    const considerationThree = [
      getTestItem721(
        nftId,
        toBN(1),
        toBN(1),
        owner.address,
        testERC721.address
      ),
    ];
    const { order: orderThree, orderHash: orderHashThree } = await createOrder(
      owner,
      zoneAddr,
      offerThree,
      considerationThree,
      2
    );

    const fulfillments = [
      [[[1, 0]], [[0, 0]]],
      [[[0, 0]], [[2, 0]]],
      [[[2, 0]], [[1, 0]]],
    ].map(([offerArr, considerationArr]) =>
      toFulfillment(offerArr, considerationArr)
    );

    await expect(
      pausableZoneController
        .connect(buyer)
        .callStatic.executeMatchOrders(
          zoneAddr,
          marketplaceContract.address,
          [orderOne, orderTwo, orderThree],
          fulfillments,
          { value: 0 }
        )
    ).to.be.revertedWithCustomError(pausableZoneController, "CallerIsNotOwner");

    // Ensure that the number of executions from matching orders with zone
    // is equal to the number of fulfillments
    const executions = await pausableZoneController
      .connect(owner)
      .callStatic.executeMatchOrders(
        zoneAddr,
        marketplaceContract.address,
        [orderOne, orderTwo, orderThree],
        fulfillments,
        { value: 0 }
      );
    expect(executions.length).to.equal(fulfillments.length);

    // Perform the match orders with zone
    const tx = await pausableZoneController
      .connect(owner)
      .executeMatchOrders(
        zoneAddr,
        marketplaceContract.address,
        [orderOne, orderTwo, orderThree],
        fulfillments
      );

    // Decode all events and get the order hashes
    const orderFulfilledEvents = await decodeEvents(tx, [
      { eventName: "OrderFulfilled", contract: marketplaceContract },
    ]);
    expect(orderFulfilledEvents.length).to.equal(fulfillments.length);

    // Check that the actual order hashes match those from the events, in order
    const actualOrderHashes = [orderHashOne, orderHashTwo, orderHashThree];
    orderFulfilledEvents.forEach((orderFulfilledEvent, i) =>
      expect(orderFulfilledEvent.data.orderHash).to.be.equal(
        actualOrderHashes[i]
      )
    );
  });

  it("Fulfills an order with executeMatchAdvancedOrders", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    // Deploy pausable zone
    const zoneAddr = await createZone(pausableZoneController);

    // Mint NFTs for use in orders
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);
    const secondNFTId = await mintAndApprove721(
      buyer,
      marketplaceContract.address
    );
    const thirdNFTId = await mintAndApprove721(
      owner,
      marketplaceContract.address
    );

    // Define orders
    const offerOne = [
      getTestItem721(nftId, toBN(1), toBN(1), undefined, testERC721.address),
    ];
    const considerationOne = [
      getTestItem721(
        secondNFTId,
        toBN(1),
        toBN(1),
        seller.address,
        testERC721.address
      ),
    ];
    const { order: orderOne, orderHash: orderHashOne } = await createOrder(
      seller,
      zoneAddr,
      offerOne,
      considerationOne,
      2
    );

    const offerTwo = [
      getTestItem721(
        secondNFTId,
        toBN(1),
        toBN(1),
        undefined,
        testERC721.address
      ),
    ];
    const considerationTwo = [
      getTestItem721(
        thirdNFTId,
        toBN(1),
        toBN(1),
        buyer.address,
        testERC721.address
      ),
    ];
    const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
      buyer,
      zoneAddr,
      offerTwo,
      considerationTwo,
      2
    );

    const offerThree = [
      getTestItem721(
        thirdNFTId,
        toBN(1),
        toBN(1),
        undefined,
        testERC721.address
      ),
    ];
    const considerationThree = [
      getTestItem721(
        nftId,
        toBN(1),
        toBN(1),
        owner.address,
        testERC721.address
      ),
    ];
    const { order: orderThree, orderHash: orderHashThree } = await createOrder(
      owner,
      zoneAddr,
      offerThree,
      considerationThree,
      2
    );

    const fulfillments = [
      [[[1, 0]], [[0, 0]]],
      [[[0, 0]], [[2, 0]]],
      [[[2, 0]], [[1, 0]]],
    ].map(([offerArr, considerationArr]) =>
      toFulfillment(offerArr, considerationArr)
    );

    await expect(
      pausableZoneController
        .connect(buyer)
        .executeMatchAdvancedOrders(
          zoneAddr,
          marketplaceContract.address,
          [orderOne, orderTwo, orderThree],
          [],
          fulfillments,
          { value: 0 }
        )
    ).to.be.revertedWithCustomError(pausableZoneController, "CallerIsNotOwner");

    // Ensure that the number of executions from matching advanced orders with zone
    // is equal to the number of fulfillments
    const executions = await pausableZoneController
      .connect(owner)
      .callStatic.executeMatchAdvancedOrders(
        zoneAddr,
        marketplaceContract.address,
        [orderOne, orderTwo, orderThree],
        [],
        fulfillments,
        { value: 0 }
      );
    expect(executions.length).to.equal(fulfillments.length);

    // Perform the match advanced orders with zone
    const tx = await pausableZoneController
      .connect(owner)
      .executeMatchAdvancedOrders(
        zoneAddr,
        marketplaceContract.address,
        [orderOne, orderTwo, orderThree],
        [],
        fulfillments
      );

    // Decode all events and get the order hashes
    const orderFulfilledEvents = await decodeEvents(tx, [
      { eventName: "OrderFulfilled", contract: marketplaceContract },
    ]);
    expect(orderFulfilledEvents.length).to.equal(fulfillments.length);

    // Check that the actual order hashes match those from the events, in order
    const actualOrderHashes = [orderHashOne, orderHashTwo, orderHashThree];
    orderFulfilledEvents.forEach((orderFulfilledEvent, i) =>
      expect(orderFulfilledEvent.data.orderHash).to.be.equal(
        actualOrderHashes[i]
      )
    );
  });

  it("Only the deployer owner can create a zone", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );

    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    // deploy pausable zone from non-deployer owner
    const salt = randomHex();
    await expect(
      pausableZoneController.connect(seller).createZone(salt)
    ).to.be.revertedWithCustomError(pausableZoneController, "CallerIsNotOwner");

    // deploy pausable zone from owner
    await createZone(pausableZoneController);
  });

  it("Assign pauser and self destruct the zone", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    const zoneAddr = await createZone(pausableZoneController);

    // Attach to Pausable Zone
    const zoneContract = await ethers.getContractFactory("PausableZone", owner);

    // Attach to zone
    const zone = await zoneContract.attach(zoneAddr);

    // Try to nuke the zone through the deployer before being assigned pauser
    await expect(pausableZoneController.connect(buyer).pause(zoneAddr)).to.be
      .reverted;

    // Try to nuke the zone directly before being assigned pauser
    await expect(zone.connect(buyer).pause(zoneAddr)).to.be.reverted;

    await expect(
      pausableZoneController.connect(buyer).assignPauser(seller.address)
    ).to.be.revertedWithCustomError(pausableZoneController, "CallerIsNotOwner");

    await expect(
      pausableZoneController.connect(owner).assignPauser(toAddress(0))
    ).to.be.revertedWithCustomError(
      pausableZoneController,
      "PauserCanNotBeSetAsZero"
    );

    // owner assigns the pauser of the zone
    await pausableZoneController.connect(owner).assignPauser(buyer.address);

    // Check pauser owner
    expect(await pausableZoneController.pauser()).to.equal(buyer.address);

    // Now as pauser, nuke the zone
    const tx = await pausableZoneController.connect(buyer).pause(zoneAddr);

    // Check paused event was emitted
    const pauseEvents = await decodeEvents(tx, [
      { eventName: "Paused", contract: zoneContract as any },
    ]);
    expect(pauseEvents.length).to.equal(1);
  });

  it("Revert on deploying a zone with the same salt", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    const salt = randomHex();

    // Create zone with salt
    await pausableZoneController.createZone(salt);

    // Create zone with same salt
    await expect(
      pausableZoneController.createZone(salt)
    ).to.be.revertedWithCustomError(
      pausableZoneController,
      "ZoneAlreadyExists"
    );
  });

  it("Revert on an order with a pausable zone if zone has been self destructed", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    const zoneAddr = await createZone(pausableZoneController);

    // create basic order using pausable as zone
    // execute basic 721 <=> ETH order
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    // eslint-disable-next-line
    const { order, orderHash, value } = await createOrder(
      seller,
      zoneAddr,
      offer,
      consideration,
      2
    );

    // owner nukes the zone
    pausableZoneController.pause(zoneAddr);

    if (!process.env.REFERENCE) {
      await expect(
        marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
          value,
        })
      ).to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidRestrictedOrder"
      );
    } else {
      await expect(
        marketplaceContract.connect(buyer).fulfillOrder(order, toKey(0), {
          value,
        })
      ).to.be.reverted;
    }
  });

  it("Reverts if non-owner tries to self destruct the zone", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    const zoneAddr = await createZone(pausableZoneController);

    // non owner tries to use pausable deployer to nuke the zone, reverts
    await expect(pausableZoneController.connect(buyer).pause(zoneAddr)).to.be
      .reverted;
  });

  it("Zone can cancel restricted orders", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    // deploy PausableZone
    const zoneAddr = await createZone(pausableZoneController);

    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { orderComponents } = await createOrder(
      seller,
      zoneAddr,
      offer,
      consideration,
      2 // FULL_RESTRICTED, zone can execute or cancel
    );

    await expect(
      pausableZoneController
        .connect(buyer)
        .cancelOrders(zoneAddr, marketplaceContract.address, [orderComponents])
    ).to.be.revertedWithCustomError(pausableZoneController, "CallerIsNotOwner");

    await pausableZoneController.cancelOrders(
      zoneAddr,
      marketplaceContract.address,
      [orderComponents]
    );
  });

  it("Operator of zone can cancel restricted orders", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    // deploy PausableZone
    const zoneAddr = await createZone(pausableZoneController);

    // Attach to PausableZone zone
    const zoneContract = await ethers.getContractFactory("PausableZone", owner);

    // Attach to zone
    const zone = await zoneContract.attach(zoneAddr);

    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { orderComponents } = await createOrder(
      seller,
      zoneAddr,
      offer,
      consideration,
      2 // FULL_RESTRICTED, zone can execute or cancel
    );

    // Non operator address should not be allowed to operate the zone
    await expect(
      zone
        .connect(seller)
        .cancelOrders(marketplaceContract.address, [orderComponents])
    ).to.be.reverted;

    // Approve operator
    await pausableZoneController
      .connect(owner)
      .assignOperator(zoneAddr, seller.address);

    // Now allowed to operate the zone
    await zone
      .connect(seller)
      .cancelOrders(marketplaceContract.address, [orderComponents]);

    // Cannot assign operator to zero address
    await expect(
      pausableZoneController
        .connect(owner)
        .assignOperator(zoneAddr, toAddress(0))
    ).to.be.revertedWithCustomError(
      pausableZoneController,
      "PauserCanNotBeSetAsZero"
    );
  });

  it("Reverts trying to assign operator as non-deployer", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    // deploy PausableZone
    const zoneAddr = await createZone(pausableZoneController);

    // Attach to pausable zone
    const zoneContract = await ethers.getContractFactory("PausableZone", owner);

    // Attach to zone
    const zone = await zoneContract.attach(zoneAddr);

    // Try to approve operator without permission
    await expect(
      pausableZoneController
        .connect(seller)
        .assignOperator(zoneAddr, seller.address)
    ).to.be.revertedWithCustomError(pausableZoneController, "CallerIsNotOwner");

    // Try to approve operator directly without permission
    await expect(zone.connect(seller).assignOperator(seller.address)).to.be
      .reverted;
  });

  it("Reverts if non-Zone tries to cancel restricted orders", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    await createZone(pausableZoneController);

    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { order } = await createOrder(
      seller,
      stubZone,
      offer,
      consideration,
      2 // FULL_RESTRICTED
    );

    await expect(marketplaceContract.connect(buyer).cancel(order as any)).to.be
      .reverted;
  });

  it("Reverts if non-owner tries to use the zone to cancel restricted orders", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    const zoneAddr = await createZone(pausableZoneController);

    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { order } = await createOrder(
      seller,
      stubZone,
      offer,
      consideration,
      2 // FULL_RESTRICTED
    );

    // buyer calls zone owner to cancel an order through the zone
    await expect(
      pausableZoneController
        .connect(buyer)
        .cancelOrders(zoneAddr, marketplaceContract.address, order as any)
    ).to.be.reverted;
  });

  it("Lets the Zone Deployer owner transfer ownership via a two-stage process", async () => {
    const pausableZoneControllerFactory = await ethers.getContractFactory(
      "PausableZoneController",
      owner
    );
    const pausableZoneController = await pausableZoneControllerFactory.deploy(
      owner.address
    );

    await createZone(pausableZoneController);

    await expect(
      pausableZoneController.connect(buyer).transferOwnership(buyer.address)
    ).to.be.revertedWithCustomError(pausableZoneController, "CallerIsNotOwner");

    await expect(
      pausableZoneController.connect(owner).transferOwnership(toAddress(0))
    ).to.be.revertedWithCustomError(
      pausableZoneController,
      "OwnerCanNotBeSetAsZero"
    );

    await expect(
      pausableZoneController.connect(seller).cancelOwnershipTransfer()
    ).to.be.revertedWithCustomError(pausableZoneController, "CallerIsNotOwner");

    await expect(
      pausableZoneController.connect(buyer).acceptOwnership()
    ).to.be.revertedWithCustomError(
      pausableZoneController,
      "CallerIsNotPotentialOwner"
    );

    // just get any random address as the next potential owner.
    await pausableZoneController
      .connect(owner)
      .transferOwnership(buyer.address);

    // Check potential owner
    expect(await pausableZoneController.potentialOwner()).to.equal(
      buyer.address
    );

    await pausableZoneController.connect(owner).cancelOwnershipTransfer();
    await pausableZoneController
      .connect(owner)
      .transferOwnership(buyer.address);
    await pausableZoneController.connect(buyer).acceptOwnership();

    expect(await pausableZoneController.owner()).to.equal(buyer.address);
  });
});
