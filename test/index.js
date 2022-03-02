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

  const randomHex = () => (
    `0x${[...Array(64)].map(() => Math.floor(Math.random() * 16).toString(16)).join('')}`
  );

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
      constants.AddressZero, // ETH
      testERC20.address,
      testERC721.address,
      testERC1155.address,
    ];


    // Required for EIP712 signing
    domainData = {
      name: "Consideration",
      version: "1",
      chainId: chainId,
      verifyingContract: marketplaceContract.address,
    };
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
      const startTime = Math.floor(new Date().getTime() / 1000) - 30;
      const endTime = startTime + 60;

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

      const flatSig = await signOrder(orderComponents, offerer);

      const orderHash = await marketplaceContract.getOrderHash(orderComponents);

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

      return {order, orderHash, value};
    }

    const createMirrorOrder = async (offerer, zone, order) => {
      const nonce = await marketplaceContract.getNonce(offerer.address, zone.address);
      const salt = randomHex();
      const startTime = Math.floor(new Date().getTime() / 1000) - 30;
      const endTime = startTime + 60;

      const orderParameters = {
          offerer: offerer.address,
          zone: zone.address,
          offer: order.parameters.consideration.map(x => ({ // TODO: aggregate like-kind items
            itemType: x.itemType,
            token: x.token,
            identifierOrCriteria: x.identifierOrCriteria,
            startAmount: x.startAmount,
            endAmount: x.endAmount,
          })),
          consideration: order.parameters.offer.map(x => ({ // TODO: aggregate like-kind items
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

    const checkExpectedEvents = (receipt, order, orderHash, fulfiller, orderStatus) => {
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
        }));

      expect(marketplaceContractEvents.length).to.equal(1);

      const event = marketplaceContractEvents[0];

      // console.log(order.parameters);
      //console.log(event);

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
        expect(item.token).to.equal(tokenByType[item.itemType]);
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

        if (offer.fulfiller !== constants.AddressZero) {
          if (offer.itemType === 1) { // ERC20
            // search for transfer
            const transferLogs = tokenEvents
              .map(x => testERC20.interface.parseLog(x))
              .filter(x => (
                x.signature === 'Transfer(address,address,uint256)' &&
                x.args.from === event.offerer &&
                x.args.to === fulfiller
              ));

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            // TODO: check amount against offer.amount

          } else if (offer.itemType === 2) { // ERC721
            // search for transfer

            const transferLogs = tokenEvents
              .map(x => testERC721.interface.parseLog(x))
              .filter(x => (
                x.signature === 'Transfer(address,address,uint256)' &&
                x.args.from === event.offerer &&
                x.args.to === fulfiller
              ));

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            expect(transferLog.args.tokenId.toString()).to.equal(offer.identifier.toString());

          } else if (offer.itemType === 3) {
            // search for transfer
            const transferLogs = tokenEvents
              .map(x => testERC1155.interface.parseLog(x))
              .filter(x => (
                x.signature === 'Transfer(address,address,uint256)' &&
                x.args.from === event.offerer &&
                x.args.to === fulfiller
              ));

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            expect(transferLog.args.tokenId.toString()).to.equal(offer.identifier.toString());
            // TODO: check amount against offer.amount

          }
        } else {
          console.error("matchOrders NOT IMPLEMENTED YET");
          process.exit(1);
        }

      }

      expect(event.consideration.length).to.equal(order.parameters.consideration.length);
      for ([index, consideration] of Object.entries(event.consideration)) {
        const considerationItem = order.parameters.consideration[index];
        compareEventItems(consideration, considerationItem);
        expect(consideration.recipient).to.equal(considerationItem.recipient);

        const tokenEvents = receipt.events
          .filter(x => x.address === considerationItem.token);

        if (consideration.fulfiller !== constants.AddressZero) {
          if (consideration.itemType === 1) { // ERC20
            // search for transfer
            const transferLogs = tokenEvents
              .map(x => testERC20.interface.parseLog(x))
              .filter(x => (
                x.signature === 'Transfer(address,address,uint256)' &&
                x.args.from === fulfiller &&
                x.args.to === event.offerer
              ));

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            // TODO: check amount against offer.amount

          } else if (consideration.itemType === 2) { // ERC721
            // search for transfer

            const transferLogs = tokenEvents
              .map(x => testERC721.interface.parseLog(x))
              .filter(x => (
                x.signature === 'Transfer(address,address,uint256)' &&
                x.args.from === fulfiller &&
                x.args.to === event.offerer
              ));

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            expect(transferLog.args.tokenId.toString()).to.equal(consideration.identifier.toString());

          } else if (consideration.itemType === 3) {
            // search for transfer
            const transferLogs = tokenEvents
              .map(x => testERC1155.interface.parseLog(x))
              .filter(x => (
                x.signature === 'Transfer(address,address,uint256)' &&
                x.args.from === fulfiller &&
                x.args.to === event.offerer
              ));

            expect(transferLogs.length).to.equal(1);
            const transferLog = transferLogs[0];
            expect(transferLog.args.tokenId.toString()).to.equal(consideration.identifier.toString());
            // TODO: check amount against offer.amount

          }
        } else {
          console.error("matchOrders NOT IMPLEMENTED YET");
          process.exit(1);
        }
      }
    }

    describe("A single ERC721 is to be transferred", async () => {
      describe("[Buy now] User fullfills a sell order for a single ERC721", async () => {
        it("ERC721 <=> ETH", async () => {
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
            const tx = await marketplaceContract.connect(buyer).fulfillOrder(order, false, {value});
            const receipt = await tx.wait();
            checkExpectedEvents(receipt, order, orderHash, buyer.address);
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
            const tx = await marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(order.parameters.consideration[0].endAmount, basicOrderParameters, {value});
            const receipt = await tx.wait();
            checkExpectedEvents(receipt, order, orderHash, buyer.address);
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
          } = await createMirrorOrder(
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

          await whileImpersonating(owner.address, provider, async () => {
            const tx = await marketplaceContract.connect(owner).matchOrders([order, mirrorOrder], fulfillments, {value});
            const receipt = await tx.wait();
            // TODO: validate
          });
        });
        it("ERC721 <=> WETH", async () => {});
        it("ERC721 <=> ERC20", async () => {});
      });
      describe("[Accept offer] User accepts a buy offer on a single ERC721", async () => {
        // Note: ETH is not a possible case
        it("ERC721 <=> WETH", async () => {});
        it("ERC721 <=> ERC20", async () => {});
      });
    });

    describe("A single ERC1155 is to be transferred", async () => {
      describe("[Buy now] User fullfills a sell order for a single ERC1155", async () => {
        describe("ERC1155 <=> ETH", async () => {});
        describe("ERC1155 <=> WETH", async () => {});
        describe("ERC1155 <=> ERC20", async () => {});
      });
      describe("[Accept offer] User accepts a buy offer on a single ERC1155", async () => {
        // Note: ETH is not a possible case
        describe("ERC1155 <=> WETH", async () => {});
        describe("ERC1155 <=> ERC20", async () => {});
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
