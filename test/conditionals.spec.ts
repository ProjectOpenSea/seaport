import { expect } from "chai";
import { ethers, network } from "hardhat";

import { getItemETH, randomHex, toKey } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { seaportFixture } from "./utils/fixtures";
import { VERSION } from "./utils/helpers";

import type {
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

  it("Fulfill an order through zone with no conditional", async () => {
    const zone = await createZone(marketplaceContract.address);

    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { order, orderHash, value } = await createOrder(
      seller,
      zone.address,
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

  it("Fulfill an order through zone dependant on another order", async () => {
    const zone = await createZone(marketplaceContract.address);

    const nftId = await mintAndApprove721(seller, marketplaceContract.address);
    const nftId2 = await mintAndApprove721(seller, marketplaceContract.address);

    const firstOrder = await createOrder(
      seller,
      zone.address,
      // offer
      [getTestItem721(nftId)],
      // consideration
      [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ],
      2
    );

    const secondOrder = await createOrder(
      seller,
      zone.address,
      // offer
      [getTestItem721(nftId2)],
      // consideration
      [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ],
      2,
      undefined,
      undefined,
      undefined,
      firstOrder.orderHash
    );

    // Second order is not valid
    await expect(
      marketplaceContract
        .connect(buyer)
        .fulfillOrder(secondOrder.order, toKey(0), {
          value: secondOrder.value,
        })
    ).to.be.revertedWith(`InvalidRestrictedOrder("${secondOrder.orderHash}")`);

    const fulfillOrder = async ({ order, orderHash, value }: any) => {
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
    };

    await fulfillOrder(firstOrder);
    await fulfillOrder(secondOrder);
  });

  it("Cannot fulfill an order when dependant order is cancelled", async () => {
    const zone = await createZone(marketplaceContract.address);

    const nftId = await mintAndApprove721(seller, marketplaceContract.address);
    const nftId2 = await mintAndApprove721(seller, marketplaceContract.address);

    const firstOrder = await createOrder(
      seller,
      zone.address,
      // offer
      [getTestItem721(nftId)],
      // consideration
      [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ],
      2
    );

    const secondOrder = await createOrder(
      seller,
      zone.address,
      // offer
      [getTestItem721(nftId2)],
      // consideration
      [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ],
      2,
      undefined,
      undefined,
      undefined,
      firstOrder.orderHash
    );

    await marketplaceContract
      .connect(seller)
      .cancel([firstOrder.orderComponents]);

    // First order is not valid
    await expect(
      marketplaceContract
        .connect(buyer)
        .fulfillOrder(firstOrder.order, toKey(0), {
          value: firstOrder.value,
        })
    ).to.be.revertedWith(`OrderIsCancelled("${firstOrder.orderHash}")`);

    // Second order is not valid
    await expect(
      marketplaceContract
        .connect(buyer)
        .fulfillOrder(secondOrder.order, toKey(0), {
          value: secondOrder.value,
        })
    ).to.be.revertedWith(`InvalidRestrictedOrder("${secondOrder.orderHash}")`);
  });
});
