import { expect } from "chai";
import { Contract /* , constants */ } from "ethers";
import { ethers } from "hardhat";

import { deployContract } from "../contracts";
import { toBN } from "../encoding";

import { conduitFixture } from "./conduit";
import { create2FactoryFixture } from "./create2";
import { marketplaceFixture } from "./marketplace";
import { tokensFixture } from "./tokens";

import type { Reenterer } from "../../../typechain-types";
import type {
  AdvancedOrder,
  ConsiderationItem,
  CriteriaResolver,
  OfferItem,
} from "../types";
import type {
  BigNumber,
  BigNumberish,
  ContractReceipt,
  ContractTransaction,
  Wallet,
} from "ethers";

export { conduitFixture } from "./conduit";
export {
  fixtureERC20,
  fixtureERC721,
  fixtureERC1155,
  tokensFixture,
} from "./tokens";

const { provider } = ethers;

export const seaportFixture = async (owner: Wallet) => {
  const EIP1271WalletFactory = await ethers.getContractFactory("EIP1271Wallet");
  const reenterer = await deployContract<Reenterer>("Reenterer", owner);
  const { chainId } = await provider.getNetwork();
  const create2Factory = await create2FactoryFixture(owner);
  const {
    conduitController,
    conduitImplementation,
    conduitKeyOne,
    conduitOne,
    getTransferSender,
    deployNewConduit,
  } = await conduitFixture(create2Factory, owner);

  const {
    testERC20,
    mintAndApproveERC20,
    getTestItem20,
    testERC721,
    set721ApprovalForAll,
    mint721,
    mint721s,
    mintAndApprove721,
    getTestItem721,
    getTestItem721WithCriteria,
    testERC1155,
    set1155ApprovalForAll,
    mint1155,
    mintAndApprove1155,
    getTestItem1155WithCriteria,
    getTestItem1155,
    testERC1155Two,
    tokenByType,
    createTransferWithApproval,
  } = await tokensFixture(owner as any);

  const {
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
  } = await marketplaceFixture(
    create2Factory,
    conduitController,
    conduitOne,
    chainId,
    owner
  );

  const withBalanceChecks = async (
    ordersArray: AdvancedOrder[], // TODO: include order statuses to account for partial fills
    additionalPayouts: 0 | BigNumber,
    criteriaResolvers: CriteriaResolver[] = [],
    fn: () => Promise<ContractReceipt>,
    multiplier = 1
  ) => {
    const ordersClone: AdvancedOrder[] = JSON.parse(
      JSON.stringify(ordersArray as any)
    ) as any;
    for (const [i, order] of Object.entries(ordersClone) as any as [
      number,
      AdvancedOrder
    ][]) {
      order.parameters.startTime = ordersArray[i].parameters.startTime;
      order.parameters.endTime = ordersArray[i].parameters.endTime;

      for (const [j, offerItem] of Object.entries(
        order.parameters.offer
      ) as any) {
        offerItem.startAmount = ordersArray[i].parameters.offer[j].startAmount;
        offerItem.endAmount = ordersArray[i].parameters.offer[j].endAmount;
      }

      for (const [j, considerationItem] of Object.entries(
        order.parameters.consideration
      ) as any) {
        considerationItem.startAmount =
          ordersArray[i].parameters.consideration[j].startAmount;
        considerationItem.endAmount =
          ordersArray[i].parameters.consideration[j].endAmount;
      }
    }

    if (criteriaResolvers) {
      for (const { orderIndex, side, index, identifier } of criteriaResolvers) {
        const itemType =
          ordersClone[orderIndex].parameters[
            side === 0 ? "offer" : "consideration"
          ][index].itemType;
        if (itemType < 4) {
          console.error("APPLYING CRITERIA TO NON-CRITERIA-BASED ITEM");
          process.exit(1);
        }

        ordersClone[orderIndex].parameters[
          side === 0 ? "offer" : "consideration"
        ][index].itemType = itemType - 2;
        ordersClone[orderIndex].parameters[
          side === 0 ? "offer" : "consideration"
        ][index].identifierOrCriteria = identifier;
      }
    }

    const allOfferedItems = ordersClone
      .map((x) =>
        x.parameters.offer.map((offerItem) => ({
          ...offerItem,
          account: x.parameters.offerer,
          numerator: x.numerator,
          denominator: x.denominator,
          startTime: x.parameters.startTime,
          endTime: x.parameters.endTime,
        }))
      )
      .flat();

    const allReceivedItems = ordersClone
      .map((x) =>
        x.parameters.consideration.map((considerationItem) => ({
          ...considerationItem,
          numerator: x.numerator,
          denominator: x.denominator,
          startTime: x.parameters.startTime,
          endTime: x.parameters.endTime,
        }))
      )
      .flat();

    for (const offeredItem of allOfferedItems as any[]) {
      if (offeredItem.itemType > 3) {
        console.error("CRITERIA ON OFFERED ITEM NOT RESOLVED");
        process.exit(1);
      }

      if (offeredItem.itemType === 0) {
        // ETH
        offeredItem.initialBalance = await provider.getBalance(
          offeredItem.account
        );
      } else if (offeredItem.itemType === 3) {
        // ERC1155
        offeredItem.initialBalance = await tokenByType[
          offeredItem.itemType
        ].balanceOf(offeredItem.account, offeredItem.identifierOrCriteria);
      } else if (offeredItem.itemType < 4) {
        offeredItem.initialBalance = await tokenByType[
          offeredItem.itemType
        ].balanceOf(offeredItem.account);
      }

      if (offeredItem.itemType === 2) {
        // ERC721
        offeredItem.ownsItemBefore =
          (await tokenByType[offeredItem.itemType].ownerOf(
            offeredItem.identifierOrCriteria
          )) === offeredItem.account;
      }
    }

    for (const receivedItem of allReceivedItems as any[]) {
      if (receivedItem.itemType > 3) {
        console.error(
          "CRITERIA-BASED BALANCE RECEIVED CHECKS NOT IMPLEMENTED YET"
        );
        process.exit(1);
      }

      if (receivedItem.itemType === 0) {
        // ETH
        receivedItem.initialBalance = await provider.getBalance(
          receivedItem.recipient
        );
      } else if (receivedItem.itemType === 3) {
        // ERC1155
        receivedItem.initialBalance = await tokenByType[
          receivedItem.itemType
        ].balanceOf(receivedItem.recipient, receivedItem.identifierOrCriteria);
      } else {
        receivedItem.initialBalance = await tokenByType[
          receivedItem.itemType
        ].balanceOf(receivedItem.recipient);
      }

      if (receivedItem.itemType === 2) {
        // ERC721
        receivedItem.ownsItemBefore =
          (await tokenByType[receivedItem.itemType].ownerOf(
            receivedItem.identifierOrCriteria
          )) === receivedItem.recipient;
      }
    }

    const receipt = await fn();

    const from = receipt.from;
    const gasUsed = receipt.gasUsed;

    for (const offeredItem of allOfferedItems as any[]) {
      if (offeredItem.account === from && offeredItem.itemType === 0) {
        offeredItem.initialBalance = offeredItem.initialBalance.sub(gasUsed);
      }
    }

    for (const receivedItem of allReceivedItems as any[]) {
      if (receivedItem.recipient === from && receivedItem.itemType === 0) {
        receivedItem.initialBalance = receivedItem.initialBalance.sub(gasUsed);
      }
    }

    for (const offeredItem of allOfferedItems as any[]) {
      if (offeredItem.itemType > 3) {
        console.error("CRITERIA-BASED BALANCE OFFERED CHECKS NOT MET");
        process.exit(1);
      }

      if (offeredItem.itemType === 0) {
        // ETH
        offeredItem.finalBalance = await provider.getBalance(
          offeredItem.account
        );
      } else if (offeredItem.itemType === 3) {
        // ERC1155
        offeredItem.finalBalance = await tokenByType[
          offeredItem.itemType
        ].balanceOf(offeredItem.account, offeredItem.identifierOrCriteria);
      } else if (offeredItem.itemType < 3) {
        // TODO: criteria-based
        offeredItem.finalBalance = await tokenByType[
          offeredItem.itemType
        ].balanceOf(offeredItem.account);
      }

      if (offeredItem.itemType === 2) {
        // ERC721
        offeredItem.ownsItemAfter =
          (await tokenByType[offeredItem.itemType].ownerOf(
            offeredItem.identifierOrCriteria
          )) === offeredItem.account;
      }
    }

    for (const receivedItem of allReceivedItems as any[]) {
      if (receivedItem.itemType > 3) {
        console.error("CRITERIA-BASED BALANCE RECEIVED CHECKS NOT MET");
        process.exit(1);
      }

      if (receivedItem.itemType === 0) {
        // ETH
        receivedItem.finalBalance = await provider.getBalance(
          receivedItem.recipient
        );
      } else if (receivedItem.itemType === 3) {
        // ERC1155
        receivedItem.finalBalance = await tokenByType[
          receivedItem.itemType
        ].balanceOf(receivedItem.recipient, receivedItem.identifierOrCriteria);
      } else {
        receivedItem.finalBalance = await tokenByType[
          receivedItem.itemType
        ].balanceOf(receivedItem.recipient);
      }

      if (receivedItem.itemType === 2) {
        // ERC721
        receivedItem.ownsItemAfter =
          (await tokenByType[receivedItem.itemType].ownerOf(
            receivedItem.identifierOrCriteria
          )) === receivedItem.recipient;
      }
    }

    const { timestamp } = await provider.getBlock(receipt.blockHash);

    for (const offeredItem of allOfferedItems as any[]) {
      const duration = toBN(offeredItem.endTime).sub(offeredItem.startTime);
      const elapsed = toBN(timestamp).sub(offeredItem.startTime);
      const remaining = duration.sub(elapsed);

      if (offeredItem.itemType < 4) {
        // TODO: criteria-based
        if (!additionalPayouts) {
          expect(
            offeredItem.initialBalance.sub(offeredItem.finalBalance).toString()
          ).to.equal(
            toBN(offeredItem.startAmount)
              .mul(remaining)
              .add(toBN(offeredItem.endAmount).mul(elapsed))
              .div(duration)
              .mul(offeredItem.numerator)
              .div(offeredItem.denominator)
              .mul(multiplier)
              .toString()
          );
        } else {
          expect(
            offeredItem.initialBalance.sub(offeredItem.finalBalance).toString()
          ).to.equal(additionalPayouts.add(offeredItem.endAmount).toString());
        }
      }

      if (offeredItem.itemType === 2) {
        // ERC721
        expect(offeredItem.ownsItemBefore).to.equal(true);
        expect(offeredItem.ownsItemAfter).to.equal(false);
      }
    }

    for (const receivedItem of allReceivedItems as any[]) {
      const duration = toBN(receivedItem.endTime).sub(receivedItem.startTime);
      const elapsed = toBN(timestamp).sub(receivedItem.startTime);
      const remaining = duration.sub(elapsed);

      expect(
        receivedItem.finalBalance.sub(receivedItem.initialBalance).toString()
      ).to.equal(
        toBN(receivedItem.startAmount)
          .mul(remaining)
          .add(toBN(receivedItem.endAmount).mul(elapsed))
          .add(duration.sub(1))
          .div(duration)
          .mul(receivedItem.numerator)
          .div(receivedItem.denominator)
          .mul(multiplier)
          .toString()
      );

      if (receivedItem.itemType === 2) {
        // ERC721
        expect(receivedItem.ownsItemBefore).to.equal(false);
        expect(receivedItem.ownsItemAfter).to.equal(true);
      }
    }

    return receipt;
  };

  const checkTransferEvent = async (
    tx: ContractTransaction | Promise<ContractTransaction>,
    item: (OfferItem | ConsiderationItem) & {
      identifier?: string;
      amount?: BigNumberish;
      recipient?: string;
    },
    {
      offerer,
      conduitKey,
      target,
    }: { offerer: string; conduitKey: string; target: string }
  ) => {
    const {
      itemType,
      token,
      identifier: id1,
      identifierOrCriteria: id2,
      amount,
      recipient,
    } = item;
    const identifier = id1 ?? id2;
    const sender = getTransferSender(offerer, conduitKey);
    if ([1, 2, 5].includes(itemType)) {
      const contract = new Contract(
        token,
        (itemType === 1 ? testERC20 : testERC721).interface,
        provider
      );
      await expect(tx)
        .to.emit(contract, "Transfer")
        .withArgs(offerer, recipient, itemType === 1 ? amount : identifier);
    } else if ([3, 4].includes(itemType)) {
      const contract = new Contract(token, testERC1155.interface, provider);
      const operator = sender !== offerer ? sender : target;
      await expect(tx)
        .to.emit(contract, "TransferSingle")
        .withArgs(operator, offerer, recipient, identifier, amount);
    }
  };

  const checkExpectedEvents = async (
    tx: Promise<ContractTransaction> | ContractTransaction,
    receipt: ContractReceipt,
    orderGroups: Array<{
      order: AdvancedOrder;
      orderHash: string;
      fulfiller?: string;
      fulfillerConduitKey?: string;
      recipient?: string;
    }>,
    standardExecutions: any[] = [],
    criteriaResolvers: any[] = [],
    shouldSkipAmountComparison = false,
    multiplier = 1
  ) => {
    const { timestamp } = await provider.getBlock(receipt.blockHash);

    if (standardExecutions && standardExecutions.length) {
      for (const standardExecution of standardExecutions) {
        const { item, offerer, conduitKey } = standardExecution;
        await checkTransferEvent(tx, item, {
          offerer,
          conduitKey,
          target: receipt.to,
        });
      }

      // TODO: sum up executions and compare to orders to ensure that all the
      // items (or partially-filled items) are accounted for
    }

    if (criteriaResolvers && criteriaResolvers.length) {
      for (const { orderIndex, side, index, identifier } of criteriaResolvers) {
        const itemType =
          orderGroups[orderIndex].order.parameters[
            side === 0 ? "offer" : "consideration"
          ][index].itemType;
        if (itemType < 4) {
          console.error("APPLYING CRITERIA TO NON-CRITERIA-BASED ITEM");
          process.exit(1);
        }

        orderGroups[orderIndex].order.parameters[
          side === 0 ? "offer" : "consideration"
        ][index].itemType = itemType - 2;
        orderGroups[orderIndex].order.parameters[
          side === 0 ? "offer" : "consideration"
        ][index].identifierOrCriteria = identifier;
      }
    }

    for (let {
      order,
      orderHash,
      fulfiller,
      fulfillerConduitKey,
      recipient,
    } of orderGroups) {
      if (!recipient) {
        recipient = fulfiller;
      }
      const duration = toBN(order.parameters.endTime).sub(
        order.parameters.startTime as any
      );
      const elapsed = toBN(timestamp).sub(order.parameters.startTime as any);
      const remaining = duration.sub(elapsed);

      const marketplaceContractEvents = (receipt.events as any[])
        .filter((x) => x.address === marketplaceContract.address)
        .filter((x) => x.event === "OrderFulfilled")
        .map((x) => ({
          eventName: x.event,
          eventSignature: x.eventSignature,
          orderHash: x.args.orderHash,
          offerer: x.args.offerer,
          zone: x.args.zone,
          recipient: x.args.recipient,
          offer: x.args.offer.map((y: any) => ({
            itemType: y.itemType,
            token: y.token,
            identifier: y.identifier,
            amount: y.amount,
          })),
          consideration: x.args.consideration.map((y: any) => ({
            itemType: y.itemType,
            token: y.token,
            identifier: y.identifier,
            amount: y.amount,
            recipient: y.recipient,
          })),
        }))
        .filter((x) => x.orderHash === orderHash);

      expect(marketplaceContractEvents.length).to.equal(1);

      const event = marketplaceContractEvents[0];

      expect(event.eventName).to.equal("OrderFulfilled");
      expect(event.eventSignature).to.equal(
        "OrderFulfilled(" +
          "bytes32,address,address,address,(" +
          "uint8,address,uint256,uint256)[],(" +
          "uint8,address,uint256,uint256,address)[])"
      );
      expect(event.orderHash).to.equal(orderHash);
      expect(event.offerer).to.equal(order.parameters.offerer);
      expect(event.zone).to.equal(order.parameters.zone);
      expect(event.recipient).to.equal(recipient);

      const { offerer, conduitKey, consideration, offer } = order.parameters;
      const compareEventItems = async (
        item: any,
        orderItem: OfferItem | ConsiderationItem,
        isConsiderationItem: boolean
      ) => {
        expect(item.itemType).to.equal(
          orderItem.itemType > 3 ? orderItem.itemType - 2 : orderItem.itemType
        );
        expect(item.token).to.equal(orderItem.token);
        expect(item.token).to.equal(tokenByType[item.itemType].address);
        if (orderItem.itemType < 4) {
          // no criteria-based
          expect(item.identifier).to.equal(orderItem.identifierOrCriteria);
        } else {
          console.error("CRITERIA-BASED EVENT VALIDATION NOT MET");
          process.exit(1);
        }

        if (order.parameters.orderType === 0) {
          // FULL_OPEN (no partial fills)
          if (
            orderItem.startAmount.toString() === orderItem.endAmount.toString()
          ) {
            expect(item.amount.toString()).to.equal(
              orderItem.endAmount.toString()
            );
          } else {
            expect(item.amount.toString()).to.equal(
              toBN(orderItem.startAmount)
                .mul(remaining)
                .add(toBN(orderItem.endAmount).mul(elapsed))
                .add(isConsiderationItem ? duration.sub(1) : 0)
                .div(duration)
                .toString()
            );
          }
        } else {
          if (
            orderItem.startAmount.toString() === orderItem.endAmount.toString()
          ) {
            expect(item.amount.toString()).to.equal(
              orderItem.endAmount
                .mul(order.numerator)
                .div(order.denominator)
                .toString()
            );
          } else {
            console.error("SLIDING AMOUNT NOT IMPLEMENTED YET");
            process.exit(1);
          }
        }
      };

      if (!standardExecutions || !standardExecutions.length) {
        for (const item of consideration) {
          const { startAmount, endAmount } = item;
          let amount;
          if (order.parameters.orderType === 0) {
            amount = startAmount.eq(endAmount)
              ? endAmount
              : startAmount
                  .mul(remaining)
                  .add(endAmount.mul(elapsed))
                  .add(duration.sub(1))
                  .div(duration);
          } else {
            amount = endAmount.mul(order.numerator).div(order.denominator);
          }
          amount = amount.mul(multiplier);

          await checkTransferEvent(
            tx,
            { ...item, amount },
            {
              offerer: receipt.from,
              conduitKey: fulfillerConduitKey!,
              target: receipt.to,
            }
          );
        }

        for (const item of offer) {
          const { startAmount, endAmount } = item;
          let amount;
          if (order.parameters.orderType === 0) {
            amount = startAmount.eq(endAmount)
              ? endAmount
              : startAmount
                  .mul(remaining)
                  .add(endAmount.mul(elapsed))
                  .div(duration);
          } else {
            amount = endAmount.mul(order.numerator).div(order.denominator);
          }
          amount = amount.mul(multiplier);

          await checkTransferEvent(
            tx,
            { ...item, amount, recipient },
            {
              offerer,
              conduitKey,
              target: receipt.to,
            }
          );
        }
      }

      expect(event.offer.length).to.equal(order.parameters.offer.length);
      for (const [index, offer] of Object.entries(event.offer) as any[]) {
        const offerItem = order.parameters.offer[index];
        await compareEventItems(offer, offerItem, false);

        const tokenEvents = receipt.events?.filter(
          (x) => x.address === offerItem.token
        );

        if (offer.itemType === 1) {
          // ERC20
          // search for transfer
          const transferLogs = (tokenEvents ?? [])
            .map((x) => testERC20.interface.parseLog(x))
            .filter(
              (x) =>
                x.signature === "Transfer(address,address,uint256)" &&
                x.args.from === event.offerer /* &&
                // TODO: work out better way to check recipient with new matchOrder logic
                (recipient !== constants.AddressZero
                  ? x.args.to === recipient
                  : true) */
            );

          expect(transferLogs.length).to.be.above(0);
          // TODO: check each transferred amount
          // for (const transferLog of transferLogs) {
          // }
        } else if (offer.itemType === 2) {
          // ERC721
          // search for transfer
          const transferLogs = (tokenEvents ?? [])
            .map((x) => testERC721.interface.parseLog(x))
            .filter(
              (x) =>
                x.signature === "Transfer(address,address,uint256)" &&
                x.args.from === event.offerer /* &&
                // TODO: work out better way to check recipient with new matchOrder logic
                (recipient !== constants.AddressZero
                  ? x.args.to === recipient
                  : true) */
            );

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];
          expect(transferLog.args.id.toString()).to.equal(
            offer.identifier.toString()
          );
        } else if (offer.itemType === 3) {
          // search for transfer
          const transferLogs = (tokenEvents ?? [])
            .map((x) => testERC1155.interface.parseLog(x))
            .filter(
              (x) =>
                (x.signature ===
                  "TransferSingle(address,address,address,uint256,uint256)" &&
                  x.args.from === event.offerer) /* &&
                  // TODO: work out better way to check recipient with new matchOrder logic
                  (fulfiller !== constants.AddressZero
                    ? x.args.to === fulfiller
                    : true) */ ||
                (x.signature ===
                  "TransferBatch(address,address,address,uint256[],uint256[])" &&
                  x.args.from === event.offerer) /* &&
                  // TODO: work out better way to check recipient with new matchOrder logic
                  (fulfiller !== constants.AddressZero
                    ? x.args.to === fulfiller
                    : true) */
            );

          expect(transferLogs.length).to.be.above(0);

          let found = false;
          for (const transferLog of transferLogs) {
            if (
              transferLog.signature ===
                "TransferSingle(address,address,address,uint256,uint256)" &&
              transferLog.args.id.toString() === offer.identifier.toString() &&
              (shouldSkipAmountComparison ||
                transferLog.args.amount.toString() ===
                  offer.amount.mul(multiplier).toString())
            ) {
              found = true;
              break;
            }
          }

          // eslint-disable-next-line no-unused-expressions
          expect(found).to.be.true;
        }
      }

      expect(event.consideration.length).to.equal(
        order.parameters.consideration.length
      );
      for (const [index, consideration] of Object.entries(
        event.consideration
      ) as any[]) {
        const considerationItem = order.parameters.consideration[index];
        await compareEventItems(consideration, considerationItem, true);
        expect(consideration.recipient).to.equal(considerationItem.recipient);

        const tokenEvents = receipt.events?.filter(
          (x) => x.address === considerationItem.token
        );

        if (consideration.itemType === 1) {
          // ERC20
          // search for transfer
          const transferLogs = (tokenEvents ?? [])
            .map((x) => testERC20.interface.parseLog(x))
            .filter(
              (x) =>
                x.signature === "Transfer(address,address,uint256)" &&
                x.args.to === consideration.recipient
            );

          expect(transferLogs.length).to.be.above(0);
          // TODO: check each transferred amount
          // for (const transferLog of transferLogs) {
          // }
        } else if (consideration.itemType === 2) {
          // ERC721
          // search for transfer
          const transferLogs = (tokenEvents ?? [])
            .map((x) => testERC721.interface.parseLog(x))
            .filter(
              (x) =>
                x.signature === "Transfer(address,address,uint256)" &&
                x.args.to === consideration.recipient
            );

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];
          expect(transferLog.args.id.toString()).to.equal(
            consideration.identifier.toString()
          );
        } else if (consideration.itemType === 3) {
          // search for transfer
          const transferLogs = (tokenEvents ?? [])
            .map((x) => testERC1155.interface.parseLog(x))
            .filter(
              (x) =>
                (x.signature ===
                  "TransferSingle(address,address,address,uint256,uint256)" &&
                  x.args.to === consideration.recipient) ||
                (x.signature ===
                  "TransferBatch(address,address,address,uint256[],uint256[])" &&
                  x.args.to === consideration.recipient)
            );

          expect(transferLogs.length).to.be.above(0);

          let found = false;
          for (const transferLog of transferLogs) {
            if (
              transferLog.signature ===
                "TransferSingle(address,address,address,uint256,uint256)" &&
              transferLog.args.id.toString() ===
                consideration.identifier.toString() &&
              (shouldSkipAmountComparison ||
                transferLog.args.amount.toString() ===
                  consideration.amount.mul(multiplier).toString())
            ) {
              found = true;
              break;
            }
          }

          // eslint-disable-next-line no-unused-expressions
          expect(found).to.be.true;
        }
      }
    }
  };

  return {
    EIP1271WalletFactory,
    reenterer,
    chainId,
    conduitController,
    conduitImplementation,
    conduitKeyOne,
    conduitOne,
    getTransferSender,
    deployNewConduit,
    testERC20,
    mintAndApproveERC20,
    getTestItem20,
    testERC721,
    set721ApprovalForAll,
    mint721,
    mint721s,
    mintAndApprove721,
    getTestItem721,
    getTestItem721WithCriteria,
    testERC1155,
    set1155ApprovalForAll,
    mint1155,
    mintAndApprove1155,
    getTestItem1155WithCriteria,
    getTestItem1155,
    testERC1155Two,
    tokenByType,
    createTransferWithApproval,
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
    withBalanceChecks,
    checkTransferEvent,
    checkExpectedEvents,
  };
};

export type SeaportFixtures = Awaited<ReturnType<typeof seaportFixture>>;
