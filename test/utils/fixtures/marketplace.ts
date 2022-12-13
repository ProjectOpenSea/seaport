import { expect } from "chai";
import { constants } from "ethers";
import { keccak256, recoverAddress } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";

import { deployContract } from "../contracts";
import { getBulkOrderTree } from "../eip712/bulk-orders";
import {
  calculateOrderHash,
  convertSignatureToEIP2098,
  randomHex,
  toBN,
} from "../encoding";
import { VERSION } from "../helpers";

import type {
  ConduitControllerInterface,
  ConduitInterface,
  ConsiderationInterface,
  ImmutableCreate2FactoryInterface,
  TestInvalidContractOfferer,
  TestInvalidContractOffererRatifyOrder,
  TestPostExecution,
  TestZone,
} from "../../../typechain-types";
import type {
  AdvancedOrder,
  ConsiderationItem,
  CriteriaResolver,
  OfferItem,
  OrderComponents,
} from "../types";
import type { Contract, Wallet } from "ethers";

const deployConstants = require("../../../constants/constants");
// const { bulkOrderType } = require("../../../eip-712-types/bulkOrder");
const { orderType } = require("../../../eip-712-types/order");

export const marketplaceFixture = async (
  create2Factory: ImmutableCreate2FactoryInterface,
  conduitController: ConduitControllerInterface,
  conduitOne: ConduitInterface,
  chainId: number,
  owner: Wallet
) => {
  // Deploy marketplace contract through efficient create2 factory
  const marketplaceContractFactory = await ethers.getContractFactory(
    process.env.REFERENCE ? "ReferenceConsideration" : "Seaport"
  );

  const directMarketplaceContract =
    await deployContract<ConsiderationInterface>(
      process.env.REFERENCE ? "ReferenceConsideration" : "Seaport",
      owner,
      conduitController.address
    );

  const marketplaceContractAddress = await create2Factory.findCreate2Address(
    deployConstants.MARKETPLACE_CONTRACT_CREATION_SALT,
    marketplaceContractFactory.bytecode +
      conduitController.address.slice(2).padStart(64, "0")
  );

  let { gasLimit } = await ethers.provider.getBlock("latest");

  if ((hre as any).__SOLIDITY_COVERAGE_RUNNING) {
    gasLimit = ethers.BigNumber.from(300_000_000);
  }

  await create2Factory.safeCreate2(
    deployConstants.MARKETPLACE_CONTRACT_CREATION_SALT,
    marketplaceContractFactory.bytecode +
      conduitController.address.slice(2).padStart(64, "0"),
    {
      gasLimit,
    }
  );

  const marketplaceContract = (await ethers.getContractAt(
    process.env.REFERENCE ? "ReferenceConsideration" : "Seaport",
    marketplaceContractAddress,
    owner
  )) as ConsiderationInterface;

  await conduitController
    .connect(owner)
    .updateChannel(conduitOne.address, marketplaceContract.address, true);

  const stubZone = await deployContract<TestZone>("TestZone", owner);
  const postExecutionZone = await deployContract<TestPostExecution>(
    "TestPostExecution",
    owner
  );

  const invalidContractOfferer =
    await deployContract<TestInvalidContractOfferer>(
      "TestInvalidContractOfferer",
      owner,
      marketplaceContractAddress
    );

  const invalidContractOffererRatifyOrder =
    await deployContract<TestInvalidContractOffererRatifyOrder>(
      "TestInvalidContractOffererRatifyOrder",
      owner,
      marketplaceContractAddress
    );

  // Required for EIP712 signing
  const domainData = {
    name: process.env.REFERENCE ? "Consideration" : "Seaport",
    version: VERSION,
    chainId,
    verifyingContract: marketplaceContract.address,
  };

  const getAndVerifyOrderHash = async (orderComponents: OrderComponents) => {
    const orderHash = await marketplaceContract.getOrderHash(orderComponents);
    const derivedOrderHash = calculateOrderHash(orderComponents);
    expect(orderHash).to.equal(derivedOrderHash);
    return orderHash;
  };

  // Returns signature
  const signOrder = async (
    orderComponents: OrderComponents,
    signer: Wallet | Contract,
    marketplace = marketplaceContract
  ) => {
    const signature = await signer._signTypedData(
      { ...domainData, verifyingContract: marketplace.address },
      orderType,
      orderComponents
    );

    const orderHash = await getAndVerifyOrderHash(orderComponents);

    const { domainSeparator } = await marketplace.information();
    const digest = keccak256(
      `0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`
    );
    const recoveredAddress = recoverAddress(digest, signature);

    expect(recoveredAddress).to.equal(signer.address);

    return signature;
  };

  const signBulkOrder = async (
    orderComponents: OrderComponents[],
    signer: Wallet | Contract,
    startIndex = 0,
    height?: number,
    extraCheap?: boolean
  ) => {
    const tree = getBulkOrderTree(orderComponents, startIndex, height);
    const bulkOrderType = tree.types;
    const chunks = tree.getDataToSign();
    let signature = await signer._signTypedData(domainData, bulkOrderType, {
      tree: chunks,
    });

    if (extraCheap) {
      signature = convertSignatureToEIP2098(signature);
    }

    const proofAndSignature = tree.getEncodedProofAndSignature(
      startIndex,
      signature
    );

    const orderHash = tree.getBulkOrderHash();

    const { domainSeparator } = await marketplaceContract.information();
    const digest = keccak256(
      `0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`
    );
    const recoveredAddress = recoverAddress(digest, signature);

    expect(recoveredAddress).to.equal(signer.address);

    // Verify each individual order
    for (const components of orderComponents) {
      const individualOrderHash = await getAndVerifyOrderHash(components);
      const digest = keccak256(
        `0x1901${domainSeparator.slice(2)}${individualOrderHash.slice(2)}`
      );
      const individualOrderSignature = await signer._signTypedData(
        domainData,
        orderType,
        components
      );
      const recoveredAddress = recoverAddress(digest, individualOrderSignature);
      expect(recoveredAddress).to.equal(signer.address);
    }

    return proofAndSignature;
  };

  const createOrder = async (
    offerer: Wallet | Contract,
    zone:
      | TestZone
      | TestPostExecution
      | Wallet
      | undefined
      | string = undefined,
    offer: OfferItem[],
    consideration: ConsiderationItem[],
    orderType: number,
    criteriaResolvers?: CriteriaResolver[],
    timeFlag?: string | null,
    signer?: Wallet,
    zoneHash = constants.HashZero,
    conduitKey = constants.HashZero,
    extraCheap = false,
    useBulkSignature = false,
    bulkSignatureIndex?: number,
    bulkSignatureHeight?: number,
    marketplace = marketplaceContract
  ) => {
    const counter = await marketplace.getCounter(offerer.address);

    const salt = !extraCheap ? randomHex() : constants.HashZero;
    const startTime =
      timeFlag !== "NOT_STARTED" ? 0 : toBN("0xee00000000000000000000000000");
    const endTime =
      timeFlag !== "EXPIRED" ? toBN("0xff00000000000000000000000000") : 1;

    const orderParameters = {
      offerer: offerer.address,
      zone: !extraCheap
        ? (zone as Wallet).address ?? zone
        : constants.AddressZero,
      offer,
      consideration,
      totalOriginalConsiderationItems: consideration.length,
      orderType,
      zoneHash,
      salt,
      conduitKey,
      startTime,
      endTime,
    };

    const orderComponents = {
      ...orderParameters,
      counter,
    };

    const orderHash = await getAndVerifyOrderHash(orderComponents);

    const { isValidated, isCancelled, totalFilled, totalSize } =
      await marketplace.getOrderStatus(orderHash);

    expect(isCancelled).to.equal(false);

    const orderStatus = {
      isValidated,
      isCancelled,
      totalFilled,
      totalSize,
    };

    const flatSig = await signOrder(
      orderComponents,
      signer ?? offerer,
      marketplace
    );

    const order = {
      parameters: orderParameters,
      signature: !extraCheap ? flatSig : convertSignatureToEIP2098(flatSig),
      numerator: 1, // only used for advanced orders
      denominator: 1, // only used for advanced orders
      extraData: "0x", // only used for advanced orders
    };

    if (useBulkSignature) {
      order.signature = await signBulkOrder(
        [orderComponents],
        signer ?? offerer,
        bulkSignatureIndex,
        bulkSignatureHeight,
        extraCheap
      );

      // Verify bulk signature length
      expect(
        order.signature.slice(2).length / 2,
        "bulk signature length should be valid (98 < length < 837)"
      )
        .to.be.gt(98)
        .and.lt(837);
      expect(
        (order.signature.slice(2).length / 2 - 67) % 32,
        "bulk signature length should be valid ((length - 67) % 32 < 2)"
      ).to.be.lt(2);
    }

    // How much ether (at most) needs to be supplied when fulfilling the order
    const value = offer
      .map((x) =>
        x.itemType === 0
          ? x.endAmount.gt(x.startAmount)
            ? x.endAmount
            : x.startAmount
          : toBN(0)
      )
      .reduce((a, b) => a.add(b), toBN(0))
      .add(
        consideration
          .map((x) =>
            x.itemType === 0
              ? x.endAmount.gt(x.startAmount)
                ? x.endAmount
                : x.startAmount
              : toBN(0)
          )
          .reduce((a, b) => a.add(b), toBN(0))
      );

    return {
      order,
      orderHash,
      value,
      orderStatus,
      orderComponents,
      startTime,
      endTime,
    };
  };

  const createMirrorBuyNowOrder = async (
    offerer: Wallet,
    zone: Wallet,
    order: AdvancedOrder,
    conduitKey = constants.HashZero
  ) => {
    const counter = await marketplaceContract.getCounter(offerer.address);
    const salt = randomHex();
    const startTime = order.parameters.startTime;
    const endTime = order.parameters.endTime;

    const compressedOfferItems = [];
    for (const {
      itemType,
      token,
      identifierOrCriteria,
      startAmount,
      endAmount,
    } of order.parameters.offer) {
      if (
        !compressedOfferItems
          .map((x) => `${x.itemType}+${x.token}+${x.identifierOrCriteria}`)
          .includes(`${itemType}+${token}+${identifierOrCriteria}`)
      ) {
        compressedOfferItems.push({
          itemType,
          token,
          identifierOrCriteria,
          startAmount: startAmount.eq(endAmount)
            ? startAmount
            : startAmount.sub(1),
          endAmount: startAmount.eq(endAmount) ? endAmount : endAmount.sub(1),
        });
      } else {
        const index = compressedOfferItems
          .map((x) => `${x.itemType}+${x.token}+${x.identifierOrCriteria}`)
          .indexOf(`${itemType}+${token}+${identifierOrCriteria}`);

        compressedOfferItems[index].startAmount = compressedOfferItems[
          index
        ].startAmount.add(
          startAmount.eq(endAmount) ? startAmount : startAmount.sub(1)
        );
        compressedOfferItems[index].endAmount = compressedOfferItems[
          index
        ].endAmount.add(
          startAmount.eq(endAmount) ? endAmount : endAmount.sub(1)
        );
      }
    }

    const compressedConsiderationItems = [];
    for (const {
      itemType,
      token,
      identifierOrCriteria,
      startAmount,
      endAmount,
      recipient,
    } of order.parameters.consideration) {
      if (
        !compressedConsiderationItems
          .map((x) => `${x.itemType}+${x.token}+${x.identifierOrCriteria}`)
          .includes(`${itemType}+${token}+${identifierOrCriteria}`)
      ) {
        compressedConsiderationItems.push({
          itemType,
          token,
          identifierOrCriteria,
          startAmount: startAmount.eq(endAmount)
            ? startAmount
            : startAmount.add(1),
          endAmount: startAmount.eq(endAmount) ? endAmount : endAmount.add(1),
          recipient,
        });
      } else {
        const index = compressedConsiderationItems
          .map((x) => `${x.itemType}+${x.token}+${x.identifierOrCriteria}`)
          .indexOf(`${itemType}+${token}+${identifierOrCriteria}`);

        compressedConsiderationItems[index].startAmount =
          compressedConsiderationItems[index].startAmount.add(
            startAmount.eq(endAmount) ? startAmount : startAmount.add(1)
          );
        compressedConsiderationItems[index].endAmount =
          compressedConsiderationItems[index].endAmount.add(
            startAmount.eq(endAmount) ? endAmount : endAmount.add(1)
          );
      }
    }

    const orderParameters = {
      offerer: offerer.address,
      zone: zone.address,
      offer: compressedConsiderationItems.map((x) => ({ ...x })),
      consideration: compressedOfferItems.map((x) => ({
        ...x,
        recipient: offerer.address,
      })),
      totalOriginalConsiderationItems: compressedOfferItems.length,
      orderType: order.parameters.orderType, // FULL_OPEN
      zoneHash: "0x".padEnd(66, "0"),
      salt,
      conduitKey,
      startTime,
      endTime,
    };

    const orderComponents = {
      ...orderParameters,
      counter,
    };

    const flatSig = await signOrder(orderComponents, offerer);

    const mirrorOrderHash = await getAndVerifyOrderHash(orderComponents);

    const mirrorOrder = {
      parameters: orderParameters,
      signature: flatSig,
      numerator: order.numerator, // only used for advanced orders
      denominator: order.denominator, // only used for advanced orders
      extraData: "0x", // only used for advanced orders
    };

    // How much ether (at most) needs to be supplied when fulfilling the order
    const mirrorValue = orderParameters.consideration
      .map((x) =>
        x.itemType === 0
          ? x.endAmount.gt(x.startAmount)
            ? x.endAmount
            : x.startAmount
          : toBN(0)
      )
      .reduce((a, b) => a.add(b), toBN(0));

    return {
      mirrorOrder,
      mirrorOrderHash,
      mirrorValue,
    };
  };

  const createMirrorAcceptOfferOrder = async (
    offerer: Wallet,
    zone: Wallet,
    order: AdvancedOrder,
    criteriaResolvers: CriteriaResolver[] = [],
    conduitKey = constants.HashZero
  ) => {
    const counter = await marketplaceContract.getCounter(offerer.address);
    const salt = randomHex();
    const startTime = order.parameters.startTime;
    const endTime = order.parameters.endTime;

    const orderParameters = {
      offerer: offerer.address,
      zone: zone.address,
      offer: order.parameters.consideration
        .filter((x) => x.itemType !== 1)
        .map((x) => ({
          itemType: x.itemType < 4 ? x.itemType : x.itemType - 2,
          token: x.token,
          identifierOrCriteria:
            x.itemType < 4
              ? x.identifierOrCriteria
              : criteriaResolvers[0].identifier,
          startAmount: x.startAmount,
          endAmount: x.endAmount,
        })),
      consideration: order.parameters.offer.map((x) => ({
        itemType: x.itemType < 4 ? x.itemType : x.itemType - 2,
        token: x.token,
        identifierOrCriteria:
          x.itemType < 4
            ? x.identifierOrCriteria
            : criteriaResolvers[0].identifier,
        recipient: offerer.address,
        startAmount: toBN(x.endAmount).sub(
          order.parameters.consideration
            .filter(
              (i) =>
                i.itemType < 2 &&
                i.itemType === x.itemType &&
                i.token === x.token
            )
            .map((i) => i.endAmount)
            .reduce((a, b) => a.add(b), toBN(0))
        ),
        endAmount: toBN(x.endAmount).sub(
          order.parameters.consideration
            .filter(
              (i) =>
                i.itemType < 2 &&
                i.itemType === x.itemType &&
                i.token === x.token
            )
            .map((i) => i.endAmount)
            .reduce((a, b) => a.add(b), toBN(0))
        ),
      })),
      totalOriginalConsiderationItems: order.parameters.offer.length,
      orderType: 0, // FULL_OPEN
      zoneHash: constants.HashZero,
      salt,
      conduitKey,
      startTime,
      endTime,
    };

    const orderComponents = {
      ...orderParameters,
      counter,
    };

    const flatSig = await signOrder(orderComponents, offerer);

    const mirrorOrderHash = await getAndVerifyOrderHash(orderComponents);

    const mirrorOrder = {
      parameters: orderParameters,
      signature: flatSig,
      numerator: 1, // only used for advanced orders
      denominator: 1, // only used for advanced orders
      extraData: "0x", // only used for advanced orders
    };

    // How much ether (at most) needs to be supplied when fulfilling the order
    const mirrorValue = orderParameters.consideration
      .map((x) =>
        x.itemType === 0
          ? x.endAmount.gt(x.startAmount)
            ? x.endAmount
            : x.startAmount
          : toBN(0)
      )
      .reduce((a, b) => a.add(b), toBN(0));

    return {
      mirrorOrder,
      mirrorOrderHash,
      mirrorValue,
    };
  };

  return {
    marketplaceContract,
    directMarketplaceContract,
    stubZone,
    postExecutionZone,
    invalidContractOfferer,
    invalidContractOffererRatifyOrder,
    domainData,
    signOrder,
    signBulkOrder,
    createOrder,
    createMirrorBuyNowOrder,
    createMirrorAcceptOfferOrder,
  };
};
