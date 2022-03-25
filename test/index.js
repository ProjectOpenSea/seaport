const { TypedDataDomain } = require("@ethersproject/abstract-signer");
const { JsonRpcProvider } = require("@ethersproject/providers");
const { Wallet } = require("@ethersproject/wallet");
const { expect } = require("chai");
const { time } = require("console");
const { constants } = require("ethers");
const { ethers } = require("hardhat");
const { TypedData, TypedDataUtils } = require("ethers-eip712");
const { faucet, whileImpersonating } = require("./utils/impersonate");
const { merkleTree } = require("./utils/criteria");
const { eip712DomainType } = require("../eip-712-types/domain");
const { orderType } = require("../eip-712-types/order");

const VERSION = "rc.1";

describe(`Consideration (version: ${VERSION}) — initial test suite`, function () {
  const provider = ethers.provider;
  let chainId;
  let marketplaceContract;
  let legacyProxyRegistry;
  let legacyProxyImplementation;
  let ownedUpgradeabilityProxy;
  let testERC20;
  let testERC721;
  let testERC1155;
  let tokenByType;
  let owner;
  let domainData;
  let withBalanceChecks;
  let simulateMatchOrders;
  let simulateAdvancedMatchOrders;
  let EIP1271WalletFactory;
  let reenterer;

  const randomHex = () => (
    `0x${[...Array(64)].map(() => Math.floor(Math.random() * 16).toString(16)).join('')}`
  );

  const randomLarge = () => (
    `0x${[...Array(60)].map(() => Math.floor(Math.random() * 16).toString(16)).join('')}`
  );

  const getBasicOrderParameters = (
    order,
    additionalRecipients = [],
    useFulfillerProxy = false
  ) => ({
    offerer: order.parameters.offerer,
    zone: order.parameters.zone,
    orderType: order.parameters.orderType,
    offeredToken: order.parameters.offer[0].token,
    offeredIdentifier: order.parameters.offer[0].identifierOrCriteria,
    offeredAmount: order.parameters.offer[0].endAmount,
    receivedToken: order.parameters.consideration[0].token,
    receivedIdentifier: order.parameters.consideration[0].identifierOrCriteria,
    receivedAmount: order.parameters.consideration[0].endAmount,
    startTime: order.parameters.startTime,
    endTime: order.parameters.endTime,
    salt: order.parameters.salt,
    signature: order.signature,
    useFulfillerProxy,
    additionalRecipients,
  });

  const convertSignatureToEIP2098 = (signature) => {
    if (signature.length === 130) {
      return signature;
    }

    if (signature.length !== 132) {
      throw error("invalid signature length (must be 64 or 65 bytes)");
    }

    signature = signature.toLowerCase();

    // flip signature if malleable
    const secp256k1n = ethers.BigNumber.from('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141');
    const maxS = ethers.BigNumber.from('0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0');
    let s = ethers.BigNumber.from('0x' + signature.slice(66, 130));
    let v = signature.slice(130);

    if (v !== '1b' && v !== '1c') {
      throw error("invalid v value (must be 27 or 28)");
    }

    if (s.gt(maxS)) {
      s = secp256k1n.sub(s);
      v = v === '1c' ? '1b' : '1c';
    }

    const nonMalleableSig = `${signature.slice(0, 66)}${s.toHexString().slice(2)}${v}`;

    // Convert the signature by adding a higher bit
    return nonMalleableSig.slice(-2) === '1b'
      ? nonMalleableSig.slice(0, -2)
      : (
        `${
          nonMalleableSig.slice(0, 66)
        }${
          (parseInt('0x' + nonMalleableSig[66]) + 8).toString(16)
        }${
          nonMalleableSig.slice(67, -2)
        }`
      );
  }

  async function getAndVerifyOrderHash(orderComponents) {
    const orderHash = await marketplaceContract.getOrderHash(orderComponents);

    const offerItemTypeString = "OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)";
    const considerationItemTypeString = "ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)";
    const orderComponentsPartialTypeString = "OrderComponents(address offerer,address zone,OfferItem[] offer,ConsiderationItem[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,uint256 salt,uint256 nonce)";
    const orderTypeString = `${orderComponentsPartialTypeString}${considerationItemTypeString}${offerItemTypeString}`;
    
    const offerItemTypeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(offerItemTypeString));
    const considerationItemTypeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(considerationItemTypeString));
    const orderTypeHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(orderTypeString));

    const offerHash = ethers.utils.keccak256(
      '0x' + orderComponents.offer.map(
        offerItem => {
          return ethers.utils.keccak256(
            '0x' + [
              offerItemTypeHash.slice(2),
              offerItem.itemType.toString().padStart(64, '0'),
              offerItem.token.slice(2).padStart(64, '0'),
              ethers.BigNumber.from(offerItem.identifierOrCriteria).toHexString().slice(2).padStart(64, '0'),
              ethers.BigNumber.from(offerItem.startAmount).toHexString().slice(2).padStart(64, '0'),
              ethers.BigNumber.from(offerItem.endAmount).toHexString().slice(2).padStart(64, '0')
            ].join('')
          ).slice(2);
        }
      ).join('')
    );

    const considerationHash = ethers.utils.keccak256(
      '0x' + orderComponents.consideration.map(
        considerationItem => {
          return ethers.utils.keccak256(
            '0x' + [
              considerationItemTypeHash.slice(2),
              considerationItem.itemType.toString().padStart(64, '0'),
              considerationItem.token.slice(2).padStart(64, '0'),
              ethers.BigNumber.from(considerationItem.identifierOrCriteria).toHexString().slice(2).padStart(64, '0'),
              ethers.BigNumber.from(considerationItem.startAmount).toHexString().slice(2).padStart(64, '0'),
              ethers.BigNumber.from(considerationItem.endAmount).toHexString().slice(2).padStart(64, '0'),
              considerationItem.recipient.slice(2).padStart(64, '0')
            ].join('')
          ).slice(2);
        }
      ).join('')
    );

    const derivedOrderHash = ethers.utils.keccak256(
      '0x' + [
        orderTypeHash.slice(2),
        orderComponents.offerer.slice(2).padStart(64, '0'),
        orderComponents.zone.slice(2).padStart(64, '0'),
        offerHash.slice(2),
        considerationHash.slice(2),
        orderComponents.orderType.toString().padStart(64, '0'),
        ethers.BigNumber.from(orderComponents.startTime).toHexString().slice(2).padStart(64, '0'),
        ethers.BigNumber.from(orderComponents.endTime).toHexString().slice(2).padStart(64, '0'),
        orderComponents.salt.slice(2).padStart(64, '0'),
        ethers.BigNumber.from(orderComponents.nonce).toHexString().slice(2).padStart(64, '0')
      ].join('')
    );

    expect(orderHash).to.equal(derivedOrderHash);

    return orderHash;
  }

  // Returns signature
  async function signOrder(
    orderComponents,
    signer
  ) {
    const signature = await signer._signTypedData(
      domainData,
      orderType,
      orderComponents
    );

    const orderHash = await getAndVerifyOrderHash(orderComponents);

    const domainSeparator = await marketplaceContract.DOMAIN_SEPARATOR();
    const digest = ethers.utils.keccak256(`0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`);
    const recoveredAddress = ethers.utils.recoverAddress(digest, signature);

    expect(recoveredAddress).to.equal(signer.address);

    return signature;
  }

  const createOrder = async (offerer, zone, offer, consideration, orderType, criteriaResolvers, timeFlag, signer) => {
    const nonce = await marketplaceContract.getNonce(offerer.address, zone.address);
    const salt = randomHex();
    const startTime = timeFlag !== "NOT_STARTED" ? 0 : ethers.BigNumber.from("0xee00000000000000000000000000");
    const endTime = timeFlag !== "EXPIRED" ? ethers.BigNumber.from("0xff00000000000000000000000000") : 1;

    const orderParameters = {
        offerer: offerer.address,
        zone: zone.address,
        offer,
        consideration,
        orderType,
        salt,
        startTime,
        endTime,
    };

    const orderComponents = {
      ...orderParameters,
      nonce,
    };

    const orderHash = await getAndVerifyOrderHash(orderComponents);

    const {
      isValidated,
      isCancelled,
      totalFilled,
      totalSize,
    } = await marketplaceContract.getOrderStatus(orderHash);

    expect(isCancelled).to.equal(false);

    const orderStatus = {
      isValidated,
      isCancelled,
      totalFilled,
      totalSize,
    };

    const flatSig = await signOrder(orderComponents, signer ? signer : offerer);

    const order = {
      parameters: orderParameters,
      signature: flatSig,
      numerator: 1,   // only used for advanced orders; TODO: support partial fills
      denominator: 1, // only used for advanced orders; TODO: support partial fills
    };

    // How much ether (at most) needs to be supplied when fulfilling the order
    const value = offer
      .map(x => (
        x.itemType === 0
          ? (x.endAmount.gt(x.startAmount) ? x.endAmount : x.startAmount)
          : ethers.BigNumber.from(0)
      )).reduce((a, b) => a.add(b), ethers.BigNumber.from(0)).add(consideration
      .map(x => (
        x.itemType === 0
          ? (x.endAmount.gt(x.startAmount) ? x.endAmount : x.startAmount)
          : ethers.BigNumber.from(0)
      )).reduce((a, b) => a.add(b), ethers.BigNumber.from(0)));

    return {order, orderHash, value, orderStatus, orderComponents};
  }

  const createMirrorBuyNowOrder = async (offerer, zone, order) => {
    const nonce = await marketplaceContract.getNonce(offerer.address, zone.address);
    const salt = randomHex();
    const startTime = 0;
    const endTime = ethers.BigNumber.from("0xff00000000000000000000000000000000000000000000000000000000000000");

    const compressedOfferItems = [];
    for (
      const {
        itemType,
        token,
        identifierOrCriteria,
        startAmount,
        endAmount,
      } of order.parameters.offer
    ) {
      if (
        !compressedOfferItems.map(
          x => `${x.itemType}+${x.token}+${x.identifierOrCriteria}`
        ).includes(
          `${itemType}+${token}+${identifierOrCriteria}`
        )
      ) {
        compressedOfferItems.push({
          itemType,
          token,
          identifierOrCriteria,
          startAmount,
          endAmount,
        });
      } else {
        const index = compressedOfferItems.map(
          x => `${x.itemType}+${x.token}+${x.identifierOrCriteria}`
        ).indexOf(
          `${itemType}+${token}+${identifierOrCriteria}`
        );

        compressedOfferItems[index].startAmount = (
          compressedOfferItems[index].startAmount.add(startAmount)
        );
        compressedOfferItems[index].endAmount = (
          compressedOfferItems[index].endAmount.add(endAmount)
        );
      }
    }

    const compressedConsiderationItems = [];
    for (
      const {
        itemType,
        token,
        identifierOrCriteria,
        startAmount,
        endAmount,
        recipient,
      } of order.parameters.consideration
    ) {
      if (
        !compressedConsiderationItems.map(
          x => `${x.itemType}+${x.token}+${x.identifierOrCriteria}`
        ).includes(
          `${itemType}+${token}+${identifierOrCriteria}`
        )
      ) {
        compressedConsiderationItems.push({
          itemType,
          token,
          identifierOrCriteria,
          startAmount,
          endAmount,
          recipient,
        });
      } else {
        const index = compressedConsiderationItems.map(
          x => `${x.itemType}+${x.token}+${x.identifierOrCriteria}`
        ).indexOf(
          `${itemType}+${token}+${identifierOrCriteria}`
        );

        compressedConsiderationItems[index].startAmount = (
          compressedConsiderationItems[index].startAmount.add(startAmount)
        );
        compressedConsiderationItems[index].endAmount = (
          compressedConsiderationItems[index].endAmount.add(endAmount)
        );
      }
    }

    const orderParameters = {
        offerer: offerer.address,
        zone: zone.address,
        offer: compressedConsiderationItems.map(x => ({
          itemType: x.itemType,
          token: x.token,
          identifierOrCriteria: x.identifierOrCriteria,
          startAmount: x.startAmount,
          endAmount: x.endAmount,
        })),
        consideration: compressedOfferItems.map(x => ({
          ...x,
          recipient: offerer.address,
        })),
        orderType: 0, // FULL_OPEN
        salt,
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
      numerator: 1,   // only used for advanced orders; TODO: support partial fills
      denominator: 1, // only used for advanced orders; TODO: support partial fills
    };

    // How much ether (at most) needs to be supplied when fulfilling the order
    const mirrorValue = orderParameters.consideration
      .map(x => (
        x.itemType === 0
          ? (x.endAmount.gt(x.startAmount) ? x.endAmount : x.startAmount)
          : ethers.BigNumber.from(0)
      )).reduce((a, b) => a.add(b), ethers.BigNumber.from(0));

    return {mirrorOrder, mirrorOrderHash, mirrorValue};
  }

  const createMirrorAcceptOfferOrder = async (offerer, zone, order, criteriaResolvers, useProxy = false) => {
    const nonce = await marketplaceContract.getNonce(offerer.address, zone.address);
    const salt = randomHex();
    const startTime = 0;
    const endTime = ethers.BigNumber.from("0xff00000000000000000000000000000000000000000000000000000000000000");

    const orderParameters = {
        offerer: offerer.address,
        zone: zone.address,
        offer: order.parameters.consideration
          .filter(x => x.itemType !== 1)
          .map(x => ({
            itemType: x.itemType < 4 ? x.itemType : x.itemType - 2,
            token: x.token,
            identifierOrCriteria: x.itemType < 4 ? x.identifierOrCriteria : criteriaResolvers[0].identifier,
            startAmount: x.startAmount,
            endAmount: x.endAmount,
          })),
        consideration: order.parameters.offer.map(x => ({
          itemType: x.itemType < 4 ? x.itemType : x.itemType - 2,
          token: x.token,
          identifierOrCriteria: x.itemType < 4 ? x.identifierOrCriteria : criteriaResolvers[0].identifier,
          startAmount: x.startAmount,
          endAmount: x.endAmount,
          recipient: offerer.address,
          startAmount: ethers.BigNumber.from(x.endAmount).sub(
            order.parameters.consideration
              .filter(i => i.itemType < 2 && i.itemType === x.itemType && i.token === x.token)
              .map(i => i.endAmount)
              .reduce((a, b) => a.add(b), ethers.BigNumber.from(0))
          ),
          endAmount: ethers.BigNumber.from(x.endAmount).sub(
            order.parameters.consideration
              .filter(i => i.itemType < 2 && i.itemType === x.itemType && i.token === x.token)
              .map(i => i.endAmount)
              .reduce((a, b) => a.add(b), ethers.BigNumber.from(0))
          )
        })),
        orderType: useProxy ? 4 : 0, // FULL_OPEN_VIA_PROXY or FULL_OPEN
        salt,
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
      numerator: 1,   // only used for advanced orders; TODO: support partial fills
      denominator: 1, // only used for advanced orders; TODO: support partial fills
    };

    // How much ether (at most) needs to be supplied when fulfilling the order
    const mirrorValue = orderParameters.consideration
      .map(x => (
        x.itemType === 0
          ? (x.endAmount.gt(x.startAmount) ? x.endAmount : x.startAmount)
          : ethers.BigNumber.from(0)
      )).reduce((a, b) => a.add(b), ethers.BigNumber.from(0));

    return {mirrorOrder, mirrorOrderHash, mirrorValue};
  }

  const checkExpectedEvents = async (
    receipt,
    orderGroups,
    standardExecutions,
    batchExecutions,
    criteriaResolvers,
    shouldSkipAmountComparison = false
  ) => {
    if (standardExecutions && standardExecutions.length > 0) {
      for (standardExecution of standardExecutions) {
        const {
          item,
          offerer,
          useProxy,
        } = standardExecution;

        const {
          itemType,
          token,
          identifier,
          amount,
          recipient,
        } = item;

        if (itemType !== 0) {
          const tokenEvents = receipt.events
            .filter(x => x.address === token);

          expect(tokenEvents.length).to.be.above(0);

          if (itemType === 1) { // ERC20
            // search for transfer
            const transferLogs = tokenEvents
              .map(x => testERC20.interface.parseLog(x))
              .filter(x => (
                x.signature === 'Transfer(address,address,uint256)' &&
                x.args.to === recipient
              ));

            expect(transferLogs.length > 0).to.be.true;
            const transferLog = transferLogs[0];
            expect(transferLog.args.value.toString()).to.equal(amount.toString());

          } else if (itemType === 2) { // ERC721
            // search for transfer
            const transferLogs = tokenEvents
              .map(x => testERC721.interface.parseLog(x))
              .filter(x => (
                x.signature === 'Transfer(address,address,uint256)' &&
                x.args.to === recipient
              ));

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            expect(transferLog.args.tokenId.toString()).to.equal(identifier.toString());

          } else if (itemType === 3) {
            // search for transfer
            const transferLogs = tokenEvents
              .map(x => testERC1155.interface.parseLog(x))
              .filter(x => (
                x.signature === 'TransferSingle(address,address,address,uint256,uint256)' &&
                x.args.to === recipient
              ));

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            expect(transferLog.args.id.toString()).to.equal(identifier.toString());
            expect(transferLog.args.value.toString()).to.equal(amount.toString());
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
        const {
          token,
          from,
          to,
          tokenIds,
          amounts,
        } = batchExecution;

        const tokenEvents = receipt.events.filter(x => x.address === token);

        expect(tokenEvents.length).to.be.above(0);

        // search for transfer
        const transferLogs = tokenEvents
          .map(x => testERC1155.interface.parseLog(x))
          .filter(x => (
            x.signature === 'TransferBatch(address,address,address,uint256[],uint256[])' &&
            x.args.to === to
          ));

        expect(transferLogs.length).to.equal(1);
        const transferLog = transferLogs[0];
        for ([i, tokenId] of Object.entries(tokenIds)) {
          expect(transferLog.args.ids[i].toString()).to.equal(tokenId.toString());
          expect(transferLog.args[4][i].toString()).to.equal(amounts[i].toString());
        }
      }
    }

    if (criteriaResolvers) {
      for (const {orderIndex, side, index, identifier} of criteriaResolvers) {
        const itemType = orderGroups[orderIndex].order.parameters[side === 0 ? 'offer' : 'consideration'][index].itemType;
        if (itemType < 4) {
          console.error("APPLYING CRITERIA TO NON-CRITERIA-BASED ITEM");
          process.exit(1);
        }

        orderGroups[orderIndex].order.parameters[side === 0 ? 'offer' : 'consideration'][index].itemType = itemType - 2;
        orderGroups[orderIndex].order.parameters[side === 0 ? 'offer' : 'consideration'][index].identifierOrCriteria = identifier;
      }
    }

    for (
      const {
        order,
        orderHash,
        fulfiller,
        orderStatus
      } of orderGroups
    ) {
      const marketplaceContractEvents = receipt.events
        .filter(x => x.address === marketplaceContract.address)
        .map(x => ({
          eventName: x.event,
          eventSignature: x.eventSignature,
          orderHash: x.args.orderHash,
          offerer: x.args.offerer,
          zone: x.args.zone,
          fulfiller: x.args.fulfiller,
          offer: x.args.offer.map(y => ({
            itemType: y.itemType,
            token: y.token,
            identifier: y.identifier,
            amount: y.amount,
          })),
          consideration: x.args.consideration.map(y => ({
            itemType: y.itemType,
            token: y.token,
            identifier: y.identifier,
            amount: y.amount,
            recipient: y.recipient,
          })),
        })).filter(x => x.orderHash === orderHash);

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

      const compareEventItems = async (item, orderItem, isConsiderationItem) => {
        expect(item.itemType).to.equal(orderItem.itemType > 3 ? orderItem.itemType - 2 : orderItem.itemType);
        expect(item.token).to.equal(orderItem.token);
        expect(item.token).to.equal(tokenByType[item.itemType].address);
        if (orderItem.itemType < 4) { // no criteria-based
          expect(item.identifier).to.equal(orderItem.identifierOrCriteria);
        } else {
          console.error("CRITERIA-BASED EVENT VALIDATION NOT MET");
          process.exit(1);
        }

        if (order.parameters.orderType === 0) { // FULL_OPEN (no partial fills)
          if (orderItem.startAmount.toString() === orderItem.endAmount.toString()) {
            expect(item.amount.toString()).to.equal(orderItem.endAmount.toString());
          } else {
            const {timestamp} = await provider.getBlock(receipt.blockHash);
            const duration = ethers.BigNumber.from(order.parameters.endTime).sub(order.parameters.startTime);
            const elapsed = ethers.BigNumber.from(timestamp).sub(order.parameters.startTime);
            const remaining = duration.sub(elapsed);

            expect(item.amount.toString()).to.equal(
              (ethers.BigNumber.from(orderItem.startAmount).mul(remaining).add(ethers.BigNumber.from(orderItem.endAmount).mul(elapsed)).add(isConsiderationItem ? duration.sub(1) : 0)).div(duration).toString()
            );
          }
        } else {
          if (orderItem.startAmount.toString() === orderItem.endAmount.toString()) {
            expect(item.amount.toString()).to.equal(
              orderItem.endAmount.mul(order.numerator).div(order.denominator).toString()
            );
          } else {
            console.error("SLIDING AMOUNT NOT IMPLEMENTED YET");
            process.exit(1);
          }
        }
      }

      expect(event.offer.length).to.equal(order.parameters.offer.length);
      for ([index, offer] of Object.entries(event.offer)) {
        const offerItem = order.parameters.offer[index];
        await compareEventItems(offer, offerItem, false);

        const tokenEvents = receipt.events
          .filter(x => x.address === offerItem.token);

        if (offer.itemType === 1) { // ERC20
          // search for transfer
          const transferLogs = tokenEvents
            .map(x => testERC20.interface.parseLog(x))
            .filter(x => (
              x.signature === 'Transfer(address,address,uint256)' &&
              x.args.from === event.offerer &&
              (fulfiller !== constants.AddressZero ? x.args.to === fulfiller : true)
            ));

          expect(transferLogs.length).to.be.above(0);
          for (const transferLog of transferLogs) {
            // TODO: check each transferred amount
          }

        } else if (offer.itemType === 2) { // ERC721
          // search for transfer
          const transferLogs = tokenEvents
            .map(x => testERC721.interface.parseLog(x))
            .filter(x => (
              x.signature === 'Transfer(address,address,uint256)' &&
              x.args.from === event.offerer &&
              (fulfiller !== constants.AddressZero ? x.args.to === fulfiller : true)
            ));

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];
          expect(transferLog.args.tokenId.toString()).to.equal(offer.identifier.toString());

        } else if (offer.itemType === 3) {
          // search for transfer
          const transferLogs = tokenEvents
            .map(x => testERC1155.interface.parseLog(x))
            .filter(x => (
              x.signature === 'TransferSingle(address,address,address,uint256,uint256)' &&
              x.args.from === event.offerer &&
              (fulfiller !== constants.AddressZero ? x.args.to === fulfiller : true)
            ) || (
              x.signature === 'TransferBatch(address,address,address,uint256[],uint256[])' &&
              x.args.from === event.offerer &&
              (fulfiller !== constants.AddressZero ? x.args.to === fulfiller : true)
            ));

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];

          if (transferLog.signature === 'TransferSingle(address,address,address,uint256,uint256)') {
            expect(transferLog.args.id.toString()).to.equal(offer.identifier.toString());
            
            if (!shouldSkipAmountComparison) {
              expect(transferLog.args.value.toString()).to.equal(offer.amount.toString());
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

      expect(event.consideration.length).to.equal(order.parameters.consideration.length);
      for ([index, consideration] of Object.entries(event.consideration)) {
        const considerationItem = order.parameters.consideration[index];
        await compareEventItems(consideration, considerationItem, true);
        expect(consideration.recipient).to.equal(considerationItem.recipient);

        const tokenEvents = receipt.events
          .filter(x => x.address === considerationItem.token);

        if (consideration.itemType === 1) { // ERC20
          // search for transfer
          const transferLogs = tokenEvents
            .map(x => testERC20.interface.parseLog(x))
            .filter(x => (
              x.signature === 'Transfer(address,address,uint256)' &&
              x.args.to === consideration.recipient
            ));

          expect(transferLogs.length).to.be.above(0);
          for (const transferLog of transferLogs) {
            // TODO: check each transferred amount
          }

        } else if (consideration.itemType === 2) { // ERC721
          // search for transfer

          const transferLogs = tokenEvents
            .map(x => testERC721.interface.parseLog(x))
            .filter(x => (
              x.signature === 'Transfer(address,address,uint256)' &&
              x.args.to === consideration.recipient
            ));

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];
          expect(transferLog.args.tokenId.toString()).to.equal(consideration.identifier.toString());

        } else if (consideration.itemType === 3) {
          // search for transfer
          const transferLogs = tokenEvents
            .map(x => testERC1155.interface.parseLog(x))
            .filter(x => (
              x.signature === 'TransferSingle(address,address,address,uint256,uint256)' &&
              x.args.to === consideration.recipient
            ) || (
              x.signature === 'TransferBatch(address,address,address,uint256[],uint256[])' &&
              x.args.to === consideration.recipient
            ));

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];

          if (transferLog.signature === 'TransferSingle(address,address,address,uint256,uint256)') {
            expect(transferLog.args.id.toString()).to.equal(consideration.identifier.toString());
            if (!shouldSkipAmountComparison) {
              expect(transferLog.args.value.toString()).to.equal(consideration.amount.toString());
            }
          } else {
            let located = false;
            for ([i, batchTokenId] of Object.entries(transferLog.args.ids)) {
              if (
                batchTokenId.toString() === consideration.identifier.toString() &&
                transferLog.args[4][i].toString() === consideration.amount.toString()
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
  }

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

    const considerationFactory = await ethers.getContractFactory(
      "Consideration"
    );
    const TestERC20Factory = await ethers.getContractFactory(
      "TestERC20",
      owner
    );
    const TestERC721Factory = await ethers.getContractFactory(
      "TestERC721",
      owner
    );
    const TestERC1155Factory = await ethers.getContractFactory(
      "TestERC1155",
      owner
    );
    const legacyProxyRegistryFactory = await ethers.getContractFactory(
      "WyvernProxyRegistry"
    );

    ownedUpgradeabilityProxy = await ethers.getContractFactory(
      "OwnedUpgradeabilityProxy"
    );

    const reentererFactory = await ethers.getContractFactory("Reenterer");

    EIP1271WalletFactory = await ethers.getContractFactory(
      "EIP1271Wallet"
    );

    reenterer = await reentererFactory.deploy();

    await whileImpersonating(owner.address, provider, async () => {
      legacyProxyRegistry = await legacyProxyRegistryFactory.connect(owner).deploy();
    });

    legacyProxyImplementation = await legacyProxyRegistry.delegateProxyImplementation();

    marketplaceContract = await considerationFactory.deploy(
      legacyProxyRegistry.address,
      legacyProxyImplementation
    );

    await whileImpersonating(owner.address, provider, async () => {
      await legacyProxyRegistry.grantInitialAuthentication(marketplaceContract.address);
    });

    testERC20 = await TestERC20Factory.deploy();
    testERC721 = await TestERC721Factory.deploy();
    testERC1155 = await TestERC1155Factory.deploy();

    tokenByType = [
      {address: constants.AddressZero}, // ETH
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
    ) => {
      const ordersClone = JSON.parse(JSON.stringify(ordersArray));
      for (const [i, order] of Object.entries(ordersClone)) {
        order.parameters.startTime = ordersArray[i].parameters.startTime;
        order.parameters.endTime = ordersArray[i].parameters.endTime;

        for (const [j, offerItem] of Object.entries(order.parameters.offer)) {
          offerItem.startAmount = ordersArray[i].parameters.offer[j].startAmount;
          offerItem.endAmount = ordersArray[i].parameters.offer[j].endAmount;
        }

        for (const [j, considerationItem] of Object.entries(order.parameters.consideration)) {
          considerationItem.startAmount = ordersArray[i].parameters.consideration[j].startAmount;
          considerationItem.endAmount = ordersArray[i].parameters.consideration[j].endAmount;
        }
      }

      if (criteriaResolvers) {
        for (const {orderIndex, side, index, identifier} of criteriaResolvers) {
          const itemType = ordersClone[orderIndex].parameters[side === 0 ? 'offer' : 'consideration'][index].itemType;
          if (itemType < 4) {
            console.error("APPLYING CRITERIA TO NON-CRITERIA-BASED ITEM");
            process.exit(1);
          }

          ordersClone[orderIndex].parameters[side === 0 ? 'offer' : 'consideration'][index].itemType = itemType - 2;
          ordersClone[orderIndex].parameters[side === 0 ? 'offer' : 'consideration'][index].identifierOrCriteria = identifier;
        }
      }

      const allOfferedItems = ordersClone.map(x => x.parameters.offer.map(offerItem => ({
        ...offerItem,
        account: x.parameters.offerer,
        numerator: x.numerator,
        denominator: x.denominator,
        startTime: x.parameters.startTime,
        endTime: x.parameters.endTime,
      }))).flat();

      const allReceivedItems = ordersClone.map(x => x.parameters.consideration.map(considerationItem => ({
        ...considerationItem,
        numerator: x.numerator,
        denominator: x.denominator,
        startTime: x.parameters.startTime,
        endTime: x.parameters.endTime,
      }))).flat();

      for (offeredItem of allOfferedItems) {
        if (offeredItem.itemType > 3) {
          console.error("CRITERIA ON OFFERED ITEM NOT RESOLVED");
          process.exit(1);
        }

        if (offeredItem.itemType === 0) { // ETH
          offeredItem.initialBalance = await provider.getBalance(offeredItem.account);
        } else if (offeredItem.itemType === 3) { // ERC1155
          offeredItem.initialBalance = await tokenByType[offeredItem.itemType].balanceOf(offeredItem.account, offeredItem.identifierOrCriteria);
        } else if (offeredItem.itemType < 4) {
          offeredItem.initialBalance = await tokenByType[offeredItem.itemType].balanceOf(offeredItem.account);
        }

        if (offeredItem.itemType === 2) { // ERC721
          offeredItem.ownsItemBefore = (
            await tokenByType[offeredItem.itemType].ownerOf(offeredItem.identifierOrCriteria)
          ) === offeredItem.account;
        }
      }

      for (receivedItem of allReceivedItems) {
        if (receivedItem.itemType > 3) {
          console.error("CRITERIA-BASED BALANCE RECEIVED CHECKS NOT IMPLEMENTED YET");
          process.exit(1);
        }

        if (receivedItem.itemType === 0) { // ETH
          receivedItem.initialBalance = await provider.getBalance(receivedItem.recipient);
        } else if (receivedItem.itemType === 3) { // ERC1155
          receivedItem.initialBalance = await tokenByType[receivedItem.itemType].balanceOf(receivedItem.recipient, receivedItem.identifierOrCriteria);
        } else {
          receivedItem.initialBalance = await tokenByType[receivedItem.itemType].balanceOf(receivedItem.recipient);
        }

        if (receivedItem.itemType === 2) { // ERC721
          receivedItem.ownsItemBefore = (
            await tokenByType[receivedItem.itemType].ownerOf(receivedItem.identifierOrCriteria)
          ) === receivedItem.recipient;
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
          receivedItem.initialBalance = receivedItem.initialBalance.sub(gasUsed);
        }
      }

      for (offeredItem of allOfferedItems) {
        if (offeredItem.itemType > 3) {
          console.error("CRITERIA-BASED BALANCE OFFERED CHECKS NOT MET");
          process.exit(1);
        }

        if (offeredItem.itemType === 0) { // ETH
          offeredItem.finalBalance = await provider.getBalance(offeredItem.account);
        } else if (offeredItem.itemType === 3) { // ERC1155
          offeredItem.finalBalance = await tokenByType[offeredItem.itemType].balanceOf(offeredItem.account, offeredItem.identifierOrCriteria);
        } else if (offeredItem.itemType < 3) { // TODO: criteria-based
          offeredItem.finalBalance = await tokenByType[offeredItem.itemType].balanceOf(offeredItem.account);
        }

        if (offeredItem.itemType === 2) { // ERC721
          offeredItem.ownsItemAfter = (
            await tokenByType[offeredItem.itemType].ownerOf(offeredItem.identifierOrCriteria)
          ) === offeredItem.account;
        }
      }

      for (receivedItem of allReceivedItems) {
        if (receivedItem.itemType > 3) {
          console.error("CRITERIA-BASED BALANCE RECEIVED CHECKS NOT MET");
          process.exit(1);
        }

        if (receivedItem.itemType === 0) { // ETH
          receivedItem.finalBalance = await provider.getBalance(receivedItem.recipient);
        } else if (receivedItem.itemType === 3) { // ERC1155
          receivedItem.finalBalance = await tokenByType[receivedItem.itemType].balanceOf(receivedItem.recipient, receivedItem.identifierOrCriteria);
        } else {
          receivedItem.finalBalance = await tokenByType[receivedItem.itemType].balanceOf(receivedItem.recipient);
        }

        if (receivedItem.itemType === 2) { // ERC721
          receivedItem.ownsItemAfter = (
            await tokenByType[receivedItem.itemType].ownerOf(receivedItem.identifierOrCriteria)
          ) === receivedItem.recipient;
        }
      }

      const {timestamp} = await provider.getBlock(receipt.blockHash);

      for (offerredItem of allOfferedItems) {
        const duration = ethers.BigNumber.from(offerredItem.endTime).sub(offerredItem.startTime);
        const elapsed = ethers.BigNumber.from(timestamp).sub(offerredItem.startTime);
        const remaining = duration.sub(elapsed);

        if (offeredItem.itemType < 4) { // TODO: criteria-based
          if (!additonalPayouts) {
            expect(offerredItem.initialBalance.sub(offerredItem.finalBalance).toString()).to.equal(
              (ethers.BigNumber.from(offerredItem.startAmount).mul(remaining).add(ethers.BigNumber.from(offerredItem.endAmount).mul(elapsed))).div(duration).mul(offerredItem.numerator).div(offerredItem.denominator).toString()
            );
          } else {
            expect(offerredItem.initialBalance.sub(offerredItem.finalBalance).toString()).to.equal(additonalPayouts.add(offerredItem.endAmount).toString());
          }
        }

        if (offeredItem.itemType === 2) { // ERC721
          expect(offeredItem.ownsItemBefore).to.equal(true);
          expect(offeredItem.ownsItemAfter).to.equal(false);
        }
      }

      for (receivedItem of allReceivedItems) {
        const duration = ethers.BigNumber.from(receivedItem.endTime).sub(receivedItem.startTime);
        const elapsed = ethers.BigNumber.from(timestamp).sub(receivedItem.startTime);
        const remaining = duration.sub(elapsed);

        expect(
          receivedItem.finalBalance.sub(receivedItem.initialBalance).toString()
        ).to.equal(
          (ethers.BigNumber.from(receivedItem.startAmount).mul(remaining).add(ethers.BigNumber.from(receivedItem.endAmount).mul(elapsed)).add(duration.sub(1))).div(duration).mul(receivedItem.numerator).div(receivedItem.denominator).toString()
        );

        if (receivedItem.itemType === 2) { // ERC721
          expect(receivedItem.ownsItemBefore).to.equal(false);
          expect(receivedItem.ownsItemAfter).to.equal(true);
        }
      }

      return receipt;
    };

    simulateMatchOrders = async (
      orders,
      fulfillments,
      caller,
      value,
    ) => {
      return marketplaceContract.connect(caller).callStatic.matchOrders(orders, fulfillments, {value});
    }

    simulateAdvancedMatchOrders = async (
      orders,
      criteriaResolvers,
      fulfillments,
      caller,
      value,
    ) => {
      return marketplaceContract.connect(caller).callStatic.matchAdvancedOrders(orders, criteriaResolvers, fulfillments, {value});
    }
  });

  describe("Getter tests", async () => {
    it("gets correct name", async () => {
      const name = await marketplaceContract.name();
      expect(name).to.equal("Consideration");
    });
    it("gets correct version", async () => {
      const version = await marketplaceContract.version();
      expect(version).to.equal(VERSION);
    });
    it("gets correct domain separator", async () => {
      const name = await marketplaceContract.name();
      const version = await marketplaceContract.version();
      const domainSeparator = await marketplaceContract.DOMAIN_SEPARATOR();
      const typehash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
      ));
      const namehash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
      const versionhash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(version));
      const {chainId} = await provider.getNetwork();
      const chainIdEncoded = chainId.toString(16).padStart(64, '0');
      const addressEncoded = marketplaceContract.address.slice(2).padStart(64, '0');
      expect(domainSeparator).to.equal(ethers.utils.keccak256(
        `0x${typehash.slice(2)}${namehash.slice(2)}${versionhash.slice(2)}${chainIdEncoded}${addressEncoded}`
      ))
    });
  });

  // Buy now or accept offer for a single ERC721 or ERC1155 in exchange for
  // ETH, WETH or ERC20
  describe("Basic buy now or accept offer flows", async () => {
    let seller;
    let sellerProxy;
    let sellerContract;
    let buyerContract;
    let buyer;
    let buyerProxy;

    beforeEach(async () => {
      // Setup basic buyer/seller wallets with ETH
      seller = ethers.Wallet.createRandom().connect(provider);
      buyer = ethers.Wallet.createRandom().connect(provider);
      zone = ethers.Wallet.createRandom().connect(provider);

      sellerContract = await EIP1271WalletFactory.deploy(seller.address);
      buyerContract = await EIP1271WalletFactory.deploy(buyer.address);

      await Promise.all(
        [seller, buyer, zone, sellerContract, buyerContract].map(
          (wallet) => faucet(wallet.address, provider)
        )
      );

      // Seller deploys legacy proxy
      await whileImpersonating(seller.address, provider, async () => {
        const tx = await legacyProxyRegistry.connect(seller).registerProxy();
        const receipt = await tx.wait();

        sellerProxy = receipt.events[0].address;

        const userProxy = ownedUpgradeabilityProxy.attach(sellerProxy);
        const proxyDeploymentEvent = userProxy.interface.parseLog(receipt.events[0]);
        expect(proxyDeploymentEvent.name).to.equal("Upgraded");
        expect(proxyDeploymentEvent.args.implementation).to.equal(legacyProxyImplementation);
        const proxyOwner = await userProxy.proxyOwner();
        expect(proxyOwner).to.equal(seller.address);
        const registeredProxy = await legacyProxyRegistry.proxies(seller.address);
        expect(registeredProxy).to.equal(sellerProxy);
      });

      // Buyer deploys legacy proxy
      await whileImpersonating(buyer.address, provider, async () => {
        const tx = await legacyProxyRegistry.connect(buyer).registerProxy();
        const receipt = await tx.wait();

        buyerProxy = receipt.events[0].address;

        const userProxy = ownedUpgradeabilityProxy.attach(buyerProxy);
        const proxyDeploymentEvent = userProxy.interface.parseLog(receipt.events[0]);
        expect(proxyDeploymentEvent.name).to.equal("Upgraded");
        expect(proxyDeploymentEvent.args.implementation).to.equal(legacyProxyImplementation);
        const proxyOwner = await userProxy.proxyOwner();
        expect(proxyOwner).to.equal(buyer.address);
        const registeredProxy = await legacyProxyRegistry.proxies(buyer.address);
        expect(registeredProxy).to.equal(buyerProxy);
      });
    });

    describe("A single ERC721 is to be transferred", async () => {
      describe("[Buy now] User fullfills a sell order for a single ERC721", async () => {
        it("ERC721 <=> ETH (standard)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          ];

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
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (standard via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves their proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
          });

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
            4, // FULL_OPEN_VIA_PROXY
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          ];

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
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ]);

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, { value });
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves their proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
          });

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
            4, // FULL_OPEN_VIA_PROXY
          );

      /*     const basicOrderParameters = {
            offerer: order.parameters.offerer,
            zone: order.parameters.zone,
            orderType: order.parameters.orderType,
            token: order.parameters.offer[0].token,
            identifier: order.parameters.offer[0].identifierOrCriteria,
            startTime: order.parameters.startTime,
            endTime: order.parameters.endTime,
            salt: order.parameters.salt,
            signature: order.signature,
            additionalRecipients: [
              {
                amount: ethers.utils.parseEther("1"),
                recipient: zone.address,
              },
              {
                amount: ethers.utils.parseEther("1"),
                recipient: owner.address,
              }
            ],
          }; */


          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ])

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value});
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          ];

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
          );

          // Validate the order from any account
          await whileImpersonating(owner.address, provider, async () => {
            await expect(marketplaceContract.connect(owner).validate([order]))
              .to.emit(marketplaceContract, "OrderValidated")
              .withArgs(orderHash, seller.address, zone.address);
          });

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ])

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value});
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          ];

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
          );

          // Convert signature to EIP 2098
          expect(order.signature.length).to.equal(132);
          order.signature = convertSignatureToEIP2098(order.signature);
          expect(order.signature.length).to.equal(130);

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ])

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value});
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          ];

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
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ])

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value: value.add(1)});
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          ];

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
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it("ERC721 <=> ETH (match via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves their proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
          });

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
            4, // FULL_OPEN_VIA_PROXY
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it("ERC721 <=> ETH (match, extra eth supplied and returned to caller)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          ];

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
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value: value.add(101)});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (standard)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
          });

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
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            0, // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (standard via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves their proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
          });

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
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            4, // FULL_OPEN_VIA_PROXY
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
          });

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
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            0, // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.BigNumber.from(50),
              recipient: zone.address,
            },
            {
              amount: ethers.BigNumber.from(50),
              recipient: owner.address,
            }
          ]);

          // basicOrderParameters.receivedAmount = basicOrderParameters.receivedAmount.sub(100);

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC20ForERC721Order(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (basic via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves their proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
          });

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
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            4, // FULL_OPEN_VIA_PROXY
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.BigNumber.from(50),
              recipient: zone.address,
            },
            {
              amount: ethers.BigNumber.from(50),
              recipient: owner.address,
            }
          ])

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC20ForERC721Order(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(sellerContract.connect(seller).approveNFT(testERC721.address, marketplaceContract.address))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(sellerContract.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
          });

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
            seller
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.BigNumber.from(50),
              recipient: zone.address,
            },
            {
              amount: ethers.BigNumber.from(50),
              recipient: owner.address,
            }
          ])

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC20ForERC721Order(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
          });

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
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            0, // FULL_OPEN
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (match via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(seller.address, nftId);

          // Seller approves their proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
          });

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
            {
              itemType: 1, // ERC20
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            4, // FULL_OPEN_VIA_PROXY
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
            await expect(testERC721.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
          });

          // Buyer approves marketplace contract to transfer ERC20 tokens too
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
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
              itemType: 2, // ERC721
              token: testERC721.address,
              identifierOrCriteria: nftId,
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
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
            0, // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (standard, fulfilled via proxy)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves proxy contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC721.connect(buyer).setApprovalForAll(buyerProxy, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, buyerProxy, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
          });

          // Buyer approves marketplace contract to transfer ERC20 tokens too
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
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
              itemType: 2, // ERC721
              token: testERC721.address,
              identifierOrCriteria: nftId,
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
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
            0, // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, true);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC721.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge());
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
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
              itemType: 2, // ERC721
              token: testERC721.address,
              identifierOrCriteria: nftId,
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
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
            0, // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.BigNumber.from(50),
              recipient: zone.address,
            },
            {
              amount: ethers.BigNumber.from(50),
              recipient: owner.address,
            }
          ]);

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], ethers.BigNumber.from(0), null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC721ForERC20Order(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (basic, fulfilled via proxy)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves proxy contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC721.connect(buyer).setApprovalForAll(buyerProxy, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, buyerProxy, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge());
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
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
              itemType: 2, // ERC721
              token: testERC721.address,
              identifierOrCriteria: nftId,
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
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
            0, // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.BigNumber.from(50),
              recipient: zone.address,
            },
            {
              amount: ethers.BigNumber.from(50),
              recipient: owner.address,
            }
          ], true);

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], ethers.BigNumber.from(0), null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC721ForERC20Order(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC721 <=> ERC20 (match)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves marketplace contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC721.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
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
              itemType: 2, // ERC721
              token: testERC721.address,
              identifierOrCriteria: nftId,
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
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
            0, // FULL_OPEN
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (match via proxy)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          await testERC721.mint(buyer.address, nftId);

          // Buyer approves proxy contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC721.connect(buyer).setApprovalForAll(buyerProxy, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(buyer.address, buyerProxy, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
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
              itemType: 2, // ERC721
              token: testERC721.address,
              identifierOrCriteria: nftId,
              startAmount: ethers.BigNumber.from(1),
              endAmount: ethers.BigNumber.from(1),
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
            0, // FULL_OPEN
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            [],
            true // use proxy
          );

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
            await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ETH (standard via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC1155.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
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
            4, // FULL_OPEN_VIA_PROXY
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ])

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC1155Order(basicOrderParameters, {value});
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            })
          });
        });
        it("ERC1155 <=> ETH (basic via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC1155.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
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
            4, // FULL_OPEN_VIA_PROXY
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ])

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC1155Order(basicOrderParameters, {value});
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            })
          });
        });
        it("ERC1155 <=> ETH (match)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it("ERC1155 <=> ETH (match via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC1155.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
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
            4, // FULL_OPEN_VIA_PROXY
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
            await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
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
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            0, // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (standard via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC1155.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
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
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            4, // FULL_OPEN_VIA_PROXY
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
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
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            0, // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.BigNumber.from(50),
              recipient: zone.address,
            },
            {
              amount: ethers.BigNumber.from(50),
              recipient: owner.address,
            }
          ]);

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC20ForERC1155Order(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (basic via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC1155.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
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
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            4, // FULL_OPEN_VIA_PROXY
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.BigNumber.from(50),
              recipient: zone.address,
            },
            {
              amount: ethers.BigNumber.from(50),
              recipient: owner.address,
            }
          ]);

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC20ForERC1155Order(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
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
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            0, // FULL_OPEN
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (match via proxy)", async () => {
          // Seller mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller approves proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC1155.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
          });

          // Buyer mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Buyer approves marketplace contract to transfer tokens
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
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
              token: testERC20.address,
              identifierOrCriteria: 0, // ignored for ERC20
              startAmount: tokenAmount.sub(100),
              endAmount: tokenAmount.sub(100),
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
            4, // FULL_OPEN_VIA_PROXY
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
            await expect(testERC1155.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
          });

          // Buyer approves marketplace contract to transfer ERC20 tokens too
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
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
            0, // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (standard, fulfilled via proxy)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(buyer.address, nftId, amount);

          // Buyer approves proxy contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC1155.connect(buyer).setApprovalForAll(buyerProxy, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, buyerProxy, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
          });

          // Buyer approves marketplace contract to transfer ERC20 tokens too
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
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
            0, // FULL_OPEN
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, true);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await expect(testERC1155.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge());
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
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
            0, // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.BigNumber.from(50),
              recipient: zone.address,
            },
            {
              amount: ethers.BigNumber.from(50),
              recipient: owner.address,
            }
          ]);

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], ethers.BigNumber.from(0), null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC1155ForERC20Order(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (basic, fulfilled via proxy)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(buyer.address, nftId, amount);

          // Buyer approves proxy contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC1155.connect(buyer).setApprovalForAll(buyerProxy, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, buyerProxy, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge());
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
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
            0, // FULL_OPEN
          );

          const basicOrderParameters = getBasicOrderParameters(order, [
            {
              amount: ethers.BigNumber.from(50),
              recipient: zone.address,
            },
            {
              amount: ethers.BigNumber.from(50),
              recipient: owner.address,
            }
          ], true);

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], ethers.BigNumber.from(0), null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC1155ForERC20Order(basicOrderParameters);
              const receipt = await tx.wait();
              await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
              return receipt;
            });
          });
        });
        it("ERC1155 <=> ERC20 (match)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(buyer.address, nftId, amount);

          // Buyer approves marketplace contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC1155.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, marketplaceContract.address, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
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
            0, // FULL_OPEN
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order
          );

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (match via proxy)", async () => {
          // Buyer mints nft
          const nftId = ethers.BigNumber.from(randomHex());
          const amount = ethers.BigNumber.from(randomHex());
          await testERC1155.mint(buyer.address, nftId, amount);

          // Buyer approves proxy contract to transfer NFT
          await whileImpersonating(buyer.address, provider, async () => {
            await expect(testERC1155.connect(buyer).setApprovalForAll(buyerProxy, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, buyerProxy, true);
          });

          // Seller mints ERC20
          const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
          await testERC20.mint(seller.address, tokenAmount);

          // Seller approves marketplace contract to transfer tokens
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, marketplaceContract.address, tokenAmount);
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
            0, // FULL_OPEN
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            [],
            true // use proxy
          );

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(0);
          expect(standardExecutions.length).to.equal(4);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments);
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
        );

        const signature = order.signature;

        const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;

        // cannot fill it with no signature yet
        order.signature = "0x";
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value})).to.be.reverted;
        });

        // cannot validate it with no signature from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.be.reverted;
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

        // Fulfill the order without a signature
        order.signature = "0x";
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
            return receipt;
          });
        });

        const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(finalStatus.isValidated).to.be.true;
        expect(finalStatus.isCancelled).to.be.false;
        expect(finalStatus.totalFilled.toString()).to.equal("1");
        expect(finalStatus.totalSize.toString()).to.equal("1");
      });
      it("Validate unsigned order from offerer and fill it with no signature", async () => {
        // Seller mints an nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
        );

        order.signature = "0x";

        const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;

        // cannot fill it with no signature yet
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value})).to.be.reverted;
        });

        // cannot validate it with no signature from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.be.reverted;
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
            const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        const signature = order.signature;

        order.signature = "0x";

        const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;

        // cannot fill it with no signature yet
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value})).to.be.reverted;
        });

        // cannot validate it with no signature from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.be.reverted;
        });

        // can cancel it
        await whileImpersonating(seller.address, provider, async () => {
          await expect(marketplaceContract.connect(seller).cancel([orderComponents]))
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHash, seller.address, zone.address);
        });     

        // cannot validate it from the seller
        await whileImpersonating(seller.address, provider, async () => {
          await expect(marketplaceContract.connect(seller).validate([order]))
            .to.be.reverted;
        });

        // cannot validate it with a signature either
        order.signature = signature;
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.be.reverted;
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        // cannot cancel it from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).cancel([orderComponents]))
            .to.be.reverted;
        }); 

        const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;
        expect(initialStatus.totalFilled.toString()).to.equal("0");
        expect(initialStatus.totalSize.toString()).to.equal("0");

        // can cancel it
        await whileImpersonating(seller.address, provider, async () => {
          await expect(marketplaceContract.connect(seller).cancel([orderComponents]))
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHash, seller.address, zone.address);
        }); 

        // cannot fill the order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value}))
            .to.be.reverted;
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        // cannot cancel it from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).cancel([orderComponents]))
            .to.be.reverted;
        }); 

        const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
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
          await expect(marketplaceContract.connect(seller).cancel([orderComponents]))
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHash, seller.address, zone.address);
        }); 

        // cannot fill the order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value}))
            .to.be.reverted;
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        // cannot cancel it from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).cancel([orderComponents]))
            .to.be.reverted;
        }); 

        const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(initialStatus.isValidated).to.be.false;
        expect(initialStatus.isCancelled).to.be.false;
        expect(initialStatus.totalFilled.toString()).to.equal("0");
        expect(initialStatus.totalSize.toString()).to.equal("0");

        // can cancel it from the zone
        await whileImpersonating(zone.address, provider, async () => {
          await expect(marketplaceContract.connect(zone).cancel([orderComponents]))
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHash, seller.address, zone.address);
        }); 

        // cannot fill the order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value}))
            .to.be.reverted;
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        const initialStatus = await marketplaceContract.getOrderStatus(orderHash);
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
          await expect(marketplaceContract.connect(owner).cancel([orderComponents]))
            .to.be.reverted;
        }); 

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(newStatus.isValidated).to.be.true;
        expect(newStatus.isCancelled).to.be.false;
        expect(newStatus.totalFilled.toString()).to.equal("0");
        expect(newStatus.totalSize.toString()).to.equal("0");

        // can cancel it from the zone
        await whileImpersonating(zone.address, provider, async () => {
          await expect(marketplaceContract.connect(zone).cancel([orderComponents]))
            .to.emit(marketplaceContract, "OrderCancelled")
            .withArgs(orderHash, seller.address, zone.address);
        }); 

        // cannot fill the order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value}))
            .to.be.reverted;
        });

        const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect(finalStatus.isValidated).to.be.false;
        expect(finalStatus.isCancelled).to.be.true;
        expect(finalStatus.totalFilled.toString()).to.equal("0");
        expect(finalStatus.totalSize.toString()).to.equal("0");
      });
      it.skip("Can cancel an order signed with a nonce ahead of the current nonce", async () => {
      });
    });

    describe("Increment Nonce", async () => {
      it("Can increment the nonce", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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

        let { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        const nonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(nonce).to.equal(0);
        expect(orderComponents.nonce).to.equal(nonce);

        // cannot increment the nonce from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).incrementNonce(seller.address, zone.address))
            .to.be.reverted;
        });

        const sameNonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(sameNonce).to.equal(0);

        // can increment the nonce
        await whileImpersonating(seller.address, provider, async () => {
          await expect(marketplaceContract.connect(seller).incrementNonce(seller.address, zone.address))
            .to.emit(marketplaceContract, "NonceIncremented")
            .withArgs(1, seller.address, zone.address);
        });

        const newNonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(newNonce).to.equal(1);

        // Cannot fill order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value}))
            .to.be.reverted;
        });

        const newOrderDetails = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        order = newOrderDetails.order;
        orderHash = newOrderDetails.orderHash;
        value = newOrderDetails.value;
        orderComponents = newOrderDetails.orderComponents;

        expect(orderComponents.nonce).to.equal(newNonce);

        // Can fill order with new nonce
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
            return receipt;
          });
        });
      });
      it("Can increment the nonce as the zone", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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

        let { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        const nonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(nonce).to.equal(0);
        expect(orderComponents.nonce).to.equal(nonce);

        // cannot increment the nonce from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).incrementNonce(seller.address, zone.address))
            .to.be.reverted;
        });

        const sameNonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(sameNonce).to.equal(0);

        // can increment the nonce as the zone
        await whileImpersonating(zone.address, provider, async () => {
          await expect(marketplaceContract.connect(zone).incrementNonce(seller.address, zone.address))
            .to.emit(marketplaceContract, "NonceIncremented")
            .withArgs(1, seller.address, zone.address);
        });

        const newNonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(newNonce).to.equal(1);

        // Cannot fill order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value}))
            .to.be.reverted;
        });

        const newOrderDetails = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        order = newOrderDetails.order;
        orderHash = newOrderDetails.orderHash;
        value = newOrderDetails.value;
        orderComponents = newOrderDetails.orderComponents;

        expect(orderComponents.nonce).to.equal(newNonce);

        // Can fill order with new nonce
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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

        let { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        const nonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(nonce).to.equal(0);
        expect(orderComponents.nonce).to.equal(nonce);

        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, zone.address);
        });

        // cannot increment the nonce from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).incrementNonce(seller.address, zone.address))
            .to.be.reverted;
        });

        const sameNonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(sameNonce).to.equal(0);

        // can increment the nonce
        await whileImpersonating(seller.address, provider, async () => {
          await expect(marketplaceContract.connect(seller).incrementNonce(seller.address, zone.address))
            .to.emit(marketplaceContract, "NonceIncremented")
            .withArgs(1, seller.address, zone.address);
        });

        const newNonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(newNonce).to.equal(1);

        // Cannot fill order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value}))
            .to.be.reverted;
        });

        const newOrderDetails = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        order = newOrderDetails.order;
        orderHash = newOrderDetails.orderHash;
        value = newOrderDetails.value;
        orderComponents = newOrderDetails.orderComponents;

        expect(orderComponents.nonce).to.equal(newNonce);

        // Can fill order with new nonce
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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

        let { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        const nonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(nonce).to.equal(0);
        expect(orderComponents.nonce).to.equal(nonce);

        // cannot increment the nonce from a random account
        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).incrementNonce(seller.address, zone.address))
            .to.be.reverted;
        });

        const sameNonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(sameNonce).to.equal(0);

        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, zone.address);
        });

        // can increment the nonce as the zone
        await whileImpersonating(zone.address, provider, async () => {
          await expect(marketplaceContract.connect(zone).incrementNonce(seller.address, zone.address))
            .to.emit(marketplaceContract, "NonceIncremented")
            .withArgs(1, seller.address, zone.address);
        });

        const newNonce = await marketplaceContract.getNonce(
          seller.address, zone.address
        );
        expect(newNonce).to.equal(1);

        // Cannot fill order anymore
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value}))
            .to.be.reverted;
        });

        const newOrderDetails = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        order = newOrderDetails.order;
        orderHash = newOrderDetails.orderHash;
        value = newOrderDetails.value;
        orderComponents = newOrderDetails.orderComponents;

        expect(orderComponents.nonce).to.equal(newNonce);

        // Can fill order with new nonce
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
            return receipt;
          });
        });
      });
      it.skip("Can increment nonce and activate an order signed with a nonce ahead of the current nonce", async () => {
      });
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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          1, // PARTIAL_OPEN
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
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
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
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
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

          for (const [j, offerItem] of Object.entries(clonedOrder.parameters.offer)) {
            offerItem.startAmount = order.parameters.offer[j].startAmount;
            offerItem.endAmount = order.parameters.offer[j].endAmount;
          }

          for (const [j, considerationItem] of Object.entries(clonedOrder.parameters.consideration)) {
            considerationItem.startAmount = order.parameters.consideration[j].startAmount;
            considerationItem.endAmount = order.parameters.consideration[j].endAmount;
          }
        }

        ordersClone[0].numerator = 3;
        ordersClone[0].denominator = 10;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(ordersClone, 0, [], async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order: ordersClone[0], orderHash, fulfiller: buyer.address}], null, null, []);
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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          1, // PARTIAL_OPEN
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
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
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
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
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

          for (const [j, offerItem] of Object.entries(clonedOrder.parameters.offer)) {
            offerItem.startAmount = order.parameters.offer[j].startAmount;
            offerItem.endAmount = order.parameters.offer[j].endAmount;
          }

          for (const [j, considerationItem] of Object.entries(clonedOrder.parameters.consideration)) {
            considerationItem.startAmount = order.parameters.consideration[j].startAmount;
            considerationItem.endAmount = order.parameters.consideration[j].endAmount;
          }
        }

        ordersClone[0].numerator = 7;
        ordersClone[0].denominator = 10;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(ordersClone, 0, [], async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order: ordersClone[0], orderHash, fulfiller: buyer.address}], null, null, []);
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(10);
        expect(orderStatus.totalSize).to.equal(10);
      });
      it.skip("Partial fills (match)", async () => {
      });
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const {root, proofs} = merkleTree(tokenIds);

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

          const criteriaResolvers = [
            {
              orderIndex: 0,
              side: 0, // offer
              index: 0,
              identifier: nftId,
              criteriaProof: proofs[nftId.toString()],
            }
          ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers,
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, criteriaResolvers, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, criteriaResolvers, false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, criteriaResolvers);
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const {root, proofs} = merkleTree(tokenIds);

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

        const criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          }
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers,
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorAcceptOfferOrder(
          buyer,
          zone,
          order,
          criteriaResolvers
        );

        const fulfillments = [
          {
            "offerComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              }
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 0
              }
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 1
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 1
              }
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 2
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 2
              }
            ]
          }
        ];

        const {
          standardExecutions,
          batchExecutions
        } = await simulateAdvancedMatchOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          owner,
          value
        );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract.connect(owner).matchAdvancedOrders([order, mirrorOrder], criteriaResolvers, fulfillments, {value});
          const receipt = await tx.wait();
          await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions, criteriaResolvers);
          await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
          await expect(testERC721.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(buyer.address, marketplaceContract.address, true);
        });

        const {root, proofs} = merkleTree(tokenIds);

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
          }
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers,
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], value.mul(-1), criteriaResolvers, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, criteriaResolvers, false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, criteriaResolvers);
            return receipt;
          });
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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
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
          await expect(testERC20.connect(seller).approve(marketplaceContract.address, tokenAmount))
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
          await expect(testERC1155.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(buyer.address, marketplaceContract.address, true);
        });

        // Buyer needs to approve marketplace to transfer ERC20 tokens too (as it's a standard fulfillment)
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
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
          0, // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it.skip("Ascending offer amount (match)", async () => {});
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer approves marketplace contract to transfer NFTs
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(testERC721.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(buyer.address, marketplaceContract.address, true);
        });

        // Owner approves marketplace contract to transfer NFTs
        await whileImpersonating(owner.address, provider, async () => {
          await expect(testERC721.connect(owner).setApprovalForAll(marketplaceContract.address, true))
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

        const { order: orderOne, orderHash: orderHashOne, value: valueOne, } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0, // FULL_OPEN
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

        const { order: orderTwo, orderHash: orderHashTwo, value: valueTwo } = await createOrder(
          buyer,
          zone,
          offerTwo,
          considerationTwo,
          0, // FULL_OPEN
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

        const { order: orderThree, orderHash: orderHashThree, value: valueThree } = await createOrder(
          owner,
          zone,
          offerThree,
          considerationThree,
          0, // FULL_OPEN
        );

        const fulfillments = [
          {
            "offerComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              }
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 2,
                "itemIndex": 0
              }
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 2,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 0
              }
            ]
          },
        ];

        const {
          standardExecutions,
          batchExecutions
        } = await simulateAdvancedMatchOrders(
          [orderOne, orderTwo, orderThree],
          [], // no criteria resolvers
          fulfillments,
          owner,
          0  // no value
        );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(fulfillments.length);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract.connect(owner).matchAdvancedOrders([orderOne, orderTwo, orderThree], [], fulfillments, {value: 0});
          const receipt = await tx.wait();
          await checkExpectedEvents(receipt, [{order: orderOne, orderHash: orderHashOne, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          await checkExpectedEvents(receipt, [{order: orderTwo, orderHash: orderHashTwo, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          await checkExpectedEvents(receipt, [{order: orderThree, orderHash: orderHashThree, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer approves marketplace contract to transfer NFTs
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(testERC721.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
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

        const considerationOne = [
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("10"),
            endAmount: ethers.utils.parseEther("10"),
            recipient: seller.address,
          },
        ];

        const { order: orderOne, orderHash: orderHashOne, value: valueOne, } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0, // FULL_OPEN
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

        const { order: orderTwo, orderHash: orderHashTwo, value: valueTwo } = await createOrder(
          seller,
          zone,
          offerTwo,
          considerationTwo,
          0, // FULL_OPEN
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

        const { order: orderThree, orderHash: orderHashThree, value: valueThree } = await createOrder(
          buyer,
          zone,
          offerThree,
          considerationThree,
          0, // FULL_OPEN
        );

        const fulfillments = [
          {
            "offerComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              }
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 2,
                "itemIndex": 0
              }
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 2,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 0
              }
            ]
          },
        ];

        const {
          standardExecutions,
          batchExecutions
        } = await simulateAdvancedMatchOrders(
          [orderOne, orderTwo, orderThree],
          [], // no criteria resolvers
          fulfillments,
          owner,
          0  // no value
        );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(fulfillments.length - 1);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract.connect(owner).matchAdvancedOrders([orderOne, orderTwo, orderThree], [], fulfillments, {value: 0});
          const receipt = await tx.wait();
          await checkExpectedEvents(receipt, [{order: orderOne, orderHash: orderHashOne, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          await checkExpectedEvents(receipt, [{order: orderTwo, orderHash: orderHashTwo, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          await checkExpectedEvents(receipt, [{order: orderThree, orderHash: orderHashThree, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20s
        const tokenAmount = ethers.BigNumber.from(randomLarge());
        await testERC20.mint(buyer.address, tokenAmount.mul(2));

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount.mul(2)))
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount.mul(2));
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

        const { order: orderOne, orderHash: orderHashOne, value: valueOne, } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0, // FULL_OPEN
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

        const { order: orderTwo, orderHash: orderHashTwo, value: valueTwo } = await createOrder(
          seller,
          zone,
          offerTwo,
          considerationTwo,
          0, // FULL_OPEN
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

        const { order: orderThree, orderHash: orderHashThree, value: valueThree } = await createOrder(
          buyer,
          zone,
          offerThree,
          considerationThree,
          0, // FULL_OPEN
        );

        const fulfillments = [
          {
            "offerComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              },
              {
                "orderIndex": 1,
                "itemIndex": 0
              },
            ],
            "considerationComponents": [
              {
                "orderIndex": 2,
                "itemIndex": 0
              }
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 2,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              }
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 2,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 0
              }
            ]
          },
        ];

        const {
          standardExecutions,
          batchExecutions
        } = await simulateAdvancedMatchOrders(
          [orderOne, orderTwo, orderThree],
          [], // no criteria resolvers
          fulfillments,
          owner,
          0  // no value
        );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(fulfillments.length);

        await whileImpersonating(buyer.address, provider, async () => {
          const tx = await marketplaceContract.connect(buyer).matchAdvancedOrders([orderOne, orderTwo, orderThree], [], fulfillments, {value: 0});
          const receipt = await tx.wait();
          await checkExpectedEvents(receipt, [{order: orderOne, orderHash: orderHashOne, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions, [], true);
          await checkExpectedEvents(receipt, [{order: orderTwo, orderHash: orderHashTwo, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions, [], true);
          await checkExpectedEvents(receipt, [{order: orderThree, orderHash: orderHashThree, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);

          expect(ethers.BigNumber.from('0x' + receipt.events[3].data.slice(66)).toString()).to.equal(amount.mul(2).toString());

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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20s
        const tokenAmount = ethers.BigNumber.from(randomLarge());
        await testERC20.mint(buyer.address, tokenAmount.mul(2));

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount.mul(2)))
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount.mul(2));
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

        const { order: orderOne, orderHash: orderHashOne, value: valueOne, } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0, // FULL_OPEN
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

        const { order: orderTwo, orderHash: orderHashTwo, value: valueTwo } = await createOrder(
          buyer,
          zone,
          offerTwo,
          considerationTwo,
          0, // FULL_OPEN
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

        const { order: orderThree, orderHash: orderHashThree, value: valueThree } = await createOrder(
          buyer,
          zone,
          offerThree,
          considerationThree,
          0, // FULL_OPEN
        );

        const fulfillments = [
          {
            "offerComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              },
            ],
            "considerationComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 0
              },
              {
                "orderIndex": 2,
                "itemIndex": 0
              },
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 1,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              }
            ]
          },
          {
            "offerComponents": [
              {
                "orderIndex": 2,
                "itemIndex": 0
              }
            ],
            "considerationComponents": [
              {
                "orderIndex": 0,
                "itemIndex": 0
              }
            ]
          },
        ];

        const {
          standardExecutions,
          batchExecutions
        } = await simulateAdvancedMatchOrders(
          [orderOne, orderTwo, orderThree],
          [], // no criteria resolvers
          fulfillments,
          owner,
          0  // no value
        );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(fulfillments.length);

        await whileImpersonating(buyer.address, provider, async () => {
          const tx = await marketplaceContract.connect(buyer).matchAdvancedOrders([orderOne, orderTwo, orderThree], [], fulfillments, {value: 0});
          const receipt = await tx.wait();
          await checkExpectedEvents(receipt, [{order: orderOne, orderHash: orderHashOne, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          await checkExpectedEvents(receipt, [{order: orderTwo, orderHash: orderHashTwo, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions, [], true);
          await checkExpectedEvents(receipt, [{order: orderThree, orderHash: orderHashThree, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions, [], true);

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
            await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
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

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(1);
          expect(standardExecutions.length).to.equal(3);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it("ERC1155 <=> ETH (match via proxy)", async () => {
          // Seller deploys legacy proxy
          await whileImpersonating(seller.address, provider, async () => {
            const tx = await legacyProxyRegistry.connect(seller).registerProxy();
            const receipt = await tx.wait();

            sellerProxy = receipt.events[0].address;

            const userProxy = ownedUpgradeabilityProxy.attach(sellerProxy);
            const proxyDeploymentEvent = userProxy.interface.parseLog(receipt.events[0]);
            expect(proxyDeploymentEvent.name).to.equal("Upgraded");
            expect(proxyDeploymentEvent.args.implementation).to.equal(legacyProxyImplementation);
            const proxyOwner = await userProxy.proxyOwner();
            expect(proxyOwner).to.equal(seller.address);
            const registeredProxy = await legacyProxyRegistry.proxies(seller.address);
            expect(registeredProxy).to.equal(sellerProxy);
          });

          // Seller mints first nft
          const nftId = ethers.BigNumber.from(randomHex().slice(0, 10));
          const amount = ethers.BigNumber.from(randomHex().slice(0, 10));
          await testERC1155.mint(seller.address, nftId, amount);

          // Seller mints second nft
          const secondNftId = ethers.BigNumber.from(randomHex().slice(0, 10));
          const secondAmount = ethers.BigNumber.from(randomHex().slice(0, 10));
          await testERC1155.mint(seller.address, secondNftId, secondAmount);

          // Seller approves proxy contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC1155.connect(seller).setApprovalForAll(sellerProxy, true))
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(seller.address, sellerProxy, true);
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
            4, // FULL_OPEN_VIA_PROXY
          );

          const {
            mirrorOrder,
            mirrorOrderHash,
            mirrorValue,
          } = await createMirrorBuyNowOrder(
            buyer,
            zone,
            order
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

          const {
            standardExecutions,
            batchExecutions
          } = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(batchExecutions.length).to.equal(1);
          expect(standardExecutions.length).to.equal(3);

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
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
        [seller, buyer, zone, sellerContract, buyerContract].map(
          (wallet) => faucet(wallet.address, provider)
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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          1, // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 0; 
        order.denominator = 10;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value})).to.be.reverted;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1; 
        order.denominator = 0;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value})).to.be.reverted;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 2; 
        order.denominator = 1;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value})).to.be.reverted;
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
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          1, // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1; 
        order.denominator = 8191;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value})).to.be.reverted;
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
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          0, // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        order.numerator = 1; 
        order.denominator = 2;

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value})).to.be.reverted;
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
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          1, // PARTIAL_OPEN
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
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(2);

        const basicOrderParameters = getBasicOrderParameters(order, [
          {
            amount: ethers.utils.parseEther("1"),
            recipient: zone.address,
          },
          {
            amount: ethers.utils.parseEther("1"),
            recipient: owner.address,
          }
        ])

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicEthForERC1155Order(basicOrderParameters, {value})).to.be.reverted;
        });
      });
      it("Reverts on fully filled order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          1, // PARTIAL_OPEN
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
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value})).to.be.reverted;
        });
      });
      it("Reverts on invalid submitter when required by order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
          2, // FULL_RESTRICTED
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = defaultBuyNowMirrorFulfillment;

        const {
          standardExecutions,
          batchExecutions
        } = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          zone,
          value
        );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
        });

        await whileImpersonating(zone.address, provider, async () => {
          const tx = await marketplaceContract.connect(zone).matchOrders([order, mirrorOrder], fulfillments, {value});
          const receipt = await tx.wait();
          await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          return receipt;
        });
      });
      it("Reverts on invalid signatures", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
        );

        const originalSignature = order.signature;

        const originalV = order.signature.slice(-2);

        // set an invalid V value
        order.signature = order.signature.slice(0, -2) + '01';

        const basicOrderParameters = {
          offerer: order.parameters.offerer,
          zone: order.parameters.zone,
          orderType: order.parameters.orderType,
          offeredToken: order.parameters.offer[0].token,
          offeredIdentifier: order.parameters.offer[0].identifierOrCriteria,
          offeredAmount: 1,
          receivedToken: constants.AddressZero,
          receivedIdentifier: constants.Zero,
          receivedAmount: order.parameters.consideration[0].endAmount,
          startTime: order.parameters.startTime,
          endTime: order.parameters.endTime,
          salt: order.parameters.salt,
          signature: order.signature,
          useFulfillerProxy: false,
          additionalRecipients: [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ],
        };

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value})).to.be.reverted;
        });

        //construct an invalid signature
        basicOrderParameters.signature = '0x'.padEnd(130, 'f') + '1c';

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value})).to.be.reverted;
        });

        basicOrderParameters.signature = originalSignature;

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
          await expect(sellerContract.connect(seller).approveNFT(testERC721.address, marketplaceContract.address))
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(sellerContract.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        });

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

        const basicOrderParameters = getBasicOrderParameters(order, [
          {
            amount: ethers.BigNumber.from(40),
            recipient: zone.address,
          },
          {
            amount: ethers.BigNumber.from(60),
            recipient: owner.address,
          }
        ])

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicERC20ForERC721Order(basicOrderParameters)).to.be.reverted;
        });
      });
      it("Reverts on invalid 1271 signature and contract does not supply a revert reason", async () => {
        await whileImpersonating(owner.address, provider, async () => {
          const tx = await sellerContract.connect(owner).revertWithMessage(false);
          const receipt = await tx.wait();
        });

        // Seller mints nft to contract
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(sellerContract.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(sellerContract.connect(seller).approveNFT(testERC721.address, marketplaceContract.address))
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(sellerContract.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        });

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

        const basicOrderParameters = getBasicOrderParameters(order, [
          {
            amount: ethers.BigNumber.from(50),
            recipient: zone.address,
          },
          {
            amount: ethers.BigNumber.from(50),
            recipient: owner.address,
          }
        ])

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicERC20ForERC721Order(basicOrderParameters)).to.be.reverted;
        });
      });
      it("Reverts on missing offer or consideration components", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        let fulfillments = [
          {
            offerComponents: [],
            considerationComponents: [],
          },
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
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
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
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
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
        });

        fulfillments = defaultBuyNowMirrorFulfillment;

        const {
          standardExecutions,
          batchExecutions
        } = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
          const receipt = await tx.wait();
          await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          return receipt;
        });
      });
      it("Reverts on mismatched offer and consideration components", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

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
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
        });

        fulfillments = defaultBuyNowMirrorFulfillment;

        const {
          standardExecutions,
          batchExecutions
        } = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
          const receipt = await tx.wait();
          await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        let fulfillments = [
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
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          {
            itemType: 0, // ETH
            token: constants.AddressZero,
            identifierOrCriteria: 0, // ignored for ETH
            startAmount: ethers.utils.parseEther("10"),
            endAmount: ethers.utils.parseEther("10"),
            recipient: seller.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
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
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

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
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
        });
      });
      it("Reverts on fulfillment component with out-of-range order", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        let fulfillments = [
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
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
        });
      });
      it("Reverts on fulfillment component with out-of-range offer item", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        let fulfillments = [
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
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
        });
      });
      it("Reverts on fulfillment component with out-of-range consideration item", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

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
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const {root, proofs} = merkleTree(tokenIds);

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

        const criteriaResolvers = [
          {
            orderIndex: 0,
            side: 0, // offer
            index: 0,
            identifier: nftId,
            criteriaProof: proofs[nftId.toString()],
          }
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers,
        );

        criteriaResolvers[0].identifier = criteriaResolvers[0].identifier.add(1);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, criteriaResolvers, false, {value})).to.be.reverted;
        });

        criteriaResolvers[0].identifier = criteriaResolvers[0].identifier.sub(1);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, criteriaResolvers, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, criteriaResolvers, false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, criteriaResolvers);
            return receipt;
          });
        });
      });
      it("Reverts on invalid proxy implementation", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller deploys legacy proxy
        await whileImpersonating(seller.address, provider, async () => {
          const tx = await legacyProxyRegistry.connect(seller).registerProxy();
          const receipt = await tx.wait();

          sellerProxy = receipt.events[0].address;

          const userProxy = ownedUpgradeabilityProxy.attach(sellerProxy);
          const proxyDeploymentEvent = userProxy.interface.parseLog(receipt.events[0]);
          expect(proxyDeploymentEvent.name).to.equal("Upgraded");
          expect(proxyDeploymentEvent.args.implementation).to.equal(legacyProxyImplementation);
          const proxyOwner = await userProxy.proxyOwner();
          expect(proxyOwner).to.equal(seller.address);
          const registeredProxy = await legacyProxyRegistry.proxies(seller.address);
          expect(registeredProxy).to.equal(sellerProxy);
        });

        // Seller modifies their proxy implementation
        await whileImpersonating(seller.address, provider, async () => {
          const userProxy = ownedUpgradeabilityProxy.attach(sellerProxy);
          const tx = await userProxy.connect(seller).upgradeTo(marketplaceContract.address);
          const receipt = await tx.wait();

          const proxyDeploymentEvent = userProxy.interface.parseLog(receipt.events[0]);
          expect(proxyDeploymentEvent.name).to.equal("Upgraded");
          expect(proxyDeploymentEvent.args.implementation).to.equal(marketplaceContract.address);
          const proxyImplementation = await userProxy.implementation();
          expect(proxyImplementation).to.equal(marketplaceContract.address);
        });

        // Seller approves their proxy contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(sellerProxy, true))
            .to.emit(testERC721, "ApprovalForAll")
            .withArgs(seller.address, sellerProxy, true);
        });

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
          4, // FULL_OPEN_VIA_PROXY
        );

        const basicOrderParameters = {
          offerer: order.parameters.offerer,
          zone: order.parameters.zone,
          orderType: order.parameters.orderType,
          offeredToken: order.parameters.offer[0].token,
          offeredIdentifier: order.parameters.offer[0].identifierOrCriteria,
          offeredAmount: 1,
          receivedToken: constants.AddressZero,
          receivedIdentifier: constants.Zero,
          receivedAmount: order.parameters.consideration[0].endAmount,
          startTime: order.parameters.startTime,
          endTime: order.parameters.endTime,
          salt: order.parameters.salt,
          signature: order.signature,
          useFulfillerProxy: false,
          additionalRecipients: [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ],
        };

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value})).to.be.reverted;
        });

        // upgrade back
        await whileImpersonating(seller.address, provider, async () => {
          const userProxy = ownedUpgradeabilityProxy.attach(sellerProxy);
          const tx = await userProxy.connect(seller).upgradeTo(legacyProxyImplementation);
          const receipt = await tx.wait();

          const proxyDeploymentEvent = userProxy.interface.parseLog(receipt.events[0]);
          expect(proxyDeploymentEvent.name).to.equal("Upgraded");
          expect(proxyDeploymentEvent.args.implementation).to.equal(legacyProxyImplementation);
          const proxyImplementation = await userProxy.implementation();
          expect(proxyImplementation).to.equal(legacyProxyImplementation);
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value})).to.be.reverted;
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
          "NOT_STARTED"
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value})).to.be.reverted;
        });
      });
      it("Reverts on orders that have expired (standard)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
          "EXPIRED"
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value})).to.be.reverted;
        });
      });
      it("Reverts on orders that have not started (basic)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
          "NOT_STARTED"
        );

        const basicOrderParameters = {
          offerer: order.parameters.offerer,
          zone: order.parameters.zone,
          orderType: order.parameters.orderType,
          offeredToken: order.parameters.offer[0].token,
          offeredIdentifier: order.parameters.offer[0].identifierOrCriteria,
          offeredAmount: 1,
          receivedToken: constants.AddressZero,
          receivedIdentifier: constants.Zero,
          receivedAmount: order.parameters.consideration[0].endAmount,
          startTime: order.parameters.startTime,
          endTime: order.parameters.endTime,
          salt: order.parameters.salt,
          signature: order.signature,
          useFulfillerProxy: false,
          additionalRecipients: [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ],
        };

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value})).to.be.reverted;
        });
      });
      it("Reverts on orders that have expired (basic)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
          "EXPIRED"
        );

        const basicOrderParameters = {
          offerer: order.parameters.offerer,
          zone: order.parameters.zone,
          orderType: order.parameters.orderType,
          offeredToken: order.parameters.offer[0].token,
          offeredIdentifier: order.parameters.offer[0].identifierOrCriteria,
          offeredAmount: 1,
          receivedToken: constants.AddressZero,
          receivedIdentifier: constants.Zero,
          receivedAmount: order.parameters.consideration[0].endAmount,
          startTime: order.parameters.startTime,
          endTime: order.parameters.endTime,
          salt: order.parameters.salt,
          signature: order.signature,
          useFulfillerProxy: false,
          additionalRecipients: [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ],
        };

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value})).to.be.reverted;
        });
      });
      it("Reverts on orders that have not started (match)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
          "NOT_STARTED"
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = defaultBuyNowMirrorFulfillment;

        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
        });
      });
      it("Reverts on orders that have expired (match)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
          "EXPIRED"
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = defaultBuyNowMirrorFulfillment;

        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
        });
      });
    });

    describe("Insufficient amounts and bad items", async () => {
      it("Reverts when not enough ether is supplied (basic)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
        );

        const basicOrderParameters = {
          offerer: order.parameters.offerer,
          zone: order.parameters.zone,
          orderType: order.parameters.orderType,
          offeredToken: order.parameters.offer[0].token,
          offeredIdentifier: order.parameters.offer[0].identifierOrCriteria,
          offeredAmount: 1,
          receivedToken: constants.AddressZero,
          receivedIdentifier: constants.Zero,
          receivedAmount: order.parameters.consideration[0].endAmount,
          startTime: order.parameters.startTime,
          endTime: order.parameters.endTime,
          salt: order.parameters.salt,
          signature: order.signature,
          useFulfillerProxy: false,
          additionalRecipients: [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ],
        };

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value: ethers.BigNumber.from(1)})).to.be.reverted;
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value: value.sub(1)})).to.be.reverted;
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, null, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
          await expect(testERC721.connect(buyer).setApprovalForAll(marketplaceContract.address, true))
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
        );

        const basicOrderParameters = {
          offerer: order.parameters.offerer,
          zone: order.parameters.zone,
          orderType: order.parameters.orderType,
          token: order.parameters.offer[0].token,
          identifier: order.parameters.offer[0].identifierOrCriteria,
          startTime: order.parameters.startTime,
          endTime: order.parameters.endTime,
          salt: order.parameters.salt,
          signature: order.signature,
          additionalRecipients: [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ],
        };

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value: ethers.BigNumber.from(1)})).to.be.reverted;
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value: ethers.utils.parseEther("9.999999")})).to.be.reverted;
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], ethers.utils.parseEther("10").mul(-1), null, async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value: ethers.utils.parseEther("12")});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
            return receipt;
          });
        });
      });
      it("Reverts when not enough ether is supplied (standard + advanced)", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          0, // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value: ethers.BigNumber.from(1)})).to.be.reverted;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value: value.sub(1)})).to.be.reverted;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        // fulfill with a tiny bit extra to test for returning eth
        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value: value.add(1)});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = defaultBuyNowMirrorFulfillment;

        const {
          standardExecutions,
          batchExecutions
        } = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(batchExecutions.length).to.equal(0);
        expect(standardExecutions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value: ethers.BigNumber.from(1)})).to.be.reverted;
        });

        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value: value.sub(1)})).to.be.reverted;
        });

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
          const receipt = await tx.wait();
          await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          return receipt;
        });
      });
      it("Reverts when tokens are not approved", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          0, // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value})).to.be.reverted;
        });

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
        });

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
            return receipt;
          });
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(true);
        expect(orderStatus.totalFilled).to.equal(1);
        expect(orderStatus.totalSize).to.equal(1);
      });
      it("Reverts when ERC20 tokens return falsey values", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount.mul(10000));

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        // Buyer mints ERC20
        const tokenAmount = ethers.BigNumber.from(randomLarge()).add(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens
        await whileImpersonating(buyer.address, provider, async () => {
          await expect(testERC20.connect(buyer).approve(marketplaceContract.address, tokenAmount))
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
          0, // FULL_OPEN
        );

        // block transfers 
        await testERC20.blockTransfer(true);

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value})).to.be.reverted;
        });

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        await testERC20.blockTransfer(false);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks([order], 0, [], async () => {
            const tx = await marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value});
            const receipt = await tx.wait();
            await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}], null, null, []);
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
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
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
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
        });

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect(orderStatus.isCancelled).to.equal(false);
        expect(orderStatus.isValidated).to.equal(false);
        expect(orderStatus.totalFilled).to.equal(0);
        expect(orderStatus.totalSize).to.equal(0);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const {
          standardExecutions,
          batchExecutions
        } = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(batchExecutions.length).to.equal(1);
        expect(standardExecutions.length).to.equal(3);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
          const receipt = await tx.wait();
          await checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
          await checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          0, // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value})).to.be.reverted;
        });
      });
      it("Reverts when non-token account is supplied as the token", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        const amount = ethers.BigNumber.from(randomHex().slice(0, 5));
        await testERC1155.mint(seller.address, nftId, amount);

        // Seller approves marketplace contract to transfer NFTs
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
          0, // FULL_OPEN
        );

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillAdvancedOrder(order, [], false, {value})).to.be.reverted;
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
          await expect(testERC1155.connect(seller).setApprovalForAll(marketplaceContract.address, true))
            .to.emit(testERC1155, "ApprovalForAll")
            .withArgs(seller.address, marketplaceContract.address, true);
        });

        const offer = [
          {
            itemType: 3, // ERC1155
            token: marketplaceContract.address,
            identifierOrCriteria: nftId,
            startAmount: amount,
            endAmount: amount,
          },
          {
            itemType: 3, // ERC1155
            token: marketplaceContract.address,
            identifierOrCriteria: secondNftId,
            startAmount: secondAmount,
            endAmount: secondAmount,
          },
        ];

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
        );

        const {
          mirrorOrder,
          mirrorOrderHash,
          mirrorValue,
        } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
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
          await expect(marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value})).to.be.reverted;
        });

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

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
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
            recipient: marketplaceContract.address,
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
        );

        const basicOrderParameters = {
          offerer: order.parameters.offerer,
          zone: order.parameters.zone,
          orderType: order.parameters.orderType,
          offeredToken: order.parameters.offer[0].token,
          offeredIdentifier: order.parameters.offer[0].identifierOrCriteria,
          offeredAmount: 1,
          receivedToken: constants.AddressZero,
          receivedIdentifier: constants.Zero,
          receivedAmount: order.parameters.consideration[0].endAmount,
          startTime: order.parameters.startTime,
          endTime: order.parameters.endTime,
          salt: order.parameters.salt,
          signature: order.signature,
          useFulfillerProxy: false,
          additionalRecipients: [
            {
              amount: ethers.utils.parseEther("1"),
              recipient: zone.address,
            },
            {
              amount: ethers.utils.parseEther("1"),
              recipient: owner.address,
            }
          ],
        };

        await whileImpersonating(owner.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(basicOrderParameters, {value})).to.be.reverted;
        });
      });
    })

    describe("Reentrancy", async () => {
      it("Reverts on a reentrant call", async () => {
        // Seller mints nft
        const nftId = ethers.BigNumber.from(randomHex());
        await testERC721.mint(seller.address, nftId);

        // Seller approves marketplace contract to transfer NFT
        await whileImpersonating(seller.address, provider, async () => {
          await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
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
        ];

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
            recipient: reenterer.address,
          },
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
        );

        // prepare the reentrant call on the reenterer
        const callData = marketplaceContract.interface.encodeFunctionData("fulfillOrder", [order, false]);
        const tx = await reenterer.prepare(marketplaceContract.address, 0, callData);
        await tx.wait();

        await whileImpersonating(buyer.address, provider, async () => {
          await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value})).to.be.reverted;
        });
      });
      it.skip("Reverts on reentrancy (test all the other permutations)", async () => {});
    })
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
