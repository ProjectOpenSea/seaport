import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { keccak256, recoverAddress, toUtf8Bytes } from "ethers/lib/utils";
import hre, { ethers, network } from "hardhat";

import { merkleTree } from "../utils/criteria";
import {
  buildResolver,
  convertSignatureToEIP2098,
  getItemETH,
  randomHex,
  toBN,
  toKey,
} from "../utils/encoding";
import { faucet } from "../utils/faucet";
import { seaportFixture } from "../utils/fixtures";
import {
  VERSION,
  changeChainId,
  getCustomRevertSelector,
} from "../utils/helpers";

import type {
  ConsiderationInterface,
  SignedZone,
  SignedZone__factory,
} from "../../typechain-types";
import type { SeaportFixtures } from "../utils/fixtures";
import type { Contract, Wallet } from "ethers";

const { signedOrderType } = require("../../eip-712-types/signedOrder");

const { parseEther } = ethers.utils;

describe(`Zone - SignedZone (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let marketplaceContract: ConsiderationInterface;
  let signedZoneFactory: SignedZone__factory;
  let signedZone: SignedZone;

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
      getTestItem721,
      getTestItem721WithCriteria,
      marketplaceContract,
      mintAndApprove721,
      withBalanceChecks,
    } = await seaportFixture(owner));
  });

  let buyer: Wallet;
  let seller: Wallet;

  let approvedSigner: Wallet;
  let chainId: number;

  beforeEach(async () => {
    // Setup basic buyer/seller wallets with ETH
    seller = new ethers.Wallet(randomHex(32), provider);
    buyer = new ethers.Wallet(randomHex(32), provider);

    for (const wallet of [seller, buyer]) {
      await faucet(wallet.address, provider);
    }

    approvedSigner = new ethers.Wallet(randomHex(32), provider);
    chainId = (await provider.getNetwork()).chainId;

    signedZoneFactory = await ethers.getContractFactory("SignedZone", owner);
    signedZone = await signedZoneFactory.deploy();
  });

  const toPaddedExpiration = (expiration: number) =>
    ethers.BigNumber.from(expiration).toHexString().slice(2).padStart(64, "0");

  const calculateSignedOrderHash = (
    fulfiller: string,
    expiration: number,
    orderHash: string
  ) => {
    const signedOrderTypeString =
      "SignedOrder(address fulfiller,uint256 expiration,bytes32 orderHash)";
    const signedOrderTypeHash = keccak256(toUtf8Bytes(signedOrderTypeString));

    const signedOrderHash = keccak256(
      "0x" +
        [
          signedOrderTypeHash.slice(2),
          fulfiller.slice(2).padStart(64, "0"),
          toPaddedExpiration(expiration),
          orderHash.slice(2),
        ].join("")
    );

    return signedOrderHash;
  };

  const signOrder = async (
    orderHash: string,
    signer: Wallet,
    zone: Contract,
    fulfiller = ethers.constants.AddressZero,
    secondsUntilExpiration = 60,
    compactSignature = false
  ) => {
    const domainData = {
      name: "SignedZone",
      version: "1.0",
      chainId,
      verifyingContract: zone.address,
    };

    const expiration = Math.round(Date.now() / 1000) + secondsUntilExpiration;
    const signedOrder = { fulfiller, expiration, orderHash };
    let signature = await signer._signTypedData(
      domainData,
      signedOrderType,
      signedOrder
    );

    expect(signature.length).to.eq(2 + 65 * 2); // 0x + 65 bytes
    if (compactSignature) {
      signature = convertSignatureToEIP2098(signature);
      expect(signature.length).to.eq(2 + 64 * 2); // 0x + 64 bytes
    }

    const domainSeparator = await zone.information();
    const signedOrderHash = calculateSignedOrderHash(
      fulfiller,
      expiration,
      orderHash
    );
    const digest = keccak256(
      `0x1901${domainSeparator.slice(2)}${signedOrderHash.slice(2)}`
    );

    const recoveredAddress = recoverAddress(digest, signature);
    expect(recoveredAddress).to.equal(signer.address);

    // extraData to be set on the order
    const extraData = `0x${fulfiller.slice(2)}${toPaddedExpiration(
      expiration
    )}${signature.slice(2)}`;

    return { signature, expiration, extraData };
  };

  it("Fulfills an order with a signed zone", async () => {
    // Execute 721 <=> ETH order
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { order, orderHash, value } = await createOrder(
      seller,
      signedZone.address,
      offer,
      consideration,
      2 // FULL_RESTRICTED
    );

    order.extraData = (
      await signOrder(orderHash, approvedSigner, signedZone)
    ).extraData;

    // Expect failure if signer is not approved
    await expect(
      marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          order,
          [],
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        )
    )
      .to.be.revertedWithCustomError(signedZone, "SignerNotApproved")
      .withArgs(approvedSigner.address, orderHash);

    // Approve signer
    await signedZone.addSigner(approvedSigner.address);

    // Expect success now that signer is approved
    await withBalanceChecks([order], 0, undefined, async () => {
      const tx = await marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          order,
          [],
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        );

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
  it("Fulfills an order with a signed zone for a specific fulfiller only", async () => {
    // Execute 721 <=> ETH order
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { order, orderHash, value } = await createOrder(
      seller,
      signedZone.address,
      offer,
      consideration,
      2 // FULL_RESTRICTED
    );

    order.extraData = (
      await signOrder(orderHash, approvedSigner, signedZone, buyer.address)
    ).extraData;

    // Approve signer
    await signedZone.addSigner(approvedSigner.address);

    // Expect failure if fulfiller does not match
    await expect(
      marketplaceContract
        .connect(owner)
        .fulfillAdvancedOrder(
          order,
          [],
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        )
    )
      .to.be.revertedWithCustomError(signedZone, "InvalidFulfiller")
      .withArgs(buyer.address, owner.address, orderHash);

    // Expect success with correct fulfiller
    await withBalanceChecks([order], 0, undefined, async () => {
      const tx = await marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          order,
          [],
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        );

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
  it("Fulfills an order with a signed zone using compact signature (EIP-2098)", async () => {
    // Execute 721 <=> ETH order
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { order, orderHash, value } = await createOrder(
      seller,
      signedZone.address,
      offer,
      consideration,
      2 // FULL_RESTRICTED
    );

    // Use compact representation of signature (EIP-2098)
    order.extraData = (
      await signOrder(
        orderHash,
        approvedSigner,
        signedZone,
        undefined,
        undefined,
        true
      )
    ).extraData;

    // Expect failure if signer is not approved
    await expect(
      marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          order,
          [],
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        )
    )
      .to.be.revertedWithCustomError(signedZone, "SignerNotApproved")
      .withArgs(approvedSigner.address, orderHash);

    // Approve signer
    await signedZone.addSigner(approvedSigner.address);

    // Expect success now that signer is approved
    await withBalanceChecks([order], 0, undefined, async () => {
      const tx = await marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          order,
          [],
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        );

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
  it("Fulfills an advanced order with criteria with a signed zone", async () => {
    const signedZoneFactory = await ethers.getContractFactory(
      "SignedZone",
      owner
    );

    const signedZone = await signedZoneFactory.deploy();

    // Create advanced order using signed zone
    // Execute 721 <=> ETH order
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
      signedZone.address,
      offer,
      consideration,
      2, // FULL_RESTRICTED
      criteriaResolvers
    );

    order.extraData = (
      await signOrder(orderHash, approvedSigner, signedZone)
    ).extraData;

    // Approve and remove signer
    await signedZone.addSigner(approvedSigner.address);
    await signedZone.removeSigner(approvedSigner.address);

    // Expect failure if signer is not approved
    await expect(
      marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          order,
          criteriaResolvers,
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        )
    )
      .to.be.revertedWithCustomError(signedZone, "SignerNotApproved")
      .withArgs(approvedSigner.address, orderHash);

    // Approve signer
    await signedZone.addSigner(approvedSigner.address);

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
  it("Does not fulfill an expired signature order with a signed zone", async () => {
    const signedZoneFactory = await ethers.getContractFactory(
      "SignedZone",
      owner
    );

    const signedZone = await signedZoneFactory.deploy();

    // Create advanced order using signed zone
    // Execute 721 <=> ETH order
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { order, orderHash, value } = await createOrder(
      seller,
      signedZone.address,
      offer,
      consideration,
      2 // FULL_RESTRICTED
    );

    const { extraData, expiration } = await signOrder(
      orderHash,
      approvedSigner,
      signedZone,
      undefined,
      -100
    );
    order.extraData = extraData;

    // Approve signer
    await signedZone.addSigner(approvedSigner.address);

    // Expect failure that signature is expired
    await expect(
      marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          order,
          [],
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        )
    )
      .to.be.revertedWithCustomError(signedZone, "SignatureExpired")
      .withArgs(expiration, orderHash);

    // Tamper with extraData by extending the expiration
    const futureExpiration = Math.round(Date.now() / 1000) + 1000;
    order.extraData = `0x${toPaddedExpiration(
      futureExpiration
    )}${extraData.slice(2, 132)}`;
    await expect(
      marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          order,
          [],
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        )
    )
      .to.be.revertedWithCustomError(signedZone, "SignerNotApproved")
      .withArgs(anyValue, orderHash);
  });
  it("Only the owner can set and remove signers", async () => {
    const signedZoneFactory = await ethers.getContractFactory(
      "SignedZone",
      owner
    );

    const signedZone = await signedZoneFactory.deploy();

    await expect(
      signedZone.connect(buyer).addSigner(buyer.address)
    ).to.be.revertedWith("Ownable: caller is not the owner");

    await expect(
      signedZone.connect(buyer).removeSigner(buyer.address)
    ).to.be.revertedWith("Ownable: caller is not the owner");

    await expect(signedZone.connect(owner).addSigner(approvedSigner.address))
      .to.emit(signedZone, "SignerAdded")
      .withArgs(approvedSigner.address);

    await expect(signedZone.connect(owner).addSigner(approvedSigner.address))
      .to.be.revertedWithCustomError(signedZone, "SignerAlreadyAdded")
      .withArgs(approvedSigner.address);

    await expect(signedZone.connect(owner).removeSigner(approvedSigner.address))
      .to.emit(signedZone, "SignerRemoved")
      .withArgs(approvedSigner.address);

    await expect(signedZone.connect(owner).removeSigner(approvedSigner.address))
      .to.be.revertedWithCustomError(signedZone, "SignerNotPresent")
      .withArgs(approvedSigner.address);

    await expect(
      signedZone.connect(owner).addSigner(ethers.constants.AddressZero)
    ).to.be.revertedWithCustomError(signedZone, "SignerCannotBeZeroAddress");

    await expect(
      signedZone.connect(owner).removeSigner(ethers.constants.AddressZero)
    )
      .to.be.revertedWithCustomError(signedZone, "SignerNotPresent")
      .withArgs(ethers.constants.AddressZero);
  });
  // Note: Run this test last in this file as it hacks changing the hre
  it("Reverts on changed chainId", async () => {
    // Create advanced order using signed zone
    // Execute 721 <=> ETH order
    const nftId = await mintAndApprove721(seller, marketplaceContract.address);

    const offer = [getTestItem721(nftId)];

    const consideration = [
      getItemETH(parseEther("10"), parseEther("10"), seller.address),
      getItemETH(parseEther("1"), parseEther("1"), owner.address),
    ];

    const { order, orderHash, value } = await createOrder(
      seller,
      signedZone.address,
      offer,
      consideration,
      2 // FULL_RESTRICTED
    );

    order.extraData = (
      await signOrder(orderHash, approvedSigner, signedZone)
    ).extraData;

    // Expect failure if signer is not approved
    await expect(
      marketplaceContract
        .connect(buyer)
        .fulfillAdvancedOrder(
          order,
          [],
          toKey(0),
          ethers.constants.AddressZero,
          {
            value,
          }
        )
    )
      .to.be.revertedWithCustomError(signedZone, "SignerNotApproved")
      .withArgs(approvedSigner.address, orderHash);

    // Approve signer
    await signedZone.addSigner(approvedSigner.address);

    // Change chainId in-flight to test branch coverage for _deriveDomainSeparator()
    // (hacky way, until https://github.com/NomicFoundation/hardhat/issues/3074 is added)
    changeChainId(hre);

    const expectedRevertReason = getCustomRevertSelector("InvalidSigner()");

    const tx = await marketplaceContract
      .connect(buyer)
      .populateTransaction.fulfillAdvancedOrder(
        order,
        [],
        toKey(0),
        ethers.constants.AddressZero,
        {
          value,
        }
      );
    tx.chainId = 1;
    const returnData = await provider.call(tx);
    expect(returnData).to.equal(expectedRevertReason);
  });
});
