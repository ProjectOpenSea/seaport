import { expect } from "chai";
import { keccak256 } from "ethers/lib/utils";
import { ethers, network } from "hardhat";

import { getItemETH, randomHex, toKey } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { seaportFixture } from "./utils/fixtures";
import { VERSION } from "./utils/helpers";

import type {
  ConditionalZone,
  ConsiderationInterface,
  EIP1271Wallet,
  EIP1271Wallet__factory,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { Wallet } from "ethers";

const { parseEther } = ethers.utils;

describe(`Zone - ConditionalZone (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let EIP1271WalletFactory: EIP1271Wallet__factory;
  let marketplaceContract: ConsiderationInterface;

  let checkExpectedEvents: SeaportFixtures["checkExpectedEvents"];
  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
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
      marketplaceContract,
      mintAndApprove721,
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

  async function createZone(marketplaceContractAddress: string) {
    const zoneContractFactory = await ethers.getContractFactory(
      "ConditionalZone"
    );
    const zoneContract = await zoneContractFactory.deploy(
      marketplaceContractAddress
    );

    return zoneContract;
  }

  async function createOrderWithZone(
    zone: ConditionalZone,
    condition?: ConditionalZone.ConditionStruct
  ) {
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    let zoneHash;
    let conditionData;

    if (condition) {
      conditionData = await zone.encodeCondition(condition);
      zoneHash = keccak256(conditionData);
    }

    const order = await createOrder(
      seller,
      zone.address,
      // offer
      [getTestItem721(nftId)],
      // consideration
      [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ],
      2,
      undefined,
      undefined,
      undefined,
      zoneHash
    );
    if (conditionData) {
      order.order.extraData = conditionData;
    }

    return order;
  }

  async function fulfillAdvancedOrder({ order, orderHash, value }: any) {
    await withBalanceChecks([order], 0, undefined, async () => {
      const tx = await marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
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
  }

  async function assertFulfillAdvancedOrderReverts(
    { order, value }: any,
    revertMessage: string
  ) {
    await expect(
      marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
          value,
        })
    ).to.be.revertedWith(revertMessage);
  }

  it("Fulfill an order through zone with no condition", async () => {
    const zone = await createZone(marketplaceContract.address);
    const { order, orderHash, value } = await createOrderWithZone(zone);

    await withBalanceChecks([order], 0, undefined, async () => {
      const tx = await marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(order, [], toKey(0), buyer.address, {
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

  it("Cannot fulfill an order when dependant order is cancelled", async () => {
    const zone = await createZone(marketplaceContract.address);
    const firstOrder = await createOrderWithZone(zone);
    const secondOrder = await createOrderWithZone(zone, {
      logicGate: 0,
      orderHashes: [firstOrder.orderHash],
    });

    await marketplaceContract
      .connect(seller)
      .cancel([firstOrder.orderComponents]);

    await assertFulfillAdvancedOrderReverts(
      firstOrder,
      `OrderIsCancelled("${firstOrder.orderHash}")`
    );

    await assertFulfillAdvancedOrderReverts(
      secondOrder,
      "A dependant order is cancelled"
    );
  });

  it("Must provide extraData when zoneHash exists", async () => {
    const zone = await createZone(marketplaceContract.address);
    const firstOrder = await createOrderWithZone(zone);
    const secondOrder = await createOrderWithZone(zone, {
      logicGate: 0,
      orderHashes: [firstOrder.orderHash],
    });

    // Reset extraData
    secondOrder.order.extraData = "0x";

    await assertFulfillAdvancedOrderReverts(
      secondOrder,
      "Must provide extraData"
    );
  });

  it("zoneHash must match hash of extraData", async () => {
    const zone = await createZone(marketplaceContract.address);
    const firstOrder = await createOrderWithZone(zone);
    const secondOrder = await createOrderWithZone(zone, {
      logicGate: 0,
      orderHashes: [firstOrder.orderHash],
    });

    // Reset extraData
    secondOrder.order.extraData = firstOrder.orderHash;

    await assertFulfillAdvancedOrderReverts(secondOrder, "Hash does not match");
  });

  it("Fulfill an order with condition - AND", async () => {
    const zone = await createZone(marketplaceContract.address);
    const firstOrder = await createOrderWithZone(zone);
    const secondOrder = await createOrderWithZone(zone);
    const thirdOrder = await createOrderWithZone(zone, {
      logicGate: 0,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });

    // Third order is not valid
    await assertFulfillAdvancedOrderReverts(thirdOrder, "Condition not met");

    // Fulfill first order
    await fulfillAdvancedOrder(firstOrder);

    // Third order is still not valid
    await assertFulfillAdvancedOrderReverts(thirdOrder, "Condition not met");

    // Fulfill second order
    await fulfillAdvancedOrder(secondOrder);

    // Third order is valid
    await fulfillAdvancedOrder(thirdOrder);
  });

  it("Fulfill an order with condition - OR", async () => {
    const zone = await createZone(marketplaceContract.address);
    const firstOrder = await createOrderWithZone(zone);
    const secondOrder = await createOrderWithZone(zone);
    const thirdOrder = await createOrderWithZone(zone, {
      logicGate: 1,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });
    const fourthOrder = await createOrderWithZone(zone, {
      logicGate: 1,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });

    // Third order is not valid
    await assertFulfillAdvancedOrderReverts(thirdOrder, "Condition not met");

    // Fourth order is not valid
    await assertFulfillAdvancedOrderReverts(fourthOrder, "Condition not met");

    // Fulfill first order
    await fulfillAdvancedOrder(firstOrder);

    // Third order is valid
    await fulfillAdvancedOrder(thirdOrder);

    // Fulfill second order
    await fulfillAdvancedOrder(secondOrder);

    // Fourth order is valid
    await fulfillAdvancedOrder(fourthOrder);
  });

  it("Fulfill an order with condition - XOR", async () => {
    const zone = await createZone(marketplaceContract.address);
    const firstOrder = await createOrderWithZone(zone);
    const secondOrder = await createOrderWithZone(zone);
    const thirdOrder = await createOrderWithZone(zone, {
      logicGate: 2,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });
    const fourthOrder = await createOrderWithZone(zone, {
      logicGate: 2,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });

    // Third order is not valid
    await assertFulfillAdvancedOrderReverts(thirdOrder, "Condition not met");

    // Fourth order is not valid
    await assertFulfillAdvancedOrderReverts(fourthOrder, "Condition not met");

    // Fulfill first order
    await fulfillAdvancedOrder(firstOrder);

    // Third order is valid
    await fulfillAdvancedOrder(thirdOrder);

    // Fulfill second order
    await fulfillAdvancedOrder(secondOrder);

    // Fourth order is not valid
    await assertFulfillAdvancedOrderReverts(fourthOrder, "Condition not met");
  });

  it("Fulfill an order with condition - NAND", async () => {
    const zone = await createZone(marketplaceContract.address);
    const firstOrder = await createOrderWithZone(zone);
    const secondOrder = await createOrderWithZone(zone);
    const thirdOrder = await createOrderWithZone(zone, {
      logicGate: 3,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });
    const fourthOrder = await createOrderWithZone(zone, {
      logicGate: 3,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });

    // Third order is valid
    await fulfillAdvancedOrder(thirdOrder);

    // Fulfill first order
    await fulfillAdvancedOrder(firstOrder);

    // Fulfill second order
    await fulfillAdvancedOrder(secondOrder);

    // Fourth order is not valid
    await assertFulfillAdvancedOrderReverts(fourthOrder, "Condition not met");
  });

  it("Fulfill an order with condition - NOR", async () => {
    const zone = await createZone(marketplaceContract.address);
    const firstOrder = await createOrderWithZone(zone);
    const secondOrder = await createOrderWithZone(zone);
    const thirdOrder = await createOrderWithZone(zone, {
      logicGate: 4,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });
    const fourthOrder = await createOrderWithZone(zone, {
      logicGate: 4,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });

    // Third order is valid
    await fulfillAdvancedOrder(thirdOrder);

    // Fulfill first order
    await fulfillAdvancedOrder(firstOrder);

    // Fourth order is not valid
    await assertFulfillAdvancedOrderReverts(fourthOrder, "Condition not met");

    // Fulfill second order
    await fulfillAdvancedOrder(secondOrder);

    // Fourth order is not valid
    await assertFulfillAdvancedOrderReverts(fourthOrder, "Condition not met");
  });

  it("Fulfill an order with condition - XNOR", async () => {
    const zone = await createZone(marketplaceContract.address);
    const firstOrder = await createOrderWithZone(zone);
    const secondOrder = await createOrderWithZone(zone);
    const thirdOrder = await createOrderWithZone(zone, {
      logicGate: 5,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });
    const fourthOrder = await createOrderWithZone(zone, {
      logicGate: 5,
      orderHashes: [firstOrder.orderHash, secondOrder.orderHash],
    });

    // Third order is valid
    await fulfillAdvancedOrder(thirdOrder);

    // Fulfill first order
    await fulfillAdvancedOrder(firstOrder);

    // Fourth order is not valid
    await assertFulfillAdvancedOrderReverts(fourthOrder, "Condition not met");

    // Fulfill second order
    await fulfillAdvancedOrder(secondOrder);

    // Fulfill fourth order
    await fulfillAdvancedOrder(fourthOrder);
  });
});
