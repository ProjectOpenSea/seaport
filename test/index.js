const { TypedDataDomain } = require("@ethersproject/abstract-signer");
const { JsonRpcProvider } = require("@ethersproject/providers");
const { Wallet } = require("@ethersproject/wallet");
const { expect } = require("chai");
const { time } = require("console");
const { constants, BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { TypedData, TypedDataUtils } = require("ethers-eip712");
const { faucet, whileImpersonating } = require("./utils/impersonate");
const { deployContract } = require("./utils/contracts");
const { merkleTree } = require("./utils/criteria");
const {
  randomHex,
  randomLarge,
  toAddress,
  toKey,
  convertSignatureToEIP2098,
  getBasicOrderParameters,
  getItem721,
  getOfferOrConsiderationItem,
  getItemETH,
} = require("./utils/encoding");
const { eip712DomainType } = require("../eip-712-types/domain");
const { orderType } = require("../eip-712-types/order");

const VERSION = "rc.1";

describe(`Consideration (version: ${VERSION}) — initial test suite`, function () {
  const provider = ethers.provider;
  let chainId;
  let marketplaceContract;
  let testERC20;
  let testERC721;
  let testERC1155;
  let testERC1155Two;
  let tokenByType;
  let owner;
  let domainData;
  let withBalanceChecks;
  let simulateMatchOrders;
  let simulateAdvancedMatchOrders;
  let EIP1271WalletFactory;
  let reenterer;
  let stubZone;
  let conduitController;
  let conduitImplementation;
  let conduitOne;
  let conduitKeyOne;

  const getTestItem721 = (
    identifierOrCriteria,
    startAmount = 1,
    endAmount = 1,
    recipient
  ) =>
    getOfferOrConsiderationItem(
      2,
      testERC721.address,
      identifierOrCriteria,
      startAmount,
      endAmount,
      recipient
    );

  const getTestItem20 = (startAmount = 50, endAmount = 50, recipient) =>
    getOfferOrConsiderationItem(
      1,
      testERC20.address,
      0,
      startAmount,
      endAmount,
      recipient
    );

  const getTestItem1155 = (
    identifierOrCriteria,
    startAmount,
    endAmount,
    token = testERC1155.address,
    recipient
  ) =>
    getOfferOrConsiderationItem(
      3,
      token,
      identifierOrCriteria,
      startAmount,
      endAmount,
      recipient
    );

  const getAndVerifyOrderHash = async (orderComponents) => {
    const orderHash = await marketplaceContract.getOrderHash(orderComponents);

    const offerItemTypeString =
      "OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)";
    const considerationItemTypeString =
      "ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)";
    const orderComponentsPartialTypeString =
      "OrderComponents(address offerer,address zone,OfferItem[] offer,ConsiderationItem[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,bytes32 zoneHash,uint256 salt,bytes32 conduitKey,uint256 nonce)";
    const orderTypeString = `${orderComponentsPartialTypeString}${considerationItemTypeString}${offerItemTypeString}`;

    const offerItemTypeHash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes(offerItemTypeString)
    );
    const considerationItemTypeHash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes(considerationItemTypeString)
    );
    const orderTypeHash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes(orderTypeString)
    );

    const offerHash = ethers.utils.keccak256(
      "0x" +
        orderComponents.offer
          .map((offerItem) => {
            return ethers.utils
              .keccak256(
                "0x" +
                  [
                    offerItemTypeHash.slice(2),
                    offerItem.itemType.toString().padStart(64, "0"),
                    offerItem.token.slice(2).padStart(64, "0"),
                    ethers.BigNumber.from(offerItem.identifierOrCriteria)
                      .toHexString()
                      .slice(2)
                      .padStart(64, "0"),
                    ethers.BigNumber.from(offerItem.startAmount)
                      .toHexString()
                      .slice(2)
                      .padStart(64, "0"),
                    ethers.BigNumber.from(offerItem.endAmount)
                      .toHexString()
                      .slice(2)
                      .padStart(64, "0"),
                  ].join("")
              )
              .slice(2);
          })
          .join("")
    );

    const considerationHash = ethers.utils.keccak256(
      "0x" +
        orderComponents.consideration
          .map((considerationItem) => {
            return ethers.utils
              .keccak256(
                "0x" +
                  [
                    considerationItemTypeHash.slice(2),
                    considerationItem.itemType.toString().padStart(64, "0"),
                    considerationItem.token.slice(2).padStart(64, "0"),
                    ethers.BigNumber.from(
                      considerationItem.identifierOrCriteria
                    )
                      .toHexString()
                      .slice(2)
                      .padStart(64, "0"),
                    ethers.BigNumber.from(considerationItem.startAmount)
                      .toHexString()
                      .slice(2)
                      .padStart(64, "0"),
                    ethers.BigNumber.from(considerationItem.endAmount)
                      .toHexString()
                      .slice(2)
                      .padStart(64, "0"),
                    considerationItem.recipient.slice(2).padStart(64, "0"),
                  ].join("")
              )
              .slice(2);
          })
          .join("")
    );

    const derivedOrderHash = ethers.utils.keccak256(
      "0x" +
        [
          orderTypeHash.slice(2),
          orderComponents.offerer.slice(2).padStart(64, "0"),
          orderComponents.zone.slice(2).padStart(64, "0"),
          offerHash.slice(2),
          considerationHash.slice(2),
          orderComponents.orderType.toString().padStart(64, "0"),
          ethers.BigNumber.from(orderComponents.startTime)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          ethers.BigNumber.from(orderComponents.endTime)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          orderComponents.zoneHash.slice(2),
          orderComponents.salt.slice(2).padStart(64, "0"),
          orderComponents.conduitKey.slice(2).padStart(64, "0"),
          ethers.BigNumber.from(orderComponents.nonce)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
        ].join("")
    );
    expect(orderHash).to.equal(derivedOrderHash);

    return orderHash;
  };

  // Returns signature
  const signOrder = async (orderComponents, signer) => {
    const signature = await signer._signTypedData(
      domainData,
      orderType,
      orderComponents
    );

    const orderHash = await getAndVerifyOrderHash(orderComponents);

    const { domainSeparator } = await marketplaceContract.information();
    const digest = ethers.utils.keccak256(
      `0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`
    );
    const recoveredAddress = ethers.utils.recoverAddress(digest, signature);

    expect(recoveredAddress).to.equal(signer.address);

    return signature;
  };

  const createOrder = async (
    offerer,
    zone,
    offer,
    consideration,
    orderType,
    criteriaResolvers,
    timeFlag,
    signer,
    zoneHash = constants.HashZero,
    conduitKey = constants.HashZero,
    extraCheap = false
  ) => {
    const nonce = await marketplaceContract.getNonce(offerer.address);

    const salt = !extraCheap ? randomHex() : constants.HashZero;
    const startTime =
      timeFlag !== "NOT_STARTED"
        ? 0
        : ethers.BigNumber.from("0xee00000000000000000000000000");
    const endTime =
      timeFlag !== "EXPIRED"
        ? ethers.BigNumber.from("0xff00000000000000000000000000")
        : 1;

    const orderParameters = {
      offerer: offerer.address,
      zone: !extraCheap ? zone.address : constants.AddressZero,
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
      nonce,
    };

    const orderHash = await getAndVerifyOrderHash(orderComponents);

    const { isValidated, isCancelled, totalFilled, totalSize } =
      await marketplaceContract.getOrderStatus(orderHash);

    expect(isCancelled).to.equal(false);

    const orderStatus = {
      isValidated,
      isCancelled,
      totalFilled,
      totalSize,
    };

    const flatSig = await signOrder(orderComponents, signer || offerer);

    const order = {
      parameters: orderParameters,
      signature: !extraCheap ? flatSig : convertSignatureToEIP2098(flatSig),
      numerator: 1, // only used for advanced orders
      denominator: 1, // only used for advanced orders
      extraData: "0x", // only used for advanced orders
    };

    // How much ether (at most) needs to be supplied when fulfilling the order
    const value = offer
      .map((x) =>
        x.itemType === 0
          ? x.endAmount.gt(x.startAmount)
            ? x.endAmount
            : x.startAmount
          : ethers.BigNumber.from(0)
      )
      .reduce((a, b) => a.add(b), ethers.BigNumber.from(0))
      .add(
        consideration
          .map((x) =>
            x.itemType === 0
              ? x.endAmount.gt(x.startAmount)
                ? x.endAmount
                : x.startAmount
              : ethers.BigNumber.from(0)
          )
          .reduce((a, b) => a.add(b), ethers.BigNumber.from(0))
      );

    return { order, orderHash, value, orderStatus, orderComponents };
  };

  const createMirrorBuyNowOrder = async (
    offerer,
    zone,
    order,
    conduitKey = constants.HashZero
  ) => {
    const nonce = await marketplaceContract.getNonce(offerer.address);
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
      offer: compressedConsiderationItems.map((x) => ({
        itemType: x.itemType,
        token: x.token,
        identifierOrCriteria: x.identifierOrCriteria,
        startAmount: x.startAmount,
        endAmount: x.endAmount,
      })),
      consideration: compressedOfferItems.map((x) => ({
        ...x,
        recipient: offerer.address,
      })),
      totalOriginalConsiderationItems: compressedOfferItems.length,
      orderType: 0, // FULL_OPEN
      zoneHash: "0x".padEnd(66, "0"),
      salt,
      conduitKey,
      startTime,
      endTime,
    };

    const orderComponents = {
      ...orderParameters,
      nonce,
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
          : ethers.BigNumber.from(0)
      )
      .reduce((a, b) => a.add(b), ethers.BigNumber.from(0));

    return { mirrorOrder, mirrorOrderHash, mirrorValue };
  };

  const createMirrorAcceptOfferOrder = async (
    offerer,
    zone,
    order,
    criteriaResolvers,
    conduitKey = constants.HashZero
  ) => {
    const nonce = await marketplaceContract.getNonce(offerer.address);
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
        startAmount: x.startAmount,
        endAmount: x.endAmount,
        recipient: offerer.address,
        startAmount: ethers.BigNumber.from(x.endAmount).sub(
          order.parameters.consideration
            .filter(
              (i) =>
                i.itemType < 2 &&
                i.itemType === x.itemType &&
                i.token === x.token
            )
            .map((i) => i.endAmount)
            .reduce((a, b) => a.add(b), ethers.BigNumber.from(0))
        ),
        endAmount: ethers.BigNumber.from(x.endAmount).sub(
          order.parameters.consideration
            .filter(
              (i) =>
                i.itemType < 2 &&
                i.itemType === x.itemType &&
                i.token === x.token
            )
            .map((i) => i.endAmount)
            .reduce((a, b) => a.add(b), ethers.BigNumber.from(0))
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
      nonce,
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
          : ethers.BigNumber.from(0)
      )
      .reduce((a, b) => a.add(b), ethers.BigNumber.from(0));

    return { mirrorOrder, mirrorOrderHash, mirrorValue };
  };

  const checkExpectedEvents = async (
    receipt,
    orderGroups,
    standardExecutions,
    batchExecutions,
    criteriaResolvers,
    shouldSkipAmountComparison = false,
    multiplier = 1
  ) => {
    if (standardExecutions && standardExecutions.length > 0) {
      for (standardExecution of standardExecutions) {
        const { item, offerer, conduitKey } = standardExecution;

        const { itemType, token, identifier, amount, recipient } = item;

        if (itemType !== 0) {
          const tokenEvents = receipt.events.filter((x) => x.address === token);

          expect(tokenEvents.length).to.be.above(0);

          if (itemType === 1) {
            // ERC20
            // search for transfer
            const transferLogs = tokenEvents
              .map((x) => testERC20.interface.parseLog(x))
              .filter(
                (x) =>
                  x.signature === "Transfer(address,address,uint256)" &&
                  x.args.to === recipient
              );

            expect(transferLogs.length > 0).to.be.true;
            const transferLog = transferLogs[0];
            expect(transferLog.args.amount.toString()).to.equal(
              amount.toString()
            );
          } else if (itemType === 2) {
            // ERC721
            // search for transfer
            const transferLogs = tokenEvents
              .map((x) => testERC721.interface.parseLog(x))
              .filter(
                (x) =>
                  x.signature === "Transfer(address,address,uint256)" &&
                  x.args.to === recipient
              );

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            expect(transferLog.args.id.toString()).to.equal(
              identifier.toString()
            );
          } else if (itemType === 3) {
            // search for transfer
            const transferLogs = tokenEvents
              .map((x) => testERC1155.interface.parseLog(x))
              .filter(
                (x) =>
                  x.signature ===
                    "TransferSingle(address,address,address,uint256,uint256)" &&
                  x.args.to === recipient
              );

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            expect(transferLog.args.id.toString()).to.equal(
              identifier.toString()
            );
            expect(transferLog.args.amount.toString()).to.equal(
              amount.toString()
            );
          } else {
            expect(false).to.be.true; // bad item type
          }
        }
      }

      // TODO: sum up executions and compare to orders to ensure that all the
      // items (or partially-filled items) are accounted for
    }

    if (batchExecutions && batchExecutions.length > 0) {
      for (batchExecution of batchExecutions) {
        const { token, from, to, tokenIds, amounts } = batchExecution;

        const tokenEvents = receipt.events.filter((x) => x.address === token);

        expect(tokenEvents.length).to.be.above(0);

        // search for transfer
        const transferLogs = tokenEvents
          .map((x) => testERC1155.interface.parseLog(x))
          .filter(
            (x) =>
              x.signature ===
                "TransferBatch(address,address,address,uint256[],uint256[])" &&
              x.args.to === to
          );

        expect(transferLogs.length).to.equal(1);
        const transferLog = transferLogs[0];
        for ([i, tokenId] of Object.entries(tokenIds)) {
          expect(transferLog.args.ids[i].toString()).to.equal(
            tokenId.toString()
          );
          expect(transferLog.args[4][i].toString()).to.equal(
            amounts[i].toString()
          );
        }
      }
    }

    if (criteriaResolvers) {
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

    for (const { order, orderHash, fulfiller, orderStatus } of orderGroups) {
      const marketplaceContractEvents = receipt.events
        .filter((x) => x.address === marketplaceContract.address)
        .map((x) => ({
          eventName: x.event,
          eventSignature: x.eventSignature,
          orderHash: x.args.orderHash,
          offerer: x.args.offerer,
          zone: x.args.zone,
          fulfiller: x.args.fulfiller,
          offer: x.args.offer.map((y) => ({
            itemType: y.itemType,
            token: y.token,
            identifier: y.identifier,
            amount: y.amount,
          })),
          consideration: x.args.consideration.map((y) => ({
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
      expect(event.fulfiller).to.equal(fulfiller);

      const compareEventItems = async (
        item,
        orderItem,
        isConsiderationItem
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
            const { timestamp } = await provider.getBlock(receipt.blockHash);
            const duration = ethers.BigNumber.from(
              order.parameters.endTime
            ).sub(order.parameters.startTime);
            const elapsed = ethers.BigNumber.from(timestamp).sub(
              order.parameters.startTime
            );
            const remaining = duration.sub(elapsed);

            expect(item.amount.toString()).to.equal(
              ethers.BigNumber.from(orderItem.startAmount)
                .mul(remaining)
                .add(ethers.BigNumber.from(orderItem.endAmount).mul(elapsed))
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

      expect(event.offer.length).to.equal(order.parameters.offer.length);
      for ([index, offer] of Object.entries(event.offer)) {
        const offerItem = order.parameters.offer[index];
        await compareEventItems(offer, offerItem, false);

        const tokenEvents = receipt.events.filter(
          (x) => x.address === offerItem.token
        );

        if (offer.itemType === 1) {
          // ERC20
          // search for transfer
          const transferLogs = tokenEvents
            .map((x) => testERC20.interface.parseLog(x))
            .filter(
              (x) =>
                x.signature === "Transfer(address,address,uint256)" &&
                x.args.from === event.offerer &&
                (fulfiller !== constants.AddressZero
                  ? x.args.to === fulfiller
                  : true)
            );

          expect(transferLogs.length).to.be.above(0);
          for (const transferLog of transferLogs) {
            // TODO: check each transferred amount
          }
        } else if (offer.itemType === 2) {
          // ERC721
          // search for transfer
          const transferLogs = tokenEvents
            .map((x) => testERC721.interface.parseLog(x))
            .filter(
              (x) =>
                x.signature === "Transfer(address,address,uint256)" &&
                x.args.from === event.offerer &&
                (fulfiller !== constants.AddressZero
                  ? x.args.to === fulfiller
                  : true)
            );

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];
          expect(transferLog.args.id.toString()).to.equal(
            offer.identifier.toString()
          );
        } else if (offer.itemType === 3) {
          // search for transfer
          const transferLogs = tokenEvents
            .map((x) => testERC1155.interface.parseLog(x))
            .filter(
              (x) =>
                (x.signature ===
                  "TransferSingle(address,address,address,uint256,uint256)" &&
                  x.args.from === event.offerer &&
                  (fulfiller !== constants.AddressZero
                    ? x.args.to === fulfiller
                    : true)) ||
                (x.signature ===
                  "TransferBatch(address,address,address,uint256[],uint256[])" &&
                  x.args.from === event.offerer &&
                  (fulfiller !== constants.AddressZero
                    ? x.args.to === fulfiller
                    : true))
            );

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];

          if (
            transferLog.signature ===
            "TransferSingle(address,address,address,uint256,uint256)"
          ) {
            expect(transferLog.args.id.toString()).to.equal(
              offer.identifier.toString()
            );

            if (!shouldSkipAmountComparison) {
              expect(transferLog.args.amount.toString()).to.equal(
                offer.amount.mul(multiplier).toString()
              );
            }
          } else {
            let located = false;
            for ([i, batchTokenId] of Object.entries(transferLog.args.ids)) {
              if (
                batchTokenId.toString() === offer.identifier.toString() &&
                transferLog.args[4][i].toString() === offer.amount.toString()
              ) {
                located = true;
                break;
              }
            }

            expect(located).to.be.true;
          }
        }
      }

      expect(event.consideration.length).to.equal(
        order.parameters.consideration.length
      );
      for ([index, consideration] of Object.entries(event.consideration)) {
        const considerationItem = order.parameters.consideration[index];
        await compareEventItems(consideration, considerationItem, true);
        expect(consideration.recipient).to.equal(considerationItem.recipient);

        const tokenEvents = receipt.events.filter(
          (x) => x.address === considerationItem.token
        );

        if (consideration.itemType === 1) {
          // ERC20
          // search for transfer
          const transferLogs = tokenEvents
            .map((x) => testERC20.interface.parseLog(x))
            .filter(
              (x) =>
                x.signature === "Transfer(address,address,uint256)" &&
                x.args.to === consideration.recipient
            );

          expect(transferLogs.length).to.be.above(0);
          for (const transferLog of transferLogs) {
            // TODO: check each transferred amount
          }
        } else if (consideration.itemType === 2) {
          // ERC721
          // search for transfer

          const transferLogs = tokenEvents
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
          const transferLogs = tokenEvents
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

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];

          if (
            transferLog.signature ===
            "TransferSingle(address,address,address,uint256,uint256)"
          ) {
            expect(transferLog.args.id.toString()).to.equal(
              consideration.identifier.toString()
            );
            if (!shouldSkipAmountComparison) {
              expect(transferLog.args.amount.toString()).to.equal(
                consideration.amount.toString()
              );
            }
          } else {
            let located = false;
            for ([i, batchTokenId] of Object.entries(transferLog.args.ids)) {
              if (
                batchTokenId.toString() ===
                  consideration.identifier.toString() &&
                transferLog.args[4][i].toString() ===
                  consideration.amount.toString()
              ) {
                located = true;
                break;
              }
            }

            expect(located).to.be.true;
          }
        }
      }
    }
  };

  const defaultBuyNowMirrorFulfillment = [
    {
      offerComponents: [
        {
          orderIndex: 0,
          itemIndex: 0,
        },
      ],
      considerationComponents: [
        {
          orderIndex: 1,
          itemIndex: 0,
        },
      ],
    },
    {
      offerComponents: [
        {
          orderIndex: 1,
          itemIndex: 0,
        },
      ],
      considerationComponents: [
        {
          orderIndex: 0,
          itemIndex: 0,
        },
      ],
    },
    {
      offerComponents: [
        {
          orderIndex: 1,
          itemIndex: 0,
        },
      ],
      considerationComponents: [
        {
          orderIndex: 0,
          itemIndex: 1,
        },
      ],
    },
    {
      offerComponents: [
        {
          orderIndex: 1,
          itemIndex: 0,
        },
      ],
      considerationComponents: [
        {
          orderIndex: 0,
          itemIndex: 2,
        },
      ],
    },
  ];

  const defaultAcceptOfferMirrorFulfillment = [
    {
      offerComponents: [
        {
          orderIndex: 1,
          itemIndex: 0,
        },
      ],
      considerationComponents: [
        {
          orderIndex: 0,
          itemIndex: 0,
        },
      ],
    },
    {
      offerComponents: [
        {
          orderIndex: 0,
          itemIndex: 0,
        },
      ],
      considerationComponents: [
        {
          orderIndex: 1,
          itemIndex: 0,
        },
      ],
    },
    {
      offerComponents: [
        {
          orderIndex: 0,
          itemIndex: 0,
        },
      ],
      considerationComponents: [
        {
          orderIndex: 0,
          itemIndex: 1,
        },
      ],
    },
    {
      offerComponents: [
        {
          orderIndex: 0,
          itemIndex: 0,
        },
      ],
      considerationComponents: [
        {
          orderIndex: 0,
          itemIndex: 2,
        },
      ],
    },
  ];

  before(async () => {
    const network = await provider.getNetwork();

    chainId = network.chainId;

    owner = ethers.Wallet.createRandom().connect(provider);

    await Promise.all(
      [owner].map((wallet) => faucet(wallet.address, provider))
    );

    EIP1271WalletFactory = await ethers.getContractFactory("EIP1271Wallet");

    reenterer = await deployContract("Reenterer", owner);

    conduitImplementation = await ethers.getContractFactory("Conduit");

    conduitController = await deployContract("ConduitController", owner);

    conduitKeyOne = `0x000000000000000000000000${owner.address.slice(2)}`;

    await conduitController.createConduit(conduitKeyOne, owner.address);

    const { conduit: conduitOneAddress, exists } =
      await conduitController.getConduit(conduitKeyOne);

    expect(exists).to.be.true;

    conduitOne = conduitImplementation.attach(conduitOneAddress);

    marketplaceContract = await deployContract(
      "Consideration",
      owner,
      conduitController.address
    );

    await conduitController
      .connect(owner)
      .updateChannel(conduitOne.address, marketplaceContract.address, true);

    testERC20 = await deployContract("TestERC20", owner);
    testERC721 = await deployContract("TestERC721", owner);
    testERC1155 = await deployContract("TestERC1155", owner);
    testERC1155Two = await deployContract("TestERC1155", owner);

    stubZone = await deployContract("TestZone", owner);

    tokenByType = [
      { address: constants.AddressZero }, // ETH
      testERC20,
      testERC721,
      testERC1155,
    ];

    // Required for EIP712 signing
    domainData = {
      name: "Consideration",
      version: VERSION,
      chainId: chainId,
      verifyingContract: marketplaceContract.address,
    };

    withBalanceChecks = async (
      ordersArray, // TODO: include order statuses to account for partial fills
      additonalPayouts,
      criteriaResolvers,
      fn,
      multiplier = 1
    ) => {
      const ordersClone = JSON.parse(JSON.stringify(ordersArray));
      for (const [i, order] of Object.entries(ordersClone)) {
        order.parameters.startTime = ordersArray[i].parameters.startTime;
        order.parameters.endTime = ordersArray[i].parameters.endTime;

        for (const [j, offerItem] of Object.entries(order.parameters.offer)) {
          offerItem.startAmount =
            ordersArray[i].parameters.offer[j].startAmount;
          offerItem.endAmount = ordersArray[i].parameters.offer[j].endAmount;
        }

        for (const [j, considerationItem] of Object.entries(
          order.parameters.consideration
        )) {
          considerationItem.startAmount =
            ordersArray[i].parameters.consideration[j].startAmount;
          considerationItem.endAmount =
            ordersArray[i].parameters.consideration[j].endAmount;
        }
      }

      if (criteriaResolvers) {
        for (const {
          orderIndex,
          side,
          index,
          identifier,
        } of criteriaResolvers) {
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

      for (offeredItem of allOfferedItems) {
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

      for (receivedItem of allReceivedItems) {
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
          ].balanceOf(
            receivedItem.recipient,
            receivedItem.identifierOrCriteria
          );
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

      for (offeredItem of allOfferedItems) {
        if (offeredItem.account === from && offeredItem.itemType === 0) {
          offerredItem.initialBalance = offeredItem.initialBalance.sub(gasUsed);
        }
      }

      for (receivedItem of allReceivedItems) {
        if (receivedItem.recipient === from && receivedItem.itemType === 0) {
          receivedItem.initialBalance =
            receivedItem.initialBalance.sub(gasUsed);
        }
      }

      for (offeredItem of allOfferedItems) {
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

      for (receivedItem of allReceivedItems) {
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
          ].balanceOf(
            receivedItem.recipient,
            receivedItem.identifierOrCriteria
          );
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

      for (offerredItem of allOfferedItems) {
        const duration = ethers.BigNumber.from(offerredItem.endTime).sub(
          offerredItem.startTime
        );
        const elapsed = ethers.BigNumber.from(timestamp).sub(
          offerredItem.startTime
        );
        const remaining = duration.sub(elapsed);

        if (offeredItem.itemType < 4) {
          // TODO: criteria-based
          if (!additonalPayouts) {
            expect(
              offerredItem.initialBalance
                .sub(offerredItem.finalBalance)
                .toString()
            ).to.equal(
              ethers.BigNumber.from(offerredItem.startAmount)
                .mul(remaining)
                .add(ethers.BigNumber.from(offerredItem.endAmount).mul(elapsed))
                .div(duration)
                .mul(offerredItem.numerator)
                .div(offerredItem.denominator)
                .mul(multiplier)
                .toString()
            );
          } else {
            expect(
              offerredItem.initialBalance
                .sub(offerredItem.finalBalance)
                .toString()
            ).to.equal(additonalPayouts.add(offerredItem.endAmount).toString());
          }
        }

        if (offeredItem.itemType === 2) {
          // ERC721
          expect(offeredItem.ownsItemBefore).to.equal(true);
          expect(offeredItem.ownsItemAfter).to.equal(false);
        }
      }

      for (receivedItem of allReceivedItems) {
        const duration = ethers.BigNumber.from(receivedItem.endTime).sub(
          receivedItem.startTime
        );
        const elapsed = ethers.BigNumber.from(timestamp).sub(
          receivedItem.startTime
        );
        const remaining = duration.sub(elapsed);

        expect(
          receivedItem.finalBalance.sub(receivedItem.initialBalance).toString()
        ).to.equal(
          ethers.BigNumber.from(receivedItem.startAmount)
            .mul(remaining)
            .add(ethers.BigNumber.from(receivedItem.endAmount).mul(elapsed))
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

    simulateMatchOrders = async (orders, fulfillments, caller, value) => {
      return marketplaceContract
        .connect(caller)
        .callStatic.matchOrders(orders, fulfillments, { value });
    };

    simulateAdvancedMatchOrders = async (
      orders,
      criteriaResolvers,
      fulfillments,
      caller,
      value
    ) => {
      return marketplaceContract
        .connect(caller)
        .callStatic.matchAdvancedOrders(
          orders,
          criteriaResolvers,
          fulfillments,
          { value }
        );
    };
  });

  describe("Getter tests", async () => {
    it("gets correct name", async () => {
      const name = await marketplaceContract.name();
      expect(name).to.equal("Consideration");
    });
    it("gets correct version, domain separator and conduit controller", async () => {
      const name = "Consideration";
      const {
        version,
        domainSeparator,
        conduitController: controller,
      } = await marketplaceContract.information();

      const typehash = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(
          "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        )
      );
      const namehash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
      const versionhash = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(version)
      );
      const { chainId } = await provider.getNetwork();
      const chainIdEncoded = chainId.toString(16).padStart(64, "0");
      const addressEncoded = marketplaceContract.address
        .slice(2)
        .padStart(64, "0");
      expect(domainSeparator).to.equal(
        ethers.utils.keccak256(
          `0x${typehash.slice(2)}${namehash.slice(2)}${versionhash.slice(
            2
          )}${chainIdEncoded}${addressEncoded}`
        )
      );
      expect(controller).to.equal(conduitController.address);
    });
  });

  // Buy now or accept offer for a single ERC721 or ERC1155 in exchange for
  // ETH, WETH or ERC20
  describe("Basic buy now or accept offer flows", async () => {
    let seller;
    let sellerContract;
    let buyerContract;
    let buyer;

    beforeEach(async () => {
      // Setup basic buyer/seller wallets with ETH
      seller = ethers.Wallet.createRandom().connect(provider);
      buyer = ethers.Wallet.createRandom().connect(provider);
      zone = ethers.Wallet.createRandom().connect(provider);

      sellerContract = await EIP1271WalletFactory.deploy(seller.address);
      buyerContract = await EIP1271WalletFactory.deploy(buyer.address);

      await Promise.all(
        [seller, buyer, zone, sellerContract, buyerContract].map((wallet) =>
          faucet(wallet.address, provider)
        )
      );
    });

    describe("A single ERC721 is to be transferred", async () => {
      describe("[Buy now] User fullfills a sell order for a single ERC721", async () => {
        it("ERC721 <=> ETH (standard)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false), { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (standard via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false), { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (standard with tip)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          // Add a tip
          order.parameters.consideration.push({
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("1"),
            endAmount: ethers.utils.parseEther("1"),
            recipient: owner.address,
          });

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false), {
                  value: value.add(ethers.utils.parseEther("1")),
                });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (standard with restricted order)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            stubZone,
            offer,
            consideration,
            2 // FULL_RESTRICTED
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false), { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (standard with restricted order and extra data)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            stubZone,
            offer,
            consideration,
            2 // FULL_RESTRICTED
          );

          order.extraData = "0x1234";

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillAdvancedOrder(order, [], toKey(false), { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic, minimal and listed off-chain)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(1);
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
              recipient: seller.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            constants.AddressZero,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            constants.HashZero,
            true // extraCheap
          );

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic, minimal and verified on-chain)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(0);
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
              recipient: seller.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            constants.AddressZero,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            constants.HashZero,
            true // extraCheap
          );

          // Validate the order from any account
          await whileImpersonating(owner.address, provider, async () => {
            await expect(marketplaceContract.connect(owner).validate([order]))
              .to.emit(marketplaceContract, "OrderValidated")
              .withArgs(orderHash, seller.address, constants.AddressZero);
          });

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (standard, minimal and listed off-chain)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(2);
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
              recipient: seller.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            constants.AddressZero,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            constants.HashZero,
            true // extraCheap
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false), { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (standard, minimal and verified on-chain)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(3);
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
              recipient: seller.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            constants.AddressZero,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            constants.HashZero,
            true // extraCheap
          );

          // Validate the order from any account
          await whileImpersonating(owner.address, provider, async () => {
            await expect(marketplaceContract.connect(owner).validate([order]))
              .to.emit(marketplaceContract, "OrderValidated")
              .withArgs(orderHash, seller.address, constants.AddressZero);
          });

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false), { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (advanced, minimal and listed off-chain)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(4);
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
              recipient: seller.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            constants.AddressZero,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            constants.HashZero,
            true // extraCheap
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillAdvancedOrder(order, [], toKey(false), { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (advanced, minimal and verified on-chain)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(5);
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
              recipient: seller.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            constants.AddressZero,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            constants.HashZero,
            true // extraCheap
          );

          // Validate the order from any account
          await whileImpersonating(owner.address, provider, async () => {
            await expect(marketplaceContract.connect(owner).validate([order]))
              .to.emit(marketplaceContract, "OrderValidated")
              .withArgs(orderHash, seller.address, constants.AddressZero);
          });

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillAdvancedOrder(order, [], toKey(false), { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic with tips)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order,
            false,
            [
              {
                amount: ethers.utils.parseEther("2"),
                recipient: `0x0000000000000000000000000000000000000001`,
              },
            ]
          );

          order.parameters.consideration.push({
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("2"),
            endAmount: ethers.utils.parseEther("2"),
            recipient: `0x0000000000000000000000000000000000000001`,
          });

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, {
                  value: value.add(ethers.utils.parseEther("2")),
                });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic with restricted order)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            stubZone,
            offer,
            consideration,
            2 // FULL_RESTRICTED
          );

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic, already validated)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          // Validate the order from any account
          await whileImpersonating(owner.address, provider, async () => {
            await expect(marketplaceContract.connect(owner).validate([order]))
              .to.emit(marketplaceContract, "OrderValidated")
              .withArgs(orderHash, seller.address, zone.address);
          });

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic, EIP-2098 signature)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          // Convert signature to EIP 2098
          expect(order.signature.length).to.equal(132);
          order.signature = convertSignatureToEIP2098(order.signature);
          expect(order.signature.length).to.equal(130);

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic, extra ether supplied and returned to caller)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, {
                  value: value.add(1),
                });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (match)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
        it("ERC721 <=> ETH (match via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
        it("ERC721 <=> ETH (match, extra eth supplied and returned to caller)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, {
                value: value.add(101),
              });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (standard)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false));
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (standard via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false));
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (basic)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(
            2, // ERC20ForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (basic via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          const basicOrderParameters = getBasicOrderParameters(
            2, // ERC20ForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (basic, EIP-1271 signature)", async () => {
          // Seller mints nft to contract
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(sellerContract.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              sellerContract
                .connect(seller)
                .approveNFT(testERC721.address, marketplaceContract.address)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(
                sellerContract.address,
                marketplaceContract.address,
                true
              );
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
              recipient: sellerContract.address,
            },
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            sellerContract,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller
          );

          const basicOrderParameters = getBasicOrderParameters(
            2, // ERC20ForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (basic, EIP-1271 signature w/ non-standard length)", async () => {
          // Seller mints nft to contract
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(sellerContract.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              sellerContract
                .connect(seller)
                .approveNFT(testERC721.address, marketplaceContract.address)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(
                sellerContract.address,
                marketplaceContract.address,
                true
              );
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
              recipient: sellerContract.address,
            },
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            sellerContract,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller
          );

          const basicOrderParameters = {
            ...getBasicOrderParameters(
              2, // ERC20ForERC721
              order
            ),
            signature: "0x",
          };

          // Fails before seller contract approves the digest (note that any
          // non-standard signature length is treated as a contract signature)
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters)
            ).to.be.revertedWith("BadContractSignature");
          });

          // Compute the digest based on the order hash
          const { domainSeparator } = await marketplaceContract.information();
          const digest = ethers.utils.keccak256(
            `0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`
          );

          // Seller approves the digest
          await whileImpersonating(seller.address, provider, async () => {
            await sellerContract.connect(seller).registerDigest(digest, true);
          });

          // Now it succeeds
          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (match)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (match via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC721
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
      });
      describe("[Accept offer] User accepts a buy offer on a single ERC721", async () => {
        // Note: ETH is not a possible case
        it("ERC721 <=> ERC20 (standard)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves marketplace contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC721
                .connect(buyer)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // Buyer approves marketplace contract to transfer ERC20 tokens too
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
            },
          ];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false));
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (standard, via conduit)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves marketplace contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC721
                .connect(buyer)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves conduit contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20.connect(seller).approve(conduitOne.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, conduitOne.address, tokenAmount);
          });

          // Buyer approves marketplace contract to transfer ERC20 tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
            },
          ];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false));
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (standard, fulfilled via conduit)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves conduit contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC721
                .connect(buyer)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, conduitOne.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // Buyer approves conduit to transfer ERC20 tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, conduitOne.address, tokenAmount);
          });

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
            },
          ];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, conduitKeyOne);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (basic)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves marketplace contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC721
                .connect(buyer)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge());
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount,
              endAmount: tokenAmount,
            },
          ];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(
            4, // ERC721ForERC20
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks(
              [order],
              ethers.BigNumber.from(0),
              null,
              async () => {
                const tx = await marketplaceContract
                  .connect(buyer)
                  .fulfillBasicOrder(basicOrderParameters);
                const receipt = await tx.wait();
                await checkExpectedEvents(receipt, [
                  { order, orderHash, fulfiller: buyer.address },
                ]);
                return receipt;
              }
            );
          });
        });
        it("ERC721 <=> ERC20 (basic, fulfilled via conduit)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves conduit contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC721
                .connect(buyer)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, conduitOne.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge());
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount,
              endAmount: tokenAmount,
            },
          ];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(
            4, // ERC721ForERC20
            order,
            conduitKeyOne
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks(
              [order],
              ethers.BigNumber.from(0),
              null,
              async () => {
                const tx = await marketplaceContract
                  .connect(buyer)
                  .fulfillBasicOrder(basicOrderParameters);
                const receipt = await tx.wait();
                await checkExpectedEvents(receipt, [
                  { order, orderHash, fulfiller: buyer.address },
                ]);
                return receipt;
              }
            );
          });
        });
        it("ERC721 <=> ERC20 (match)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves marketplace contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC721
                .connect(buyer)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
            },
          ];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorAcceptOfferOrder(buyer, zone, order);

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (match via conduit)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves conduit contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC721
                .connect(buyer)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, conduitOne.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
            },
          ];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorAcceptOfferOrder(
              buyer,
              zone,
              order,
              [],
              conduitKeyOne
            );

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
      });
    });

    describe("A single ERC1155 is to be transferred", async () => {
      describe("[Buy now] User fullfills a sell order for a single ERC1155", async () => {
        it("ERC1155 <=> ETH (standard)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false), { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ETH (standard via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false), { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ETH (basic)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(
            1, // EthForERC1155
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ETH (basic via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          const basicOrderParameters = getBasicOrderParameters(
            1, // EthForERC1155
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ETH (match)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
        it("ERC1155 <=> ETH (match via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("10"),
              endAmount: ethers.utils.parseEther("10"),
              recipient: seller.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              itemType: 0, // ETH
              token: constants.AddressZero,
              identifierOrCriteria: 0, // ignored for ETH
              startAmount: ethers.utils.parseEther("1"),
              endAmount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            },
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (standard)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false));
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (standard via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false));
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (basic)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(
            3, // ERC20ForERC1155
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (basic via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          const basicOrderParameters = getBasicOrderParameters(
            3, // ERC20ForERC1155
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (match)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (match via conduit)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves conduit contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC1155
                .connect(seller)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, conduitOne.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              seller.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller,
            constants.HashZero,
            conduitKeyOne
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
      });
      describe("[Accept offer] User accepts a buy offer on a single ERC1155", async () => {
        // Note: ETH is not a possible case
        it("ERC1155 <=> ERC20 (standard)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(buyer.address, nftId, amount);

          // Buyer approves marketplace contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC1155
                .connect(buyer)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // Buyer approves marketplace contract to transfer ERC20 tokens too
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20
                .connect(buyer)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                buyer.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
            },
          ];

          const consideration = [
            {
              itemType: 3, // ERC1155
              token: testERC1155.address,
              identifierOrCriteria: nftId,
              startAmount: amount,
              endAmount: amount,
              recipient: seller.address,
            },
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false));
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (standard, fulfilled via conduit)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(buyer.address, nftId, amount);

          // Buyer approves conduit contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC1155
                .connect(buyer)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, conduitOne.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // Buyer approves conduit to transfer ERC20 tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, conduitOne.address, tokenAmount);
          });

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
            },
          ];

          const consideration = [
            {
              itemType: 3, // ERC1155
              token: testERC1155.address,
              identifierOrCriteria: nftId,
              startAmount: amount,
              endAmount: amount,
              recipient: seller.address,
            },
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, conduitKeyOne);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (basic)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(buyer.address, nftId, amount);

          // Buyer approves marketplace contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC1155
                .connect(buyer)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge());
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount,
              endAmount: tokenAmount,
            },
          ];

          const consideration = [
            {
              itemType: 3, // ERC1155
              token: testERC1155.address,
              identifierOrCriteria: nftId,
              startAmount: amount,
              endAmount: amount,
              recipient: seller.address,
            },
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(
            5, // ERC1155ForERC20
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks(
              [order],
              ethers.BigNumber.from(0),
              null,
              async () => {
                const tx = await marketplaceContract
                  .connect(buyer)
                  .fulfillBasicOrder(basicOrderParameters);
                const receipt = await tx.wait();
                await checkExpectedEvents(receipt, [
                  { order, orderHash, fulfiller: buyer.address },
                ]);
                return receipt;
              }
            );
          });
        });
        it("ERC1155 <=> ERC20 (basic, fulfilled via conduit)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(buyer.address, nftId, amount);

          // Buyer approves conduit contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC1155
                .connect(buyer)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, conduitOne.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge());
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount,
              endAmount: tokenAmount,
            },
          ];

          const consideration = [
            {
              itemType: 3, // ERC1155
              token: testERC1155.address,
              identifierOrCriteria: nftId,
              startAmount: amount,
              endAmount: amount,
              recipient: seller.address,
            },
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(
            5, // ERC1155ForERC20
            order,
            conduitKeyOne
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks(
              [order],
              ethers.BigNumber.from(0),
              null,
              async () => {
                const tx = await marketplaceContract
                  .connect(buyer)
                  .fulfillBasicOrder(basicOrderParameters);
                const receipt = await tx.wait();
                await checkExpectedEvents(receipt, [
                  { order, orderHash, fulfiller: buyer.address },
                ]);
                return receipt;
              }
            );
          });
        });
        it("ERC1155 <=> ERC20 (match)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(buyer.address, nftId, amount);

          // Buyer approves marketplace contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC1155
                .connect(buyer)
                .setApprovalForAll(marketplaceContract.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
            },
          ];

          const consideration = [
            {
              itemType: 3, // ERC1155
              token: testERC1155.address,
              identifierOrCriteria: nftId,
              startAmount: amount,
              endAmount: amount,
              recipient: seller.address,
            },
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorAcceptOfferOrder(buyer, zone, order);

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (match via conduit)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(buyer.address, nftId, amount);

          // Buyer approves conduit contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(
              testERC1155
                .connect(buyer)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, conduitOne.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(
              testERC20
                .connect(seller)
                .approve(marketplaceContract.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(
                seller.address,
                marketplaceContract.address,
                tokenAmount
              );
          });

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
            },
          ];

          const consideration = [
            {
              itemType: 3, // ERC1155
              token: testERC1155.address,
              identifierOrCriteria: nftId,
              startAmount: amount,
              endAmount: amount,
              recipient: seller.address,
            },
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash, mirrorValue } =
            await createMirrorAcceptOfferOrder(
              buyer,
              zone,
              order,
              [],
              conduitKeyOne
            );

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const { standardExecutions, batchExecutions } =
            await simulateMatchOrders(
              [order, mirrorOrder],
              fulfillments,
              owner,
              value
            );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: constants.AddressZero }],
              standardExecutions,
              batchExecutions
            );
            await checkExpectedEvents(
              receipt,
              [
                {
                  order: mirrorOrder,
                  orderHash: mirrorOrderHash,
                  fulfiller: constants.AddressZero,
                },
              ],
              standardExecutions,
              batchExecutions
            );
            return receipt;
          });
        });
      });
    });
  });

  describe("Validate, cancel, and increment nonce flows", async () => {
    let seller;
    let buyer;

    beforeEach(async () => {
      // Setup basic buyer/seller wallets with ETH
      seller = ethers.Wallet.createRandom().connect(provider);
      buyer = ethers.Wallet.createRandom().connect(provider);
      zone = ethers.Wallet.createRandom().connect(provider);
      await Promise.all(
        [seller, buyer, zone].map((wallet) => faucet(wallet.address, provider))
      );
    });

    describe("Validate", async () => {
      it("Validate signed order and fill it with no signature", async () => {
        // Seller mints an nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const signature = order.signature;

        const initialStatus = await marketplaceContract.getOrderStatus(
          orderHash
        );
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;

        // cannot fill it with no signature yet
        order.signature = "0x";
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("InvalidSigner");
        });

        // cannot validate it with no signature from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract.connect(owner).validate([order])
          ).to.be.revertedWith("InvalidSigner");
        });

        // can validate it once you add the signature back
        order.signature = signature;
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, zone.address);
        });

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(newStatus.isValidated).to.be.true;
        expect(newStatus.isCancelled).to.be.false;
        expect(newStatus.totalFilled.toString()).to.equal("0");
        expect(newStatus.totalSize.toString()).to.equal("0");

        // Can validate it repeatedly, but no event after the first time
        await whileImpersonating(owner.address, provider, async () => {
          await marketplaceContract.connect(owner).validate([order, order]);
        });

        // Fulfill the order without a signature
        order.signature = "0x";
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              { order, orderHash, fulfiller: buyer.address },
            ]);
            return receipt;
          });
        });

        const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(finalStatus.isValidated).to.be.true;
        expect(finalStatus.isCancelled).to.be.false;
        expect(finalStatus.totalFilled.toString()).to.equal("1");
        expect(finalStatus.totalSize.toString()).to.equal("1");

        // cannot validate it once it's been fully filled
        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract.connect(owner).validate([order])
          ).to.be.revertedWith("OrderAlreadyFilled", orderHash);
        });
      });
      it("Validate unsigned order from offerer and fill it with no signature", async () => {
        // Seller mints an nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        order.signature = "0x";

        const initialStatus = await marketplaceContract.getOrderStatus(
          orderHash
        );
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;

        // cannot fill it with no signature yet
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("InvalidSigner");
        });

        // cannot validate it with no signature from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract.connect(owner).validate([order])
          ).to.be.revertedWith("InvalidSigner");
        });

        // can validate it from the seller
        await whileImpersonating(seller.address, provider, async () => {
          await expect(marketplaceContract.connect(seller).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, zone.address);
        });

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(newStatus.isValidated).to.be.true;
        expect(newStatus.isCancelled).to.be.false;
        expect(newStatus.totalFilled.toString()).to.equal("0");
        expect(newStatus.totalSize.toString()).to.equal("0");

        // Fulfill the order without a signature
        order.signature = "0x";
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              { order, orderHash, fulfiller: buyer.address },
            ]);
            return receipt;
          });
        });

        const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(finalStatus.isValidated).to.be.true;
        expect(finalStatus.isCancelled).to.be.false;
        expect(finalStatus.totalFilled.toString()).to.equal("1");
        expect(finalStatus.totalSize.toString()).to.equal("1");
      });
      it("Cannot validate a cancelled order", async () => {
        // Seller mints an nft
        const nftId = ethers.BigNumber.from(randomHex());

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const signature = order.signature;

        order.signature = "0x";

        const initialStatus = await marketplaceContract.getOrderStatus(
          orderHash
        );
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;

        // cannot fill it with no signature yet
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("InvalidSigner");
        });

        // cannot validate it with no signature from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract.connect(owner).validate([order])
          ).to.be.revertedWith("InvalidSigner");
        });

        // can cancel it
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            marketplaceContract.connect(seller).cancel([orderComponents])
          )
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHash, seller.address, zone.address);
        });

        // cannot validate it from the seller
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            marketplaceContract.connect(seller).validate([order])
          ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);
        });

        // cannot validate it with a signature either
        order.signature = signature;
        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract.connect(owner).validate([order])
          ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);
        });

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(newStatus.isValidated).to.be.false;
        expect(newStatus.isCancelled).to.be.true;
        expect(newStatus.totalFilled.toString()).to.equal("0");
        expect(newStatus.totalSize.toString()).to.equal("0");
      });
    });

    describe("Cancel", async () => {
      it("Can cancel an order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // cannot cancel it from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract.connect(owner).cancel([orderComponents])
          ).to.be.revertedWith("InvalidCanceller");
        });

        const initialStatus = await marketplaceContract.getOrderStatus(
          orderHash
        );
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;
        expect(initialStatus.totalFilled.toString()).to.equal("0");
        expect(initialStatus.totalSize.toString()).to.equal("0");

        // can cancel it
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            marketplaceContract.connect(seller).cancel([orderComponents])
          )
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHash, seller.address, zone.address);
        });

        // cannot fill the order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);
        });

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(newStatus.isValidated).to.be.false;
        expect(newStatus.isCancelled).to.be.true;
        expect(newStatus.totalFilled.toString()).to.equal("0");
        expect(newStatus.totalSize.toString()).to.equal("0");
      });
      it("Can cancel a validated order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // cannot cancel it from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract.connect(owner).cancel([orderComponents])
          ).to.be.revertedWith("InvalidCanceller");
        });

        const initialStatus = await marketplaceContract.getOrderStatus(
          orderHash
        );
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;
        expect(initialStatus.totalFilled.toString()).to.equal("0");
        expect(initialStatus.totalSize.toString()).to.equal("0");

        // Can validate it
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, zone.address);
        });

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(newStatus.isValidated).to.be.true;
        expect(newStatus.isCancelled).to.be.false;
        expect(newStatus.totalFilled.toString()).to.equal("0");
        expect(newStatus.totalSize.toString()).to.equal("0");

        // can cancel it
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            marketplaceContract.connect(seller).cancel([orderComponents])
          )
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHash, seller.address, zone.address);
        });

        // cannot fill the order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);
        });

        const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(finalStatus.isValidated).to.be.false;
        expect(finalStatus.isCancelled).to.be.true;
        expect(finalStatus.totalFilled.toString()).to.equal("0");
        expect(finalStatus.totalSize.toString()).to.equal("0");
      });
      it("Can cancel an order from the zone", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // cannot cancel it from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract.connect(owner).cancel([orderComponents])
          ).to.be.revertedWith("InvalidCanceller");
        });

        const initialStatus = await marketplaceContract.getOrderStatus(
          orderHash
        );
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;
        expect(initialStatus.totalFilled.toString()).to.equal("0");
        expect(initialStatus.totalSize.toString()).to.equal("0");

        // can cancel it from the zone
        await whileImpersonating(zone.address, provider, async () => {
          await expect(
            marketplaceContract.connect(zone).cancel([orderComponents])
          )
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHash, seller.address, zone.address);
        });

        // cannot fill the order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);
        });

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(newStatus.isValidated).to.be.false;
        expect(newStatus.isCancelled).to.be.true;
        expect(newStatus.totalFilled.toString()).to.equal("0");
        expect(newStatus.totalSize.toString()).to.equal("0");
      });
      it("Can cancel a validated order from a zone", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const initialStatus = await marketplaceContract.getOrderStatus(
          orderHash
        );
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;
        expect(initialStatus.totalFilled.toString()).to.equal("0");
        expect(initialStatus.totalSize.toString()).to.equal("0");

        // Can validate it
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, zone.address);
        });

        // cannot cancel it from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract.connect(owner).cancel([orderComponents])
          ).to.be.revertedWith("InvalidCanceller");
        });

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(newStatus.isValidated).to.be.true;
        expect(newStatus.isCancelled).to.be.false;
        expect(newStatus.totalFilled.toString()).to.equal("0");
        expect(newStatus.totalSize.toString()).to.equal("0");

        // can cancel it from the zone
        await whileImpersonating(zone.address, provider, async () => {
          await expect(
            marketplaceContract.connect(zone).cancel([orderComponents])
          )
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHash, seller.address, zone.address);
        });

        // cannot fill the order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);
        });

        const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(finalStatus.isValidated).to.be.false;
        expect(finalStatus.isCancelled).to.be.true;
        expect(finalStatus.totalFilled.toString()).to.equal("0");
        expect(finalStatus.totalSize.toString()).to.equal("0");
      });
      it.skip("Can cancel an order signed with a nonce ahead of the current nonce", async () => {});
    });

    describe("Increment Nonce", async () => {
      it("Can increment the nonce", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        let { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const nonce = await marketplaceContract.getNonce(seller.address);
        expect(nonce).to.equal(0);
        expect(orderComponents.nonce).to.equal(nonce);

        // can increment the nonce
        await whileImpersonating(seller.address, provider, async () => {
          await expect(marketplaceContract.connect(seller).incrementNonce())
            .to.emit(marketplaceContract, "NonceIncremented")
            .withArgs(1, seller.address);
        });

        const newNonce = await marketplaceContract.getNonce(seller.address);
        expect(newNonce).to.equal(1);

        // Cannot fill order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("InvalidSigner");
        });

        const newOrderDetails = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        order = newOrderDetails.order;
        orderHash = newOrderDetails.orderHash;
        value = newOrderDetails.value;
        orderComponents = newOrderDetails.orderComponents;

        expect(orderComponents.nonce).to.equal(newNonce);

        // Can fill order with new nonce
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              { order, orderHash, fulfiller: buyer.address },
            ]);
            return receipt;
          });
        });
      });
      it("Can increment the nonce and implicitly cancel a validated order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        let { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const nonce = await marketplaceContract.getNonce(seller.address);
        expect(nonce).to.equal(0);
        expect(orderComponents.nonce).to.equal(nonce);

        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, zone.address);
        });

        // can increment the nonce
        await whileImpersonating(seller.address, provider, async () => {
          await expect(marketplaceContract.connect(seller).incrementNonce())
            .to.emit(marketplaceContract, "NonceIncremented")
            .withArgs(1, seller.address);
        });

        const newNonce = await marketplaceContract.getNonce(seller.address);
        expect(newNonce).to.equal(1);

        // Cannot fill order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("InvalidSigner");
        });

        const newOrderDetails = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        order = newOrderDetails.order;
        orderHash = newOrderDetails.orderHash;
        value = newOrderDetails.value;
        orderComponents = newOrderDetails.orderComponents;

        expect(orderComponents.nonce).to.equal(newNonce);

        // Can fill order with new nonce
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              { order, orderHash, fulfiller: buyer.address },
            ]);
            return receipt;
          });
        });
      });
      it("Can increment the nonce as the zone and implicitly cancel a validated order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        let { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const nonce = await marketplaceContract.getNonce(seller.address);
        expect(nonce).to.equal(0);
        expect(orderComponents.nonce).to.equal(nonce);

        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, zone.address);
        });

        // can increment the nonce as the offerer
        await whileImpersonating(seller.address, provider, async () => {
          await expect(marketplaceContract.connect(seller).incrementNonce())
            .to.emit(marketplaceContract, "NonceIncremented")
            .withArgs(1, seller.address);
        });

        const newNonce = await marketplaceContract.getNonce(seller.address);
        expect(newNonce).to.equal(1);

        // Cannot fill order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("InvalidSigner");
        });

        const newOrderDetails = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        order = newOrderDetails.order;
        orderHash = newOrderDetails.orderHash;
        value = newOrderDetails.value;
        orderComponents = newOrderDetails.orderComponents;

        expect(orderComponents.nonce).to.equal(newNonce);

        // Can fill order with new nonce
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              { order, orderHash, fulfiller: buyer.address },
            ]);
            return receipt;
          });
        });
      });
      it.skip("Can increment nonce and activate an order signed with a nonce ahead of the current nonce", async () => {});
    });
  });

  describe("Advanced orders", async () => {
    let seller;
    let buyer;

    beforeEach(async () => {
      // Setup basic buyer/seller wallets with ETH
      seller = ethers.Wallet.createRandom().connect(provider);
      buyer = ethers.Wallet.createRandom().connect(provider);
      zone = ethers.Wallet.createRandom().connect(provider);
      await Promise.all(
        [seller, buyer, zone].map((wallet) => faucet(wallet.address, provider))
      );
    });

    describe("Partial fills", async () => {
      it("Partial fills (standard)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 2; // fill two tenths or one fifth
        order.denominator = 10; // fill two tenths or one fifth

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(2);
        expect(orderStatus.totalSize).to.equal(10);

        order.numerator = 1; // fill one half
        order.denominator = 2; // fill one half

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(14);
        expect(orderStatus.totalSize).to.equal(20);

        // Fill remaining; only 3/10ths will be fillable
        order.numerator = 1; // fill one half
        order.denominator = 2; // fill one half

        const ordersClone = JSON.parse(JSON.stringify([order]));
        for (const [i, clonedOrder] of Object.entries(ordersClone)) {
          clonedOrder.parameters.startTime = order.parameters.startTime;
          clonedOrder.parameters.endTime = order.parameters.endTime;

          for (const [j, offerItem] of Object.entries(
            clonedOrder.parameters.offer
          )) {
            offerItem.startAmount = order.parameters.offer[j].startAmount;
            offerItem.endAmount = order.parameters.offer[j].endAmount;
          }

          for (const [j, considerationItem] of Object.entries(
            clonedOrder.parameters.consideration
          )) {
            considerationItem.startAmount =
              order.parameters.consideration[j].startAmount;
            considerationItem.endAmount =
              order.parameters.consideration[j].endAmount;
          }
        }

        ordersClone[0].numerator = 3;
        ordersClone[0].denominator = 10;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(ordersClone, 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order: ordersClone[0], orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(40);
        expect(orderStatus.totalSize).to.equal(40);
      });
      it("Partial fills (standard, additional permutations)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 2; // fill two tenths or one fifth
        order.denominator = 10; // fill two tenths or one fifth

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(2);
        expect(orderStatus.totalSize).to.equal(10);

        order.numerator = 1; // fill one tenth
        order.denominator = 10; // fill one tenth

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(3);
        expect(orderStatus.totalSize).to.equal(10);

        // Fill all available; only 7/10ths will be fillable
        order.numerator = 1; // fill all available
        order.denominator = 1; // fill all available

        const ordersClone = JSON.parse(JSON.stringify([order]));
        for (const [i, clonedOrder] of Object.entries(ordersClone)) {
          clonedOrder.parameters.startTime = order.parameters.startTime;
          clonedOrder.parameters.endTime = order.parameters.endTime;

          for (const [j, offerItem] of Object.entries(
            clonedOrder.parameters.offer
          )) {
            offerItem.startAmount = order.parameters.offer[j].startAmount;
            offerItem.endAmount = order.parameters.offer[j].endAmount;
          }

          for (const [j, considerationItem] of Object.entries(
            clonedOrder.parameters.consideration
          )) {
            considerationItem.startAmount =
              order.parameters.consideration[j].startAmount;
            considerationItem.endAmount =
              order.parameters.consideration[j].endAmount;
          }
        }

        ordersClone[0].numerator = 7;
        ordersClone[0].denominator = 10;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(ordersClone, 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order: ordersClone[0], orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(10);
        expect(orderStatus.totalSize).to.equal(10);
      });
      it.skip("Partial fills (match)", async () => {});
    });

    describe("Criteria-based orders", async () => {
      it("Criteria-based offer item (standard)", async () => {
        // Seller mints nfts
        const nftId = ethers.BigNumber.from(randomHex());
        const secondNFTId = ethers.BigNumber.from(randomHex());
        const thirdNFTId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [
          {
            itemType: 4, // ERC721WithCriteria
            token: testERC721.address,
            identifierOrCriteria: root,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, criteriaResolvers, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              criteriaResolvers
            );
            return receipt;
          });
        });
      });
      it("Criteria-based offer item (match)", async () => {
        // Seller mints nfts
        const nftId = ethers.BigNumber.from(randomHex());
        const secondNFTId = ethers.BigNumber.from(randomHex());
        const thirdNFTId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [
          {
            itemType: 4, // ERC721WithCriteria
            token: testERC721.address,
            identifierOrCriteria: root,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            criteriaResolvers
          );

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 2,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateAdvancedMatchOrders(
            [order, mirrorOrder],
            criteriaResolvers,
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [order, mirrorOrder],
              criteriaResolvers,
              fulfillments,
              { value }
            );
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions,
            criteriaResolvers
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("Criteria-based consideration item (standard)", async () => {
        // buyer mints nfts
        const nftId = ethers.BigNumber.from(randomHex());
        const secondNFTId = ethers.BigNumber.from(randomHex());
        const thirdNFTId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(buyer.address, nftId);
        await testERC721.mint(buyer.address, secondNFTId);
        await testERC721.mint(buyer.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC721
              .connect(buyer)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(buyer.address, marketplaceContract.address, true);
        });

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("10"),
            endAmount: ethers.utils.parseEther("10"),
          },
        ];

        const consideration = [
          {
            itemType: 4, // ERC721WithCriteria
            token: testERC721.address,
            identifierOrCriteria: root,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
            recipient: seller.address,
          },
        ];

        const criteriaResolvers = [
          {
            orderIndex: 0,
            side: 1, // consideration
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [order],
            value.mul(-1),
            criteriaResolvers,
            async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                  value,
                });
              const receipt = await tx.wait();
              await checkExpectedEvents(
                receipt,
                [{ order, orderHash, fulfiller: buyer.address }],
                null,
                null,
                criteriaResolvers
              );
              return receipt;
            }
          );
        });
      });
      it("Criteria-based wildcard consideration item (standard)", async () => {
        // buyer mints nft
        const nftId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(buyer.address, nftId);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC721
              .connect(buyer)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(buyer.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("10"),
            endAmount: ethers.utils.parseEther("10"),
          },
        ];

        const consideration = [
          {
            itemType: 4, // ERC721WithCriteria
            token: testERC721.address,
            identifierOrCriteria: ethers.constants.HashZero,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
            recipient: seller.address,
          },
        ];

        const criteriaResolvers = [
          {
            orderIndex: 0,
            side: 1, // consideration
            index: 0,
            identifier: nftId,
            criteriaProof: [],
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [order],
            value.mul(-1),
            criteriaResolvers,
            async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                  value,
                });
              const receipt = await tx.wait();
              await checkExpectedEvents(
                receipt,
                [{ order, orderHash, fulfiller: buyer.address }],
                null,
                null,
                criteriaResolvers
              );
              return receipt;
            }
          );
        });
      });
      it.skip("Criteria-based consideration item (match)", async () => {});
    });

    describe("Ascending / Descending amounts", async () => {
      it("Ascending offer amount (standard)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const startAmount = ethers.BigNumber.from(randomHex().slice(0, 5));
        const endAmount = startAmount.mul(2);
        await testERC1155.mint(seller.address, nftId, endAmount.mul(10));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount,
            endAmount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it("Ascending consideration amount (standard)", async () => {
        // Seller mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge());
        await testERC20.mint(seller.address, tokenAmount);

        // Seller approves marketplace contract to transfer tokens
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC20
              .connect(seller)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(seller.address, marketplaceContract.address, tokenAmount);
        });

        // Buyer mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const startAmount = ethers.BigNumber.from(randomHex().slice(0, 5));
        const endAmount = startAmount.mul(2);
        await testERC1155.mint(buyer.address, nftId, endAmount.mul(10));

        // Buyer approves marketplace contract to transfer NFTs
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC1155
              .connect(buyer)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(buyer.address, marketplaceContract.address, true);
        });

        // Buyer needs to approve marketplace to transfer ERC20 tokens too (as it's a standard fulfillment)
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        });

        const offer = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ERC20
            startAmount: tokenAmount,
            endAmount: tokenAmount,
          },
        ];

        const consideration = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount,
            endAmount,
            recipient: seller.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ERC20
            startAmount: ethers.BigNumber.from(50),
            endAmount: ethers.BigNumber.from(50),
            recipient: zone.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ERC20
            startAmount: ethers.BigNumber.from(50),
            endAmount: ethers.BigNumber.from(50),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it("Ascending offer amount (match)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const startAmount = ethers.BigNumber.from(randomHex().slice(0, 5));
        const endAmount = startAmount.mul(2);
        await testERC1155.mint(seller.address, nftId, endAmount.mul(10));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount,
            endAmount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = defaultBuyNowMirrorFulfillment;

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it.skip("Ascending consideration amount (match)", async () => {});
      it.skip("Ascending amount + partial fill (standard)", async () => {});
      it.skip("Ascending amount + partial fill (match)", async () => {});
      it.skip("Descending offer amount (standard)", async () => {});
      it.skip("Descending consideration amount (standard)", async () => {});
      it.skip("Descending offer amount (match)", async () => {});
      it.skip("Descending consideration amount (match)", async () => {});
      it.skip("Descending amount + partial fill (standard)", async () => {});
      it.skip("Descending amount + partial fill (match)", async () => {});
    });

    describe("Sequenced Orders", async () => {
      it("Match A => B => C => A", async () => {
        // Everybody mints an NFT
        const nftId = ethers.BigNumber.from(randomHex());
        const secondNFTId = ethers.BigNumber.from(randomHex());
        const thirdNFTId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(buyer.address, secondNFTId);
        await testERC721.mint(owner.address, thirdNFTId);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer approves marketplace contract to transfer NFTs
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC721
              .connect(buyer)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(buyer.address, marketplaceContract.address, true);
        });

        // Owner approves marketplace contract to transfer NFTs
        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            testERC721
              .connect(owner)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(owner.address, marketplaceContract.address, true);
        });

        const offerOne = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const considerationOne = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: secondNFTId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
            recipient: seller.address,
          },
        ];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value: valueOne,
        } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0 // FULL_OPEN
        );

        const offerTwo = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: secondNFTId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const considerationTwo = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: thirdNFTId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
            recipient: buyer.address,
          },
        ];

        const {
          order: orderTwo,
          orderHash: orderHashTwo,
          value: valueTwo,
        } = await createOrder(
          buyer,
          zone,
          offerTwo,
          considerationTwo,
          0 // FULL_OPEN
        );

        const offerThree = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: thirdNFTId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const considerationThree = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
            recipient: owner.address,
          },
        ];

        const {
          order: orderThree,
          orderHash: orderHashThree,
          value: valueThree,
        } = await createOrder(
          owner,
          zone,
          offerThree,
          considerationThree,
          0 // FULL_OPEN
        );

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 2,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 2,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateAdvancedMatchOrders(
            [orderOne, orderTwo, orderThree],
            [], // no criteria resolvers
            fulfillments,
            owner,
            0 // no value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(fulfillments.length);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [orderOne, orderTwo, orderThree],
              [],
              fulfillments,
              { value: 0 }
            );
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderTwo,
                orderHash: orderHashTwo,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderThree,
                orderHash: orderHashThree,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("Match with fewer executions when one party has multiple orders that coincide", async () => {
        // Seller and buyer both mint an NFT
        const nftId = ethers.BigNumber.from(randomHex());
        const secondNFTId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(buyer.address, secondNFTId);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer approves marketplace contract to transfer NFTs
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC721
              .connect(buyer)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(buyer.address, marketplaceContract.address, true);
        });

        const offerOne = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const considerationOne = [getItemETH(10, 10, seller.address)];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value: valueOne,
        } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0 // FULL_OPEN
        );

        const offerTwo = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("10"),
            endAmount: ethers.utils.parseEther("10"),
          },
        ];

        const considerationTwo = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: secondNFTId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
            recipient: seller.address,
          },
        ];

        const {
          order: orderTwo,
          orderHash: orderHashTwo,
          value: valueTwo,
        } = await createOrder(
          seller,
          zone,
          offerTwo,
          considerationTwo,
          0 // FULL_OPEN
        );

        const offerThree = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: secondNFTId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const considerationThree = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
            recipient: buyer.address,
          },
        ];

        const {
          order: orderThree,
          orderHash: orderHashThree,
          value: valueThree,
        } = await createOrder(
          buyer,
          zone,
          offerThree,
          considerationThree,
          0 // FULL_OPEN
        );

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 2,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 2,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateAdvancedMatchOrders(
            [orderOne, orderTwo, orderThree],
            [], // no criteria resolvers
            fulfillments,
            owner,
            0 // no value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(fulfillments.length - 1);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [orderOne, orderTwo, orderThree],
              [],
              fulfillments,
              { value: 0 }
            );
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderTwo,
                orderHash: orderHashTwo,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderThree,
                orderHash: orderHashThree,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
    });

    describe("Order groups", async () => {
      it("Multiple offer components at once", async () => {
        // Seller mints NFTs
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount.mul(2));

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20s
        const tokenAmount = ethers.BigNumber.from(randomLarge());
        await testERC20.mint(buyer.address, tokenAmount.mul(2));

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount.mul(2))
          )
            .to.emit(testERC20, "Approval")
            .withArgs(
              buyer.address,
              marketplaceContract.address,
              tokenAmount.mul(2)
            );
        });

        const offerOne = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const considerationOne = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: tokenAmount,
            endAmount: tokenAmount,
            recipient: seller.address,
          },
        ];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value: valueOne,
        } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0 // FULL_OPEN
        );

        const offerTwo = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const considerationTwo = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: tokenAmount,
            endAmount: tokenAmount,
            recipient: seller.address,
          },
        ];

        const {
          order: orderTwo,
          orderHash: orderHashTwo,
          value: valueTwo,
        } = await createOrder(
          seller,
          zone,
          offerTwo,
          considerationTwo,
          0 // FULL_OPEN
        );

        const offerThree = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: tokenAmount.mul(2),
            endAmount: tokenAmount.mul(2),
          },
        ];

        const considerationThree = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(2),
            endAmount: amount.mul(2),
            recipient: buyer.address,
          },
        ];

        const {
          order: orderThree,
          orderHash: orderHashThree,
          value: valueThree,
        } = await createOrder(
          buyer,
          zone,
          offerThree,
          considerationThree,
          0 // FULL_OPEN
        );

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 2,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 2,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 2,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateAdvancedMatchOrders(
            [orderOne, orderTwo, orderThree],
            [], // no criteria resolvers
            fulfillments,
            owner,
            0 // no value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(fulfillments.length);

        await whileImpersonating(buyer.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(buyer)
            .matchAdvancedOrders(
              [orderOne, orderTwo, orderThree],
              [],
              fulfillments,
              { value: 0 }
            );
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions,
            [],
            true
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderTwo,
                orderHash: orderHashTwo,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions,
            [],
            true
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderThree,
                orderHash: orderHashThree,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );

          expect(
            ethers.BigNumber.from(
              "0x" + receipt.events[3].data.slice(66)
            ).toString()
          ).to.equal(amount.mul(2).toString());

          return receipt;
        });
      });
      it("Multiple consideration components at once", async () => {
        // Seller mints NFTs
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount.mul(2));

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20s
        const tokenAmount = ethers.BigNumber.from(randomLarge());
        await testERC20.mint(buyer.address, tokenAmount.mul(2));

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount.mul(2))
          )
            .to.emit(testERC20, "Approval")
            .withArgs(
              buyer.address,
              marketplaceContract.address,
              tokenAmount.mul(2)
            );
        });

        const offerOne = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(2),
            endAmount: amount.mul(2),
          },
        ];

        const considerationOne = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: tokenAmount.mul(2),
            endAmount: tokenAmount.mul(2),
            recipient: seller.address,
          },
        ];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value: valueOne,
        } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0 // FULL_OPEN
        );

        const offerTwo = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: tokenAmount,
            endAmount: tokenAmount,
          },
        ];

        const considerationTwo = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
            recipient: buyer.address,
          },
        ];

        const {
          order: orderTwo,
          orderHash: orderHashTwo,
          value: valueTwo,
        } = await createOrder(
          buyer,
          zone,
          offerTwo,
          considerationTwo,
          0 // FULL_OPEN
        );

        const offerThree = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: tokenAmount,
            endAmount: tokenAmount,
          },
        ];

        const considerationThree = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
            recipient: buyer.address,
          },
        ];

        const {
          order: orderThree,
          orderHash: orderHashThree,
          value: valueThree,
        } = await createOrder(
          buyer,
          zone,
          offerThree,
          considerationThree,
          0 // FULL_OPEN
        );

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
              {
                orderIndex: 2,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 2,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateAdvancedMatchOrders(
            [orderOne, orderTwo, orderThree],
            [], // no criteria resolvers
            fulfillments,
            owner,
            0 // no value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(fulfillments.length);

        await whileImpersonating(buyer.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(buyer)
            .matchAdvancedOrders(
              [orderOne, orderTwo, orderThree],
              [],
              fulfillments,
              { value: 0 }
            );
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderTwo,
                orderHash: orderHashTwo,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions,
            [],
            true
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: orderThree,
                orderHash: orderHashThree,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions,
            [],
            true
          );

          // TODO: inlcude balance checks on the duplicate ERC20 transfers

          return receipt;
        });
      });
    });

    describe("ERC1155 batch transfers", async () => {
      it("ERC1155 <=> ETH (match)", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, secondNftId, secondAmount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: secondNftId,
            startAmount: secondAmount,
            endAmount: secondAmount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(1);
        expect(standardExecutions.length).to.equal(3);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match, three items)", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, secondNftId, secondAmount);

        // Seller mints third nft
        const thirdNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const thirdAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, thirdNftId, thirdAmount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: secondNftId,
            startAmount: secondAmount,
            endAmount: secondAmount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: thirdNftId,
            startAmount: thirdAmount,
            endAmount: thirdAmount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 2,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(1);
        expect(standardExecutions.length).to.equal(3);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match via conduit)", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, secondNftId, secondAmount);

        // Seller approves conduit contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(conduitOne.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, conduitOne.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: secondNftId,
            startAmount: secondAmount,
            endAmount: secondAmount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          constants.HashZero,
          conduitKeyOne
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(1);
        expect(standardExecutions.length).to.equal(3);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match, single item)", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, secondNftId, secondAmount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const consideration = [];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(1);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match, single 1155)", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, secondNftId, secondAmount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match, two different 1155 contracts)", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155Two
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155Two, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155Two.address,
            identifierOrCriteria: secondNftId,
            startAmount: secondAmount,
            endAmount: secondAmount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(5);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          // TODO: check events (need to account for second 1155 token)
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match, on single and one batch of 1155's)", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

        // Seller mints third nft
        const thirdNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const thirdAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, thirdNftId, thirdAmount);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155Two
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155Two, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155Two.address,
            identifierOrCriteria: secondNftId,
            startAmount: secondAmount,
            endAmount: secondAmount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: thirdNftId,
            startAmount: thirdAmount,
            endAmount: thirdAmount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 2,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(1);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          // TODO: check events (need to account for second 1155 token)
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match, two different batches of 1155's)", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

        // Seller mints third nft
        const thirdNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const thirdAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, thirdNftId, thirdAmount);

        // Seller mints fourth nft
        const fourthNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const fourthAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155Two.mint(seller.address, fourthNftId, fourthAmount);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155Two
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155Two, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155Two.address,
            identifierOrCriteria: secondNftId,
            startAmount: secondAmount,
            endAmount: secondAmount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: thirdNftId,
            startAmount: thirdAmount,
            endAmount: thirdAmount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155Two.address,
            identifierOrCriteria: fourthNftId,
            startAmount: fourthAmount,
            endAmount: fourthAmount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 2,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 3,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 3,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(2);
        expect(standardExecutions.length).to.equal(3);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          // TODO: check events (need to account for second 1155 token)
          return receipt;
        });
      });
    });

    describe("Fulfill Available Orders", async () => {
      it("Can fulfill a single order via fulfillAvailableOrders", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAvailableOrders(
                [order],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value }
              );
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              { order, orderHash, fulfiller: buyer.address },
            ]);
            return receipt;
          });
        });
      });
      it("Can fulfill a single order via fulfillAvailableAdvancedOrders", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAvailableAdvancedOrders(
                [order],
                [],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value }
              );
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              { order, orderHash, fulfiller: buyer.address },
            ]);
            return receipt;
          });
        });
      });
      it("Can fulfill and aggregate multiple orders via fulfillAvailableOrders", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10)).mul(2);
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.div(2),
            endAmount: amount.div(2),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
            {
              orderIndex: 1,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
            {
              orderIndex: 1,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [orderOne, orderTwo],
            0,
            null,
            async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillAvailableOrders(
                  [orderOne, orderTwo],
                  offerComponents,
                  considerationComponents,
                  toKey(false),
                  100,
                  { value: value.mul(2) }
                );
              const receipt = await tx.wait();
              await checkExpectedEvents(
                receipt,
                [
                  {
                    order: orderOne,
                    orderHash: orderHashOne,
                    fulfiller: buyer.address,
                  },
                ],
                [],
                [],
                [],
                false,
                2
              );
              await checkExpectedEvents(
                receipt,
                [
                  {
                    order: orderTwo,
                    orderHash: orderHashTwo,
                    fulfiller: buyer.address,
                  },
                ],
                [],
                [],
                [],
                false,
                2
              );
              return receipt;
            },
            2
          );
        });
      });
      it("Can fulfill and aggregate multiple orders via fulfillAvailableAdvancedOrders", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10)).mul(2);
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.div(2),
            endAmount: amount.div(2),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
            {
              orderIndex: 1,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
            {
              orderIndex: 1,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [orderOne, orderTwo],
            0,
            null,
            async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillAvailableAdvancedOrders(
                  [orderOne, orderTwo],
                  [],
                  offerComponents,
                  considerationComponents,
                  toKey(false),
                  100,
                  { value: value.mul(2) }
                );
              const receipt = await tx.wait();
              await checkExpectedEvents(
                receipt,
                [
                  {
                    order: orderOne,
                    orderHash: orderHashOne,
                    fulfiller: buyer.address,
                  },
                ],
                [],
                [],
                [],
                false,
                2
              );
              await checkExpectedEvents(
                receipt,
                [
                  {
                    order: orderTwo,
                    orderHash: orderHashTwo,
                    fulfiller: buyer.address,
                  },
                ],
                [],
                [],
                [],
                false,
                2
              );
              return receipt;
            },
            2
          );
        });
      });
      it("Can fulfill and aggregate a max number of multiple orders via fulfillAvailableOrders", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10)).mul(2);
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.div(2),
            endAmount: amount.div(2),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
            {
              orderIndex: 1,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
            {
              orderIndex: 1,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [orderOne],
            0,
            null,
            async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillAvailableOrders(
                  [orderOne, orderTwo],
                  offerComponents,
                  considerationComponents,
                  toKey(false),
                  1,
                  { value: value.mul(2) }
                );
              const receipt = await tx.wait();
              await checkExpectedEvents(
                receipt,
                [
                  {
                    order: orderOne,
                    orderHash: orderHashOne,
                    fulfiller: buyer.address,
                  },
                ],
                [],
                [],
                [],
                false,
                1
              );
              return receipt;
            },
            1
          );
        });
      });
      it("Can fulfill and aggregate a max number of multiple orders via fulfillAvailableAdvancedOrders", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10)).mul(2);
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.div(2),
            endAmount: amount.div(2),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
            {
              orderIndex: 1,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
            {
              orderIndex: 1,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [orderOne],
            0,
            null,
            async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillAvailableAdvancedOrders(
                  [orderOne, orderTwo],
                  [],
                  offerComponents,
                  considerationComponents,
                  toKey(false),
                  1,
                  { value: value.mul(2) }
                );
              const receipt = await tx.wait();
              await checkExpectedEvents(
                receipt,
                [
                  {
                    order: orderOne,
                    orderHash: orderHashOne,
                    fulfiller: buyer.address,
                  },
                ],
                [],
                [],
                [],
                false,
                1
              );
              return receipt;
            },
            1
          );
        });
      });
      it("Can fulfill and aggregate multiple orders via fulfillAvailableOrders with failing orders", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10)).mul(2);
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.div(2),
            endAmount: amount.div(2),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // second order is expired
        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "EXPIRED"
        );

        // third order will be cancelled
        const {
          order: orderThree,
          orderHash: orderHashThree,
          orderComponents,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // can cancel it
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            marketplaceContract.connect(seller).cancel([orderComponents])
          )
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHashThree, seller.address, zone.address);
        });

        // fourth order will be filled
        const { order: orderFour, orderHash: orderHashFour } =
          await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

        // can fill it
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([orderFour], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillOrder(orderFour, toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              {
                order: orderFour,
                orderHash: orderHashFour,
                fulfiller: buyer.address,
              },
            ]);
            return receipt;
          });
        });

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
            {
              orderIndex: 2,
              itemIndex: 0,
            },
            {
              orderIndex: 3,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
            {
              orderIndex: 2,
              itemIndex: 0,
            },
            {
              orderIndex: 3,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
            {
              orderIndex: 1,
              itemIndex: 1,
            },
            {
              orderIndex: 2,
              itemIndex: 1,
            },
            {
              orderIndex: 3,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
            {
              orderIndex: 1,
              itemIndex: 2,
            },
            {
              orderIndex: 2,
              itemIndex: 2,
            },
            {
              orderIndex: 3,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([orderOne], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAvailableOrders(
                [orderOne, orderTwo, orderThree, orderFour],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value: value.mul(4) }
              );
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: buyer.address,
              },
            ]);
            return receipt;
          });
        });
      });
      it("Can fulfill and aggregate multiple orders via fulfillAvailableAdvancedOrders with failing orders", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10)).mul(2);
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.div(2),
            endAmount: amount.div(2),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // second order is expired
        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "EXPIRED"
        );

        // third order will be cancelled
        const {
          order: orderThree,
          orderHash: orderHashThree,
          orderComponents,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // can cancel it
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            marketplaceContract.connect(seller).cancel([orderComponents])
          )
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHashThree, seller.address, zone.address);
        });

        // fourth order will be filled
        const { order: orderFour, orderHash: orderHashFour } =
          await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

        // can fill it
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([orderFour], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillOrder(orderFour, toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              {
                order: orderFour,
                orderHash: orderHashFour,
                fulfiller: buyer.address,
              },
            ]);
            return receipt;
          });
        });

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
            {
              orderIndex: 2,
              itemIndex: 0,
            },
            {
              orderIndex: 3,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
            {
              orderIndex: 2,
              itemIndex: 0,
            },
            {
              orderIndex: 3,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
            {
              orderIndex: 1,
              itemIndex: 1,
            },
            {
              orderIndex: 2,
              itemIndex: 1,
            },
            {
              orderIndex: 3,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
            {
              orderIndex: 1,
              itemIndex: 2,
            },
            {
              orderIndex: 2,
              itemIndex: 2,
            },
            {
              orderIndex: 3,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([orderOne], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAvailableAdvancedOrders(
                [orderOne, orderTwo, orderThree, orderFour],
                [],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value: value.mul(4) }
              );
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: buyer.address,
              },
            ]);
            return receipt;
          });
        });
      });
      it("Can fulfill and aggregate multiple orders via fulfillAvailableAdvancedOrders with failing components including criteria", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, secondNftId, secondAmount);

        // Seller mints nfts for criteria-based item
        const criteriaNftId = ethers.BigNumber.from(randomHex());
        const secondCriteriaNFTId = ethers.BigNumber.from(randomHex());
        const thirdCriteriaNFTId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(seller.address, criteriaNftId);
        await testERC721.mint(seller.address, secondCriteriaNFTId);
        await testERC721.mint(seller.address, thirdCriteriaNFTId);

        const tokenIds = [
          criteriaNftId,
          secondCriteriaNFTId,
          thirdCriteriaNFTId,
        ];

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const { root, proofs } = merkleTree(tokenIds);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const offerTwo = [
          {
            itemType: 4, // ERC721WithCriteria
            token: testERC721.address,
            identifierOrCriteria: root,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        let criteriaResolvers = [
          {
            orderIndex: 1,
            side: 0, // offer
            index: 0,
            identifier: criteriaNftId,
            criteriaProof: proofs[criteriaNftId.toString()],
          },
        ];

        const {
          order: orderOne,
          orderHash: orderHashOne,
          value,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // second order is expired
        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          seller,
          zone,
          offerTwo,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers,
          "EXPIRED"
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 1,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
            {
              orderIndex: 1,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
            {
              orderIndex: 1,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([orderOne], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAvailableAdvancedOrders(
                [orderOne, orderTwo],
                criteriaResolvers,
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value: value.mul(2) }
              );
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: buyer.address,
              },
            ]);
            return receipt;
          });
        });
      });
    });
  });

  describe("Conduit tests", async () => {
    let seller;
    let buyer;
    let sellerContract;
    let buyerContract;

    beforeEach(async () => {
      // Setup basic buyer/seller wallets with ETH
      seller = ethers.Wallet.createRandom().connect(provider);
      buyer = ethers.Wallet.createRandom().connect(provider);
      zone = ethers.Wallet.createRandom().connect(provider);

      sellerContract = await EIP1271WalletFactory.deploy(seller.address);
      buyerContract = await EIP1271WalletFactory.deploy(buyer.address);

      await Promise.all(
        [seller, buyer, zone, sellerContract, buyerContract].map((wallet) =>
          faucet(wallet.address, provider)
        )
      );
    });

    it("Reverts when attempting to update a conduit channel when call is not from controller", async () => {
      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitOne.connect(owner).updateChannel(constants.AddressZero, true)
        ).to.be.revertedWith("InvalidController");
      });
    });

    it("Reverts when attempting to execute transfers on a conduit when not called from a channel", async () => {
      await whileImpersonating(owner.address, provider, async () => {
        await expect(conduitOne.connect(owner).execute([])).to.be.revertedWith(
          "ChannelClosed"
        );
      });
    });

    it("Reverts when attempting to execute with batch 1155 transfers on a conduit when not called from a channel", async () => {
      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitOne.connect(owner).executeWithBatch1155([], [])
        ).to.be.revertedWith("ChannelClosed");
      });
    });

    it("Retrieves the owner of a conduit", async () => {
      const ownerOf = await conduitController.ownerOf(conduitOne.address);
      expect(ownerOf).to.equal(owner.address);

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController.connect(owner).ownerOf(buyer.address)
        ).to.be.revertedWith("NoConduit");
      });
    });

    it("Retrieves the key of a conduit", async () => {
      const key = await conduitController.getKey(conduitOne.address);
      expect(key.toLowerCase()).to.equal(conduitKeyOne.toLowerCase());

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController.connect(owner).getKey(buyer.address)
        ).to.be.revertedWith("NoConduit");
      });
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

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController
            .connect(owner)
            .getChannelStatus(buyer.address, seller.address)
        ).to.be.revertedWith("NoConduit");
      });
    });

    it("Retrieves conduit channels from the controller", async () => {
      const totalChannels = await conduitController.getTotalChannels(
        conduitOne.address
      );
      expect(totalChannels).to.equal(1);

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController.connect(owner).getTotalChannels(buyer.address)
        ).to.be.revertedWith("NoConduit");
      });

      const firstChannel = await conduitController.getChannel(
        conduitOne.address,
        0
      );
      expect(firstChannel).to.equal(marketplaceContract.address);

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController
            .connect(owner)
            .getChannel(buyer.address, totalChannels - 1)
        ).to.be.revertedWith("NoConduit");
      });

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController.connect(owner).getChannel(conduitOne.address, 1)
        ).to.be.revertedWith("ChannelOutOfRange", conduitOne.address);
      });

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController.connect(owner).getChannel(conduitOne.address, 2)
        ).to.be.revertedWith("ChannelOutOfRange", conduitOne.address);
      });

      const channels = await conduitController.getChannels(conduitOne.address);
      expect(channels.length).to.equal(1);
      expect(channels[0]).to.equal(marketplaceContract.address);

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController.connect(owner).getChannels(buyer.address)
        ).to.be.revertedWith("NoConduit");
      });
    });

    it("Adds and removes channels", async () => {
      let isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        marketplaceContract.address
      );
      expect(isOpen).to.be.true;

      // No-op
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(conduitOne.address, marketplaceContract.address, true);
      });

      isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        marketplaceContract.address
      );
      expect(isOpen).to.be.true;

      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(conduitOne.address, seller.address, true);
      });

      isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        seller.address
      );
      expect(isOpen).to.be.true;

      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(
            conduitOne.address,
            marketplaceContract.address,
            false
          );
      });

      isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        marketplaceContract.address
      );
      expect(isOpen).to.be.false;

      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(conduitOne.address, seller.address, false);
      });

      isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        seller.address
      );
      expect(isOpen).to.be.false;

      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(conduitOne.address, marketplaceContract.address, true);
      });

      isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        marketplaceContract.address
      );
      expect(isOpen).to.be.true;
    });

    it("Reverts on an attempt to move an unsupported item", async () => {
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(conduitOne.address, seller.address, true);
      });

      let isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        seller.address
      );
      expect(isOpen).to.be.true;

      await whileImpersonating(seller.address, provider, async () => {
        await expect(
          conduitOne.connect(seller).executeWithBatch1155(
            [
              {
                itemType: 1, // ERC20
                token: testERC20.address,
                from: buyer.address,
                to: seller.address,
                identifier: 0,
                amount: 0,
              },
              {
                itemType: 0, // NATIVE (invalid)
                token: ethers.constants.AddressZero,
                from: conduitOne.address,
                to: seller.address,
                identifier: 0,
                amount: 1,
              },
            ],
            []
          )
        ).to.be.revertedWith("InvalidItemType");
      });
    });

    it("Reverts when attempting to create a conduit not scoped to the creator", async () => {
      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController
            .connect(owner)
            .createConduit(ethers.constants.HashZero, owner.address)
        ).to.be.revertedWith("InvalidCreator");
      });
    });

    it("Reverts when attempting to create a conduit that already exists", async () => {
      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController
            .connect(owner)
            .createConduit(conduitKeyOne, owner.address)
        ).to.be.revertedWith(`ConduitAlreadyExists("${conduitOne.address}")`);
      });
    });

    it("Reverts when attempting to update a channel for an unowned conduit", async () => {
      await whileImpersonating(buyer.address, provider, async () => {
        await expect(
          conduitController
            .connect(buyer)
            .updateChannel(conduitOne.address, buyer.address, true)
        ).to.be.revertedWith(`CallerIsNotOwner("${conduitOne.address}")`);
      });
    });

    it("Retrieves no initial potential owner for new conduit", async () => {
      const potentialOwner = await conduitController.getPotentialOwner(
        conduitOne.address
      );
      expect(potentialOwner).to.equal(ethers.constants.AddressZero);

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController.connect(owner).getPotentialOwner(buyer.address)
        ).to.be.revertedWith("NoConduit");
      });
    });

    it("Lets the owner transfer ownership via a two-stage process", async () => {
      await whileImpersonating(buyer.address, provider, async () => {
        await expect(
          conduitController
            .connect(buyer)
            .transferOwnership(conduitOne.address, buyer.address)
        ).to.be.revertedWith("CallerIsNotOwner", conduitOne.address);
      });

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController
            .connect(owner)
            .transferOwnership(conduitOne.address, ethers.constants.AddressZero)
        ).to.be.revertedWith(
          "NewPotentialOwnerIsZeroAddress",
          conduitOne.address
        );
      });

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController
            .connect(owner)
            .transferOwnership(seller.address, buyer.address)
        ).to.be.revertedWith("NoConduit");
      });

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

      await whileImpersonating(buyer.address, provider, async () => {
        await expect(
          conduitController
            .connect(buyer)
            .cancelOwnershipTransfer(conduitOne.address)
        ).to.be.revertedWith("CallerIsNotOwner", conduitOne.address);
      });

      await whileImpersonating(owner.address, provider, async () => {
        await expect(
          conduitController
            .connect(owner)
            .cancelOwnershipTransfer(seller.address)
        ).to.be.revertedWith("NoConduit");
      });

      await conduitController.cancelOwnershipTransfer(conduitOne.address);

      potentialOwner = await conduitController.getPotentialOwner(
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

      await whileImpersonating(buyer.address, provider, async () => {
        await expect(
          conduitController.connect(buyer).acceptOwnership(seller.address)
        ).to.be.revertedWith("NoConduit");
      });

      await whileImpersonating(seller.address, provider, async () => {
        await expect(
          conduitController.connect(seller).acceptOwnership(conduitOne.address)
        ).to.be.revertedWith(
          "CallerIsNotNewPotentialOwner",
          conduitOne.address
        );
      });

      await whileImpersonating(buyer.address, provider, async () => {
        await conduitController
          .connect(buyer)
          .acceptOwnership(conduitOne.address);
      });

      potentialOwner = await conduitController.getPotentialOwner(
        conduitOne.address
      );
      expect(potentialOwner).to.equal(ethers.constants.AddressZero);

      const ownerOf = await conduitController.ownerOf(conduitOne.address);
      expect(ownerOf).to.equal(buyer.address);
    });
  });

  describe("Reverts", async () => {
    let seller;
    let buyer;
    let sellerContract;
    let buyerContract;

    beforeEach(async () => {
      // Setup basic buyer/seller wallets with ETH
      seller = ethers.Wallet.createRandom().connect(provider);
      buyer = ethers.Wallet.createRandom().connect(provider);
      zone = ethers.Wallet.createRandom().connect(provider);

      sellerContract = await EIP1271WalletFactory.deploy(seller.address);
      buyerContract = await EIP1271WalletFactory.deploy(buyer.address);

      await Promise.all(
        [seller, buyer, zone, sellerContract, buyerContract].map((wallet) =>
          faucet(wallet.address, provider)
        )
      );
    });

    describe("Misconfigured orders", async () => {
      it("Reverts on bad fraction amounts", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 0;
        order.denominator = 10;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith("BadFraction");
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1;
        order.denominator = 0;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith("BadFraction");
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 2;
        order.denominator = 1;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith("BadFraction");
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1;
        order.denominator = 2;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(2);
      });
      it("Reverts on inexact fraction amounts", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1;
        order.denominator = 8191;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith("InexactFraction");
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1;
        order.denominator = 2;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(2);
      });
      it("Reverts on partial fill attempt when not supported by order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1;
        order.denominator = 2;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith("PartialFillsNotEnabledForOrder");
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1;
        order.denominator = 1;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it("Reverts on partially filled order via basic fulfillment", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1;
        order.denominator = 2;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(2);

        const basicOrderParameters = getBasicOrderParameters(
          1, // EthForERC1155
          order
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, { value })
          ).to.be.revertedWith(`OrderPartiallyFilled("${orderHash}")`);
        });
      });
      it("Reverts on fully filled order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1;
        order.denominator = 1;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith(`OrderAlreadyFilled("${orderHash}")`);
        });
      });
      it("Reverts on inadequate consideration items", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        // Remove a consideration item, but do not reduce
        // totalOriginalConsiderationItems as MissingOriginalConsiderationItems
        // is being tested for
        order.parameters.consideration.pop();

        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith("MissingOriginalConsiderationItems");
        });
      });
      it("Reverts on invalid submitter when required by order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          2 // FULL_RESTRICTED
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = defaultBuyNowMirrorFulfillment;

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            zone,
            value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
        });

        await whileImpersonating(zone.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(zone)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("Reverts on invalid signatures", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const originalSignature = order.signature;

        const originalV = order.signature.slice(-2);

        // set an invalid V value
        order.signature = order.signature.slice(0, -2) + "01";

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, { value })
          ).to.be.revertedWith("BadSignatureV(1)");
        });

        // construct an invalid signature
        basicOrderParameters.signature = "0x".padEnd(130, "f") + "1c";

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, { value })
          ).to.be.revertedWith("InvalidSignature");
        });

        basicOrderParameters.signature = originalSignature;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              { order, orderHash, fulfiller: buyer.address },
            ]);
            return receipt;
          });
        });
      });
      it("Reverts on invalid 1271 signature", async () => {
        // Seller mints nft to contract
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(sellerContract.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            sellerContract
              .connect(seller)
              .approveNFT(testERC721.address, marketplaceContract.address)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(
              sellerContract.address,
              marketplaceContract.address,
              true
            );
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ERC20
            startAmount: tokenAmount.sub(100),
            endAmount: tokenAmount.sub(100),
            recipient: sellerContract.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ERC20
            startAmount: ethers.BigNumber.from(40),
            endAmount: ethers.BigNumber.from(40),
            recipient: zone.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ERC20
            startAmount: ethers.BigNumber.from(60),
            endAmount: ethers.BigNumber.from(60),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          sellerContract,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          zone // wrong signer
        );

        const basicOrderParameters = getBasicOrderParameters(
          2, // ERC20ForERC721
          order
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters)
          ).to.be.revertedWith("BAD SIGNER");
        });
      });
      it("Reverts on invalid contract 1271 signature and contract does not supply a revert reason", async () => {
        await whileImpersonating(owner.address, provider, async () => {
          const tx = await sellerContract
            .connect(owner)
            .revertWithMessage(false);
          const receipt = await tx.wait();
        });

        // Seller mints nft to contract
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(sellerContract.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            sellerContract
              .connect(seller)
              .approveNFT(testERC721.address, marketplaceContract.address)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(
              sellerContract.address,
              marketplaceContract.address,
              true
            );
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ERC20
            startAmount: tokenAmount.sub(100),
            endAmount: tokenAmount.sub(100),
            recipient: sellerContract.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ERC20
            startAmount: ethers.BigNumber.from(50),
            endAmount: ethers.BigNumber.from(50),
            recipient: zone.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ERC20
            startAmount: ethers.BigNumber.from(50),
            endAmount: ethers.BigNumber.from(50),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          sellerContract,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          zone // wrong signer
        );

        const basicOrderParameters = getBasicOrderParameters(
          2, // ERC20ForERC721
          order
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters)
          ).to.be.revertedWith("BadContractSignature");
        });
      });
      it("Reverts on restricted order where isValidOrder reverts with no data", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          stubZone,
          offer,
          consideration,
          2, // FULL_RESTRICTED,
          [],
          null,
          seller,
          "0x".padEnd(65, "0") + "2"
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
        });
      });
      it("Reverts on missing offer or consideration components", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        let fulfillments = [
          {
            offerComponents: [],
            considerationComponents: [],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("OfferAndConsiderationRequiredOnFulfillment");
        });

        fulfillments = [
          {
            offerComponents: [],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("OfferAndConsiderationRequiredOnFulfillment");
        });

        fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("OfferAndConsiderationRequiredOnFulfillment");
        });

        fulfillments = defaultBuyNowMirrorFulfillment;

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("Reverts on mismatched offer and consideration components", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        let fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith(
            "MismatchedFulfillmentOfferAndConsiderationComponents"
          );
        });

        fulfillments = defaultBuyNowMirrorFulfillment;

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("Reverts on mismatched offer components", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        const secondNFTId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, secondNFTId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: secondNFTId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("InvalidFulfillmentComponentData");
        });
      });
      it("Reverts on mismatched consideration components", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        const secondNFTId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, secondNFTId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: secondNFTId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("1"),
            endAmount: ethers.utils.parseEther("1"),
            recipient: zone.address,
          },
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("InvalidFulfillmentComponentData");
        });
      });
      it("Reverts on fulfillment component with out-of-range order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 2,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("InvalidFulfillmentComponentData");
        });
      });
      it("Reverts on fulfillment component with out-of-range offer item", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 5,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("InvalidFulfillmentComponentData");
        });
      });
      it("Reverts on fulfillment component with out-of-range consideration item", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 5,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("InvalidFulfillmentComponentData");
        });
      });
      it("Reverts on unmet consideration items", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("10"),
            endAmount: ethers.utils.parseEther("10"),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("1"),
            endAmount: ethers.utils.parseEther("1"),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("1"),
            endAmount: ethers.utils.parseEther("1"),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
        ];

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith(
            `ConsiderationNotMet(0, 2, ${ethers.utils
              .parseEther("1")
              .toString()}`
          );
        });
      });
      it("Reverts on fulfillAvailableAdvancedOrders with empty fulfillment component", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [[]];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAvailableAdvancedOrders(
                [order],
                [],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value }
              )
          ).to.be.revertedWith("MissingFulfillmentComponentOnAggregation(0)");
        });
      });
      it("Reverts on fulfillAvailableAdvancedOrders with out-of-range initial offer order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount.mul(2));

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 2,
              itemIndex: 0,
            },
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAvailableAdvancedOrders(
                [order],
                [],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value }
              )
          ).to.be.revertedWith("InvalidFulfillmentComponentData");
        });
      });
      it("Reverts on fulfillAvailableAdvancedOrders with out-of-range offer order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount.mul(2));

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 2,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAvailableAdvancedOrders(
                [order],
                [],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value }
              )
          ).to.be.revertedWith("InvalidFulfillmentComponentData");
        });
      });
      it("Reverts on fulfillAvailableAdvancedOrders with mismatched offer components", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("1"),
            endAmount: ethers.utils.parseEther("1"),
          },
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 0,
              itemIndex: 1,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAvailableAdvancedOrders(
                [order],
                [],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value }
              )
          ).to.be.revertedWith("InvalidFulfillmentComponentData");
        });
      });
      it("Reverts on fulfillAvailableAdvancedOrders with out-of-range consideration order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 2,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 2,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAvailableAdvancedOrders(
                [order],
                [],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value }
              )
          ).to.be.revertedWith("InvalidFulfillmentComponentData");
        });
      });
      it("Reverts on fulfillAvailableAdvancedOrders with mismatched consideration components", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
            recipient: zone.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 0,
              itemIndex: 1,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAvailableAdvancedOrders(
                [order],
                [],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value }
              )
          ).to.be.revertedWith("InvalidFulfillmentComponentData");
        });
      });
      it("Reverts on fulfillAvailableAdvancedOrders no available components", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10)).mul(2);
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.div(2),
            endAmount: amount.div(2),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        // first order is expired
        const {
          order: orderOne,
          orderHash: orderHashOne,
          value,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "EXPIRED"
        );

        // second order will be cancelled
        const {
          order: orderTwo,
          orderHash: orderHashTwo,
          orderComponents,
        } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // can cancel it
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            marketplaceContract.connect(seller).cancel([orderComponents])
          )
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHashTwo, seller.address, zone.address);
        });

        // third order will be filled
        const { order: orderThree, orderHash: orderHashThree } =
          await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

        // can fill it
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([orderThree], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillOrder(orderThree, toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              {
                order: orderThree,
                orderHash: orderHashThree,
                fulfiller: buyer.address,
              },
            ]);
            return receipt;
          });
        });

        const offerComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
            {
              orderIndex: 2,
              itemIndex: 0,
            },
          ],
        ];

        const considerationComponents = [
          [
            {
              orderIndex: 0,
              itemIndex: 0,
            },
            {
              orderIndex: 1,
              itemIndex: 0,
            },
            {
              orderIndex: 2,
              itemIndex: 0,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 1,
            },
            {
              orderIndex: 1,
              itemIndex: 1,
            },
            {
              orderIndex: 2,
              itemIndex: 1,
            },
          ],
          [
            {
              orderIndex: 0,
              itemIndex: 2,
            },
            {
              orderIndex: 1,
              itemIndex: 2,
            },
            {
              orderIndex: 2,
              itemIndex: 2,
            },
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAvailableAdvancedOrders(
                [orderOne, orderTwo, orderThree],
                [],
                offerComponents,
                considerationComponents,
                toKey(false),
                100,
                { value: value.mul(3) }
              )
          ).to.be.revertedWith("NoSpecifiedOrdersAvailable");
        });
      });
      it("Reverts on out-of-range criteria resolvers", async () => {
        // Seller mints nfts
        const nftId = ethers.BigNumber.from(randomHex());
        const secondNFTId = ethers.BigNumber.from(randomHex());
        const thirdNFTId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [
          {
            itemType: 4, // ERC721WithCriteria
            token: testERC721.address,
            identifierOrCriteria: root,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        let criteriaResolvers = [
          {
            orderIndex: 3,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
        ];

        let { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              })
          ).to.be.revertedWith("OrderCriteriaResolverOutOfRange");
        });

        criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 5,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              })
          ).to.be.revertedWith("OfferCriteriaResolverOutOfRange");
        });

        criteriaResolvers = [
          {
            orderIndex: 0,
            side: 1, // consideration
            index: 5,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              })
          ).to.be.revertedWith("ConsiderationCriteriaResolverOutOfRange");
        });

        criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, criteriaResolvers, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              criteriaResolvers
            );
            return receipt;
          });
        });
      });
      it("Reverts on unresolved criteria items", async () => {
        // Seller and buyer both mints nfts
        const nftId = ethers.BigNumber.from(randomHex());
        const secondNFTId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(buyer.address, secondNFTId);

        const tokenIds = [nftId, secondNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer approves marketplace contract to transfer NFTs
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC721
              .connect(buyer)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(buyer.address, marketplaceContract.address, true);
        });

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [
          {
            itemType: 4, // ERC721WithCriteria
            token: testERC721.address,
            identifierOrCriteria: root,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const consideration = [
          {
            itemType: 4, // ERC721WithCriteria
            token: testERC721.address,
            identifierOrCriteria: root,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
            recipient: owner.address,
          },
        ];

        let criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
          {
            orderIndex: 0,
            side: 1, // consideration
            index: 0,
            identifier: secondNFTId,
            criteriaProof: proofs[secondNFTId.toString()],
          },
        ];

        let { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              })
          ).to.be.revertedWith("UnresolvedConsiderationCriteria");
        });

        criteriaResolvers = [
          {
            orderIndex: 0,
            side: 1, // consideration
            index: 0,
            identifier: secondNFTId,
            criteriaProof: proofs[secondNFTId.toString()],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              })
          ).to.be.revertedWith("UnresolvedOfferCriteria");
        });

        criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
          {
            orderIndex: 0,
            side: 1, // consideration
            index: 0,
            identifier: secondNFTId,
            criteriaProof: proofs[secondNFTId.toString()],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, criteriaResolvers, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              criteriaResolvers
            );
            return receipt;
          });
        });
      });
      it("Reverts on attempts to resolve criteria for non-criteria item", async () => {
        // Seller mints nfts
        const nftId = ethers.BigNumber.from(randomHex());
        const secondNFTId = ethers.BigNumber.from(randomHex());
        const thirdNFTId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              })
          ).to.be.revertedWith("CriteriaNotEnabledForItem");
        });
      });
      it("Reverts on invalid criteria proof", async () => {
        // Seller mints nfts
        const nftId = ethers.BigNumber.from(randomHex());
        const secondNFTId = ethers.BigNumber.from(randomHex());
        const thirdNFTId = ethers.BigNumber.from(randomHex());

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [
          {
            itemType: 4, // ERC721WithCriteria
            token: testERC721.address,
            identifierOrCriteria: root,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        criteriaResolvers[0].identifier =
          criteriaResolvers[0].identifier.add(1);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              })
          ).to.be.revertedWith("InvalidProof");
        });

        criteriaResolvers[0].identifier =
          criteriaResolvers[0].identifier.sub(1);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, criteriaResolvers, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, criteriaResolvers, toKey(false), {
                value,
              });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              criteriaResolvers
            );
            return receipt;
          });
        });
      });
      it("Reverts on attempts to transfer >1 ERC721 in single transfer", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(2),
            endAmount: ethers.BigNumber.from(2),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("InvalidERC721TransferAmount");
        });
      });
      it("Reverts on attempts to transfer >1 ERC721 in single transfer via conduit", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves conduit contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(conduitOne.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, conduitOne.address, true);
        });

        const offer = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(2),
            endAmount: ethers.BigNumber.from(2),
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          constants.HashZero,
          conduitKeyOne
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("InvalidERC721TransferAmount");
        });
      });
    });

    describe("Out of timespan", async () => {
      it("Reverts on orders that have not started (standard)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "NOT_STARTED"
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("InvalidTime");
        });
      });
      it("Reverts on orders that have expired (standard)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "EXPIRED"
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("InvalidTime");
        });
      });
      it("Reverts on orders that have not started (basic)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "NOT_STARTED"
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, { value })
          ).to.be.revertedWith("InvalidTime");
        });
      });
      it("Reverts on orders that have expired (basic)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "EXPIRED"
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, { value })
          ).to.be.revertedWith("InvalidTime");
        });
      });
      it("Reverts on orders that have not started (match)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "NOT_STARTED"
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = defaultBuyNowMirrorFulfillment;

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("InvalidTime");
        });
      });
      it("Reverts on orders that have expired (match)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "EXPIRED"
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = defaultBuyNowMirrorFulfillment;

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("InvalidTime");
        });
      });
    });

    describe("Insufficient amounts and bad items", async () => {
      it("Reverts when no enough ether is supplied (basic)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value: ethers.BigNumber.from(1),
              })
          ).to.be.revertedWith("InsufficientEtherSupplied");
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              { order, orderHash, fulfiller: buyer.address },
            ]);
            return receipt;
          });
        });
      });
      it("Reverts when not enough ether is supplied (basic)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value: ethers.BigNumber.from(1),
              })
          ).to.be.revertedWith("InsufficientEtherSupplied");
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, { value: value.sub(1) })
          ).to.be.revertedWith("InsufficientEtherSupplied");
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [
              { order, orderHash, fulfiller: buyer.address },
            ]);
            return receipt;
          });
        });
      });
      it("Reverts when not enough ether is supplied as offer item (standard)", async () => {
        // NOTE: this is a ridiculous scenario, buyer is paying the seller's offer

        // buyer mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(buyer.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC721
              .connect(buyer)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(buyer.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("10"),
            endAmount: ethers.utils.parseEther("10"),
          },
        ];

        const consideration = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: ethers.BigNumber.from(1),
            endAmount: ethers.BigNumber.from(1),
            recipient: seller.address,
          },
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value: ethers.BigNumber.from(1),
              })
          ).to.be.revertedWith("InsufficientEtherSupplied");
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value: ethers.utils.parseEther("9.999999"),
              })
          ).to.be.revertedWith("InsufficientEtherSupplied");
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [order],
            ethers.utils.parseEther("10").mul(-1),
            null,
            async () => {
              const tx = await marketplaceContract
                .connect(buyer)
                .fulfillOrder(order, toKey(false), {
                  value: ethers.utils.parseEther("12"),
                });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);
              return receipt;
            }
          );
        });
      });
      it("Reverts when not enough ether is supplied (standard + advanced)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), {
                value: ethers.BigNumber.from(1),
              })
          ).to.be.revertedWith("InsufficientEtherSupplied");
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), {
                value: value.sub(1),
              })
          ).to.be.revertedWith("InsufficientEtherSupplied");
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        // fulfill with a tiny bit extra to test for returning eth
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), {
                value: value.add(1),
              });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it("Reverts when not enough ether is supplied (match)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = defaultBuyNowMirrorFulfillment;

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, {
                value: ethers.BigNumber.from(1),
              })
          ).to.be.revertedWith("InsufficientEtherSupplied");
        });

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, {
                value: value.sub(1),
              })
          ).to.be.revertedWith("InsufficientEtherSupplied");
        });

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("Reverts when ether is supplied to a non-payable route (basic)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, marketplaceContract.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const basicOrderParameters = getBasicOrderParameters(
          2, // ERC20_TO_ERC721
          order
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value: 1,
              })
          ).to.be.revertedWith("InvalidMsgValue(1)");
        });
      });
      it("Reverts when ether transfer fails (basic)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, marketplaceContract.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value: ethers.utils.parseEther("12"),
              })
          ).to.be.revertedWith(
            `EtherTransferGenericFailure("${
              marketplaceContract.address
            }", ${ethers.utils.parseEther("1").toString()})`
          );
        });
      });
      it("Reverts when tokens are not approved", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.reverted; // panic code thrown by underlying 721
        });

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it("Reverts when 1155 token transfer reverts", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [getItemETH(10, 10, seller.address)];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith("NOT_AUTHORIZED");
        });
      });
      it("Reverts when 1155 token transfer reverts (via conduit)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [getItemETH(10, 10, seller.address)];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          constants.HashZero,
          conduitKeyOne
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith(`NOT_AUTHORIZED`);
        });
      });
      it("Reverts when transferred item amount is zero", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(0),
            endAmount: amount.mul(0),
          },
        ];

        const consideration = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith("MissingItemAmount");
        });
      });
      it("Reverts when ERC20 tokens return falsey values", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // block transfers
        await testERC20.blockTransfer(true);

        expect(await testERC20.blocked()).to.be.true;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.reverted; // TODO: hardhat can't find error msg on IR pipeline
        });

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await testERC20.blockTransfer(false);

        expect(await testERC20.blocked()).to.be.false;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it("Reverts when ERC20 tokens return falsey values (via conduit)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves conduit contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(conduitOne.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, conduitOne.address, true);
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves conduit contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, conduitOne.address, tokenAmount);
        });

        // Seller approves conduit contract to transfer tokens
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC20.connect(seller).approve(conduitOne.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(seller.address, conduitOne.address, tokenAmount);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          constants.HashZero,
          conduitKeyOne
        );

        // block transfers
        await testERC20.blockTransfer(true);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], conduitKeyOne, { value })
          ).to.be.revertedWith(
            `BadReturnValueFromERC20OnTransfer("${testERC20.address}", "${
              buyer.address
            }", "${seller.address}", ${amount.mul(1000).toString()})`
          );
        });

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await testERC20.blockTransfer(false);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], conduitKeyOne, { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it("Reverts when providing non-existent conduit", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves conduit contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(conduitOne.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, conduitOne.address, true);
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves conduit contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, conduitOne.address, tokenAmount);
        });

        // Seller approves conduit contract to transfer tokens
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC20.connect(seller).approve(conduitOne.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(seller.address, conduitOne.address, tokenAmount);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
          },
        ];

        const consideration = [
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(1000),
            endAmount: amount.mul(1000),
            recipient: seller.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(10),
            endAmount: amount.mul(10),
            recipient: zone.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0,
            startAmount: amount.mul(20),
            endAmount: amount.mul(20),
            recipient: owner.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          constants.HashZero,
          conduitKeyOne
        );

        const badKey = ethers.constants.HashZero.slice(0, -1) + "2";

        const missingConduit = await conduitController.getConduit(badKey);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], badKey, { value })
          ).to.be.revertedWith("InvalidConduit", badKey, missingConduit);
        });

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], conduitKeyOne, { value });
            const receipt = await tx.wait();
            await checkExpectedEvents(
              receipt,
              [{ order, orderHash, fulfiller: buyer.address }],
              null,
              null,
              []
            );
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it("Reverts when 1155 batch tokens are not approved", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, secondNftId, secondAmount);

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: secondNftId,
            startAmount: secondAmount,
            endAmount: secondAmount,
          },
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("NOT_AUTHORIZED");
        });

        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const { standardExecutions, batchExecutions } =
          await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

        expect(batchExecutions.length).to.equal(1);
        expect(standardExecutions.length).to.equal(3);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value });
          const receipt = await tx.wait();
          await checkExpectedEvents(
            receipt,
            [{ order, orderHash, fulfiller: constants.AddressZero }],
            standardExecutions,
            batchExecutions
          );
          await checkExpectedEvents(
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            standardExecutions,
            batchExecutions
          );
          return receipt;
        });
      });
      it("Reverts when token account with no code is supplied", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const consideration = [
          {
            itemType: 1, // ERC20
            token: ethers.constants.AddressZero,
            identifierOrCriteria: 0,
            startAmount: amount,
            endAmount: amount,
            recipient: seller.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.reverted; // TODO: look into the revert reason more thoroughly
          // Transaction reverted: function returned an unexpected amount of data
        });
      });
      it("Reverts when 1155 account with no code is supplied", async () => {
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));

        const offer = [
          {
            itemType: 3, // ERC1155
            token: ethers.constants.AddressZero,
            identifierOrCriteria: 0,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const consideration = [getItemETH(10, 10, seller.address)];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith(`NoContract("${ethers.constants.AddressZero}")`);
        });
      });
      it("Reverts when 1155 account with no code is supplied (via conduit)", async () => {
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));

        const offer = [
          {
            itemType: 3, // ERC1155
            token: ethers.constants.AddressZero,
            identifierOrCriteria: 0,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const consideration = [getItemETH(10, 10, seller.address)];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          constants.HashZero,
          conduitKeyOne
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith(`NoContract("${ethers.constants.AddressZero}")`);
        });
      });
      it("Reverts when non-token account is supplied as the token", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const consideration = [
          {
            itemType: 1, // ERC20
            token: marketplaceContract.address,
            identifierOrCriteria: 0,
            startAmount: amount,
            endAmount: amount,
            recipient: seller.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith(
            `TokenTransferGenericFailure("${marketplaceContract.address}", "${
              buyer.address
            }", "${seller.address}", 0, ${amount.toString()})`
          );
        });
      });
      it("Reverts when non-token account is supplied as the token fulfilled via conduit", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: testERC1155.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const consideration = [
          {
            itemType: 1, // ERC20
            token: marketplaceContract.address,
            identifierOrCriteria: 0,
            startAmount: amount,
            endAmount: amount,
            recipient: seller.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], conduitKeyOne, { value })
          ).to.be.revertedWith(
            `TokenTransferGenericFailure("${marketplaceContract.address}", "${
              buyer.address
            }", "${seller.address}", 0, ${amount.toString()})`
          );
        });
      });
      it("Reverts when non-1155 account is supplied as the token", async () => {
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));

        const offer = [
          {
            itemType: 3, // ERC1155
            token: marketplaceContract.address,
            identifierOrCriteria: 0,
            startAmount: amount,
            endAmount: amount,
          },
        ];

        const consideration = [getItemETH(10, 10, seller.address)];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), { value })
          ).to.be.revertedWith(
            `TokenTransferGenericFailure("${marketplaceContract.address}", "${
              seller.address
            }", "${buyer.address}", 0, ${amount.toString()})`
          );
        });
      });
      it("Reverts when 1155 batch non-token account is supplied as the token", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, secondNftId, secondAmount);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          getTestItem1155(nftId, amount, amount, marketplaceContract.address),
          getTestItem1155(
            secondNftId,
            secondAmount,
            secondAmount,
            marketplaceContract.address
          ),
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith(
            `ERC1155BatchTransferGenericFailure("${
              marketplaceContract.address
            }", "${seller.address}", "${
              buyer.address
            }", [${nftId.toString()}, ${secondNftId.toString()}], [${amount.toString()}, ${secondAmount.toString()}])`
          );
        });

        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);
      });
      it("Reverts when 1155 batch non-token account is supplied as the token via conduit", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, secondNftId, secondAmount);

        // Seller approves conduit contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC1155
              .connect(seller)
              .setApprovalForAll(conduitOne.address, true)
          )
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, conduitOne.address, true);
        });

        const offer = [
          getTestItem1155(nftId, amount, amount, marketplaceContract.address),
          getTestItem1155(
            secondNftId,
            secondAmount,
            secondAmount,
            marketplaceContract.address
          ),
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          constants.HashZero,
          conduitKeyOne
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith(
            `ERC1155BatchTransferGenericFailure("${
              marketplaceContract.address
            }", "${seller.address}", "${
              buyer.address
            }", [${nftId.toString()}, ${secondNftId.toString()}], [${amount.toString()}, ${secondAmount.toString()}])`
          );
        });

        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);
      });
      it("Reverts when 1155 batch token is not approved via conduit", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
        await testERC1155.mint(seller.address, secondNftId, secondAmount);

        const offer = [
          getTestItem1155(nftId, amount, amount, testERC1155.address),
          getTestItem1155(
            secondNftId,
            secondAmount,
            secondAmount,
            testERC1155.address
          ),
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          constants.HashZero,
          conduitKeyOne
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("NOT_AUTHORIZED");
        });

        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);
      });
      it("Reverts when 1155 batch token with no code is supplied as the token via conduit", async () => {
        // Seller mints first nft
        const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const amount = ethers.BigNumber.from(randomHex().slice(0, 10));

        // Seller mints second nft
        const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
        const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));

        const offer = [
          getTestItem1155(nftId, amount, amount, ethers.constants.AddressZero),
          getTestItem1155(
            secondNftId,
            secondAmount,
            secondAmount,
            ethers.constants.AddressZero
          ),
        ];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, zone.address),
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          null,
          seller,
          constants.HashZero,
          conduitKeyOne
        );

        const { mirrorOrder, mirrorOrderHash, mirrorValue } =
          await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = [
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 1,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 0,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 1,
              },
            ],
          },
          {
            offerComponents: [
              {
                orderIndex: 1,
                itemIndex: 0,
              },
            ],
            considerationComponents: [
              {
                orderIndex: 0,
                itemIndex: 2,
              },
            ],
          },
        ];

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, { value })
          ).to.be.revertedWith("NoContract", ethers.constants.AddressZero);
        });

        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);
      });
      it("Reverts when non-payable ether recipient is supplied", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("1"),
            endAmount: ethers.utils.parseEther("1"),
            recipient: marketplaceContract.address,
          },
          getItemETH(1, 1, owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, { value })
          ).to.be.revertedWith(
            `EtherTransferGenericFailure("${
              marketplaceContract.address
            }", ${ethers.utils.parseEther("1").toString()})`
          );
        });
      });
    });

    describe("Basic Order Calldata", () => {
      let calldata, value;

      before(async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [getItemETH(10, 10, seller.address)];
        let order;
        ({ order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        ));

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        ({ data: calldata } =
          await marketplaceContract.populateTransaction.fulfillBasicOrder(
            basicOrderParameters
          ));
      });

      it("Reverts if BasicOrderParameters has non-default offset", async () => {
        const badData = [calldata.slice(0, 73), "1", calldata.slice(74)].join(
          ""
        );
        expect(badData.length).to.eq(calldata.length);

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            buyer.sendTransaction({
              to: marketplaceContract.address,
              data: badData,
              value,
            })
          ).to.be.revertedWith("InvalidBasicOrderParameterEncoding");
        });
      });

      it("Reverts if additionalRecipients has non-default offset", async () => {
        const badData = [
          calldata.slice(0, 1161),
          "1",
          calldata.slice(1162),
        ].join("");

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            buyer.sendTransaction({
              to: marketplaceContract.address,
              data: badData,
              value,
            })
          ).to.be.revertedWith("InvalidBasicOrderParameterEncoding");
        });
      });

      it("Reverts if signature has non-default offset", async () => {
        const badData = [
          calldata.slice(0, 1161),
          "2",
          calldata.slice(1162),
        ].join("");

        await whileImpersonating(owner.address, provider, async () => {
          await expect(
            buyer.sendTransaction({
              to: marketplaceContract.address,
              data: badData,
              value,
            })
          ).to.be.revertedWith("InvalidBasicOrderParameterEncoding");
        });
      });
    });

    describe("Reentrancy", async () => {
      it("Reverts on a reentrant call", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(
            testERC721
              .connect(seller)
              .setApprovalForAll(marketplaceContract.address, true)
          )
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(10, 10, seller.address),
          getItemETH(1, 1, reenterer.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // prepare the reentrant call on the reenterer
        const callData = marketplaceContract.interface.encodeFunctionData(
          "fulfillOrder",
          [order, toKey(false)]
        );
        const tx = await reenterer.prepare(
          marketplaceContract.address,
          0,
          callData
        );
        await tx.wait();

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), { value })
          ).to.be.revertedWith("NoReentrantCalls");
        });
      });
      it.skip("Reverts on reentrancy (test all the other permutations)", async () => {});
    });
  });

  describe("Auctions for single nft items", async () => {
    describe("English auction", async () => {});
    describe("Dutch auction", async () => {});
  });

  // Is this a thing?
  describe("Auctions for mixed item bundles", async () => {
    describe("English auction", async () => {});
    describe("Dutch auction", async () => {});
  });

  describe("Multiple nfts being sold or bought", async () => {
    describe("Bundles", async () => {});
    describe("Partial fills", async () => {});
  });

  //   Etc this is a brain dump
});
