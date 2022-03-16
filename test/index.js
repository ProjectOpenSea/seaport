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

describe("Consideration functional tests", function () {
  const provider = ethers.provider;
  let chainId;
  let marketplaceContract;
  let testERC20;
  let testERC721;
  let testERC1155;
  let tokenByType;
  let owner;
  let domainData;
  let withBalanceChecks;
  let simulateMatchOrders;
  let simulateAdvancedMatchOrders;

  const randomHex = () => (
    `0x${[...Array(64)].map(() => Math.floor(Math.random() * 16).toString(16)).join('')}`
  );

  const randomLarge = () => (
    `0x${[...Array(60)].map(() => Math.floor(Math.random() * 16).toString(16)).join('')}`
  );

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

  // Returns signature
  async function signOrder(
    orderComponents,
    signer
  ) {
    return await signer._signTypedData(
      domainData,
      orderType,
      orderComponents
    );
  }

  const createOrder = async (offerer, zone, offer, consideration, orderType, criteriaResolvers) => {
    const nonce = await marketplaceContract.getNonce(offerer.address, zone.address);
    const salt = randomHex();
    const startTime = 0;
    const endTime = ethers.BigNumber.from("0xff00000000000000000000000000");

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

    const orderHash = await marketplaceContract.getOrderHash(orderComponents);

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

    const flatSig = await signOrder(orderComponents, offerer);

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

    const mirrorOrderHash = await marketplaceContract.getOrderHash(orderComponents);

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

  const createMirrorAcceptOfferOrder = async (offerer, zone, order, criteriaResolvers) => {
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

    const mirrorOrderHash = await marketplaceContract.getOrderHash(orderComponents);

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

  const checkExpectedEvents = async (receipt, orderGroups, standardExecutions, batchExecutions, criteriaResolvers) => {
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

            expect(transferLogs.length).to.equal(1);
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
                x.args.operator === marketplaceContract.address &&
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
            x.args.operator === marketplaceContract.address &&
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
              x.args.operator === marketplaceContract.address &&
              x.args.from === event.offerer &&
              (fulfiller !== constants.AddressZero ? x.args.to === fulfiller : true)
            ) || (
              x.signature === 'TransferBatch(address,address,address,uint256[],uint256[])' &&
              x.args.operator === marketplaceContract.address &&
              x.args.from === event.offerer &&
              (fulfiller !== constants.AddressZero ? x.args.to === fulfiller : true)
            ));

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];

          if (transferLog.signature === 'TransferSingle(address,address,address,uint256,uint256)') {
            expect(transferLog.args.id.toString()).to.equal(offer.identifier.toString());
            expect(transferLog.args.value.toString()).to.equal(offer.amount.toString());
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
              x.args.operator === marketplaceContract.address &&
              x.args.to === consideration.recipient
            ) || (
              x.signature === 'TransferBatch(address,address,address,uint256[],uint256[])' &&
              x.args.operator === marketplaceContract.address &&
              x.args.to === consideration.recipient
            ));

          expect(transferLogs.length).to.equal(1);
          const transferLog = transferLogs[0];



          if (transferLog.signature === 'TransferSingle(address,address,address,uint256,uint256)') {
            expect(transferLog.args.id.toString()).to.equal(consideration.identifier.toString());
            expect(transferLog.args.value.toString()).to.equal(consideration.amount.toString());
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

    marketplaceContract = await considerationFactory.deploy(
      ethers.constants.AddressZero, // TODO: use actual proxy factory
      ethers.constants.AddressZero, // TODO: use actual proxy implementation
    );

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
      version: "1",
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
    it("gets correct name, version, and domain separator", async () => {
      const name = await marketplaceContract.name();
      expect(name).to.equal("Consideration");

      const version = await marketplaceContract.version();
      expect(version).to.equal("1");

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
              startAmount: 1,
              endAmount: 1,
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
              startAmount: 1,
              endAmount: 1,
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
            token: order.parameters.offer[0].token,
            identifier: order.parameters.offer[0].identifierOrCriteria,
            startTime: order.parameters.startTime,
            endTime: order.parameters.endTime,
            salt: order.parameters.salt,
            useFulfillerProxy: false,
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
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(order.parameters.consideration[0].endAmount, basicOrderParameters, {value});
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
              startAmount: 1,
              endAmount: 1,
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

          const basicOrderParameters = {
            offerer: order.parameters.offerer,
            zone: order.parameters.zone,
            orderType: order.parameters.orderType,
            token: order.parameters.offer[0].token,
            identifier: order.parameters.offer[0].identifierOrCriteria,
            startTime: order.parameters.startTime,
            endTime: order.parameters.endTime,
            salt: order.parameters.salt,
            useFulfillerProxy: false,
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
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(order.parameters.consideration[0].endAmount, basicOrderParameters, {value});
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
              startAmount: 1,
              endAmount: 1,
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

          const basicOrderParameters = {
            offerer: order.parameters.offerer,
            zone: order.parameters.zone,
            orderType: order.parameters.orderType,
            token: order.parameters.offer[0].token,
            identifier: order.parameters.offer[0].identifierOrCriteria,
            startTime: order.parameters.startTime,
            endTime: order.parameters.endTime,
            salt: order.parameters.salt,
            useFulfillerProxy: false,
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
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(order.parameters.consideration[0].endAmount, basicOrderParameters, {value});
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
              startAmount: 1,
              endAmount: 1,
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
              startAmount: 1,
              endAmount: 1,
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
              startAmount: 1,
              endAmount: 1,
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
              startAmount: 1,
              endAmount: 1,
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

          const basicOrderParameters = {
            offerer: order.parameters.offerer,
            zone: order.parameters.zone,
            orderType: order.parameters.orderType,
            token: order.parameters.offer[0].token,
            identifier: order.parameters.offer[0].identifierOrCriteria,
            startTime: order.parameters.startTime,
            endTime: order.parameters.endTime,
            salt: order.parameters.salt,
            useFulfillerProxy: false,
            signature: order.signature,
            additionalRecipients: [
              {
                amount: ethers.BigNumber.from(50),
                recipient: zone.address,
              },
              {
                amount: ethers.BigNumber.from(50),
                recipient: owner.address,
              }
            ],
          };

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC20ForERC721Order(testERC20.address, tokenAmount.sub(100), basicOrderParameters);
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
              startAmount: 1,
              endAmount: 1,
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
              startAmount: 1,
              endAmount: 1,
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
              startAmount: 1,
              endAmount: 1,
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

          const basicOrderParameters = {
            offerer: order.parameters.offerer,
            zone: order.parameters.zone,
            orderType: order.parameters.orderType,
            token: order.parameters.consideration[0].token,
            identifier: order.parameters.consideration[0].identifierOrCriteria,
            startTime: order.parameters.startTime,
            endTime: order.parameters.endTime,
            salt: order.parameters.salt,
            useFulfillerProxy: false,
            signature: order.signature,
            additionalRecipients: [
              {
                amount: ethers.BigNumber.from(50),
                recipient: zone.address,
              },
              {
                amount: ethers.BigNumber.from(50),
                recipient: owner.address,
              }
            ],
          };

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], ethers.BigNumber.from(0), null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC721ForERC20Order(testERC20.address, tokenAmount, basicOrderParameters);
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
              startAmount: 1,
              endAmount: 1,
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

          const basicOrderParameters = {
            offerer: order.parameters.offerer,
            zone: order.parameters.zone,
            orderType: order.parameters.orderType,
            token: order.parameters.offer[0].token,
            identifier: order.parameters.offer[0].identifierOrCriteria,
            startTime: order.parameters.startTime,
            endTime: order.parameters.endTime,
            salt: order.parameters.salt,
            useFulfillerProxy: false,
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
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC1155Order(order.parameters.consideration[0].endAmount, order.parameters.offer[0].endAmount, basicOrderParameters, {value});
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

          const basicOrderParameters = {
            offerer: order.parameters.offerer,
            zone: order.parameters.zone,
            orderType: order.parameters.orderType,
            token: order.parameters.offer[0].token,
            identifier: order.parameters.offer[0].identifierOrCriteria,
            startTime: order.parameters.startTime,
            endTime: order.parameters.endTime,
            salt: order.parameters.salt,
            useFulfillerProxy: false,
            signature: order.signature,
            additionalRecipients: [
              {
                amount: ethers.BigNumber.from(50),
                recipient: zone.address,
              },
              {
                amount: ethers.BigNumber.from(50),
                recipient: owner.address,
              }
            ],
          };

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC20ForERC1155Order(testERC20.address, tokenAmount.sub(100), amount, basicOrderParameters);
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

          const basicOrderParameters = {
            offerer: order.parameters.offerer,
            zone: order.parameters.zone,
            orderType: order.parameters.orderType,
            token: order.parameters.consideration[0].token,
            identifier: order.parameters.consideration[0].identifierOrCriteria,
            startTime: order.parameters.startTime,
            endTime: order.parameters.endTime,
            salt: order.parameters.salt,
            useFulfillerProxy: false,
            signature: order.signature,
            additionalRecipients: [
              {
                amount: ethers.BigNumber.from(50),
                recipient: zone.address,
              },
              {
                amount: ethers.BigNumber.from(50),
                recipient: owner.address,
              }
            ],
          };

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], ethers.BigNumber.from(0), null, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC1155ForERC20Order(testERC20.address, tokenAmount, amount, basicOrderParameters);
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 50,
            endAmount: 50,
            recipient: zone.address,
          },
          {
            itemType: 1, // ERC20
            token: testERC20.address,
            identifierOrCriteria: 0, // ignored for ERC20
            startAmount: 50,
            endAmount: 50,
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
    });

    describe("Cyclical orders", async () => {
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
            startAmount: 1,
            endAmount: 1,
          },
        ];

        const considerationOne = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: secondNFTId,
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
          },
        ];

        const considerationTwo = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: thirdNFTId,
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
          },
        ];

        const considerationThree = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
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
            startAmount: 1,
            endAmount: 1,
          },
        ];

        const considerationThree = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: 1,
            endAmount: 1,
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
