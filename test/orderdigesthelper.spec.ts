import { expect } from "chai";
import { ethers, network } from "hardhat";

import { getItemETH, randomHex } from "./utils/encoding";
import { seaportFixture } from "./utils/fixtures";
import { VERSION } from "./utils/helpers";
import { faucet } from "./utils/impersonate";

import type {
  ConsiderationInterface,
  EIP1271Wallet__factory,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";

const { parseEther, keccak256 } = ethers.utils;

describe(`OrderDigestHelper tests (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let directMarketplaceContract: ConsiderationInterface;
  let marketplaceContract: ConsiderationInterface;

  let EIP1271WalletFactory: EIP1271Wallet__factory;

  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await faucet(owner.address, provider);

    ({
      directMarketplaceContract,
      marketplaceContract,
      EIP1271WalletFactory,
      mintAndApprove721,
      getTestItem721,
      createOrder,
    } = await seaportFixture(owner));
  });

  let tempHelper;
  let buyer;
  let seller: any;
  let senderContract;
  let recipientContract;
  let zone: any;

  beforeEach(async () => {
    // Setup basic buyer/seller wallets with ETH
    buyer = new ethers.Wallet(randomHex(32), provider);
    seller = new ethers.Wallet(randomHex(32), provider);
    zone = new ethers.Wallet(randomHex(32), provider);

    senderContract = await EIP1271WalletFactory.deploy(buyer.address);
    recipientContract = await EIP1271WalletFactory.deploy(seller.address);

    await Promise.all(
      [buyer, seller, zone, senderContract, recipientContract].map((wallet) =>
        faucet(wallet.address, provider)
      )
    );
  });

  it("DigestHelper reverts with error code BadDomainSeparator() if separator doesn't match", async () => {
    // Deploy a new DomainHelper, but the digest will not match
    const contract = process.env.REFERENCE
      ? "ReferenceTestOrderHashDigestHelper"
      : "TestOrderHashDigestHelper";
    const digestHelperFactory = await ethers.getContractFactory(contract);
    let address = directMarketplaceContract.address;

    // If reference, fake a marketplace contract with 'information' function to get revert
    if (process.env.REFERENCE) {
      const testMarketplaceFactory = await ethers.getContractFactory(
        "ReferenceMarketplaceInfoTest"
      );
      const temp = await testMarketplaceFactory.deploy();
      address = temp.address;
    }

    await expect(digestHelperFactory.deploy(address)).to.be.revertedWith(
      "BadDomainSeparator"
    );
  });

  it("OrderHashHelper Test: Check order hash matches create order: ERC721 <=> ETH (basic)", async () => {
    // Deploy a new OrderHashHelper
    const contract = process.env.REFERENCE
      ? "ReferenceTestOrderHashDigestHelper"
      : "TestOrderHashDigestHelper";
    const orderHashHelperFactory = await ethers.getContractFactory(contract);
    tempHelper = await orderHashHelperFactory.deploy(
      marketplaceContract.address
    );

    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), zone.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { orderHash, orderComponents } = await createOrder(
      seller,
      zone,
      offer,
      consideration,
      0 // FULL_OPEN
    );

    const orderHashHelped = await tempHelper.testDeriveOrderHash(
      orderComponents,
      orderComponents.counter
    );

    expect(orderHash).to.equal(orderHashHelped);
  });

  it("DigestHelper Test: Check Digest Helper gets the correct digest with given order hash", async () => {
    // Deploy a new DomainHelper
    const contract = process.env.REFERENCE
      ? "ReferenceTestOrderHashDigestHelper"
      : "TestOrderHashDigestHelper";
    const digestHelperFactory = await ethers.getContractFactory(contract);
    tempHelper = await digestHelperFactory.deploy(marketplaceContract.address);

    const { domainSeparator } = await marketplaceContract.information();

    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), zone.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { orderHash } = await createOrder(
      seller,
      zone,
      offer,
      consideration,
      0 // FULL_OPEN
    );

    const digest = keccak256(
      `0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`
    );

    const digestHelped = await tempHelper.testDeriveEIP712Digest(orderHash);

    expect(digest).to.equal(digestHelped);
  });

  it("DigestHelper Test: Digest Helper gets the correct domain separator", async () => {
    // Deploy a new DomainHelper
    const contract = process.env.REFERENCE
      ? "ReferenceTestOrderHashDigestHelper"
      : "TestOrderHashDigestHelper";
    const digestHelperFactory = await ethers.getContractFactory(contract);
    tempHelper = await digestHelperFactory.deploy(marketplaceContract.address);

    const { domainSeparator } = await marketplaceContract.information();

    const domainSeparatorHelpered =
      await tempHelper.testDeriveDomainSeparator();

    expect(domainSeparator).to.equal(domainSeparatorHelpered);
  });
});
