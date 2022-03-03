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

  const randomHex = () => (
    `0x${[...Array(64)].map(() => Math.floor(Math.random() * 16).toString(16)).join('')}`
  );

  const randomLarge = () => (
    `0x${[...Array(60)].map(() => Math.floor(Math.random() * 16).toString(16)).join('')}`
  );

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
      orders, // TODO: include order statuses to account for partial fills
      additonalPayouts,
      fn,
    ) => {
      const allOfferedItems = orders.map(order => order.parameters.offer.map(offerItem => ({
        ...offerItem,
        account: order.parameters.offerer,
      }))).flat();

      const allReceivedItems = orders.map(order => order.parameters.consideration).flat();

      for (offeredItem of allOfferedItems) {
        if (offeredItem.itemType > 3) {
          console.error("CRITERIA-BASED BALANCE OFFERED CHECKS NOT IMPLEMENTED YET");
          process.exit(0);
        }

        if (offeredItem.itemType === 0) { // ETH
          offeredItem.initialBalance = await provider.getBalance(offeredItem.account);
        } else if (offeredItem.itemType === 3) { // ERC1155
          offeredItem.initialBalance = await tokenByType[offeredItem.itemType].balanceOf(offeredItem.account, offeredItem.identifierOrCriteria);
        } else {
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
          process.exit(0);
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
          console.error("CRITERIA-BASED BALANCE OFFERED CHECKS NOT IMPLEMENTED YET");
          process.exit(0);
        }

        if (offeredItem.itemType === 0) { // ETH
          offeredItem.finalBalance = await provider.getBalance(offeredItem.account);
        } else if (offeredItem.itemType === 3) { // ERC1155
          offeredItem.finalBalance = await tokenByType[offeredItem.itemType].balanceOf(offeredItem.account, offeredItem.identifierOrCriteria);
        } else {
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
          console.error("CRITERIA-BASED BALANCE RECEIVED CHECKS NOT IMPLEMENTED YET");
          process.exit(0);
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

      for (offerredItem of allOfferedItems) {
        if (offerredItem.startAmount.toString() !== offerredItem.endAmount.toString()) {
          console.error("SLIDING AMOUNT BALANCE OFFERED CHECKS NOT IMPLEMENTED YET");
          process.exit(0);
        }

        if (!additonalPayouts) {
          expect(offerredItem.initialBalance.sub(offerredItem.finalBalance).toString()).to.equal(offerredItem.endAmount.toString());
        } else {
          expect(offerredItem.initialBalance.sub(offerredItem.finalBalance).toString()).to.equal(additonalPayouts.add(offerredItem.endAmount).toString());
        }

        if (offeredItem.itemType === 2) { // ERC721
          expect(offeredItem.ownsItemBefore).to.equal(true);
          expect(offeredItem.ownsItemAfter).to.equal(false);
        }
      }

      for (receivedItem of allReceivedItems) {
        if (receivedItem.startAmount.toString() !== receivedItem.endAmount.toString()) {
          console.error("SLIDING AMOUNT BALANCE RECEIVED CHECKS NOT IMPLEMENTED YET");
          process.exit(0);
        }
        expect(receivedItem.finalBalance.sub(receivedItem.initialBalance).toString()).to.equal(receivedItem.endAmount.toString());

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
  });

  describe("Getter tests", async () => {
    it("gets name and version", async () => {
      const name = await marketplaceContract.name();
      expect(name).to.equal("Consideration");

      const version = await marketplaceContract.version();
      expect(version).to.equal("1");
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

    const createOrder = async (offerer, zone, offer, consideration, orderType) => {
      const nonce = await marketplaceContract.getNonce(offerer.address, zone.address);
      const salt = randomHex();
      const startTime = 0;
      const endTime = ethers.BigNumber.from("0xff00000000000000000000000000000000000000000000000000000000000000");

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
      };

      // How much ether (at most) needs to be supplied when fulfilling the order
      const value = consideration
        .map(x => (
          x.itemType === 0
            ? (x.endAmount.gt(x.startAmount) ? x.endAmount : x.startAmount)
            : ethers.BigNumber.from(0)
        )).reduce((a, b) => a.add(b), ethers.BigNumber.from(0));

      return {order, orderHash, value, orderStatus};
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

    const createMirrorAcceptOfferOrder = async (offerer, zone, order) => {
      const nonce = await marketplaceContract.getNonce(offerer.address, zone.address);
      const salt = randomHex();
      const startTime = 0;
      const endTime = ethers.BigNumber.from("0xff00000000000000000000000000000000000000000000000000000000000000");

      const orderParameters = {
          offerer: offerer.address,
          zone: zone.address,
          offer: order.parameters.consideration
            .filter(x => x.itemType > 1)
            .map(x => ({
              itemType: x.itemType,
              token: x.token,
              identifierOrCriteria: x.identifierOrCriteria,
              startAmount: x.startAmount,
              endAmount: x.endAmount,
            })),
          consideration: order.parameters.offer.map(x => ({
            ...x,
            recipient: offerer.address,
            startAmount: x.endAmount.sub(
              order.parameters.consideration
                .filter(i => i.itemType < 2 && i.itemType === x.itemType && i.token === x.token)
                .map(i => i.endAmount)
                .reduce((a, b) => a.add(b), ethers.BigNumber.from(0))
            ),
            endAmount: x.endAmount.sub(
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

    const checkExpectedEvents = (receipt, orderGroups, standardExecutions, batchExecutions) => {
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
        console.error("BATCH EXECUTION VALIDATION NOT IMPLEMENTED YET");
        process.exit(1);
      }

      for (const {order, orderHash, fulfiller, orderStatus} of orderGroups) {
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

        const compareEventItems = (item, orderItem) => {
          expect(item.itemType).to.equal(orderItem.itemType);
          expect(item.token).to.equal(orderItem.token);
          expect(item.token).to.equal(tokenByType[item.itemType].address);
          if (orderItem.itemType < 4) { // no criteria-based
            expect(item.identifier).to.equal(orderItem.identifierOrCriteria);
          } else {
            console.error("CRITERIA-BASED NOT IMPLEMENTED YET");
            process.exit(1);
          }

          if (order.parameters.orderType === 0) { // FULL_OPEN (no partial fills)
            if (orderItem.startAmount.toString() === orderItem.endAmount.toString()) {
              expect(item.amount.toString()).to.equal(orderItem.endAmount.toString());
            } else {
              console.error("SLIDING AMOUNT NOT IMPLEMENTED YET");
              process.exit(1);
            }
          } else {
            console.error("NON_FULL_OPEN NOT IMPLEMENTED YET");
            process.exit(1);
          }
        }

        expect(event.offer.length).to.equal(order.parameters.offer.length);
        for ([index, offer] of Object.entries(event.offer)) {
          const offerItem = order.parameters.offer[index];
          compareEventItems(offer, offerItem);

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
              ));

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            expect(transferLog.args.id.toString()).to.equal(offer.identifier.toString());
            expect(transferLog.args.value.toString()).to.equal(offer.amount.toString());
          }
        }

        expect(event.consideration.length).to.equal(order.parameters.consideration.length);
        for ([index, consideration] of Object.entries(event.consideration)) {
          const considerationItem = order.parameters.consideration[index];
          compareEventItems(consideration, considerationItem);
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
              ));

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            expect(transferLog.args.id.toString()).to.equal(consideration.identifier.toString());
            expect(transferLog.args.value.toString()).to.equal(consideration.amount.toString());
          }
        }
      }
    }

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
            await withBalanceChecks([order], 0, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await withBalanceChecks([order], 0, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(order.parameters.consideration[0].endAmount, basicOrderParameters, {value});
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it.skip("ERC721 <=> WETH", async () => {

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
            await withBalanceChecks([order], 0, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false);
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await withBalanceChecks([order], 0, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC20ForERC721Order(testERC20.address, tokenAmount.sub(100), basicOrderParameters);
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
      });
      describe("[Accept offer] User accepts a buy offer on a single ERC721", async () => {
        // Note: ETH is not a possible case
        it.skip("ERC721 <=> WETH", async () => {});
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
            await withBalanceChecks([order], 0, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false);
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await withBalanceChecks([order], ethers.BigNumber.from(100), async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC721ForERC20Order(testERC20.address, tokenAmount.sub(100), basicOrderParameters);
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
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
            await withBalanceChecks([order], 0, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await withBalanceChecks([order], 0, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC1155Order(order.parameters.consideration[0].endAmount, order.parameters.offer[0].endAmount, basicOrderParameters, {value});
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
        it.skip("ERC1155 <=> WETH", async () => {});
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
            await withBalanceChecks([order], 0, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false);
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await withBalanceChecks([order], 0, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC20ForERC1155Order(testERC20.address, tokenAmount.sub(100), amount, basicOrderParameters);
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
        });
      });
      describe("[Accept offer] User accepts a buy offer on a single ERC1155", async () => {
        // Note: ETH is not a possible case
        it.skip("ERC1155 <=> WETH", async () => {});
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
            await withBalanceChecks([order], 0, async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false);
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            await withBalanceChecks([order], ethers.BigNumber.from(100), async () => {
              const tx = await marketplaceContract.connect(buyer).fulfillBasicERC1155ForERC20Order(testERC20.address, tokenAmount.sub(100), amount, basicOrderParameters);
              const receipt = await tx.wait();
              checkExpectedEvents(receipt, [{order, orderHash, fulfiller: buyer.address}]);
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
            checkExpectedEvents(receipt, [{order, orderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            checkExpectedEvents(receipt, [{order: mirrorOrder, orderHash: mirrorOrderHash, fulfiller: constants.AddressZero}], standardExecutions, batchExecutions);
            return receipt;
          });
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
