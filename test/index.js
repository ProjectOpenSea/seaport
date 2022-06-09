/* eslint-disable no-unused-expressions */
const { expect } = require("chai");
const {
  constants,
  utils: { parseEther, keccak256, toUtf8Bytes },
} = require("ethers");
const { ethers, network } = require("hardhat");
const {
  faucet,
  whileImpersonating,
  getWalletWithEther,
} = require("./utils/impersonate");
const { merkleTree } = require("./utils/criteria");
const {
  randomHex,
  random128,
  toAddress,
  toKey,
  convertSignatureToEIP2098,
  getBasicOrderParameters,
  getItemETH,
  toBN,
  randomBN,
  toFulfillment,
  toFulfillmentComponents,
  getBasicOrderExecutions,
  buildResolver,
  buildOrderStatus,
  defaultBuyNowMirrorFulfillment,
  defaultAcceptOfferMirrorFulfillment,
} = require("./utils/encoding");
const { randomInt } = require("crypto");
const {
  fixtureERC20,
  fixtureERC721,
  fixtureERC1155,
  seaportFixture,
} = require("./utils/fixtures");
const { deployContract } = require("./utils/contracts");

const VERSION = !process.env.REFERENCE ? "1.1" : "rc.1.1";

const minRandom = (min) => randomBN(10).add(min);

describe(`Consideration (version: ${VERSION}) — initial test suite`, function () {
  const provider = ethers.provider;
  let zone;
  let marketplaceContract;
  let testERC20;
  let testERC721;
  let testERC1155;
  let testERC1155Two;
  let owner;
  let withBalanceChecks;
  let EIP1271WalletFactory;
  let reenterer;
  let stubZone;
  let conduitController;
  let conduitImplementation;
  let conduitOne;
  let conduitKeyOne;
  let directMarketplaceContract;
  let mintAndApproveERC20;
  let getTestItem20;
  let set721ApprovalForAll;
  let mint721;
  let mint721s;
  let mintAndApprove721;
  let getTestItem721;
  let getTestItem721WithCriteria;
  let set1155ApprovalForAll;
  let mint1155;
  let mintAndApprove1155;
  let getTestItem1155WithCriteria;
  let getTestItem1155;
  let deployNewConduit;
  let createTransferWithApproval;
  let createOrder;
  let createMirrorBuyNowOrder;
  let createMirrorAcceptOfferOrder;
  let checkExpectedEvents;

  const simulateMatchOrders = async (orders, fulfillments, caller, value) => {
    return marketplaceContract
      .connect(caller)
      .callStatic.matchOrders(orders, fulfillments, {
        value,
      });
  };

  const simulateAdvancedMatchOrders = async (
    orders,
    criteriaResolvers,
    fulfillments,
    caller,
    value
  ) => {
    return marketplaceContract
      .connect(caller)
      .callStatic.matchAdvancedOrders(orders, criteriaResolvers, fulfillments, {
        value,
      });
  };

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    owner = new ethers.Wallet(randomHex(32), provider);

    await Promise.all(
      [owner].map((wallet) => faucet(wallet.address, provider))
    );

    ({
      EIP1271WalletFactory,
      reenterer,
      conduitController,
      conduitImplementation,
      conduitKeyOne,
      conduitOne,
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
      createTransferWithApproval,
      marketplaceContract,
      directMarketplaceContract,
      stubZone,
      createOrder,
      createMirrorBuyNowOrder,
      createMirrorAcceptOfferOrder,
      withBalanceChecks,
      checkExpectedEvents,
    } = await seaportFixture(owner));
  });

  describe("Getter tests", async () => {
    it("gets correct name", async () => {
      const name = await marketplaceContract.name();
      expect(name).to.equal(
        process.env.REFERENCE ? "Consideration" : "Seaport"
      );

      const directName = await directMarketplaceContract.name();
      expect(directName).to.equal("Consideration");
    });
    it("gets correct version, domain separator and conduit controller", async () => {
      const name = process.env.REFERENCE ? "Consideration" : "Seaport";
      const {
        version,
        domainSeparator,
        conduitController: controller,
      } = await marketplaceContract.information();

      const typehash = keccak256(
        toUtf8Bytes(
          "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        )
      );
      const namehash = keccak256(toUtf8Bytes(name));
      const versionhash = keccak256(toUtf8Bytes(version));
      const { chainId } = await provider.getNetwork();
      const chainIdEncoded = chainId.toString(16).padStart(64, "0");
      const addressEncoded = marketplaceContract.address
        .slice(2)
        .padStart(64, "0");
      expect(domainSeparator).to.equal(
        keccak256(
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
      seller = new ethers.Wallet(randomHex(32), provider);
      buyer = new ethers.Wallet(randomHex(32), provider);
      zone = new ethers.Wallet(randomHex(32), provider);

      sellerContract = await EIP1271WalletFactory.deploy(seller.address);
      buyerContract = await EIP1271WalletFactory.deploy(buyer.address);

      await Promise.all(
        [seller, buyer, zone, sellerContract, buyerContract].map((wallet) =>
          faucet(wallet.address, provider)
        )
      );
    });

    describe("A single ERC721 is to be transferred", async () => {
      describe("[Buy now] User fulfills a sell order for a single ERC721", async () => {
        it("ERC721 <=> ETH (standard)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);
            return receipt;
          });
        });
        it("ERC721 <=> ETH (standard via conduit)", async () => {
          const nftId = await mintAndApprove721(seller, conduitOne.address);

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (standard with tip)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          // Add a tip
          order.parameters.consideration.push(
            getItemETH(parseEther("1"), parseEther("1"), owner.address)
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value: value.add(parseEther("1")),
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (standard with restricted order)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            stubZone,
            offer,
            consideration,
            2 // FULL_RESTRICTED
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (standard with restricted order and extra data)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            stubZone,
            offer,
            consideration,
            2 // FULL_RESTRICTED
          );

          order.extraData = "0x1234";

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              );
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (standard with restricted order, specified recipient and extra data)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            stubZone,
            offer,
            consideration,
            2 // FULL_RESTRICTED
          );

          order.extraData = "0x1234";

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(order, [], toKey(false), owner.address, {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                recipient: owner.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (basic)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (basic, minimal and listed off-chain)", async () => {
          // Seller mints nft
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [getItemETH(toBN(1), toBN(1), seller.address)];

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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (basic, minimal and verified on-chain)", async () => {
          // Seller mints nft
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [getItemETH(toBN(1), toBN(1), seller.address)];

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
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, constants.AddressZero);

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (standard, minimal and listed off-chain)", async () => {
          // Seller mints nft
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [getItemETH(toBN(1), toBN(1), seller.address)];

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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (standard, minimal and verified on-chain)", async () => {
          // Seller mints nft
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(toBN(1), toBN(1), constants.AddressZero),
          ];
          console.log(Object.keys(marketplaceContract.interface.functions));
          for (const signature of Object.keys(
            marketplaceContract.interface.functions
          )) {
            console.log(
              `${signature.slice(0, signature.indexOf("("))}: ${keccak256(
                Buffer.from(signature, "utf8")
              ).slice(0, 10)}`
            );
          }

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
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, constants.AddressZero);

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (advanced, minimal and listed off-chain)", async () => {
          // Seller mints nft
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [getItemETH(toBN(1), toBN(1), seller.address)];

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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              );
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (advanced, minimal and verified on-chain)", async () => {
          // Seller mints nft
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [getItemETH(toBN(1), toBN(1), seller.address)];

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
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, constants.AddressZero);

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              );
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (basic with tips)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
                amount: parseEther("2"),
                recipient: `0x0000000000000000000000000000000000000001`,
              },
              {
                amount: parseEther("3"),
                recipient: `0x0000000000000000000000000000000000000002`,
              },
              {
                amount: parseEther("4"),
                recipient: `0x0000000000000000000000000000000000000003`,
              },
            ]
          );

          order.parameters.consideration.push(
            getItemETH(
              parseEther("2"),
              parseEther("2"),
              "0x0000000000000000000000000000000000000001"
            )
          );

          order.parameters.consideration.push(
            getItemETH(
              parseEther("3"),
              parseEther("3"),
              "0x0000000000000000000000000000000000000002"
            )
          );

          order.parameters.consideration.push(
            getItemETH(
              parseEther("4"),
              parseEther("4"),
              "0x0000000000000000000000000000000000000003"
            )
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value: value.add(parseEther("9")),
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (basic via conduit)", async () => {
          const nftId = await mintAndApprove721(seller, conduitOne.address);

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (basic with restricted order)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (basic with partial restricted order)", async () => {
          // Seller mints nft
          const nftId = randomBN();
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
            3 // PARTIAL_RESTRICTED
          );

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await whileImpersonating(buyer.address, provider, async () => {
            await withBalanceChecks([order], 0, null, async () => {
              const tx = marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters, { value });
              const receipt = await (await tx).wait();
              await checkExpectedEvents(tx, receipt, [
                { order, orderHash, fulfiller: buyer.address },
              ]);

              return receipt;
            });
          });
        });
        it("ERC721 <=> ETH (basic, already validated)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          // Validate the order from any account
          await expect(marketplaceContract.connect(owner).validate([order]))
            .to.emit(marketplaceContract, "OrderValidated")
            .withArgs(orderHash, seller.address, zone.address);

          const basicOrderParameters = getBasicOrderParameters(
            0, // EthForERC721
            order
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (basic, EIP-2098 signature)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (basic, extra ether supplied and returned to caller)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value: value.add(1),
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ETH (match)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );
          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
        it("ERC721 <=> ETH (match via conduit)", async () => {
          const nftId = await mintAndApprove721(seller, conduitOne.address);

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
        it("ERC721 <=> ETH (match, extra eth supplied and returned to caller)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value: value.add(101),
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
        it("ERC721 <=> ERC20 (standard)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { order, orderHash } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false));
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);
            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (standard via conduit)", async () => {
          const nftId = await mintAndApprove721(seller, conduitOne.address);

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false));
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (basic)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (basic via conduit)", async () => {
          const nftId = await mintAndApprove721(seller, conduitOne.address);

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (basic, EIP-1271 signature)", async () => {
          // Seller mints nft to contract
          const nftId = await mint721(sellerContract);

          // Seller approves marketplace contract to transfer NFT
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

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              sellerContract.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (EIP-1271 signature on non-ECDSA 64 bytes)", async () => {
          const sellerContract = await deployContract(
            "EIP1271Wallet",
            seller,
            seller.address
          );

          // Seller mints nft to contract
          const nftId = await mint721(sellerContract);

          // Seller approves marketplace contract to transfer NFT
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

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              sellerContract.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
            sellerContract,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller
          );

          // Compute the digest based on the order hash
          const { domainSeparator } = await marketplaceContract.information();
          const digest = keccak256(
            `0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`
          );

          const signature = `0x`.padEnd(130, "f");

          const basicOrderParameters = {
            ...getBasicOrderParameters(
              2, // ERC20ForERC721
              order
            ),
            signature,
          };

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (EIP-1271 signature on non-ECDSA 65 bytes)", async () => {
          const sellerContract = await deployContract(
            "EIP1271Wallet",
            seller,
            seller.address
          );

          // Seller mints nft to contract
          const nftId = await mint721(sellerContract);

          // Seller approves marketplace contract to transfer NFT
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

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              sellerContract.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
            sellerContract,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            [],
            null,
            seller
          );

          // Compute the digest based on the order hash
          const { domainSeparator } = await marketplaceContract.information();
          const digest = keccak256(
            `0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`
          );

          await sellerContract.registerDigest(digest, true);

          const signature = `0x`.padEnd(132, "f");

          const basicOrderParameters = {
            ...getBasicOrderParameters(
              2, // ERC20ForERC721
              order
            ),
            signature,
          };

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });

          await sellerContract.registerDigest(digest, false);
        });
        it("ERC721 <=> ERC20 (basic, EIP-1271 signature w/ non-standard length)", async () => {
          // Seller mints nft to contract
          const nftId = await mint721(sellerContract);

          // Seller approves marketplace contract to transfer NFT
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

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

          const offer = [getTestItem721(nftId)];

          const consideration = [
            getTestItem20(
              tokenAmount.sub(100),
              tokenAmount.sub(100),
              sellerContract.address
            ),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
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
          if (!process.env.REFERENCE) {
            await expect(
              marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters)
            ).to.be.revertedWith("BadContractSignature");
          } else {
            await expect(
              marketplaceContract
                .connect(buyer)
                .fulfillBasicOrder(basicOrderParameters)
            ).to.be.reverted;
          }

          // Compute the digest based on the order hash
          const { domainSeparator } = await marketplaceContract.information();
          const digest = keccak256(
            `0x1901${domainSeparator.slice(2)}${orderHash.slice(2)}`
          );

          // Seller approves the digest
          await sellerContract.connect(seller).registerDigest(digest, true);

          // Now it succeeds
          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (match)", async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
        it("ERC721 <=> ERC20 (match via conduit)", async () => {
          const nftId = await mintAndApprove721(seller, conduitOne.address);

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      describe("[Accept offer] User accepts a buy offer on a single ERC721", async () => {
        // Note: ETH is not a possible case
        it("ERC721 <=> ERC20 (standard)", async () => {
          // Buyer mints nft
          const nftId = await mint721(buyer);

          // Buyer approves marketplace contract to transfer NFT
          await set721ApprovalForAll(buyer, marketplaceContract.address, true);

          // Seller mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // Buyer approves marketplace contract to transfer ERC20 tokens too
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

          const offer = [
            getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
          ];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false));
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (standard, via conduit)", async () => {
          // Buyer mints nft
          const nftId = await mint721(buyer);

          // Buyer approves marketplace contract to transfer NFT
          await set721ApprovalForAll(buyer, marketplaceContract.address, true);

          // Seller mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(seller, conduitOne.address, tokenAmount);

          // Buyer approves marketplace contract to transfer ERC20 tokens
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

          const offer = [
            getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
          ];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false));
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (standard, fulfilled via conduit)", async () => {
          // Buyer mints nft
          const nftId = await mint721(buyer);

          // Buyer approves conduit contract to transfer NFT
          await set721ApprovalForAll(buyer, conduitOne.address, true);

          // Seller mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // Buyer approves conduit to transfer ERC20 tokens
          await expect(
            testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, conduitOne.address, tokenAmount);

          const offer = [
            getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
          ];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, conduitKeyOne);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: conduitKeyOne,
              },
            ]);

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (basic)", async () => {
          // Buyer mints nft
          const nftId = await mint721(buyer);

          // Buyer approves marketplace contract to transfer NFT
          await set721ApprovalForAll(buyer, marketplaceContract.address, true);

          // Seller mints ERC20
          const tokenAmount = toBN(random128());
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [getTestItem20(tokenAmount, tokenAmount)];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], toBN(0), null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(
              tx,
              receipt,
              [
                {
                  order,
                  orderHash,
                  fulfiller: buyer.address,
                },
              ],
              getBasicOrderExecutions(order, buyer.address)
            );

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (basic, many via conduit)", async () => {
          // Buyer mints nft
          const nftId = await mint721(buyer);

          // Buyer approves marketplace contract to transfer NFT
          await set721ApprovalForAll(buyer, marketplaceContract.address, true);

          // Seller mints ERC20
          const tokenAmount = toBN(random128());
          await mintAndApproveERC20(seller, conduitOne.address, tokenAmount);

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [getTestItem20(tokenAmount, tokenAmount)];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(1, 1, zone.address),
          ];

          for (let i = 1; i <= 50; ++i) {
            consideration.push(
              getTestItem20(i, i, toAddress(parseInt(i) + 10000))
            );
          }

          const { order, orderHash } = await createOrder(
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
            4, // ERC721ForERC20
            order
          );

          await withBalanceChecks([order], toBN(0), null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(
              tx,
              receipt,
              [
                {
                  order,
                  orderHash,
                  fulfiller: buyer.address,
                },
              ],
              getBasicOrderExecutions(order, buyer.address)
            );

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (basic, fulfilled via conduit)", async () => {
          // Buyer mints nft
          const nftId = await mint721(buyer);

          // Buyer approves conduit contract to transfer NFT
          await set721ApprovalForAll(buyer, conduitOne.address, true);

          // Seller mints ERC20
          const tokenAmount = toBN(random128());
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [getTestItem20(tokenAmount, tokenAmount)];

          const consideration = [
            getTestItem721(nftId, 1, 1, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], toBN(0), null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(
              tx,
              receipt,
              [
                {
                  order,
                  orderHash,
                  fulfiller: buyer.address,
                  fulfillerConduitKey: conduitKeyOne,
                },
              ],
              getBasicOrderExecutions(order, buyer.address, conduitKeyOne)
            );

            return receipt;
          });
        });
        it("ERC721 <=> ERC20 (match)", async () => {
          // Buyer mints nft
          const nftId = await mint721(buyer);

          // Buyer approves marketplace contract to transfer NFT
          await set721ApprovalForAll(buyer, marketplaceContract.address, true);

          // Seller mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
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

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorAcceptOfferOrder(buyer, zone, order);

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
        it("ERC721 <=> ERC20 (match via conduit)", async () => {
          // Buyer mints nft
          const nftId = await mint721(buyer);

          // Buyer approves conduit contract to transfer NFT
          await set721ApprovalForAll(buyer, conduitOne.address, true);

          // Seller mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
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

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorAcceptOfferOrder(
              buyer,
              zone,
              order,
              [],
              conduitKeyOne
            );

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
    });

    describe("A single ERC1155 is to be transferred", async () => {
      describe("[Buy now] User fulfills a sell order for a single ERC1155", async () => {
        it("ERC1155 <=> ETH (standard)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC1155 <=> ETH (standard via conduit)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            conduitOne.address
          );

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC1155 <=> ETH (basic)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC1155 <=> ETH (basic via conduit)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            conduitOne.address
          );

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              });
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC1155 <=> ETH (match)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            marketplaceContract.address
          );

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
          ];

          const { order, orderHash, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
        it("ERC1155 <=> ETH (match via conduit)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            conduitOne.address
          );

          const offer = [getTestItem1155(nftId, amount, amount)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
        it("ERC1155 <=> ERC20 (standard)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            marketplaceContract.address
          );

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { order, orderHash } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false));
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (standard via conduit)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            conduitOne.address
          );

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false));
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (basic)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            marketplaceContract.address
          );

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(
              tx,
              receipt,
              [
                {
                  order,
                  orderHash,
                  fulfiller: buyer.address,
                },
              ],
              getBasicOrderExecutions(order, buyer.address)
            );

            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (basic via conduit)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            conduitOne.address
          );

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { order, orderHash } = await createOrder(
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

          const basicOrderParameters = getBasicOrderParameters(3, order);

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
              },
            ]);

            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (match)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            marketplaceContract.address
          );

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
        it("ERC1155 <=> ERC20 (match via conduit)", async () => {
          // Seller mints nft
          const { nftId, amount } = await mintAndApprove1155(
            seller,
            conduitOne.address
          );

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            buyer,
            marketplaceContract.address,
            tokenAmount
          );

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

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorBuyNowOrder(buyer, zone, order);

          const fulfillments = defaultBuyNowMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      describe("[Accept offer] User accepts a buy offer on a single ERC1155", async () => {
        // Note: ETH is not a possible case
        it("ERC1155 <=> ERC20 (standard)", async () => {
          // Buyer mints nft
          const { nftId, amount } = await mintAndApprove1155(
            buyer,
            marketplaceContract.address
          );

          // Seller mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // Buyer approves marketplace contract to transfer ERC20 tokens too
          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

          const offer = [
            getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
          ];

          const consideration = [
            getTestItem1155(nftId, amount, amount, undefined, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false));
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ]);

            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (standard, fulfilled via conduit)", async () => {
          // Buyer mints nft
          const { nftId, amount } = await mintAndApprove1155(
            buyer,
            conduitOne.address
          );

          // Seller mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // Buyer approves conduit to transfer ERC20 tokens
          await expect(
            testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, conduitOne.address, tokenAmount);

          const offer = [
            getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
          ];

          const consideration = [
            getTestItem1155(nftId, amount, amount, undefined, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0 // FULL_OPEN
          );

          await withBalanceChecks([order], 0, null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, conduitKeyOne);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(tx, receipt, [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: conduitKeyOne,
              },
            ]);

            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (basic)", async () => {
          // Buyer mints nft
          const { nftId, amount } = await mintAndApprove1155(
            buyer,
            marketplaceContract.address
          );

          // Seller mints ERC20
          const tokenAmount = toBN(random128());
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [getTestItem20(tokenAmount, tokenAmount)];

          const consideration = [
            getTestItem1155(nftId, amount, amount, undefined, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], toBN(0), null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);
            const receipt = await (await tx).wait();
            await checkExpectedEvents(
              tx,
              receipt,
              [
                {
                  order,
                  orderHash,
                  fulfiller: buyer.address,
                },
              ],
              getBasicOrderExecutions(order, buyer.address)
            );

            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (basic, fulfilled via conduit)", async () => {
          // Buyer mints nft
          const { nftId, amount } = await mintAndApprove1155(
            buyer,
            conduitOne.address
          );

          // Seller mints ERC20
          const tokenAmount = toBN(random128());
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [getTestItem20(tokenAmount, tokenAmount)];

          const consideration = [
            getTestItem1155(nftId, amount, amount, undefined, seller.address),
            getTestItem20(50, 50, zone.address),
            getTestItem20(50, 50, owner.address),
          ];

          const { order, orderHash } = await createOrder(
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

          await withBalanceChecks([order], toBN(0), null, async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters);

            const executions = getBasicOrderExecutions(
              order,
              buyer.address,
              conduitKeyOne
            );
            const receipt = await (await tx).wait();
            await checkExpectedEvents(
              tx,
              receipt,
              [
                {
                  order,
                  orderHash,
                  fulfiller: buyer.address,
                  fulfillerConduitKey: conduitKeyOne,
                },
              ],
              executions
            );

            return receipt;
          });
        });
        it("ERC1155 <=> ERC20 (match)", async () => {
          // Buyer mints nft
          const { nftId, amount } = await mintAndApprove1155(
            buyer,
            marketplaceContract.address
          );

          // Seller mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
          ];

          const consideration = [
            getTestItem1155(nftId, amount, amount, undefined, seller.address),
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

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorAcceptOfferOrder(buyer, zone, order);

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
        it("ERC1155 <=> ERC20 (match via conduit)", async () => {
          // Buyer mints nft
          const { nftId, amount } = await mintAndApprove1155(
            buyer,
            conduitOne.address
          );

          // Seller mints ERC20
          const tokenAmount = minRandom(100);
          await mintAndApproveERC20(
            seller,
            marketplaceContract.address,
            tokenAmount
          );

          // NOTE: Buyer does not need to approve marketplace for ERC20 tokens

          const offer = [
            getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
          ];

          const consideration = [
            getTestItem1155(nftId, amount, amount, undefined, seller.address),
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

          const { mirrorOrder, mirrorOrderHash } =
            await createMirrorAcceptOfferOrder(
              buyer,
              zone,
              order,
              [],
              conduitKeyOne
            );

          const fulfillments = defaultAcceptOfferMirrorFulfillment;

          const executions = await simulateMatchOrders(
            [order, mirrorOrder],
            fulfillments,
            owner,
            value
          );

          expect(executions.length).to.equal(4);

          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments);
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
    });
  });

  describe("Validate, cancel, and increment counter flows", async () => {
    let seller;
    let buyer;

    beforeEach(async () => {
      // Setup basic buyer/seller wallets with ETH
      seller = new ethers.Wallet(randomHex(32), provider);
      buyer = new ethers.Wallet(randomHex(32), provider);
      zone = new ethers.Wallet(randomHex(32), provider);
      await Promise.all(
        [seller, buyer, zone].map((wallet) => faucet(wallet.address, provider))
      );
    });

    describe("Validate", async () => {
      it("Validate signed order and fill it with no signature", async () => {
        // Seller mints an nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
        expect({ ...initialStatus }).to.deep.eq(
          buildOrderStatus(false, false, 0, 0)
        );

        // cannot fill it with no signature yet
        order.signature = "0x";

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.revertedWith("InvalidSigner");

          // cannot validate it with no signature from a random account
          await expect(
            marketplaceContract.connect(owner).validate([order])
          ).to.be.revertedWith("InvalidSigner");
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.reverted;

          // cannot validate it with no signature from a random account
          await expect(marketplaceContract.connect(owner).validate([order])).to
            .be.reverted;
        }

        // can validate it once you add the signature back
        order.signature = signature;
        await expect(marketplaceContract.connect(owner).validate([order]))
          .to.emit(marketplaceContract, "OrderValidated")
          .withArgs(orderHash, seller.address, zone.address);

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...newStatus }).to.deep.eq(
          buildOrderStatus(true, false, 0, 0)
        );

        // Can validate it repeatedly, but no event after the first time
        await marketplaceContract.connect(owner).validate([order, order]);

        // Fulfill the order without a signature
        order.signature = "0x";
        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(false), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(false),
            },
          ]);

          return receipt;
        });

        const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...finalStatus }).to.deep.eq(
          buildOrderStatus(true, false, 1, 1)
        );

        // cannot validate it once it's been fully filled
        await expect(
          marketplaceContract.connect(owner).validate([order])
        ).to.be.revertedWith("OrderAlreadyFilled", orderHash);
      });
      it("Validate unsigned order from offerer and fill it with no signature", async () => {
        // Seller mints an nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
        expect({ ...initialStatus }).to.deep.eq(
          buildOrderStatus(false, false, 0, 0)
        );

        if (!process.env.REFERENCE) {
          // cannot fill it with no signature yet
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.revertedWith("InvalidSigner");

          // cannot validate it with no signature from a random account
          await expect(
            marketplaceContract.connect(owner).validate([order])
          ).to.be.revertedWith("InvalidSigner");
        } else {
          // cannot fill it with no signature yet
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.reverted;

          // cannot validate it with no signature from a random account
          await expect(marketplaceContract.connect(owner).validate([order])).to
            .be.reverted;
        }

        // can validate it from the seller
        await expect(marketplaceContract.connect(seller).validate([order]))
          .to.emit(marketplaceContract, "OrderValidated")
          .withArgs(orderHash, seller.address, zone.address);

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...newStatus }).to.deep.eq(
          buildOrderStatus(true, false, 0, 0)
        );

        // Fulfill the order without a signature
        order.signature = "0x";
        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(false), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(false),
            },
          ]);

          return receipt;
        });

        const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...finalStatus }).to.deep.eq(
          buildOrderStatus(true, false, 1, 1)
        );
      });
      it("Cannot validate a cancelled order", async () => {
        // Seller mints an nft
        const nftId = randomBN();

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
        expect({ ...initialStatus }).to.deep.eq(
          buildOrderStatus(false, false, 0, 0)
        );

        if (!process.env.REFERENCE) {
          // cannot fill it with no signature yet
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.revertedWith("InvalidSigner");

          // cannot validate it with no signature from a random account
          await expect(
            marketplaceContract.connect(owner).validate([order])
          ).to.be.revertedWith("InvalidSigner");
        } else {
          // cannot fill it with no signature yet
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.reverted;

          // cannot validate it with no signature from a random account
          await expect(marketplaceContract.connect(owner).validate([order])).to
            .be.reverted;
        }

        // can cancel it
        await expect(
          marketplaceContract.connect(seller).cancel([orderComponents])
        )
          .to.emit(marketplaceContract, "OrderCancelled")
          .withArgs(orderHash, seller.address, zone.address);

        // cannot validate it from the seller
        await expect(
          marketplaceContract.connect(seller).validate([order])
        ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

        // cannot validate it with a signature either
        order.signature = signature;
        await expect(
          marketplaceContract.connect(owner).validate([order])
        ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...newStatus }).to.deep.eq(
          buildOrderStatus(false, true, 0, 0)
        );
      });
    });

    describe("Cancel", async () => {
      it("Can cancel an order", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // cannot cancel it from a random account
        await expect(
          marketplaceContract.connect(owner).cancel([orderComponents])
        ).to.be.revertedWith("InvalidCanceller");

        const initialStatus = await marketplaceContract.getOrderStatus(
          orderHash
        );
        expect({ ...initialStatus }).to.deep.eq(
          buildOrderStatus(false, false, 0, 0)
        );

        // can cancel it
        await expect(
          marketplaceContract.connect(seller).cancel([orderComponents])
        )
          .to.emit(marketplaceContract, "OrderCancelled")
          .withArgs(orderHash, seller.address, zone.address);

        // cannot fill the order anymore
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(false), {
            value,
          })
        ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...newStatus }).to.deep.eq(
          buildOrderStatus(false, true, 0, 0)
        );
      });
      it("Can cancel a validated order", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // cannot cancel it from a random account
        await expect(
          marketplaceContract.connect(owner).cancel([orderComponents])
        ).to.be.revertedWith("InvalidCanceller");

        const initialStatus = await marketplaceContract.getOrderStatus(
          orderHash
        );
        expect({ ...initialStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        // Can validate it
        await expect(marketplaceContract.connect(owner).validate([order]))
          .to.emit(marketplaceContract, "OrderValidated")
          .withArgs(orderHash, seller.address, zone.address);

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...newStatus }).to.deep.equal(
          buildOrderStatus(true, false, 0, 0)
        );

        // can cancel it
        await expect(
          marketplaceContract.connect(seller).cancel([orderComponents])
        )
          .to.emit(marketplaceContract, "OrderCancelled")
          .withArgs(orderHash, seller.address, zone.address);

        // cannot fill the order anymore
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(false), {
            value,
          })
        ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

        const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...finalStatus }).to.deep.equal(
          buildOrderStatus(false, true, 0, 0)
        );
      });
      it("Can cancel an order from the zone", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        // cannot cancel it from a random account
        await expect(
          marketplaceContract.connect(owner).cancel([orderComponents])
        ).to.be.revertedWith("InvalidCanceller");

        const initialStatus = await marketplaceContract.getOrderStatus(
          orderHash
        );
        expect({ ...initialStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        // can cancel it from the zone
        await expect(
          marketplaceContract.connect(zone).cancel([orderComponents])
        )
          .to.emit(marketplaceContract, "OrderCancelled")
          .withArgs(orderHash, seller.address, zone.address);

        // cannot fill the order anymore
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(false), {
            value,
          })
        ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...newStatus }).to.deep.equal(
          buildOrderStatus(false, true, 0, 0)
        );
      });
      it("Can cancel a validated order from a zone", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
        expect({ ...initialStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        // Can validate it
        await expect(marketplaceContract.connect(owner).validate([order]))
          .to.emit(marketplaceContract, "OrderValidated")
          .withArgs(orderHash, seller.address, zone.address);

        // cannot cancel it from a random account
        await expect(
          marketplaceContract.connect(owner).cancel([orderComponents])
        ).to.be.revertedWith("InvalidCanceller");

        const newStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...newStatus }).to.deep.equal(
          buildOrderStatus(true, false, 0, 0)
        );

        // can cancel it from the zone
        await expect(
          marketplaceContract.connect(zone).cancel([orderComponents])
        )
          .to.emit(marketplaceContract, "OrderCancelled")
          .withArgs(orderHash, seller.address, zone.address);

        // cannot fill the order anymore
        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(false), {
            value,
          })
        ).to.be.revertedWith(`OrderIsCancelled("${orderHash}")`);

        const finalStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...finalStatus }).to.deep.equal(
          buildOrderStatus(false, true, 0, 0)
        );
      });
    });

    describe("Increment Counter", async () => {
      it("Can increment the counter", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        let { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const counter = await marketplaceContract.getCounter(seller.address);
        expect(counter).to.equal(0);
        expect(orderComponents.counter).to.equal(counter);

        // can increment the counter
        await expect(marketplaceContract.connect(seller).incrementCounter())
          .to.emit(marketplaceContract, "CounterIncremented")
          .withArgs(1, seller.address);

        const newCounter = await marketplaceContract.getCounter(seller.address);
        expect(newCounter).to.equal(1);

        if (!process.env.REFERENCE) {
          // Cannot fill order anymore
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.revertedWith("InvalidSigner");
        } else {
          // Cannot fill order anymore
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.reverted;
        }

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

        expect(orderComponents.counter).to.equal(newCounter);

        // Can fill order with new counter
        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(false), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(false),
            },
          ]);

          return receipt;
        });
      });
      it("Can increment the counter and implicitly cancel a validated order", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        let { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const counter = await marketplaceContract.getCounter(seller.address);
        expect(counter).to.equal(0);
        expect(orderComponents.counter).to.equal(counter);

        await expect(marketplaceContract.connect(owner).validate([order]))
          .to.emit(marketplaceContract, "OrderValidated")
          .withArgs(orderHash, seller.address, zone.address);

        // can increment the counter
        await expect(marketplaceContract.connect(seller).incrementCounter())
          .to.emit(marketplaceContract, "CounterIncremented")
          .withArgs(1, seller.address);

        const newCounter = await marketplaceContract.getCounter(seller.address);
        expect(newCounter).to.equal(1);

        if (!process.env.REFERENCE) {
          // Cannot fill order anymore
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.revertedWith("InvalidSigner");
        } else {
          // Cannot fill order anymore
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.reverted;
        }

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

        expect(orderComponents.counter).to.equal(newCounter);

        // Can fill order with new counter
        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(false), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(false),
            },
          ]);

          return receipt;
        });
      });
      it("Can increment the counter as the zone and implicitly cancel a validated order", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        let { order, orderHash, value, orderComponents } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const counter = await marketplaceContract.getCounter(seller.address);
        expect(counter).to.equal(0);
        expect(orderComponents.counter).to.equal(counter);

        await expect(marketplaceContract.connect(owner).validate([order]))
          .to.emit(marketplaceContract, "OrderValidated")
          .withArgs(orderHash, seller.address, zone.address);

        // can increment the counter as the offerer
        await expect(marketplaceContract.connect(seller).incrementCounter())
          .to.emit(marketplaceContract, "CounterIncremented")
          .withArgs(1, seller.address);

        const newCounter = await marketplaceContract.getCounter(seller.address);
        expect(newCounter).to.equal(1);

        if (!process.env.REFERENCE) {
          // Cannot fill order anymore
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.revertedWith("InvalidSigner");
        } else {
          // Cannot fill order anymore
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.reverted;
        }

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

        expect(orderComponents.counter).to.equal(newCounter);

        // Can fill order with new counter
        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(false), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(false),
            },
          ]);

          return receipt;
        });
      });
    });
  });

  describe("Advanced orders", async () => {
    let seller;
    let buyer;

    beforeEach(async () => {
      // Setup basic buyer/seller wallets with ETH
      seller = new ethers.Wallet(randomHex(32), provider);
      buyer = new ethers.Wallet(randomHex(32), provider);
      zone = new ethers.Wallet(randomHex(32), provider);
      await Promise.all(
        [seller, buyer, zone].map((wallet) => faucet(wallet.address, provider))
      );
    });

    describe("Partial fills", async () => {
      it("Partial fills (standard)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
          getItemETH(amount.mul(10), amount.mul(10), zone.address),
          getItemETH(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 2; // fill two tenths or one fifth
        order.denominator = 10; // fill two tenths or one fifth

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 2, 10)
        );

        order.numerator = 1; // fill one half
        order.denominator = 2; // fill one half

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 14, 20)
        );

        // Fill remaining; only 3/10ths will be fillable
        order.numerator = 1; // fill one half
        order.denominator = 2; // fill one half

        const ordersClone = JSON.parse(JSON.stringify([order]));
        for (const [, clonedOrder] of Object.entries(ordersClone)) {
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

        await withBalanceChecks(ordersClone, 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: ordersClone[0],
                orderHash,
                fulfiller: buyer.address,
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 40, 40)
        );
      });
      it("Partial fills (standard, additional permutations)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
          getItemETH(amount.mul(10), amount.mul(10), zone.address),
          getItemETH(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 2; // fill two tenths or one fifth
        order.denominator = 10; // fill two tenths or one fifth

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 2, 10)
        );

        order.numerator = 1; // fill one tenth
        order.denominator = 10; // fill one tenth

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 3, 10)
        );

        // Fill all available; only 7/10ths will be fillable
        order.numerator = 1; // fill all available
        order.denominator = 1; // fill all available

        const ordersClone = JSON.parse(JSON.stringify([order]));
        for (const [, clonedOrder] of Object.entries(ordersClone)) {
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

        await withBalanceChecks(ordersClone, 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: ordersClone[0],
                orderHash,
                fulfiller: buyer.address,
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 10, 10)
        );
      });
      it("Partial fills (match)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
          getItemETH(amount.mul(10), amount.mul(10), zone.address),
          getItemETH(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 2; // fill two tenths or one fifth
        order.denominator = 10; // fill two tenths or one fifth

        let mirrorObject;
        mirrorObject = await createMirrorBuyNowOrder(buyer, zone, order);

        const fulfillments = defaultBuyNowMirrorFulfillment;

        let executions = await simulateAdvancedMatchOrders(
          [order, mirrorObject.mirrorOrder],
          [], // no criteria resolvers
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        const tx = marketplaceContract.connect(owner).matchAdvancedOrders(
          [order, mirrorObject.mirrorOrder],
          [], // no criteria resolvers
          fulfillments,
          {
            value,
          }
        );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );

        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order: mirrorObject.mirrorOrder,
              orderHash: mirrorObject.mirrorOrderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 2, 10)
        );

        order.numerator = 1; // fill one tenth
        order.denominator = 10; // fill one tenth

        mirrorObject = await createMirrorBuyNowOrder(buyer, zone, order);

        executions = await simulateAdvancedMatchOrders(
          [order, mirrorObject.mirrorOrder],
          [], // no criteria resolvers
          fulfillments,
          owner,
          value
        );

        const tx2 = marketplaceContract.connect(owner).matchAdvancedOrders(
          [order, mirrorObject.mirrorOrder],
          [], // no criteria resolvers
          fulfillments,
          {
            value,
          }
        );
        const receipt2 = await (await tx2).wait();
        await checkExpectedEvents(
          tx2,
          receipt2,
          [
            {
              order,
              orderHash,
              fulfiller: constants.AddressZero,
            },
            {
              order: mirrorObject.mirrorOrder,
              orderHash: mirrorObject.mirrorOrderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 3, 10)
        );

        // Fill all available; only 7/10ths will be fillable
        order.numerator = 7; // fill all available
        order.denominator = 10; // fill all available

        mirrorObject = await createMirrorBuyNowOrder(buyer, zone, order);

        executions = await simulateAdvancedMatchOrders(
          [order, mirrorObject.mirrorOrder],
          [], // no criteria resolvers
          fulfillments,
          owner,
          value
        );

        const tx3 = await marketplaceContract
          .connect(owner)
          .matchAdvancedOrders(
            [order, mirrorObject.mirrorOrder],
            [], // no criteria resolvers
            fulfillments,
            {
              value,
            }
          );
        const receipt3 = await tx3.wait();
        await checkExpectedEvents(
          tx3,
          receipt3,
          [
            {
              order,
              orderHash,
              fulfiller: constants.AddressZero,
            },
            {
              order: mirrorObject.mirrorOrder,
              orderHash: mirrorObject.mirrorOrderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );
        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 10, 10)
        );
      });

      it("Simplifies fraction when numerator/denominator would overflow", async () => {
        const numer1 = toBN(2).pow(100);
        const denom1 = toBN(2).pow(101);
        const numer2 = toBN(2).pow(20);
        const denom2 = toBN(2).pow(22);
        const amt = 8;
        await mintAndApproveERC20(buyer, marketplaceContract.address, amt);
        // Seller mints nft
        const { nftId } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000,
          undefined,
          amt
        );

        const offer = [getTestItem1155(nftId, amt, amt)];

        const consideration = [getTestItem20(amt, amt, seller.address)];
        const { order, orderHash, value } = await createOrder(
          seller,
          undefined,
          offer,
          consideration,
          1, // PARTIAL_OPEN
          undefined,
          undefined,
          undefined,
          undefined,
          undefined,
          true
        );
        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        // 1/2
        order.numerator = numer1;
        order.denominator = denom1;

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(order, [], toKey(false), buyer.address, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, numer1, denom1)
        );

        order.numerator = numer2;
        order.denominator = denom2;

        await marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(order, [], toKey(false), buyer.address, {
            value,
          });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, toBN(3), toBN(4))
        );
      });

      it("Reverts when numerator/denominator overflow", async () => {
        const prime1 = toBN(2).pow(7).sub(1);
        const prime2 = toBN(2).pow(61).sub(1);
        const prime3 = toBN(2).pow(107).sub(1);
        const amt = prime1.mul(prime2).mul(prime3);
        await mintAndApproveERC20(buyer, marketplaceContract.address, amt);
        // Seller mints nft
        const { nftId } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000,
          undefined,
          amt
        );

        const offer = [getTestItem1155(nftId, amt, amt)];

        const consideration = [getTestItem20(amt, amt, seller.address)];
        const { order, orderHash, value } = await createOrder(
          seller,
          undefined,
          offer,
          consideration,
          1, // PARTIAL_OPEN
          undefined,
          undefined,
          undefined,
          undefined,
          undefined,
          true
        );
        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        // 1/2
        order.numerator = 1;
        order.denominator = prime2;

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(order, [], toKey(false), buyer.address, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, toBN(1), prime2)
        );

        order.numerator = prime1;
        order.denominator = prime3;

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(order, [], toKey(false), buyer.address, {
              value,
            })
        ).to.be.revertedWith(
          "0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
        );
      });
    });

    describe("Criteria-based orders", async () => {
      it("Criteria-based offer item ERC721 (standard)", async () => {
        // Seller mints nfts
        const [nftId, secondNFTId, thirdNFTId] = await mint721s(seller, 3);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await withBalanceChecks([order], 0, criteriaResolvers, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            criteriaResolvers
          );

          return receipt;
        });
      });
      it("Criteria-based offer item ERC1155 (standard)", async () => {
        // Seller mints nfts
        const { nftId, amount } = await mint1155(seller);

        // Seller approves marketplace contract to transfer NFTs
        await set1155ApprovalForAll(seller, marketplaceContract.address, true);

        const { root, proofs } = merkleTree([nftId]);

        const offer = [getTestItem1155WithCriteria(root, toBN(1), toBN(1))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await withBalanceChecks([order], 0, criteriaResolvers, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            criteriaResolvers
          );

          return receipt;
        });
      });
      it("Criteria-based offer item (standard, collection-level)", async () => {
        // Seller mints nfts
        const nftId = randomBN();
        const secondNFTId = randomBN();
        const thirdNFTId = randomBN();

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const offer = [
          getTestItem721WithCriteria(constants.HashZero, toBN(1), toBN(1)),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const criteriaResolvers = [buildResolver(0, 0, 0, nftId, [])];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await withBalanceChecks([order], 0, criteriaResolvers, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            criteriaResolvers
          );

          return receipt;
        });
      });
      it("Criteria-based offer item ERC721 (match)", async () => {
        // Seller mints nfts
        const nftId = randomBN();
        const secondNFTId = randomBN();
        const thirdNFTId = randomBN();

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        const { mirrorOrder, mirrorOrderHash } =
          await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            criteriaResolvers
          );

        const fulfillments = [
          [[[1, 0]], [[0, 0]]],
          [[[0, 0]], [[1, 0]]],
          [[[1, 1]], [[0, 1]]],
          [[[1, 2]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateAdvancedMatchOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [order, mirrorOrder],
              criteriaResolvers,
              fulfillments,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions,
            criteriaResolvers
          );

          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      it("Criteria-based offer item ERC1155 (match)", async () => {
        // Seller mints nfts
        const { nftId, amount } = await mint1155(seller);

        // Seller approves marketplace contract to transfer NFTs
        await set1155ApprovalForAll(seller, marketplaceContract.address, true);

        const { root, proofs } = merkleTree([nftId]);

        const offer = [getTestItem1155WithCriteria(root, toBN(1), toBN(1))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        const { mirrorOrder, mirrorOrderHash } =
          await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            criteriaResolvers
          );

        const fulfillments = [
          [[[1, 0]], [[0, 0]]],
          [[[0, 0]], [[1, 0]]],
          [[[1, 1]], [[0, 1]]],
          [[[1, 2]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateAdvancedMatchOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [order, mirrorOrder],
              criteriaResolvers,
              fulfillments,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions,
            criteriaResolvers
          );

          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      it("Criteria-based offer item (match, collection-level)", async () => {
        // Seller mints nfts
        const nftId = randomBN();
        const secondNFTId = randomBN();
        const thirdNFTId = randomBN();

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const offer = [
          getTestItem721WithCriteria(constants.HashZero, toBN(1), toBN(1)),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const criteriaResolvers = [buildResolver(0, 0, 0, nftId, [])];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        const { mirrorOrder, mirrorOrderHash } =
          await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            criteriaResolvers
          );

        const fulfillments = [
          [[[1, 0]], [[0, 0]]],
          [[[0, 0]], [[1, 0]]],
          [[[1, 1]], [[0, 1]]],
          [[[1, 2]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateAdvancedMatchOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = marketplaceContract
            .connect(owner)
            .matchAdvancedOrders(
              [order, mirrorOrder],
              criteriaResolvers,
              fulfillments,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions,
            criteriaResolvers
          );

          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      it("Criteria-based consideration item (standard)", async () => {
        // buyer mints nfts
        const nftId = randomBN();
        const secondNFTId = randomBN();
        const thirdNFTId = randomBN();

        await testERC721.mint(buyer.address, nftId);
        await testERC721.mint(buyer.address, secondNFTId);
        await testERC721.mint(buyer.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        const { root, proofs } = merkleTree(tokenIds);
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );
        const offer = [getTestItem20(tokenAmount, tokenAmount)];

        const consideration = [
          getTestItem721WithCriteria(root, toBN(1), toBN(1), seller.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 1, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await withBalanceChecks(
          [order],
          value.mul(-1),
          criteriaResolvers,
          async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                criteriaResolvers,
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              );
            const receipt = await (await tx).wait();
            await checkExpectedEvents(
              tx,
              receipt,
              [
                {
                  order,
                  orderHash,
                  fulfiller: buyer.address,
                  fulfillerConduitKey: toKey(false),
                },
              ],
              null,
              criteriaResolvers
            );

            return receipt;
          }
        );
      });
      it("Criteria-based consideration item ERC1155 (standard)", async () => {
        // buyer mints nfts
        const { nftId, amount } = await mint1155(buyer);

        // Seller approves marketplace contract to transfer NFTs
        await set1155ApprovalForAll(buyer, marketplaceContract.address, true);

        const { root, proofs } = merkleTree([nftId]);
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );
        const offer = [getTestItem20(tokenAmount, tokenAmount)];

        const consideration = [
          getTestItem1155WithCriteria(root, toBN(1), toBN(1), seller.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 1, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await withBalanceChecks(
          [order],
          value.mul(-1),
          criteriaResolvers,
          async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                criteriaResolvers,
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              );
            const receipt = await (await tx).wait();
            await checkExpectedEvents(
              tx,
              receipt,
              [
                {
                  order,
                  orderHash,
                  fulfiller: buyer.address,
                  fulfillerConduitKey: toKey(false),
                },
              ],
              null,
              criteriaResolvers
            );

            return receipt;
          }
        );
      });
      it("Criteria-based wildcard consideration item (standard)", async () => {
        // buyer mints nft
        const nftId = await mintAndApprove721(
          buyer,
          marketplaceContract.address
        );
        const tokenAmount = minRandom(100);
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );
        const offer = [getTestItem20(tokenAmount, tokenAmount)];

        const consideration = [
          getTestItem721WithCriteria(
            constants.HashZero,
            toBN(1),
            toBN(1),
            seller.address
          ),
        ];

        const criteriaResolvers = [buildResolver(0, 1, 0, nftId, [])];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await withBalanceChecks(
          [order],
          value.mul(-1),
          criteriaResolvers,
          async () => {
            const tx = marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                criteriaResolvers,
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              );
            const receipt = await (await tx).wait();
            await checkExpectedEvents(
              tx,
              receipt,
              [
                {
                  order,
                  orderHash,
                  fulfiller: buyer.address,
                  fulfillerConduitKey: toKey(false),
                },
              ],
              null,
              criteriaResolvers
            );

            return receipt;
          }
        );
      });
      it("Criteria-based consideration item ERC721 (match)", async () => {
        // Fulfiller mints nft
        const nftId = await mint721(buyer);
        const tokenAmount = minRandom(100);

        // Fulfiller approves marketplace contract to transfer NFT
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        // Offerer mints ERC20
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // Fulfiller mints ERC20
        await mintAndApproveERC20(
          buyer,
          marketplaceContract.address,
          tokenAmount
        );

        const { root, proofs } = merkleTree([nftId]);

        const offer = [
          // Offerer (Seller)
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

        const consideration = [
          // Fulfiller (Buyer)
          {
            itemType: 4, // ERC721WithCriteria
            token: testERC721.address,
            identifierOrCriteria: root,
            startAmount: toBN(1),
            endAmount: toBN(1),
            recipient: seller.address,
          },
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 1, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        const { mirrorOrder, mirrorOrderHash } =
          await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            criteriaResolvers
          );

        const fulfillments = defaultAcceptOfferMirrorFulfillment;

        const executions = await simulateAdvancedMatchOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        const tx = marketplaceContract
          .connect(owner)
          .matchAdvancedOrders(
            [order, mirrorOrder],
            criteriaResolvers,
            fulfillments,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions,
          criteriaResolvers
        );

        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order: mirrorOrder,
              orderHash: mirrorOrderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );
        return receipt;
      });
      it("Criteria-based consideration item ERC1155 (match)", async () => {
        // Fulfiller mints nft
        const { nftId, amount } = await mint1155(buyer);
        const tokenAmount = minRandom(100);

        // Fulfiller approves marketplace contract to transfer NFT
        await set1155ApprovalForAll(buyer, marketplaceContract.address, true);

        // Offerer mints ERC20
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // Fulfiller mints ERC20
        await mintAndApproveERC20(
          buyer,
          marketplaceContract.address,
          tokenAmount
        );

        const { root, proofs } = merkleTree([nftId]);

        const offer = [
          // Offerer (Seller)
          getTestItem20(tokenAmount.sub(100), tokenAmount.sub(100)),
        ];

        const consideration = [
          // Fulfiller (Buyer)
          {
            itemType: 5, // ERC1155_WITH_CRITERIA
            token: testERC1155.address,
            identifierOrCriteria: root,
            startAmount: toBN(1),
            endAmount: toBN(1),
            recipient: seller.address,
          },
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 1, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        const { mirrorOrder, mirrorOrderHash } =
          await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            criteriaResolvers
          );

        const fulfillments = defaultAcceptOfferMirrorFulfillment;

        const executions = await simulateAdvancedMatchOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        const tx = marketplaceContract
          .connect(owner)
          .matchAdvancedOrders(
            [order, mirrorOrder],
            criteriaResolvers,
            fulfillments,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions,
          criteriaResolvers
        );

        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order: mirrorOrder,
              orderHash: mirrorOrderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );
        return receipt;
      });
    });

    describe("Ascending / Descending amounts", async () => {
      it("Ascending offer amount (standard)", async () => {
        // Seller mints nft
        const nftId = randomBN();
        const startAmount = toBN(randomBN(2));
        const endAmount = startAmount.mul(2);
        await testERC1155.mint(seller.address, nftId, endAmount.mul(10));

        // Seller approves marketplace contract to transfer NFTs

        await set1155ApprovalForAll(seller, marketplaceContract.address, true);

        const offer = [
          getTestItem1155(nftId, startAmount, endAmount, undefined),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );
      });
      it("Ascending consideration amount (standard)", async () => {
        // Seller mints ERC20
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(
          seller,
          marketplaceContract.address,
          tokenAmount
        );

        // Buyer mints nft
        const nftId = randomBN();
        const startAmount = toBN(randomBN(2));
        const endAmount = startAmount.mul(2);
        await testERC1155.mint(buyer.address, nftId, endAmount.mul(10));

        // Buyer approves marketplace contract to transfer NFTs
        await set1155ApprovalForAll(buyer, marketplaceContract.address, true);

        // Buyer needs to approve marketplace to transfer ERC20 tokens too (as it's a standard fulfillment)
        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [getTestItem20(tokenAmount, tokenAmount)];

        const consideration = [
          getTestItem1155(
            nftId,
            startAmount,
            endAmount,
            undefined,
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

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );
      });
      it("Ascending offer amount (match)", async () => {
        // Seller mints nft
        const nftId = randomBN();
        const startAmount = toBN(randomBN(2));
        const endAmount = startAmount.mul(2);
        await testERC1155.mint(seller.address, nftId, endAmount.mul(10));

        // Seller approves marketplace contract to transfer NFTs

        await set1155ApprovalForAll(seller, marketplaceContract.address, true);

        const offer = [
          getTestItem1155(nftId, startAmount, endAmount, undefined),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = defaultBuyNowMirrorFulfillment;

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        const tx = marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: constants.AddressZero,
            },
            {
              order: mirrorOrder,
              orderHash: mirrorOrderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );
      });
    });

    describe("Sequenced Orders", async () => {
      it("Match A => B => C => A", async () => {
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );
        const secondNFTId = await mintAndApprove721(
          buyer,
          marketplaceContract.address
        );
        const thirdNFTId = await mintAndApprove721(
          owner,
          marketplaceContract.address
        );

        const offerOne = [
          getTestItem721(
            nftId,
            toBN(1),
            toBN(1),
            undefined,
            testERC721.address
          ),
        ];

        const considerationOne = [
          getTestItem721(
            secondNFTId,
            toBN(1),
            toBN(1),
            seller.address,
            testERC721.address
          ),
        ];

        const { order: orderOne, orderHash: orderHashOne } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0 // FULL_OPEN
        );

        const offerTwo = [
          getTestItem721(
            secondNFTId,
            toBN(1),
            toBN(1),
            undefined,
            testERC721.address
          ),
        ];

        const considerationTwo = [
          getTestItem721(
            thirdNFTId,
            toBN(1),
            toBN(1),
            buyer.address,
            testERC721.address
          ),
        ];

        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          buyer,
          zone,
          offerTwo,
          considerationTwo,
          0 // FULL_OPEN
        );

        const offerThree = [
          getTestItem721(
            thirdNFTId,
            toBN(1),
            toBN(1),
            undefined,
            testERC721.address
          ),
        ];

        const considerationThree = [
          getTestItem721(
            nftId,
            toBN(1),
            toBN(1),
            owner.address,
            testERC721.address
          ),
        ];

        const { order: orderThree, orderHash: orderHashThree } =
          await createOrder(
            owner,
            zone,
            offerThree,
            considerationThree,
            0 // FULL_OPEN
          );

        const fulfillments = [
          [[[1, 0]], [[0, 0]]],
          [[[0, 0]], [[2, 0]]],
          [[[2, 0]], [[1, 0]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateAdvancedMatchOrders(
          [orderOne, orderTwo, orderThree],
          [], // no criteria resolvers
          fulfillments,
          owner,
          0 // no value
        );

        expect(executions.length).to.equal(fulfillments.length);

        const tx = marketplaceContract
          .connect(owner)
          .matchAdvancedOrders(
            [orderOne, orderTwo, orderThree],
            [],
            fulfillments,
            {
              value: 0,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order: orderOne,
              orderHash: orderHashOne,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );

        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order: orderTwo,
              orderHash: orderHashTwo,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order: orderThree,
              orderHash: orderHashThree,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );
      });
      it("Match with fewer executions when one party has multiple orders that coincide", async () => {
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );
        const secondNFTId = await mintAndApprove721(
          buyer,
          marketplaceContract.address
        );

        const offerOne = [
          getTestItem721(
            nftId,
            toBN(1),
            toBN(1),
            undefined,
            testERC721.address
          ),
        ];

        const considerationOne = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
        ];

        const { order: orderOne, orderHash: orderHashOne } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0 // FULL_OPEN
        );

        const offerTwo = [getItemETH(parseEther("10"), parseEther("10"))];

        const considerationTwo = [
          getTestItem721(
            secondNFTId,
            toBN(1),
            toBN(1),
            seller.address,
            testERC721.address
          ),
        ];

        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          seller,
          zone,
          offerTwo,
          considerationTwo,
          0 // FULL_OPEN
        );

        const offerThree = [
          getTestItem721(
            secondNFTId,
            toBN(1),
            toBN(1),
            undefined,
            testERC721.address
          ),
        ];

        const considerationThree = [
          getTestItem721(
            nftId,
            toBN(1),
            toBN(1),
            buyer.address,
            testERC721.address
          ),
        ];

        const { order: orderThree, orderHash: orderHashThree } =
          await createOrder(
            buyer,
            zone,
            offerThree,
            considerationThree,
            0 // FULL_OPEN
          );

        const fulfillments = [
          [[[1, 0]], [[0, 0]]],
          [[[0, 0]], [[2, 0]]],
          [[[2, 0]], [[1, 0]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateAdvancedMatchOrders(
          [orderOne, orderTwo, orderThree],
          [], // no criteria resolvers
          fulfillments,
          owner,
          0 // no value
        );

        expect(executions.length).to.equal(fulfillments.length - 1);

        const tx = marketplaceContract
          .connect(owner)
          .matchAdvancedOrders(
            [orderOne, orderTwo, orderThree],
            [],
            fulfillments,
            {
              value: 0,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order: orderOne,
              orderHash: orderHashOne,
              fulfiller: constants.AddressZero,
            },
            {
              order: orderTwo,
              orderHash: orderHashTwo,
              fulfiller: constants.AddressZero,
            },
            {
              order: orderThree,
              orderHash: orderHashThree,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );
        return receipt;
      });
    });

    describe("Order groups", async () => {
      it("Multiple offer components at once", async () => {
        // Seller mints NFTs
        const { nftId, amount } = await mint1155(seller, 2);

        // Seller approves marketplace contract to transfer NFT

        await set1155ApprovalForAll(seller, marketplaceContract.address, true);

        // Buyer mints ERC20s
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(
          buyer,
          marketplaceContract.address,
          tokenAmount.mul(2)
        );

        const offerOne = [getTestItem1155(nftId, amount, amount)];

        const considerationOne = [
          getTestItem20(tokenAmount, tokenAmount, seller.address),
        ];

        const { order: orderOne, orderHash: orderHashOne } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0 // FULL_OPEN
        );

        const offerTwo = [getTestItem1155(nftId, amount, amount)];

        const considerationTwo = [
          getTestItem20(tokenAmount, tokenAmount, seller.address),
        ];

        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          seller,
          zone,
          offerTwo,
          considerationTwo,
          0 // FULL_OPEN
        );

        const offerThree = [
          getTestItem20(tokenAmount.mul(2), tokenAmount.mul(2)),
        ];

        const considerationThree = [
          getTestItem1155(
            nftId,
            amount.mul(2),
            amount.mul(2),
            undefined,
            buyer.address
          ),
        ];

        const { order: orderThree, orderHash: orderHashThree } =
          await createOrder(
            buyer,
            zone,
            offerThree,
            considerationThree,
            0 // FULL_OPEN
          );

        const fulfillments = [
          [
            [
              [0, 0],
              [1, 0],
            ],
            [[2, 0]],
          ],
          [[[2, 0]], [[0, 0]]],
          [[[2, 0]], [[1, 0]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateAdvancedMatchOrders(
          [orderOne, orderTwo, orderThree],
          [], // no criteria resolvers
          fulfillments,
          owner,
          0 // no value
        );

        expect(executions.length).to.equal(fulfillments.length);

        const tx = marketplaceContract
          .connect(buyer)
          .matchAdvancedOrders(
            [orderOne, orderTwo, orderThree],
            [],
            fulfillments,
            {
              value: 0,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order: orderOne,
              orderHash: orderHashOne,
              fulfiller: constants.AddressZero,
            },
            {
              order: orderTwo,
              orderHash: orderHashTwo,
              fulfiller: constants.AddressZero,
            },
            {
              order: orderThree,
              orderHash: orderHashThree,
              fulfiller: constants.AddressZero,
            },
          ],
          executions,
          [],
          true
        );

        expect(
          toBN("0x" + receipt.events[3].data.slice(66)).toString()
        ).to.equal(amount.mul(2).toString());

        return receipt;
      });
      it("Multiple consideration components at once", async () => {
        // Seller mints NFTs
        const { nftId, amount } = await mint1155(seller, 2);

        // Seller approves marketplace contract to transfer NFT

        await set1155ApprovalForAll(seller, marketplaceContract.address, true);

        // Buyer mints ERC20s
        const tokenAmount = toBN(random128());
        await mintAndApproveERC20(
          buyer,
          marketplaceContract.address,
          tokenAmount.mul(2)
        );

        const offerOne = [
          getTestItem1155(nftId, amount.mul(2), amount.mul(2), undefined),
        ];

        const considerationOne = [
          getTestItem20(tokenAmount.mul(2), tokenAmount.mul(2), seller.address),
        ];

        const { order: orderOne, orderHash: orderHashOne } = await createOrder(
          seller,
          zone,
          offerOne,
          considerationOne,
          0 // FULL_OPEN
        );

        const offerTwo = [getTestItem20(tokenAmount, tokenAmount)];

        const considerationTwo = [
          getTestItem1155(nftId, amount, amount, undefined, buyer.address),
        ];

        const { order: orderTwo, orderHash: orderHashTwo } = await createOrder(
          buyer,
          zone,
          offerTwo,
          considerationTwo,
          0 // FULL_OPEN
        );

        const offerThree = [getTestItem20(tokenAmount, tokenAmount)];

        const considerationThree = [
          getTestItem1155(nftId, amount, amount, undefined, buyer.address),
        ];

        const { order: orderThree, orderHash: orderHashThree } =
          await createOrder(
            buyer,
            zone,
            offerThree,
            considerationThree,
            0 // FULL_OPEN
          );

        const fulfillments = [
          [
            [[0, 0]],
            [
              [1, 0],
              [2, 0],
            ],
          ],
          [[[1, 0]], [[0, 0]]],
          [[[2, 0]], [[0, 0]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateAdvancedMatchOrders(
          [orderOne, orderTwo, orderThree],
          [], // no criteria resolvers
          fulfillments,
          owner,
          0 // no value
        );

        expect(executions.length).to.equal(fulfillments.length);

        await whileImpersonating(buyer.address, provider, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .matchAdvancedOrders(
              [orderOne, orderTwo, orderThree],
              [],
              fulfillments,
              {
                value: 0,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order: orderOne,
                orderHash: orderHashOne,
                fulfiller: constants.AddressZero,
              },
              {
                order: orderTwo,
                orderHash: orderHashTwo,
                fulfiller: constants.AddressZero,
              },
              {
                order: orderThree,
                orderHash: orderHashThree,
                fulfiller: constants.AddressZero,
              },
            ],
            executions,
            [],
            true
          );

          // TODO: include balance checks on the duplicate ERC20 transfers

          return receipt;
        });
      });
    });

    describe("Complex ERC1155 transfers", async () => {
      it("ERC1155 <=> ETH (match)", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mint1155(seller);

        // Seller mints second nft
        const { nftId: secondNftId, amount: secondAmount } =
          await mintAndApprove1155(seller, marketplaceContract.address);

        const offer = [
          getTestItem1155(nftId, amount, amount, undefined),
          getTestItem1155(secondNftId, secondAmount, secondAmount),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[0, 1]], [[1, 1]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(5);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match, three items)", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mint1155(seller);

        // Seller mints second nft
        const { nftId: secondNftId, amount: secondAmount } = await mint1155(
          seller
        );

        // Seller mints third nft
        const { nftId: thirdNftId, amount: thirdAmount } =
          await mintAndApprove1155(seller, marketplaceContract.address);

        const offer = [
          getTestItem1155(nftId, amount, amount, undefined),
          getTestItem1155(secondNftId, secondAmount, secondAmount),
          getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[0, 1]], [[1, 1]]],
          [[[0, 2]], [[1, 2]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(6);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match via conduit)", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mint1155(seller);

        // Seller mints second nft
        const { nftId: secondNftId, amount: secondAmount } =
          await mintAndApprove1155(seller, conduitOne.address);

        const offer = [
          getTestItem1155(nftId, amount, amount, undefined),
          getTestItem1155(secondNftId, secondAmount, secondAmount),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[0, 1]], [[1, 1]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(5);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match, single item)", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem1155(nftId, amount, amount, undefined)];

        const consideration = [];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [toFulfillment([[0, 0]], [[1, 0]])];

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(1);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match, single 1155)", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem1155(nftId, amount, amount, undefined)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        await whileImpersonating(owner.address, provider, async () => {
          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      it("ERC1155 <=> ETH (match, two different 1155 contracts)", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mint1155(seller);

        // Seller mints second nft
        const secondNftId = toBN(randomBN(4));
        const secondAmount = toBN(randomBN(4));
        await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

        // Seller approves marketplace contract to transfer NFTs

        await set1155ApprovalForAll(seller, marketplaceContract.address, true);

        await expect(
          testERC1155Two
            .connect(seller)
            .setApprovalForAll(marketplaceContract.address, true)
        )
          .to.emit(testERC1155Two, "ApprovalForAll")
          .withArgs(seller.address, marketplaceContract.address, true);

        const offer = [
          getTestItem1155(nftId, amount, amount, undefined),
          getTestItem1155(
            secondNftId,
            secondAmount,
            secondAmount,
            testERC1155Two.address
          ),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[0, 1]], [[1, 1]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(5);

        await marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          });
      });
      it("ERC1155 <=> ETH (match, one single and one with two 1155's)", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        // Seller mints second nft
        const secondNftId = toBN(randomBN(4));
        const secondAmount = toBN(randomBN(4));
        await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

        // Seller mints third nft
        const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(
          seller
        );

        // Seller approves marketplace contract to transfer NFTs

        await expect(
          testERC1155Two
            .connect(seller)
            .setApprovalForAll(marketplaceContract.address, true)
        )
          .to.emit(testERC1155Two, "ApprovalForAll")
          .withArgs(seller.address, marketplaceContract.address, true);

        const offer = [
          getTestItem1155(nftId, amount, amount, undefined),
          getTestItem1155(
            secondNftId,
            secondAmount,
            secondAmount,
            testERC1155Two.address
          ),
          getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[0, 1]], [[1, 1]]],
          [[[0, 2]], [[1, 2]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(6);

        await marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          });
      });
      it("ERC1155 <=> ETH (match, two different groups of 1155's)", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        // Seller mints second nft
        const secondNftId = toBN(randomBN(4));
        const secondAmount = toBN(randomBN(4));
        await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

        // Seller mints third nft
        const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(
          seller
        );

        // Seller mints fourth nft
        const fourthNftId = toBN(randomBN(4));
        const fourthAmount = toBN(randomBN(4));
        await testERC1155Two.mint(seller.address, fourthNftId, fourthAmount);

        // Seller approves marketplace contract to transfer NFTs

        await expect(
          testERC1155Two
            .connect(seller)
            .setApprovalForAll(marketplaceContract.address, true)
        )
          .to.emit(testERC1155Two, "ApprovalForAll")
          .withArgs(seller.address, marketplaceContract.address, true);

        const offer = [
          getTestItem1155(nftId, amount, amount, undefined),
          getTestItem1155(
            secondNftId,
            secondAmount,
            secondAmount,
            testERC1155Two.address
          ),
          getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
          getTestItem1155(
            fourthNftId,
            fourthAmount,
            fourthAmount,
            testERC1155Two.address
          ),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[0, 1]], [[1, 1]]],
          [[[0, 2]], [[1, 2]]],
          [[[0, 3]], [[1, 3]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(7);

        await marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          });
      });
    });

    describe("Fulfill Available Orders", async () => {
      it("Can fulfill a single order via fulfillAvailableOrders", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address,
          10
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [toFulfillmentComponents([[0, 0]])];

        const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]].map(
          toFulfillmentComponents
        );

        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [order],
              offerComponents,
              considerationComponents,
              toKey(false),
              100,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
            },
          ]);

          return receipt;
        });
      });
      it("Can fulfill a single order via fulfillAvailableAdvancedOrders", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address,
          11
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [[[0, 0]]];

        const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              offerComponents,
              considerationComponents,
              toKey(false),
              constants.AddressZero,
              100,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
            },
          ]);

          return receipt;
        });
      });
      it("Can fulfill a single order via fulfillAvailableAdvancedOrders with recipient specified", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [[[0, 0]]];

        const considerationComponents = [[[0, 0]], [[0, 1]]];

        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              offerComponents,
              considerationComponents,
              toKey(false),
              owner.address,
              100,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              recipient: owner.address,
            },
          ]);

          return receipt;
        });
      });
      it("Can fulfill and aggregate multiple orders via fulfillAvailableOrders", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          1,
          1,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
          toFulfillmentComponents([
            [0, 0],
            [1, 0],
          ]),
        ];

        const considerationComponents = [
          [
            [0, 0],
            [1, 0],
          ],
          [
            [0, 1],
            [1, 1],
          ],
          [
            [0, 2],
            [1, 2],
          ],
        ].map(toFulfillmentComponents);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [orderOne, orderTwo],
            0,
            null,
            async () => {
              const tx = marketplaceContract
                .connect(buyer)
                .fulfillAvailableOrders(
                  [orderOne, orderTwo],
                  offerComponents,
                  considerationComponents,
                  toKey(false),
                  100,
                  {
                    value: value.mul(2),
                  }
                );
              const receipt = await (await tx).wait();
              await checkExpectedEvents(
                tx,
                receipt,
                [
                  {
                    order: orderOne,
                    orderHash: orderHashOne,
                    fulfiller: buyer.address,
                  },
                  {
                    order: orderTwo,
                    orderHash: orderHashTwo,
                    fulfiller: buyer.address,
                  },
                ],
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
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          1,
          2,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
          toFulfillmentComponents([
            [0, 0],
            [1, 0],
          ]),
        ];

        const considerationComponents = [
          [
            [0, 0],
            [1, 0],
          ],
          [
            [0, 1],
            [1, 1],
          ],
          [
            [0, 2],
            [1, 2],
          ],
        ].map(toFulfillmentComponents);

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [orderOne, orderTwo],
            0,
            null,
            async () => {
              const tx = marketplaceContract
                .connect(buyer)
                .fulfillAvailableAdvancedOrders(
                  [orderOne, orderTwo],
                  [],
                  offerComponents,
                  considerationComponents,
                  toKey(false),
                  constants.AddressZero,
                  100,
                  {
                    value: value.mul(2),
                  }
                );
              const receipt = await (await tx).wait();
              await checkExpectedEvents(
                tx,
                receipt,
                [
                  {
                    order: orderOne,
                    orderHash: orderHashOne,
                    fulfiller: buyer.address,
                  },
                  {
                    order: orderTwo,
                    orderHash: orderHashTwo,
                    fulfiller: buyer.address,
                  },
                ],
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
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          1,
          3,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

        const { order: orderTwo } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            [0, 0],
            [1, 0],
          ],
        ];

        const considerationComponents = [
          [
            [0, 0],
            [1, 0],
          ],
          [
            [0, 1],
            [1, 1],
          ],
          [
            [0, 2],
            [1, 2],
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [orderOne],
            0,
            null,
            async () => {
              const { executions } = await marketplaceContract
                .connect(buyer)
                .callStatic.fulfillAvailableOrders(
                  [orderOne, orderTwo],
                  offerComponents,
                  considerationComponents,
                  toKey(false),
                  1,
                  {
                    value: value.mul(2),
                  }
                );
              const tx = marketplaceContract
                .connect(buyer)
                .fulfillAvailableOrders(
                  [orderOne, orderTwo],
                  offerComponents,
                  considerationComponents,
                  toKey(false),
                  1,
                  {
                    value: value.mul(2),
                  }
                );
              const receipt = await (await tx).wait();
              await checkExpectedEvents(
                tx,
                receipt,
                [
                  {
                    order: orderOne,
                    orderHash: orderHashOne,
                    fulfiller: buyer.address,
                  },
                ],
                executions
              );

              return receipt;
            },
            1
          );
        });
      });
      it("Can fulfill and aggregate a max number of multiple orders via fulfillAvailableAdvancedOrders", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          1,
          4,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

        const { order: orderTwo } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            [0, 0],
            [1, 0],
          ],
        ];

        const considerationComponents = [
          [
            [0, 0],
            [1, 0],
          ],
          [
            [0, 1],
            [1, 1],
          ],
          [
            [0, 2],
            [1, 2],
          ],
        ];

        await whileImpersonating(buyer.address, provider, async () => {
          await withBalanceChecks(
            [orderOne],
            0,
            null,
            async () => {
              const tx = marketplaceContract
                .connect(buyer)
                .fulfillAvailableAdvancedOrders(
                  [orderOne, orderTwo],
                  [],
                  offerComponents,
                  considerationComponents,
                  toKey(false),
                  constants.AddressZero,
                  1,
                  {
                    value: value.mul(2),
                  }
                );
              const receipt = await (await tx).wait();
              await checkExpectedEvents(
                tx,
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
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          1,
          5,
          100000
        );

        const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
        const { order: orderTwo } = await createOrder(
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
        await expect(
          marketplaceContract.connect(seller).cancel([orderComponents])
        )
          .to.emit(marketplaceContract, "OrderCancelled")
          .withArgs(orderHashThree, seller.address, zone.address);

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
        await withBalanceChecks([orderFour], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(orderFour, toKey(false), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order: orderFour,
              orderHash: orderHashFour,
              fulfiller: buyer.address,
            },
          ]);

          return receipt;
        });

        const offerComponents = [
          [
            [0, 0],
            [1, 0],
            [2, 0],
            [3, 0],
          ],
        ];

        const considerationComponents = [
          [
            [0, 0],
            [1, 0],
            [2, 0],
            [3, 0],
          ],
          [
            [0, 1],
            [1, 1],
            [2, 1],
            [3, 1],
          ],
          [
            [0, 2],
            [1, 2],
            [2, 2],
            [3, 2],
          ],
        ];

        await withBalanceChecks([orderOne], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [orderOne, orderTwo, orderThree, orderFour],
              offerComponents,
              considerationComponents,
              toKey(false),
              100,
              {
                value: value.mul(4),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order: orderOne,
              orderHash: orderHashOne,
              fulfiller: buyer.address,
            },
          ]);

          return receipt;
        });
      });
      it("Can fulfill and aggregate multiple orders via fulfillAvailableAdvancedOrders with failing orders", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          1,
          6,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
        const { order: orderTwo } = await createOrder(
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
        await expect(
          marketplaceContract.connect(seller).cancel([orderComponents])
        )
          .to.emit(marketplaceContract, "OrderCancelled")
          .withArgs(orderHashThree, seller.address, zone.address);

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
        await withBalanceChecks([orderFour], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(orderFour, toKey(false), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order: orderFour,
              orderHash: orderHashFour,
              fulfiller: buyer.address,
            },
          ]);

          return receipt;
        });

        const offerComponents = [
          [
            [0, 0],
            [1, 0],
            [2, 0],
            [3, 0],
          ],
        ];

        const considerationComponents = [
          [
            [0, 0],
            [1, 0],
            [2, 0],
            [3, 0],
          ],
          [
            [0, 1],
            [1, 1],
            [2, 1],
            [3, 1],
          ],
          [
            [0, 2],
            [1, 2],
            [2, 2],
            [3, 2],
          ],
        ];

        await withBalanceChecks([orderOne], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [orderOne, orderTwo, orderThree, orderFour],
              [],
              offerComponents,
              considerationComponents,
              toKey(false),
              constants.AddressZero,
              100,
              {
                value: value.mul(4),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order: orderOne,
              orderHash: orderHashOne,
              fulfiller: buyer.address,
            },
          ]);

          return receipt;
        });
      });
      it("Can fulfill and aggregate multiple orders via fulfillAvailableAdvancedOrders with failing components including criteria", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          1,
          7,
          10000
        );

        // Seller mints second nft

        // Seller mints nfts for criteria-based item
        const criteriaNftId = randomBN();
        const secondCriteriaNFTId = randomBN();
        const thirdCriteriaNFTId = randomBN();

        await testERC721.mint(seller.address, criteriaNftId);
        await testERC721.mint(seller.address, secondCriteriaNFTId);
        await testERC721.mint(seller.address, thirdCriteriaNFTId);

        const tokenIds = [
          criteriaNftId,
          secondCriteriaNFTId,
          thirdCriteriaNFTId,
        ];

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [getTestItem1155(nftId, amount, amount, undefined)];

        const offerTwo = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const criteriaResolvers = [
          buildResolver(
            1,
            0,
            0,
            criteriaNftId,
            proofs[criteriaNftId.toString()]
          ),
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
        const { order: orderTwo } = await createOrder(
          seller,
          zone,
          offerTwo,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers,
          "EXPIRED"
        );

        const offerComponents = [[[0, 0]], [[1, 0]]];

        const considerationComponents = [
          [
            [0, 0],
            [1, 0],
          ],
          [
            [0, 1],
            [1, 1],
          ],
          [
            [0, 2],
            [1, 2],
          ],
        ];

        await withBalanceChecks([orderOne], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [orderOne, orderTwo],
              criteriaResolvers,
              offerComponents,
              considerationComponents,
              toKey(false),
              constants.AddressZero,
              100,
              {
                value: value.mul(2),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
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

  describe("Conduit tests", async () => {
    let seller;
    let buyer;
    let sellerContract;
    let buyerContract;
    let tempConduit;

    beforeEach(async () => {
      // Setup basic buyer/seller wallets with ETH
      seller = new ethers.Wallet(randomHex(32), provider);
      buyer = new ethers.Wallet(randomHex(32), provider);
      zone = new ethers.Wallet(randomHex(32), provider);

      sellerContract = await EIP1271WalletFactory.deploy(seller.address);
      buyerContract = await EIP1271WalletFactory.deploy(buyer.address);

      // Deploy a new conduit
      tempConduit = await deployNewConduit(owner);

      await Promise.all(
        [seller, buyer, zone, sellerContract, buyerContract].map((wallet) =>
          faucet(wallet.address, provider)
        )
      );
    });

    it("Adds a channel, and executes transfers (ERC1155 with batch)", async () => {
      // Owner updates conduit channel to allow seller access
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, seller.address, true);
      });

      const { nftId, amount } = await mint1155(owner, 2);

      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        owner,
        2
      );

      await testERC1155.mint(seller.address, nftId, amount.mul(2));
      await testERC1155.mint(seller.address, secondNftId, secondAmount.mul(2));
      await set1155ApprovalForAll(seller, tempConduit.address, true);

      await tempConduit.connect(seller).executeWithBatch1155(
        [],
        [
          {
            token: testERC1155.address,
            from: seller.address,
            to: buyer.address,
            ids: [nftId, secondNftId],
            amounts: [amount, secondAmount],
          },
          {
            token: testERC1155.address,
            from: seller.address,
            to: buyer.address,
            ids: [secondNftId, nftId],
            amounts: [secondAmount, amount],
          },
        ]
      );
    });

    it("Adds a channel, and executes only batch transfers (ERC1155 with batch)", async () => {
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, seller.address, true);
      });

      const { nftId, amount } = await mint1155(owner, 2);

      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        owner,
        2
      );

      await testERC1155.mint(seller.address, nftId, amount.mul(2));
      await testERC1155.mint(seller.address, secondNftId, secondAmount.mul(2));
      await set1155ApprovalForAll(seller, tempConduit.address, true);

      await tempConduit.connect(seller).executeBatch1155([
        {
          token: testERC1155.address,
          from: seller.address,
          to: buyer.address,
          ids: [nftId, secondNftId],
          amounts: [amount, secondAmount],
        },
        {
          token: testERC1155.address,
          from: seller.address,
          to: buyer.address,
          ids: [secondNftId, nftId],
          amounts: [secondAmount, amount],
        },
      ]);
    });

    it("Adds a channel, and executes transfers (ERC721)", async () => {
      // Owner updates conduit channel to allow seller access
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, seller.address, true);
      });

      // Seller mints nft
      const nftId = randomBN();
      await testERC721.mint(seller.address, nftId);

      const secondNftId = randomBN();
      await testERC721.mint(seller.address, secondNftId);

      // Check ownership
      expect(await testERC721.ownerOf(nftId)).to.equal(seller.address);
      expect(await testERC721.ownerOf(secondNftId)).to.equal(seller.address);

      await whileImpersonating(seller.address, provider, async () => {
        await expect(
          testERC721
            .connect(seller)
            .setApprovalForAll(tempConduit.address, true)
        )
          .to.emit(testERC721, "ApprovalForAll")
          .withArgs(seller.address, tempConduit.address, true);
      });

      await tempConduit.connect(seller).execute([
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          from: seller.address,
          to: buyer.address,
          identifier: nftId,
          amount: ethers.BigNumber.from(1),
        },
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          from: seller.address,
          to: buyer.address,
          identifier: secondNftId,
          amount: ethers.BigNumber.from(1),
        },
      ]);

      // Check ownership
      expect(await testERC721.ownerOf(nftId)).to.equal(buyer.address);
      expect(await testERC721.ownerOf(secondNftId)).to.equal(buyer.address);
    });

    it("Adds a channel, and executes transfers (ERC721 + ERC20)", async () => {
      // Owner updates conduit channel to allow seller access
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, seller.address, true);
      });

      // Seller mints nft
      const nftId = randomBN();
      await testERC721.mint(seller.address, nftId);

      // Check ownership
      expect(await testERC721.ownerOf(nftId)).to.equal(seller.address);

      // Set approval of nft
      await whileImpersonating(seller.address, provider, async () => {
        await expect(
          testERC721
            .connect(seller)
            .setApprovalForAll(tempConduit.address, true)
        )
          .to.emit(testERC721, "ApprovalForAll")
          .withArgs(seller.address, tempConduit.address, true);
      });

      const tokenAmount = minRandom(100);
      await testERC20.mint(seller.address, tokenAmount);

      // Check balance
      expect(await testERC20.balanceOf(seller.address)).to.equal(tokenAmount);

      // Seller approves conduit contract to transfer tokens
      await whileImpersonating(seller.address, provider, async () => {
        await expect(
          testERC20.connect(seller).approve(tempConduit.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(seller.address, tempConduit.address, tokenAmount);
      });

      // Send an ERC721 and (token amount - 100) ERC20 tokens
      await tempConduit.connect(seller).execute([
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          from: seller.address,
          to: buyer.address,
          identifier: nftId,
          amount: ethers.BigNumber.from(1),
        },
        {
          itemType: 1, // ERC20
          token: testERC20.address,
          from: seller.address,
          to: buyer.address,
          identifier: 0,
          amount: tokenAmount.sub(100),
        },
      ]);

      // Check ownership
      expect(await testERC721.ownerOf(nftId)).to.equal(buyer.address);
      // Check balance
      expect(await testERC20.balanceOf(seller.address)).to.equal(100);
      expect(await testERC20.balanceOf(buyer.address)).to.equal(
        tokenAmount.sub(100)
      );
    });

    it("Adds a channel, and executes transfers (ERC721 + ERC1155)", async () => {
      // Owner updates conduit channel to allow seller access
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, seller.address, true);
      });

      // Seller mints nft
      const nftId = randomBN();
      await testERC721.mint(seller.address, nftId);

      // Check ownership
      expect(await testERC721.ownerOf(nftId)).to.equal(seller.address);

      // Set approval of nft
      await whileImpersonating(seller.address, provider, async () => {
        await expect(
          testERC721
            .connect(seller)
            .setApprovalForAll(tempConduit.address, true)
        )
          .to.emit(testERC721, "ApprovalForAll")
          .withArgs(seller.address, tempConduit.address, true);
      });

      const secondNftId = random128();
      const amount = random128().add(1);
      await testERC1155.mint(seller.address, secondNftId, amount);

      await whileImpersonating(seller.address, provider, async () => {
        await expect(
          testERC1155
            .connect(seller)
            .setApprovalForAll(tempConduit.address, true)
        )
          .to.emit(testERC1155, "ApprovalForAll")
          .withArgs(seller.address, tempConduit.address, true);
      });

      // Check ownership
      expect(await testERC1155.balanceOf(seller.address, secondNftId)).to.equal(
        amount
      );

      // Send an ERC721 and ERC1155
      await tempConduit.connect(seller).execute([
        {
          itemType: 2, // ERC721
          token: testERC721.address,
          from: seller.address,
          to: buyer.address,
          identifier: nftId,
          amount: ethers.BigNumber.from(1),
        },
        {
          itemType: 3, // ERC1155
          token: testERC1155.address,
          from: seller.address,
          to: buyer.address,
          identifier: secondNftId,
          amount: amount.sub(10),
        },
      ]);

      // Check ownership
      expect(await testERC721.ownerOf(nftId)).to.equal(buyer.address);
      // Check balance
      expect(await testERC1155.balanceOf(seller.address, secondNftId)).to.equal(
        10
      );
      expect(await testERC1155.balanceOf(buyer.address, secondNftId)).to.equal(
        amount.sub(10)
      );
    });

    it("Adds a channel, and executes transfers (ERC20 + ERC1155)", async () => {
      // Owner updates conduit channel to allow seller access
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, seller.address, true);
      });

      // Seller mints nft
      const tokenAmount = minRandom(100).div(100);
      await testERC20.mint(seller.address, tokenAmount);

      // Check balance
      expect(await testERC20.balanceOf(seller.address)).to.equal(tokenAmount);

      // Seller approves conduit contract to transfer tokens
      await whileImpersonating(seller.address, provider, async () => {
        await expect(
          testERC20.connect(seller).approve(tempConduit.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(seller.address, tempConduit.address, tokenAmount);
      });

      const nftId = random128();
      const erc1155amount = random128().add(1);
      await testERC1155.mint(seller.address, nftId, erc1155amount);

      await whileImpersonating(seller.address, provider, async () => {
        await expect(
          testERC1155
            .connect(seller)
            .setApprovalForAll(tempConduit.address, true)
        )
          .to.emit(testERC1155, "ApprovalForAll")
          .withArgs(seller.address, tempConduit.address, true);
      });

      // Check ownership
      expect(await testERC1155.balanceOf(seller.address, nftId)).to.equal(
        erc1155amount
      );

      // Send an ERC20 and ERC1155
      await tempConduit.connect(seller).execute([
        {
          itemType: 1, // ERC20
          token: testERC20.address,
          from: seller.address,
          to: buyer.address,
          identifier: 0,
          amount: tokenAmount.sub(100),
        },
        {
          itemType: 3, // ERC1155
          token: testERC1155.address,
          from: seller.address,
          to: buyer.address,
          identifier: nftId,
          amount: erc1155amount.sub(10),
        },
      ]);

      // Check balance
      expect(await testERC20.balanceOf(seller.address)).to.equal(100);
      expect(await testERC20.balanceOf(buyer.address)).to.equal(
        tokenAmount.sub(100)
      );
      expect(await testERC1155.balanceOf(seller.address, nftId)).to.equal(10);
      expect(await testERC1155.balanceOf(buyer.address, nftId)).to.equal(
        erc1155amount.sub(10)
      );
    });

    it("Adds a channel, and executes transfers (ERC20 + ERC721 + ERC1155)", async () => {
      // Owner updates conduit channel to allow seller access
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, seller.address, true);
      });

      // Create/Approve X amount of  ERC20s
      const erc20Transfer = await createTransferWithApproval(
        testERC20,
        seller,
        1,
        tempConduit.address,
        seller.address,
        buyer.address
      );

      // Create/Approve Y amount of  ERC721s
      const erc721Transfer = await createTransferWithApproval(
        testERC721,
        seller,
        2,
        tempConduit.address,
        seller.address,
        buyer.address
      );

      // Create/Approve Z amount of ERC1155s
      const erc1155Transfer = await createTransferWithApproval(
        testERC1155,
        seller,
        3,
        tempConduit.address,
        seller.address,
        buyer.address
      );

      // Send an ERC20, ERC721, and ERC1155
      await tempConduit
        .connect(seller)
        .execute([erc20Transfer, erc721Transfer, erc1155Transfer]);

      // Check ownership
      expect(await testERC721.ownerOf(erc721Transfer.identifier)).to.equal(
        buyer.address
      );
      // Check balance
      expect(await testERC20.balanceOf(seller.address)).to.equal(0);
      expect(await testERC20.balanceOf(buyer.address)).to.equal(
        erc20Transfer.amount
      );
      expect(
        await testERC1155.balanceOf(seller.address, erc1155Transfer.identifier)
      ).to.equal(0);
      expect(
        await testERC1155.balanceOf(buyer.address, erc1155Transfer.identifier)
      ).to.equal(erc1155Transfer.amount);
    });

    it("Adds a channel, and executes transfers (many token types)", async () => {
      // Owner updates conduit channel to allow seller access
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, seller.address, true);
      });

      // Get 3 Numbers that's value adds to Item Amount and minimum 1.
      const itemsToCreate = 64;
      const numERC20s = Math.max(1, randomInt(itemsToCreate - 2));
      const numEC721s = Math.max(1, randomInt(itemsToCreate - numERC20s - 1));
      const numERC1155s = Math.max(1, itemsToCreate - numERC20s - numEC721s);

      const erc20Contracts = [numERC20s];
      const erc20Transfers = [numERC20s];

      const erc721Contracts = [numEC721s];
      const erc721Transfers = [numEC721s];

      const erc1155Contracts = [numERC1155s];
      const erc1155Transfers = [numERC1155s];

      // Create numERC20s amount of ERC20 objects
      for (let i = 0; i < numERC20s; i++) {
        // Deploy Contract
        const { testERC20: tempERC20Contract } = await fixtureERC20(owner);
        // Create/Approve X amount of  ERC20s
        const erc20Transfer = await createTransferWithApproval(
          tempERC20Contract,
          seller,
          1,
          tempConduit.address,
          seller.address,
          buyer.address
        );
        erc20Contracts[i] = tempERC20Contract;
        erc20Transfers[i] = erc20Transfer;
      }

      // Create numEC721s amount of ERC20 objects
      for (let i = 0; i < numEC721s; i++) {
        // Deploy Contract
        const { testERC721: tempERC721Contract } = await fixtureERC721(owner);
        // Create/Approve numEC721s amount of  ERC721s
        const erc721Transfer = await createTransferWithApproval(
          tempERC721Contract,
          seller,
          2,
          tempConduit.address,
          seller.address,
          buyer.address
        );
        erc721Contracts[i] = tempERC721Contract;
        erc721Transfers[i] = erc721Transfer;
      }

      // Create numERC1155s amount of ERC1155 objects
      for (let i = 0; i < numERC1155s; i++) {
        // Deploy Contract
        const { testERC1155: tempERC1155Contract } = await fixtureERC1155(
          owner
        );
        // Create/Approve numERC1155s amount of ERC1155s
        const erc1155Transfer = await createTransferWithApproval(
          tempERC1155Contract,
          seller,
          3,
          tempConduit.address,
          seller.address,
          buyer.address
        );
        erc1155Contracts[i] = tempERC1155Contract;
        erc1155Transfers[i] = erc1155Transfer;
      }

      const transfers = erc20Transfers.concat(
        erc721Transfers,
        erc1155Transfers
      );
      const contracts = erc20Contracts.concat(
        erc721Contracts,
        erc1155Contracts
      );
      // Send the transfers
      await tempConduit.connect(seller).execute(transfers);

      // Loop through all transfer to do ownership/balance checks
      for (let i = 0; i < transfers.length; i++) {
        // Get Itemtype, token, from, to, amount, identifier
        itemType = transfers[i].itemType;
        token = contracts[i];
        from = transfers[i].from;
        to = transfers[i].to;
        amount = transfers[i].amount;
        identifier = transfers[i].identifier;

        switch (itemType) {
          case 1: // ERC20
            // Check balance
            expect(await token.balanceOf(from)).to.equal(0);
            expect(await token.balanceOf(to)).to.equal(amount);
            break;
          case 2: // ERC721
          case 4: // ERC721_WITH_CRITERIA
            expect(await token.ownerOf(identifier)).to.equal(to);
            break;
          case 3: // ERC1155
          case 5: // ERC1155_WITH_CRITERIA
            // Check balance
            expect(await token.balanceOf(from, identifier)).to.equal(0);
            expect(await token.balanceOf(to, identifier)).to.equal(amount);
            break;
        }
      }
    });

    it("Reverts on calls to batch transfer 1155 items with no contract on a conduit", async () => {
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, owner.address, true);
      });

      const { nftId, amount } = await mint1155(owner, 2);

      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        owner,
        2
      );

      await set1155ApprovalForAll(owner, tempConduit.address, true);

      await expect(
        tempConduit.connect(owner).executeWithBatch1155(
          [],
          [
            {
              token: constants.AddressZero,
              from: owner.address,
              to: buyer.address,
              ids: [nftId, secondNftId],
              amounts: [amount, secondAmount],
            },
          ]
        )
      ).to.be.revertedWith("NoContract");
    });

    it("Reverts on calls to only batch transfer 1155 items with no contract on a conduit", async () => {
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, owner.address, true);
      });

      const { nftId, amount } = await mint1155(owner, 2);

      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        owner,
        2
      );

      await set1155ApprovalForAll(owner, tempConduit.address, true);

      await expect(
        tempConduit.connect(owner).executeBatch1155([
          {
            token: constants.AddressZero,
            from: owner.address,
            to: buyer.address,
            ids: [nftId, secondNftId],
            amounts: [amount, secondAmount],
          },
        ])
      ).to.be.revertedWith("NoContract");
    });

    it("ERC1155 batch transfer reverts with revert data if it has sufficient gas", async () => {
      // Owner updates conduit channel to allow seller access
      await whileImpersonating(owner.address, provider, async () => {
        await conduitController
          .connect(owner)
          .updateChannel(tempConduit.address, seller.address, true);
      });

      await expect(
        tempConduit.connect(seller).executeWithBatch1155(
          [],
          [
            {
              token: testERC1155.address,
              from: seller.address,
              to: buyer.address,
              ids: [1],
              amounts: [1],
            },
          ]
        )
      ).to.be.revertedWith("NOT_AUTHORIZED");
    });
    if (!process.env.REFERENCE) {
      it("ERC1155 batch transfer sends no data", async () => {
        const receiver = await deployContract("ERC1155BatchRecipient", owner);
        // Owner updates conduit channel to allow seller access
        await whileImpersonating(owner.address, provider, async () => {
          await conduitController
            .connect(owner)
            .updateChannel(tempConduit.address, seller.address, true);
        });

        const { nftId, amount } = await mint1155(owner, 2);

        const { nftId: secondNftId, amount: secondAmount } = await mint1155(
          owner,
          2
        );
        const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(
          owner,
          2
        );

        await testERC1155.mint(seller.address, nftId, amount.mul(2));
        await testERC1155.mint(
          seller.address,
          secondNftId,
          secondAmount.mul(2)
        );
        await testERC1155.mint(seller.address, thirdNftId, thirdAmount.mul(2));
        await set1155ApprovalForAll(seller, tempConduit.address, true);

        await tempConduit.connect(seller).executeWithBatch1155(
          [],
          [
            {
              token: testERC1155.address,
              from: seller.address,
              to: receiver.address,
              ids: [nftId, secondNftId, thirdNftId],
              amounts: [amount, secondAmount, thirdAmount],
            },
            {
              token: testERC1155.address,
              from: seller.address,
              to: receiver.address,
              ids: [secondNftId, nftId],
              amounts: [secondAmount, amount],
            },
          ]
        );
      });

      it("ERC1155 batch transfer reverts with generic error if it has insufficient gas to copy revert data", async () => {
        const receiver = await deployContract(
          "ExcessReturnDataRecipient",
          owner
        );
        // Owner updates conduit channel to allow seller access
        await whileImpersonating(owner.address, provider, async () => {
          await conduitController
            .connect(owner)
            .updateChannel(tempConduit.address, seller.address, true);
        });

        await expect(
          tempConduit.connect(seller).executeWithBatch1155(
            [],
            [
              {
                token: receiver.address,
                from: seller.address,
                to: receiver.address,
                ids: [1],
                amounts: [1],
              },
            ]
          )
        ).to.be.revertedWith(
          `ERC1155BatchTransferGenericFailure("${receiver.address}", "${seller.address}", "${receiver.address}", [1], [1])`
        );
      });
    }

    it("Makes batch transfer 1155 items through a conduit", async () => {
      const tempConduitKey = owner.address + "ff00000000000000000000f1";

      const { conduit: tempConduitAddress } =
        await conduitController.getConduit(tempConduitKey);

      await conduitController
        .connect(owner)
        .createConduit(tempConduitKey, owner.address);

      const tempConduit = conduitImplementation.attach(tempConduitAddress);

      await conduitController
        .connect(owner)
        .updateChannel(tempConduit.address, owner.address, true);

      const { nftId, amount } = await mint1155(owner, 2);

      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        owner,
        2
      );

      const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(
        owner,
        2
      );

      const { nftId: nftId4, amount: amount4 } = await mint1155(owner, 2);

      const { nftId: nftId5, amount: amount5 } = await mint1155(owner, 2);

      const { nftId: nftId6, amount: amount6 } = await mint1155(owner, 2);

      const { nftId: nftId7, amount: amount7 } = await mint1155(owner, 2);

      const { nftId: nftId8, amount: amount8 } = await mint1155(owner, 2);

      const { nftId: nftId9, amount: amount9 } = await mint1155(owner, 2);

      const { nftId: nftId10, amount: amount10 } = await mint1155(owner, 2);

      await set1155ApprovalForAll(owner, tempConduit.address, true);

      await tempConduit.connect(owner).executeWithBatch1155(
        [],
        [
          {
            token: testERC1155.address,
            from: owner.address,
            to: buyer.address,
            ids: [
              nftId,
              secondNftId,
              thirdNftId,
              nftId4,
              nftId5,
              nftId6,
              nftId7,
              nftId8,
              nftId9,
              nftId10,
            ],
            amounts: [
              amount,
              secondAmount,
              thirdAmount,
              amount4,
              amount5,
              amount6,
              amount7,
              amount8,
              amount9,
              amount10,
            ],
          },
        ]
      );
    });

    it("Performs complex batch transfer through a conduit", async () => {
      const tempConduitKey = owner.address + "f100000000000000000000f1";

      const { conduit: tempConduitAddress } =
        await conduitController.getConduit(tempConduitKey);

      await conduitController
        .connect(owner)
        .createConduit(tempConduitKey, owner.address);

      const tempConduit = conduitImplementation.attach(tempConduitAddress);

      await conduitController
        .connect(owner)
        .updateChannel(tempConduit.address, owner.address, true);

      const { nftId, amount } = await mint1155(owner, 2);

      const { nftId: secondNftId, amount: secondAmount } = await mint1155(
        owner,
        2
      );

      const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(
        owner,
        2
      );

      const { nftId: nftId4, amount: amount4 } = await mint1155(owner, 2);

      const { nftId: nftId5, amount: amount5 } = await mint1155(
        owner,
        2,
        testERC1155Two
      );

      const { nftId: nftId6, amount: amount6 } = await mint1155(
        owner,
        2,
        testERC1155Two
      );

      const { nftId: nftId7, amount: amount7 } = await mint1155(
        owner,
        2,
        testERC1155Two
      );

      const { nftId: nftId8, amount: amount8 } = await mint1155(
        owner,
        2,
        testERC1155Two
      );

      const amount9 = toBN(randomBN(4)).add(1);
      await mintAndApproveERC20(owner, tempConduit.address, amount9.mul(2));

      const nftId10 = await mint721(owner);

      await set1155ApprovalForAll(owner, tempConduit.address, true);

      await expect(
        testERC1155Two
          .connect(owner)
          .setApprovalForAll(tempConduit.address, true)
      )
        .to.emit(testERC1155Two, "ApprovalForAll")
        .withArgs(owner.address, tempConduit.address, true);

      await set721ApprovalForAll(owner, tempConduit.address, true);

      const newAddress = toAddress(12345);

      await tempConduit.connect(owner).executeWithBatch1155(
        [
          {
            itemType: 1,
            token: testERC20.address,
            from: owner.address,
            to: newAddress,
            identifier: toBN(0),
            amount: amount9,
          },
          {
            itemType: 2,
            token: testERC721.address,
            from: owner.address,
            to: newAddress,
            identifier: nftId10,
            amount: toBN(1),
          },
        ],
        [
          {
            token: testERC1155.address,
            from: owner.address,
            to: newAddress,
            ids: [nftId, secondNftId, thirdNftId, nftId4],
            amounts: [amount, secondAmount, thirdAmount, amount4],
          },
          {
            token: testERC1155Two.address,
            from: owner.address,
            to: newAddress,
            ids: [nftId5, nftId6, nftId7, nftId8],
            amounts: [amount5, amount6, amount7, amount8],
          },
        ]
      );

      expect(await testERC1155.balanceOf(newAddress, nftId)).to.equal(amount);
      expect(await testERC1155.balanceOf(newAddress, secondNftId)).to.equal(
        secondAmount
      );
      expect(await testERC1155.balanceOf(newAddress, thirdNftId)).to.equal(
        thirdAmount
      );
      expect(await testERC1155.balanceOf(newAddress, nftId4)).to.equal(amount4);

      expect(await testERC1155Two.balanceOf(newAddress, nftId5)).to.equal(
        amount5
      );
      expect(await testERC1155Two.balanceOf(newAddress, nftId6)).to.equal(
        amount6
      );
      expect(await testERC1155Two.balanceOf(newAddress, nftId7)).to.equal(
        amount7
      );
      expect(await testERC1155Two.balanceOf(newAddress, nftId8)).to.equal(
        amount8
      );

      expect(await testERC20.balanceOf(newAddress)).to.equal(amount9);
      expect(await testERC721.ownerOf(nftId10)).to.equal(newAddress);
    });

    it("ERC1155 <=> ETH (match, two different groups of 1155's)", async () => {
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const secondNftId = toBN(randomBN(4));
      const secondAmount = toBN(randomBN(4));
      await testERC1155Two.mint(seller.address, secondNftId, secondAmount);

      // Seller mints third nft
      const { nftId: thirdNftId, amount: thirdAmount } = await mint1155(seller);

      // Seller mints fourth nft
      const fourthNftId = toBN(randomBN(4));
      const fourthAmount = toBN(randomBN(4));
      await testERC1155Two.mint(seller.address, fourthNftId, fourthAmount);

      // Seller approves marketplace contract to transfer NFTs
      await set1155ApprovalForAll(seller, marketplaceContract.address, true);

      await expect(
        testERC1155Two
          .connect(seller)
          .setApprovalForAll(marketplaceContract.address, true)
      )
        .to.emit(testERC1155Two, "ApprovalForAll")
        .withArgs(seller.address, marketplaceContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount, amount),
        getTestItem1155(
          secondNftId,
          secondAmount,
          secondAmount,
          testERC1155Two.address
        ),
        getTestItem1155(thirdNftId, thirdAmount, thirdAmount),
        getTestItem1155(
          fourthNftId,
          fourthAmount,
          fourthAmount,
          testERC1155Two.address
        ),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      const { mirrorOrder } = await createMirrorBuyNowOrder(buyer, zone, order);

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [[[0, 1]], [[1, 1]]],
        [[[0, 2]], [[1, 2]]],
        [[[0, 3]], [[1, 3]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(7);

      await marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
    });

    it("Reverts when attempting to update a conduit channel when call is not from controller", async () => {
      await expect(
        conduitOne.connect(owner).updateChannel(constants.AddressZero, true)
      ).to.be.revertedWith("InvalidController");
    });

    it("Reverts when attempting to execute transfers on a conduit when not called from a channel", async () => {
      await expect(conduitOne.connect(owner).execute([])).to.be.revertedWith(
        "ChannelClosed"
      );
    });

    it("Reverts when attempting to execute with 1155 transfers on a conduit when not called from a channel", async () => {
      await expect(
        conduitOne.connect(owner).executeWithBatch1155([], [])
      ).to.be.revertedWith("ChannelClosed");
    });

    it("Reverts when attempting to execute batch 1155 transfers on a conduit when not called from a channel", async () => {
      await expect(
        conduitOne.connect(owner).executeBatch1155([])
      ).to.be.revertedWith("ChannelClosed");
    });

    it("Retrieves the owner of a conduit", async () => {
      const ownerOf = await conduitController.ownerOf(conduitOne.address);
      expect(ownerOf).to.equal(owner.address);

      await expect(
        conduitController.connect(owner).ownerOf(buyer.address)
      ).to.be.revertedWith("NoConduit");
    });

    it("Retrieves the key of a conduit", async () => {
      const key = await conduitController.getKey(conduitOne.address);
      expect(key.toLowerCase()).to.equal(conduitKeyOne.toLowerCase());

      await expect(
        conduitController.connect(owner).getKey(buyer.address)
      ).to.be.revertedWith("NoConduit");
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

      await expect(
        conduitController
          .connect(owner)
          .getChannelStatus(buyer.address, seller.address)
      ).to.be.revertedWith("NoConduit");
    });

    it("Retrieves conduit channels from the controller", async () => {
      const totalChannels = await conduitController.getTotalChannels(
        conduitOne.address
      );
      expect(totalChannels).to.equal(1);

      await expect(
        conduitController.connect(owner).getTotalChannels(buyer.address)
      ).to.be.revertedWith("NoConduit");

      const firstChannel = await conduitController.getChannel(
        conduitOne.address,
        0
      );
      expect(firstChannel).to.equal(marketplaceContract.address);

      await expect(
        conduitController
          .connect(owner)
          .getChannel(buyer.address, totalChannels - 1)
      ).to.be.revertedWith("NoConduit");

      await expect(
        conduitController.connect(owner).getChannel(conduitOne.address, 1)
      ).to.be.revertedWith("ChannelOutOfRange", conduitOne.address);

      await expect(
        conduitController.connect(owner).getChannel(conduitOne.address, 2)
      ).to.be.revertedWith("ChannelOutOfRange", conduitOne.address);

      const channels = await conduitController.getChannels(conduitOne.address);
      expect(channels.length).to.equal(1);
      expect(channels[0]).to.equal(marketplaceContract.address);

      await expect(
        conduitController.connect(owner).getChannels(buyer.address)
      ).to.be.revertedWith("NoConduit");
    });

    it("Adds and removes channels", async () => {
      // Get number of open channels
      let totalChannels = await conduitController.getTotalChannels(
        conduitOne.address
      );
      expect(totalChannels).to.equal(1);

      let isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        marketplaceContract.address
      );
      expect(isOpen).to.be.true;

      // No-op
      await expect(
        conduitController
          .connect(owner)
          .updateChannel(conduitOne.address, marketplaceContract.address, true)
      ).to.be.reverted; // ChannelStatusAlreadySet

      isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        marketplaceContract.address
      );
      expect(isOpen).to.be.true;

      // Get number of open channels
      totalChannels = await conduitController.getTotalChannels(
        conduitOne.address
      );
      expect(totalChannels).to.equal(1);

      await conduitController
        .connect(owner)
        .updateChannel(conduitOne.address, seller.address, true);

      isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        seller.address
      );
      expect(isOpen).to.be.true;

      // Get number of open channels
      totalChannels = await conduitController.getTotalChannels(
        conduitOne.address
      );
      expect(totalChannels).to.equal(2);

      await conduitController
        .connect(owner)
        .updateChannel(conduitOne.address, marketplaceContract.address, false);

      isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        marketplaceContract.address
      );
      expect(isOpen).to.be.false;

      // Get number of open channels
      totalChannels = await conduitController.getTotalChannels(
        conduitOne.address
      );
      expect(totalChannels).to.equal(1);

      await conduitController
        .connect(owner)
        .updateChannel(conduitOne.address, seller.address, false);

      isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        seller.address
      );
      expect(isOpen).to.be.false;

      // Get number of open channels
      totalChannels = await conduitController.getTotalChannels(
        conduitOne.address
      );
      expect(totalChannels).to.equal(0);

      await conduitController
        .connect(owner)
        .updateChannel(conduitOne.address, marketplaceContract.address, true);

      isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        marketplaceContract.address
      );
      expect(isOpen).to.be.true;

      // Get number of open channels
      totalChannels = await conduitController.getTotalChannels(
        conduitOne.address
      );
      expect(totalChannels).to.equal(1);
    });

    it("Reverts on an attempt to move an unsupported item", async () => {
      await conduitController
        .connect(owner)
        .updateChannel(conduitOne.address, seller.address, true);

      const isOpen = await conduitController.getChannelStatus(
        conduitOne.address,
        seller.address
      );
      expect(isOpen).to.be.true;

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
              token: constants.AddressZero,
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

    it("Reverts when attempting to create a conduit not scoped to the creator", async () => {
      await expect(
        conduitController
          .connect(owner)
          .createConduit(constants.HashZero, owner.address)
      ).to.be.revertedWith("InvalidCreator");
    });

    it("Reverts when attempting to create a conduit that already exists", async () => {
      await expect(
        conduitController
          .connect(owner)
          .createConduit(conduitKeyOne, owner.address)
      ).to.be.revertedWith(`ConduitAlreadyExists("${conduitOne.address}")`);
    });

    it("Reverts when attempting to update a channel for an unowned conduit", async () => {
      await expect(
        conduitController
          .connect(buyer)
          .updateChannel(conduitOne.address, buyer.address, true)
      ).to.be.revertedWith(`CallerIsNotOwner("${conduitOne.address}")`);
    });

    it("Retrieves no initial potential owner for new conduit", async () => {
      const potentialOwner = await conduitController.getPotentialOwner(
        conduitOne.address
      );
      expect(potentialOwner).to.equal(constants.AddressZero);

      await expect(
        conduitController.connect(owner).getPotentialOwner(buyer.address)
      ).to.be.revertedWith("NoConduit");
    });

    it("Lets the owner transfer ownership via a two-stage process", async () => {
      await expect(
        conduitController
          .connect(buyer)
          .transferOwnership(conduitOne.address, buyer.address)
      ).to.be.revertedWith("CallerIsNotOwner", conduitOne.address);

      await expect(
        conduitController
          .connect(owner)
          .transferOwnership(conduitOne.address, constants.AddressZero)
      ).to.be.revertedWith(
        "NewPotentialOwnerIsZeroAddress",
        conduitOne.address
      );

      await expect(
        conduitController
          .connect(owner)
          .transferOwnership(seller.address, buyer.address)
      ).to.be.revertedWith("NoConduit");

      let potentialOwner = await conduitController.getPotentialOwner(
        conduitOne.address
      );
      expect(potentialOwner).to.equal(constants.AddressZero);

      await conduitController.transferOwnership(
        conduitOne.address,
        buyer.address
      );

      potentialOwner = await conduitController.getPotentialOwner(
        conduitOne.address
      );
      expect(potentialOwner).to.equal(buyer.address);

      await expect(
        conduitController
          .connect(owner)
          .transferOwnership(conduitOne.address, buyer.address)
      ).to.be.revertedWith(
        "NewPotentialOwnerAlreadySet",
        conduitOne.address,
        buyer.address
      );

      await expect(
        conduitController
          .connect(buyer)
          .cancelOwnershipTransfer(conduitOne.address)
      ).to.be.revertedWith("CallerIsNotOwner", conduitOne.address);

      await expect(
        conduitController.connect(owner).cancelOwnershipTransfer(seller.address)
      ).to.be.revertedWith("NoConduit");

      await conduitController.cancelOwnershipTransfer(conduitOne.address);

      potentialOwner = await conduitController.getPotentialOwner(
        conduitOne.address
      );
      expect(potentialOwner).to.equal(constants.AddressZero);

      await expect(
        conduitController
          .connect(owner)
          .cancelOwnershipTransfer(conduitOne.address)
      ).to.be.revertedWith("NoPotentialOwnerCurrentlySet", conduitOne.address);

      await conduitController.transferOwnership(
        conduitOne.address,
        buyer.address
      );

      potentialOwner = await conduitController.getPotentialOwner(
        conduitOne.address
      );
      expect(potentialOwner).to.equal(buyer.address);

      await expect(
        conduitController.connect(buyer).acceptOwnership(seller.address)
      ).to.be.revertedWith("NoConduit");

      await expect(
        conduitController.connect(seller).acceptOwnership(conduitOne.address)
      ).to.be.revertedWith("CallerIsNotNewPotentialOwner", conduitOne.address);

      await conduitController
        .connect(buyer)
        .acceptOwnership(conduitOne.address);

      potentialOwner = await conduitController.getPotentialOwner(
        conduitOne.address
      );
      expect(potentialOwner).to.equal(constants.AddressZero);

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
      seller = new ethers.Wallet(randomHex(32), provider);
      buyer = new ethers.Wallet(randomHex(32), provider);
      zone = new ethers.Wallet(randomHex(32), provider);

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
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
          getItemETH(amount.mul(10), amount.mul(10), zone.address),
          getItemETH(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 0;
        order.denominator = 10;

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("BadFraction");

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 1;
        order.denominator = 0;

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("BadFraction");

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 2;
        order.denominator = 1;

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("BadFraction");

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 1;
        order.denominator = 2;

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 2)
        );
      });
      it("Reverts on inexact fraction amounts", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
          getItemETH(amount.mul(10), amount.mul(10), zone.address),
          getItemETH(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 1;
        order.denominator = 8191;

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("InexactFraction");

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 1;
        order.denominator = 2;

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 2)
        );
      });
      it("Reverts on partial fill attempt when not supported by order", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
          getItemETH(amount.mul(10), amount.mul(10), zone.address),
          getItemETH(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 1;
        order.denominator = 2;

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("PartialFillsNotEnabledForOrder");

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 1;
        order.denominator = 1;

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );
      });
      it("Reverts on partially filled order via basic fulfillment", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
          getItemETH(amount.mul(10), amount.mul(10), zone.address),
          getItemETH(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 1;
        order.denominator = 2;

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 2)
        );

        const basicOrderParameters = getBasicOrderParameters(
          1, // EthForERC1155
          order
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            })
        ).to.be.revertedWith(`OrderPartiallyFilled("${orderHash}")`);
      });
      it("Reverts on fully filled order", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
          getItemETH(amount.mul(10), amount.mul(10), zone.address),
          getItemETH(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1 // PARTIAL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        order.numerator = 1;
        order.denominator = 1;

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith(`OrderAlreadyFilled("${orderHash}")`);
      });
      it("Reverts on inadequate consideration items", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
          getItemETH(amount.mul(10), amount.mul(10), zone.address),
          getItemETH(amount.mul(20), amount.mul(20), owner.address),
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

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("MissingOriginalConsiderationItems");
      });
      it("Reverts on invalid submitter when required by order", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          2 // FULL_RESTRICTED
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = defaultBuyNowMirrorFulfillment;

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          zone,
          value
        );

        expect(executions.length).to.equal(4);

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, {
                value,
              })
          ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
        } else {
          await expect(
            marketplaceContract
              .connect(owner)
              .matchOrders([order, mirrorOrder], fulfillments, {
                value,
              })
          ).to.be.reverted;
        }

        const tx = marketplaceContract
          .connect(zone)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: constants.AddressZero,
            },
            {
              order: mirrorOrder,
              orderHash: mirrorOrderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );
        return receipt;
      });
      it("Reverts on invalid signatures", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const originalSignature = order.signature;

        // set an invalid V value
        order.signature = order.signature.slice(0, -2) + "01";

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            })
        ).to.be.revertedWith("BadSignatureV(1)");

        // construct an invalid signature
        basicOrderParameters.signature = "0x".padEnd(130, "f") + "1c";

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            })
        ).to.be.revertedWith("InvalidSignature");

        basicOrderParameters.signature = originalSignature;

        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
            },
          ]);

          return receipt;
        });
      });
      it("Reverts on invalid 1271 signature", async () => {
        // Seller mints nft to contract
        const nftId = await mint721(sellerContract);

        // Seller approves marketplace contract to transfer NFT
        await expect(
          sellerContract
            .connect(seller)
            .approveNFT(testERC721.address, marketplaceContract.address)
        )
          .to.emit(testERC721, "ApprovalForAll")
          .withArgs(sellerContract.address, marketplaceContract.address, true);

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens
        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getTestItem20(
            tokenAmount.sub(100),
            tokenAmount.sub(100),
            sellerContract.address
          ),
          getTestItem20(40, 40, zone.address),
          getTestItem20(40, 40, owner.address),
        ];

        const { order } = await createOrder(
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters)
        ).to.be.revertedWith("BAD SIGNER");
      });
      it("Reverts on invalid contract 1271 signature and contract does not supply a revert reason", async () => {
        await sellerContract.connect(owner).revertWithMessage(false);

        // Seller mints nft to contract
        const nftId = await mint721(sellerContract);

        // Seller approves marketplace contract to transfer NFT
        await expect(
          sellerContract
            .connect(seller)
            .approveNFT(testERC721.address, marketplaceContract.address)
        )
          .to.emit(testERC721, "ApprovalForAll")
          .withArgs(sellerContract.address, marketplaceContract.address, true);

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens
        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getTestItem20(
            tokenAmount.sub(100),
            tokenAmount.sub(100),
            sellerContract.address
          ),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order } = await createOrder(
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

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters)
          ).to.be.revertedWith("BadContractSignature");
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters)
          ).to.be.reverted;
        }
      });
      it("Reverts on invalid contract 1271 signature and contract does not return magic value", async () => {
        await sellerContract.connect(owner).setValid(false);

        // Seller mints nft to contract
        const nftId = await mint721(sellerContract);

        // Seller approves marketplace contract to transfer NFT
        await expect(
          sellerContract
            .connect(seller)
            .approveNFT(testERC721.address, marketplaceContract.address)
        )
          .to.emit(testERC721, "ApprovalForAll")
          .withArgs(sellerContract.address, marketplaceContract.address, true);

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens
        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getTestItem20(
            tokenAmount.sub(100),
            tokenAmount.sub(100),
            sellerContract.address
          ),
          getTestItem20(50, 50, zone.address),
          getTestItem20(50, 50, owner.address),
        ];

        const { order } = await createOrder(
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

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters)
          ).to.be.revertedWith("BadContractSignature");
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters)
          ).to.be.reverted;
        }

        await sellerContract.connect(owner).setValid(true);
      });
      it("Reverts on restricted order where isValidOrder reverts with no data", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.reverted;
        }

        order.extraData = "0x0102030405";

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              )
          ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              )
          ).to.be.reverted;
        }
      });
      it("Reverts on restricted order where isValidOrder returns non-magic value", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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
          "0x".padEnd(65, "0") + "3"
        );

        const basicOrderParameters = getBasicOrderParameters(
          0, // EthForERC721
          order
        );

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              })
          ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillBasicOrder(basicOrderParameters, {
                value,
              })
          ).to.be.reverted;
        }

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.reverted;
        }

        order.extraData = "0x01";

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              )
          ).to.be.revertedWith(`InvalidRestrictedOrder("${orderHash}")`);
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              )
          ).to.be.reverted;
        }
      });
      it("Reverts on missing offer or consideration components", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
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

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value })
        ).to.be.revertedWith("OfferAndConsiderationRequiredOnFulfillment");

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

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, { value })
        ).to.be.revertedWith("OfferAndConsiderationRequiredOnFulfillment");

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

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith("OfferAndConsiderationRequiredOnFulfillment");

        fulfillments = defaultBuyNowMirrorFulfillment;

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        const tx = marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: constants.AddressZero,
            },
            {
              order: mirrorOrder,
              orderHash: mirrorOrderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );
        return receipt;
      });
      it("Reverts on mismatched offer and consideration components", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        let fulfillments = [toFulfillment([[0, 0]], [[0, 0]])];

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith(
          "MismatchedFulfillmentOfferAndConsiderationComponents"
        );

        fulfillments = defaultBuyNowMirrorFulfillment;

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        const tx = marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: constants.AddressZero,
            },
            {
              order: mirrorOrder,
              orderHash: mirrorOrderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );
        return receipt;
      });
      it("Reverts on mismatched offer components", async () => {
        // Seller mints nft
        const nftId = await mint721(seller);

        const secondNFTId = await mint721(seller);

        // Seller approves marketplace contract to transfer NFT
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const offer = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: toBN(1),
            endAmount: toBN(1),
          },
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: secondNFTId,
            startAmount: toBN(1),
            endAmount: toBN(1),
          },
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [
            [
              [0, 0],
              [0, 1],
            ],
            [[1, 0]],
          ],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on mismatched consideration components", async () => {
        // Seller mints nft
        const nftId = await mint721(seller);

        const secondNFTId = await mint721(seller);

        // Seller approves marketplace contract to transfer NFT
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const offer = [
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: toBN(1),
            endAmount: toBN(1),
          },
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: secondNFTId,
            startAmount: toBN(1),
            endAmount: toBN(1),
          },
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getTestItem20(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [
            [[0, 0]],
            [
              [1, 0],
              [1, 1],
            ],
          ],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on fulfillment component with out-of-range order", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [
            [[2, 0]],
            [
              [1, 0],
              [1, 1],
            ],
          ],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on fulfillment component with out-of-range offer item", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 5]], [[1, 0]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on fulfillment component with out-of-range initial order on fulfillAvailableOrders", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [
          getTestItem1155(nftId, amount.div(2), amount.div(2)),
          getTestItem1155(nftId, amount.div(2), amount.div(2)),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            [5, 0],
            [0, 0],
          ],
        ];

        const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [order],
              offerComponents,
              considerationComponents,
              toKey(false),
              100,
              {
                value,
              }
            )
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on fulfillment component with out-of-range initial offer item on fulfillAvailableOrders", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [
          getTestItem1155(nftId, amount.div(2), amount.div(2)),
          getTestItem1155(nftId, amount.div(2), amount.div(2)),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            [0, 5],
            [0, 0],
          ],
        ];

        const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

        let success = false;

        try {
          const tx = await marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [order],
              offerComponents,
              considerationComponents,
              toKey(false),
              100,
              {
                value,
              }
            );

          const receipt = await tx.wait();
          success = receipt.status;
        } catch (err) {}

        expect(success).to.be.false; // TODO: fix out-of-gas
      });
      it("Reverts on fulfillment component with out-of-range subsequent offer item on fulfillAvailableOrders", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [
          getTestItem1155(nftId, amount.div(2), amount.div(2)),
          getTestItem1155(nftId, amount.div(2), amount.div(2)),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            [0, 0],
            [0, 5],
          ],
        ];

        const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [order],
              offerComponents,
              considerationComponents,
              toKey(false),
              100,
              {
                value,
              }
            )
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on fulfillment component with out-of-range consideration item", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 5]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on unmet consideration items", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith(
          `ConsiderationNotMet(0, 2, ${parseEther("1").toString()}`
        );
      });
      it("Reverts on fulfillAvailableAdvancedOrders with empty fulfillment component", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [[]];

        const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              offerComponents,
              considerationComponents,
              toKey(false),
              constants.AddressZero,
              100,
              {
                value,
              }
            )
        ).to.be.revertedWith("MissingFulfillmentComponentOnAggregation(0)");
      });
      it("Reverts on fulfillAvailableAdvancedOrders with out-of-range initial offer order", async () => {
        // Seller mints nft
        const { nftId, amount } = await mint1155(seller, 2);

        // Seller approves marketplace contract to transfer NFT

        await set1155ApprovalForAll(seller, marketplaceContract.address, true);

        const offer = [
          getTestItem1155(nftId, amount, amount, undefined),
          getTestItem1155(nftId, amount, amount, undefined),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            [2, 0],
            [0, 0],
          ],
        ];

        const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              offerComponents,
              considerationComponents,
              toKey(false),
              constants.AddressZero,
              100,
              {
                value,
              }
            )
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on fulfillAvailableAdvancedOrders with out-of-range offer order", async () => {
        // Seller mints nft
        const { nftId, amount } = await mint1155(seller, 2);

        // Seller approves marketplace contract to transfer NFT

        await set1155ApprovalForAll(seller, marketplaceContract.address, true);

        const offer = [
          getTestItem1155(nftId, amount, amount, undefined),
          getTestItem1155(nftId, amount, amount, undefined),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            [0, 0],
            [2, 0],
          ],
        ];

        const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              offerComponents,
              considerationComponents,
              toKey(false),
              constants.AddressZero,
              100,
              {
                value,
              }
            )
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on fulfillAvailableAdvancedOrders with mismatched offer components", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId), getTestItem20(1, 1)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [
          [
            [0, 0],
            [0, 1],
          ],
        ];

        const considerationComponents = [[[0, 0]], [[0, 1]], [[0, 2]]];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              offerComponents,
              considerationComponents,
              toKey(false),
              constants.AddressZero,
              100,
              {
                value,
              }
            )
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on fulfillAvailableAdvancedOrders with out-of-range consideration order", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [[[0, 0]]];

        const considerationComponents = [
          [
            [0, 0],
            [2, 1],
          ],
          [[2, 2]],
        ];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              offerComponents,
              considerationComponents,
              toKey(false),
              constants.AddressZero,
              100,
              {
                value,
              }
            )
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on fulfillAvailableAdvancedOrders with mismatched consideration components", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          {
            itemType: 2, // ERC721
            token: testERC721.address,
            identifierOrCriteria: nftId,
            startAmount: toBN(1),
            endAmount: toBN(1),
            recipient: zone.address,
          },
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const offerComponents = [[[0, 0]]];

        const considerationComponents = [
          [
            [0, 0],
            [0, 1],
          ],
        ];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              offerComponents,
              considerationComponents,
              toKey(false),
              constants.AddressZero,
              100,
              {
                value,
              }
            )
        ).to.be.revertedWith("InvalidFulfillmentComponentData");
      });
      it("Reverts on fulfillAvailableAdvancedOrders no available components", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem1155(nftId, amount.div(2), amount.div(2))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        // first order is expired
        const { order: orderOne, value } = await createOrder(
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
        await expect(
          marketplaceContract.connect(seller).cancel([orderComponents])
        )
          .to.emit(marketplaceContract, "OrderCancelled")
          .withArgs(orderHashTwo, seller.address, zone.address);

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
        await withBalanceChecks([orderThree], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillOrder(orderThree, toKey(false), {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order: orderThree,
              orderHash: orderHashThree,
              fulfiller: buyer.address,
            },
          ]);

          return receipt;
        });

        const offerComponents = [
          [
            [0, 0],
            [1, 0],
            [2, 0],
          ],
        ];

        const considerationComponents = [
          [
            [0, 0],
            [1, 0],
            [2, 0],
          ],
          [
            [0, 1],
            [1, 1],
            [2, 1],
          ],
          [
            [0, 2],
            [1, 2],
            [2, 2],
          ],
        ];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [orderOne, orderTwo, orderThree],
              [],
              offerComponents,
              considerationComponents,
              toKey(false),
              constants.AddressZero,
              100,
              {
                value: value.mul(3),
              }
            )
        ).to.be.revertedWith("NoSpecifiedOrdersAvailable");
      });
      it("Reverts on out-of-range criteria resolvers", async () => {
        // Seller mints nfts
        const nftId = randomBN();
        const secondNFTId = randomBN();
        const thirdNFTId = randomBN();

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        let criteriaResolvers = [
          buildResolver(3, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("OrderCriteriaResolverOutOfRange");

        criteriaResolvers = [
          buildResolver(0, 0, 5, nftId, proofs[nftId.toString()]),
        ];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("OfferCriteriaResolverOutOfRange");

        criteriaResolvers = [
          buildResolver(0, 1, 5, nftId, proofs[nftId.toString()]),
        ];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("ConsiderationCriteriaResolverOutOfRange");

        criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        await withBalanceChecks([order], 0, criteriaResolvers, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            criteriaResolvers
          );

          return receipt;
        });
      });
      if (process.env.REFERENCE) {
        it("Reverts on out-of-range criteria resolver (match)", async () => {
          // Seller mints nfts
          const nftId = await mint721(seller);

          // Seller approves marketplace contract to transfer NFTs
          await set721ApprovalForAll(seller, marketplaceContract.address, true);

          const { root, proofs } = merkleTree([nftId]);

          const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
          ];

          let criteriaResolvers = [
            buildResolver(3, 0, 0, nftId, proofs[nftId.toString()]),
          ];

          const { order, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            criteriaResolvers
          );

          const { mirrorOrder } = await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            criteriaResolvers
          );

          const fulfillments = [toFulfillment([[1, 0]], [[0, 0]])];

          await expect(
            marketplaceContract
              .connect(owner)
              .matchAdvancedOrders(
                [order, mirrorOrder],
                criteriaResolvers,
                fulfillments,
                {
                  value,
                }
              )
          ).to.be.revertedWith("OrderCriteriaResolverOutOfRange");

          criteriaResolvers = [
            buildResolver(0, 0, 5, nftId, proofs[nftId.toString()]),
          ];

          await expect(
            marketplaceContract
              .connect(owner)
              .matchAdvancedOrders(
                [order, mirrorOrder],
                criteriaResolvers,
                fulfillments,
                {
                  value,
                }
              )
          ).to.be.revertedWith("OfferCriteriaResolverOutOfRange");

          criteriaResolvers = [
            buildResolver(0, 1, 5, nftId, proofs[nftId.toString()]),
          ];

          await expect(
            marketplaceContract
              .connect(owner)
              .matchAdvancedOrders(
                [order, mirrorOrder],
                criteriaResolvers,
                fulfillments,
                {
                  value,
                }
              )
          ).to.be.revertedWith("ConsiderationCriteriaResolverOutOfRange");
        });
      }
      it("Reverts on unresolved criteria items", async () => {
        // Seller and buyer both mints nfts
        const nftId = randomBN();
        const secondNFTId = randomBN();

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(buyer.address, secondNFTId);

        const tokenIds = [nftId, secondNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        // Buyer approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(buyer, marketplaceContract.address, true);

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

        const consideration = [
          getTestItem721WithCriteria(root, toBN(1), toBN(1), owner.address),
        ];

        let criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
          buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("UnresolvedConsiderationCriteria");

        criteriaResolvers = [
          buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
        ];

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("UnresolvedOfferCriteria");

        criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
          buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
        ];

        await withBalanceChecks([order], 0, criteriaResolvers, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            criteriaResolvers
          );

          return receipt;
        });
      });
      if (process.env.REFERENCE) {
        it("Reverts on unresolved criteria items (match)", async () => {
          // Seller mints nfts
          const nftId = randomBN();
          const secondNFTId = randomBN();

          await testERC721.mint(seller.address, nftId);
          await testERC721.mint(seller.address, secondNFTId);

          const tokenIds = [nftId, secondNFTId];

          // Seller approves marketplace contract to transfer NFTs
          await set721ApprovalForAll(seller, marketplaceContract.address, true);

          const { root, proofs } = merkleTree(tokenIds);

          const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

          const consideration = [
            getTestItem721WithCriteria(root, toBN(1), toBN(1), owner.address),
          ];

          let criteriaResolvers = [
            buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
            buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
          ];

          const { order, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            criteriaResolvers
          );

          criteriaResolvers = [
            buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
          ];

          const { mirrorOrder } = await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            criteriaResolvers
          );

          const fulfillments = [toFulfillment([[1, 0]], [[0, 0]])];

          await expect(
            marketplaceContract
              .connect(owner)
              .matchAdvancedOrders(
                [order, mirrorOrder],
                criteriaResolvers,
                fulfillments,
                {
                  value,
                }
              )
          ).to.be.revertedWith("UnresolvedConsiderationCriteria");

          criteriaResolvers = [
            buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
          ];

          await expect(
            marketplaceContract
              .connect(owner)
              .matchAdvancedOrders(
                [order, mirrorOrder],
                criteriaResolvers,
                fulfillments,
                {
                  value,
                }
              )
          ).to.be.revertedWith("UnresolvedOfferCriteria");

          criteriaResolvers = [
            buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
            buildResolver(0, 1, 0, secondNFTId, proofs[secondNFTId.toString()]),
          ];
        });
      }
      it("Reverts on attempts to resolve criteria for non-criteria item", async () => {
        // Seller mints nfts
        const nftId = randomBN();
        const secondNFTId = randomBN();
        const thirdNFTId = randomBN();

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const { proofs } = merkleTree(tokenIds);

        const offer = [
          getTestItem721(
            nftId,
            toBN(1),
            toBN(1),
            undefined,
            testERC721.address
          ),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          criteriaResolvers
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("CriteriaNotEnabledForItem");
      });
      if (process.env.REFERENCE) {
        it("Reverts on attempts to resolve criteria for non-criteria item (match)", async () => {
          // Seller mints nfts
          const nftId = await mint721(seller);

          // Seller approves marketplace contract to transfer NFTs
          await set721ApprovalForAll(seller, marketplaceContract.address, true);

          const { root, proofs } = merkleTree([nftId]);

          const offer = [
            getTestItem721(
              root,
              toBN(1),
              toBN(1),
              undefined,
              testERC721.address
            ),
          ];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), zone.address),
            getItemETH(parseEther("1"), parseEther("1"), owner.address),
          ];

          const criteriaResolvers = [
            buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
          ];

          const { order, value } = await createOrder(
            seller,
            zone,
            offer,
            consideration,
            0, // FULL_OPEN
            criteriaResolvers
          );

          const { mirrorOrder } = await createMirrorAcceptOfferOrder(
            buyer,
            zone,
            order,
            criteriaResolvers
          );

          const fulfillments = [toFulfillment([[1, 0]], [[0, 0]])];

          await expect(
            marketplaceContract
              .connect(owner)
              .matchAdvancedOrders(
                [order, mirrorOrder],
                criteriaResolvers,
                fulfillments,
                {
                  value,
                }
              )
          ).to.be.revertedWith("CriteriaNotEnabledForItem");
        });
      }
      it("Reverts on offer amount overflow", async () => {
        const { testERC20: testERC20Two } = await fixtureERC20(owner);
        // Buyer mints nfts
        const nftId = await mintAndApprove721(
          buyer,
          marketplaceContract.address
        );

        await testERC20Two.mint(seller.address, constants.MaxUint256);
        // Seller approves marketplace contract to transfer NFTs
        await testERC20Two
          .connect(seller)
          .approve(marketplaceContract.address, constants.MaxUint256);

        const offer = [
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            undefined,
            testERC20Two.address
          ),
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            undefined,
            testERC20Two.address
          ),
        ];

        const consideration = [getTestItem721(nftId, 1, 1, seller.address)];

        const offer2 = [getTestItem721(nftId, 1, 1)];
        const consideration2 = [
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            buyer.address,
            testERC20Two.address
          ),
        ];

        const fulfillments = [
          toFulfillment(
            [
              [0, 0],
              [0, 1],
            ],
            [[1, 0]]
          ),
          toFulfillment([[1, 0]], [[0, 0]]),
        ];

        const { order } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1
        );

        const { order: order2 } = await createOrder(
          buyer,
          zone,
          offer2,
          consideration2,
          1
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchAdvancedOrders([order, order2], [], fulfillments)
        ).to.be.revertedWith(
          "panic code 0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
        );
      });

      it("Reverts on offer amount overflow when another amount is 0", async () => {
        const { testERC20: testERC20Two } = await fixtureERC20(owner);
        // Buyer mints nfts
        const nftId = await mintAndApprove721(
          buyer,
          marketplaceContract.address
        );

        await testERC20Two.mint(seller.address, constants.MaxUint256);
        // Seller approves marketplace contract to transfer NFTs
        await testERC20Two
          .connect(seller)
          .approve(marketplaceContract.address, constants.MaxUint256);

        const offer = [
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            undefined,
            testERC20Two.address
          ),
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            undefined,
            testERC20Two.address
          ),
          getTestItem20(0, 0, undefined, testERC20Two.address),
        ];

        const consideration = [getTestItem721(nftId, 1, 1, seller.address)];

        const offer2 = [getTestItem721(nftId, 1, 1)];
        const consideration2 = [
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            buyer.address,
            testERC20Two.address
          ),
        ];

        const fulfillments = [
          toFulfillment(
            [
              [0, 0],
              [0, 1],
              [0, 2],
            ],
            [[1, 0]]
          ),
          toFulfillment([[1, 0]], [[0, 0]]),
        ];

        const { order } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1
        );

        const { order: order2 } = await createOrder(
          buyer,
          zone,
          offer2,
          consideration2,
          1
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchAdvancedOrders([order, order2], [], fulfillments)
        ).to.be.revertedWith(
          "panic code 0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
        );
      });

      it("Reverts on consideration amount overflow", async () => {
        const { testERC20: testERC20Two } = await fixtureERC20(owner);
        // Buyer mints nfts
        const nftId = await mintAndApprove721(
          buyer,
          marketplaceContract.address
        );

        await testERC20Two.mint(seller.address, constants.MaxUint256);
        // Seller approves marketplace contract to transfer NFTs
        await testERC20Two
          .connect(seller)
          .approve(marketplaceContract.address, constants.MaxUint256);

        const offer = [getTestItem721(nftId, 1, 1)];

        const consideration = [
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            seller.address,
            testERC20Two.address
          ),
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            seller.address,
            testERC20Two.address
          ),
        ];

        const offer2 = [
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            undefined,
            testERC20Two.address
          ),
        ];
        const consideration2 = [getTestItem721(nftId, 1, 1, buyer.address)];

        const fulfillments = [
          toFulfillment(
            [[1, 0]],
            [
              [0, 0],
              [0, 1],
            ]
          ),
          toFulfillment([[0, 0]], [[1, 0]]),
        ];

        const { order } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1
        );

        const { order: order2 } = await createOrder(
          buyer,
          zone,
          offer2,
          consideration2,
          1
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchAdvancedOrders([order, order2], [], fulfillments)
        ).to.be.revertedWith(
          "panic code 0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
        );
      });

      it("Reverts on consideration amount overflow when another amount is 0", async () => {
        const { testERC20: testERC20Two } = await fixtureERC20(owner);
        // Buyer mints nfts
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        await testERC20Two.mint(buyer.address, constants.MaxUint256);
        // Seller approves marketplace contract to transfer NFTs
        await testERC20Two
          .connect(buyer)
          .approve(marketplaceContract.address, constants.MaxUint256);

        const offer = [getTestItem721(nftId, 1, 1)];

        const consideration = [
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            seller.address,
            testERC20Two.address
          ),
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            seller.address,
            testERC20Two.address
          ),
          getTestItem20(0, 0, seller.address, testERC20Two.address),
        ];

        const offer2 = [
          getTestItem20(
            constants.MaxUint256,
            constants.MaxUint256,
            undefined,
            testERC20Two.address
          ),
        ];
        const consideration2 = [getTestItem721(nftId, 1, 1, buyer.address)];

        const fulfillments = [
          toFulfillment(
            [[1, 0]],
            [
              [0, 0],
              [0, 1],
              [0, 2],
            ]
          ),
          toFulfillment([[0, 0]], [[1, 0]]),
        ];

        const { order } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          1
        );

        const { order: order2 } = await createOrder(
          buyer,
          zone,
          offer2,
          consideration2,
          1
        );

        await expect(
          marketplaceContract.matchAdvancedOrders(
            [order, order2],
            [],
            fulfillments
          )
        ).to.be.revertedWith(
          "panic code 0x11 (Arithmetic operation underflowed or overflowed outside of an unchecked block)"
        );
      });

      it("Reverts on invalid criteria proof", async () => {
        // Seller mints nfts
        const nftId = randomBN();
        const secondNFTId = randomBN();
        const thirdNFTId = randomBN();

        await testERC721.mint(seller.address, nftId);
        await testERC721.mint(seller.address, secondNFTId);
        await testERC721.mint(seller.address, thirdNFTId);

        const tokenIds = [nftId, secondNFTId, thirdNFTId];

        // Seller approves marketplace contract to transfer NFTs
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        const { root, proofs } = merkleTree(tokenIds);

        const offer = [getTestItem721WithCriteria(root, toBN(1), toBN(1))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const criteriaResolvers = [
          buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("InvalidProof");

        criteriaResolvers[0].identifier =
          criteriaResolvers[0].identifier.sub(1);

        await withBalanceChecks([order], 0, criteriaResolvers, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              criteriaResolvers,
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            criteriaResolvers
          );

          return receipt;
        });
      });
      it("Reverts on attempts to transfer >1 ERC721 in single transfer", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [
          getTestItem721(
            nftId,
            toBN(2),
            toBN(2),
            undefined,
            testERC721.address
          ),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(false), {
            value,
          })
        ).to.be.revertedWith("InvalidERC721TransferAmount");
      });
      it("Reverts on attempts to transfer >1 ERC721 in single transfer (basic)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [
          getTestItem721(
            nftId,
            toBN(2),
            toBN(2),
            undefined,
            testERC721.address
          ),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            })
        ).to.be.revertedWith("InvalidERC721TransferAmount");
      });
      it("Reverts on attempts to transfer >1 ERC721 in single transfer via conduit", async () => {
        const nftId = await mintAndApprove721(seller, conduitOne.address, true);

        const offer = [
          getTestItem721(
            nftId,
            toBN(2),
            toBN(2),
            undefined,
            testERC721.address
          ),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
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

        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(false), {
            value,
          })
        ).to.be.revertedWith("InvalidERC721TransferAmount");
      });
    });

    describe("Out of timespan", async () => {
      it("Reverts on orders that have not started (standard)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "NOT_STARTED"
        );

        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(false), {
            value,
          })
        ).to.be.revertedWith("InvalidTime");
      });
      it("Reverts on orders that have expired (standard)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "EXPIRED"
        );

        await expect(
          marketplaceContract.connect(buyer).fulfillOrder(order, toKey(false), {
            value,
          })
        ).to.be.revertedWith("InvalidTime");
      });
      it("Reverts on orders that have not started (basic)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            })
        ).to.be.revertedWith("InvalidTime");
      });
      it("Reverts on orders that have expired (basic)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            })
        ).to.be.revertedWith("InvalidTime");
      });
      it("Reverts on orders that have not started (match)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "NOT_STARTED"
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], defaultBuyNowMirrorFulfillment, {
              value,
            })
        ).to.be.revertedWith("InvalidTime");
      });
      it("Reverts on orders that have expired (match)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0, // FULL_OPEN
          [],
          "EXPIRED"
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], defaultBuyNowMirrorFulfillment, {
              value,
            })
        ).to.be.revertedWith("InvalidTime");
      });
    });

    describe("Insufficient amounts and bad items", async () => {
      it("Reverts when no ether is supplied (basic)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value: toBN(0),
            })
        ).to.be.revertedWith("InvalidMsgValue");

        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
            },
          ]);

          return receipt;
        });
      });
      it("Reverts when not enough ether is supplied (basic)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value: toBN(1),
            })
        ).to.be.revertedWith("InsufficientEtherSupplied");

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value: value.sub(1),
            })
        ).to.be.revertedWith("InsufficientEtherSupplied");

        await withBalanceChecks([order], 0, null, async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(tx, receipt, [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
            },
          ]);

          return receipt;
        });
      });
      it("Reverts when not enough ether is supplied as offer item (match)", async () => {
        // NOTE: this is a ridiculous scenario, buyer is paying the seller's offer
        const offer = [getItemETH(parseEther("10"), parseEther("10"))];

        const consideration = [
          getItemETH(parseEther("1"), parseEther("1"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = defaultBuyNowMirrorFulfillment;

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        await expect(
          marketplaceContract
            .connect(buyer)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value: toBN(1),
            })
        ).to.be.revertedWith("InsufficientEtherSupplied");

        await expect(
          marketplaceContract
            .connect(buyer)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value: parseEther("9.999999"),
            })
        ).to.be.revertedWith("InsufficientEtherSupplied");

        await marketplaceContract
          .connect(buyer)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value: parseEther("13"),
          });
      });
      it("Reverts when not enough ether is supplied (standard + advanced)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(amount.mul(1000), amount.mul(1000), seller.address),
          getItemETH(amount.mul(10), amount.mul(10), zone.address),
          getItemETH(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value: toBN(1),
              }
            )
        ).to.be.revertedWith("InsufficientEtherSupplied");

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value: value.sub(1),
              }
            )
        ).to.be.revertedWith("InsufficientEtherSupplied");

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        // fulfill with a tiny bit extra to test for returning eth
        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value: value.add(1),
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );
      });
      it("Reverts when not enough ether is supplied (match)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = defaultBuyNowMirrorFulfillment;

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(4);

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value: toBN(1),
            })
        ).to.be.revertedWith("InsufficientEtherSupplied");

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value: value.sub(1),
            })
        ).to.be.revertedWith("InsufficientEtherSupplied");

        await whileImpersonating(owner.address, provider, async () => {
          const tx = marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            });
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: constants.AddressZero,
              },
              {
                order: mirrorOrder,
                orderHash: mirrorOrderHash,
                fulfiller: constants.AddressZero,
              },
            ],
            executions
          );
          return receipt;
        });
      });
      it("Reverts when ether is supplied to a non-payable route (basic)", async () => {
        // Seller mints nft
        const nftId = randomBN();
        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(
            parseEther("1"),
            parseEther("1"),
            marketplaceContract.address
          ),
        ];

        const { order } = await createOrder(
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value: 1,
            })
        ).to.be.revertedWith("InvalidMsgValue(1)");
      });

      it(`Reverts when ether transfer fails (returndata)${
        process.env.REFERENCE ? " — SKIPPED ON REFERENCE" : ""
      }`, async () => {
        if (process.env.REFERENCE) {
          return;
        }

        const recipient = await (
          await ethers.getContractFactory("ExcessReturnDataRecipient")
        ).deploy();
        const setup = async () => {
          const nftId = await mintAndApprove721(
            seller,
            marketplaceContract.address
          );

          // Buyer mints ERC20
          const tokenAmount = minRandom(100);
          await testERC20.mint(buyer.address, tokenAmount);

          // Seller approves marketplace contract to transfer NFT
          await set721ApprovalForAll(seller, marketplaceContract.address, true);

          // Buyer approves marketplace contract to transfer tokens

          await expect(
            testERC20
              .connect(buyer)
              .approve(marketplaceContract.address, tokenAmount)
          )
            .to.emit(testERC20, "Approval")
            .withArgs(buyer.address, marketplaceContract.address, tokenAmount);
          const offer = [getTestItem721(nftId)];

          const consideration = [
            getItemETH(parseEther("10"), parseEther("10"), seller.address),
            getItemETH(parseEther("1"), parseEther("1"), recipient.address),
          ];

          const { order } = await createOrder(
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
          return basicOrderParameters;
        };
        let basicOrderParameters = await setup();
        const baseGas = await marketplaceContract
          .connect(buyer)
          .estimateGas.fulfillBasicOrder(basicOrderParameters, {
            value: parseEther("12"),
          });

        // TODO: clean *this* up
        basicOrderParameters = await setup();
        await recipient.setRevertDataSize(1);

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value: parseEther("12"),
              gasLimit: hre.__SOLIDITY_COVERAGE_RUNNING
                ? baseGas.add(35000)
                : baseGas.add(1000),
            })
        ).to.be.revertedWith("EtherTransferGenericFailure");
      });

      it("Reverts when ether transfer fails (basic)", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Seller approves marketplace contract to transfer NFT
        await set721ApprovalForAll(seller, marketplaceContract.address, true);

        // Buyer approves marketplace contract to transfer tokens

        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(
            parseEther("1"),
            parseEther("1"),
            marketplaceContract.address
          ),
        ];

        const { order } = await createOrder(
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value: parseEther("12"),
            })
        ).to.be.revertedWith(
          `EtherTransferGenericFailure("${
            marketplaceContract.address
          }", ${parseEther("1").toString()})`
        );
      });
      it("Reverts when tokens are not approved", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
          getTestItem20(amount.mul(10), amount.mul(10), zone.address),
          getTestItem20(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.reverted; // panic code thrown by underlying 721

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        // Buyer approves marketplace contract to transfer tokens
        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);
        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );
      });
      it("Reverts when 1155 token transfer reverts", async () => {
        // Seller mints nft
        const { nftId, amount } = await mint1155(seller, 10000);

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("NOT_AUTHORIZED");
      });
      it("Reverts when 1155 token transfer reverts (via conduit)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mint1155(seller, 10000);

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
        ];

        const { order, value } = await createOrder(
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith(`NOT_AUTHORIZED`);
      });

      // Skip this test when testing the reference contract
      if (!process.env.REFERENCE) {
        it("Reverts when 1155 token transfer reverts (via conduit, returndata)", async () => {
          const recipient = await (
            await ethers.getContractFactory("ExcessReturnDataRecipient")
          ).deploy();

          const setup = async () => {
            // seller mints ERC20
            const tokenAmount = minRandom(100);
            await testERC20.mint(seller.address, tokenAmount);

            // Seller approves conduit contract to transfer tokens
            await expect(
              testERC20.connect(seller).approve(conduitOne.address, tokenAmount)
            )
              .to.emit(testERC20, "Approval")
              .withArgs(seller.address, conduitOne.address, tokenAmount);

            // Buyer mints nft
            const nftId = randomBN();
            const amount = toBN(randomBN(2));
            await testERC1155.mint(buyer.address, nftId, amount.mul(10000));

            // Buyer approves conduit contract to transfer NFTs
            await expect(
              testERC1155
                .connect(buyer)
                .setApprovalForAll(conduitOne.address, true)
            )
              .to.emit(testERC1155, "ApprovalForAll")
              .withArgs(buyer.address, conduitOne.address, true);

            const offer = [getTestItem20(tokenAmount, tokenAmount)];

            const consideration = [
              getTestItem1155(
                nftId,
                amount.mul(10),
                amount.mul(10),
                undefined,
                recipient.address
              ),
            ];

            const { order, value } = await createOrder(
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

            return {
              order,
              value,
            };
          };

          const { order: initialOrder, value } = await setup();
          const baseGas = await marketplaceContract
            .connect(buyer)
            .estimateGas.fulfillAdvancedOrder(
              initialOrder,
              [],
              conduitKeyOne,
              constants.AddressZero,
              {
                value,
              }
            );

          // TODO: clean *this* up
          const { order } = await setup();
          await recipient.setRevertDataSize(1);
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                conduitKeyOne,
                constants.AddressZero,
                {
                  value,
                  gasLimit: baseGas.add(74000),
                }
              )
          ).to.be.revertedWith("InvalidCallToConduit");
        });
      }

      it("Reverts when transferred item amount is zero", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens

        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [getTestItem1155(nftId, 0, 0, undefined)];

        const consideration = [
          getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
          getTestItem20(amount.mul(10), amount.mul(10), zone.address),
          getTestItem20(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith("MissingItemAmount");
      });
      it("Reverts when ERC20 tokens return falsey values", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens

        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
          getTestItem20(amount.mul(10), amount.mul(10), zone.address),
          getTestItem20(amount.mul(20), amount.mul(20), owner.address),
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.reverted; // TODO: hardhat can't find error msg on IR pipeline

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        await testERC20.blockTransfer(false);

        expect(await testERC20.blocked()).to.be.false;

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );
      });
      it("Works when ERC20 tokens return falsey values", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address,
          10000
        );

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves marketplace contract to transfer tokens

        await expect(
          testERC20
            .connect(buyer)
            .approve(marketplaceContract.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, marketplaceContract.address, tokenAmount);

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
          getTestItem20(amount.mul(10), amount.mul(10), zone.address),
          getTestItem20(amount.mul(20), amount.mul(20), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await testERC20.setNoReturnData(true);

        expect(await testERC20.noReturnData()).to.be.true;

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: toKey(false),
              },
            ],
            null,
            []
          );

          return receipt;
        });

        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );

        await testERC20.setNoReturnData(false);

        expect(await testERC20.noReturnData()).to.be.false;
      });
      it("Reverts when ERC20 tokens return falsey values (via conduit)", async () => {
        // Seller mints nft
        const { nftId, amount } = await mint1155(seller, 10000);

        // Seller approves conduit contract to transfer NFTs
        await set1155ApprovalForAll(seller, conduitOne.address, true);

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves conduit contract to transfer tokens

        await expect(
          testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, conduitOne.address, tokenAmount);

        // Seller approves conduit contract to transfer tokens
        await expect(
          testERC20.connect(seller).approve(conduitOne.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(seller.address, conduitOne.address, tokenAmount);

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
          getTestItem20(amount.mul(10), amount.mul(10), zone.address),
          getTestItem20(amount.mul(20), amount.mul(20), owner.address),
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

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                conduitKeyOne,
                constants.AddressZero,
                {
                  value,
                }
              )
          ).to.be.revertedWith(
            `BadReturnValueFromERC20OnTransfer("${testERC20.address}", "${
              buyer.address
            }", "${seller.address}", ${amount.mul(1000).toString()})`
          );
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                conduitKeyOne,
                constants.AddressZero,
                {
                  value,
                }
              )
          ).to.be.reverted;
        }

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        await testERC20.blockTransfer(false);

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              conduitKeyOne,
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: conduitKeyOne,
              },
            ],
            null,
            []
          );

          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );
      });
      it("Reverts when providing non-existent conduit", async () => {
        // Seller mints nft
        const { nftId, amount } = await mint1155(seller, 10000);

        // Seller approves conduit contract to transfer NFTs
        await set1155ApprovalForAll(seller, conduitOne.address, true);

        // Buyer mints ERC20
        const tokenAmount = minRandom(100);
        await testERC20.mint(buyer.address, tokenAmount);

        // Buyer approves conduit contract to transfer tokens
        await expect(
          testERC20.connect(buyer).approve(conduitOne.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(buyer.address, conduitOne.address, tokenAmount);

        // Seller approves conduit contract to transfer tokens
        await expect(
          testERC20.connect(seller).approve(conduitOne.address, tokenAmount)
        )
          .to.emit(testERC20, "Approval")
          .withArgs(seller.address, conduitOne.address, tokenAmount);

        const offer = [getTestItem1155(nftId, amount.mul(10), amount.mul(10))];

        const consideration = [
          getTestItem20(amount.mul(1000), amount.mul(1000), seller.address),
          getTestItem20(amount.mul(10), amount.mul(10), zone.address),
          getTestItem20(amount.mul(20), amount.mul(20), owner.address),
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

        const badKey = constants.HashZero.slice(0, -1) + "2";

        const missingConduit = await conduitController.getConduit(badKey);

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(order, [], badKey, constants.AddressZero, {
              value,
            })
        ).to.be.revertedWith("InvalidConduit", badKey, missingConduit);

        let orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        await withBalanceChecks([order], 0, [], async () => {
          const tx = marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              conduitKeyOne,
              constants.AddressZero,
              {
                value,
              }
            );
          const receipt = await (await tx).wait();
          await checkExpectedEvents(
            tx,
            receipt,
            [
              {
                order,
                orderHash,
                fulfiller: buyer.address,
                fulfillerConduitKey: conduitKeyOne,
              },
            ],
            null,
            null
          );
          return receipt;
        });

        orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(true, false, 1, 1)
        );
      });
      it("Reverts when 1155 tokens are not approved", async () => {
        // Seller mints first nft
        const { nftId } = await mint1155(seller);

        // Seller mints second nft
        const { nftId: secondNftId, amount: secondAmount } = await mint1155(
          seller
        );

        const offer = [
          getTestItem1155(nftId, 0, 0),
          getTestItem1155(secondNftId, secondAmount, secondAmount),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[0, 1]], [[1, 1]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith("MissingItemAmount");
      });
      it("Reverts when 1155 tokens are not approved", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mint1155(seller);

        // Seller mints second nft
        const { nftId: secondNftId, amount: secondAmount } = await mint1155(
          seller
        );

        const offer = [
          getTestItem1155(nftId, amount, amount, undefined),
          getTestItem1155(secondNftId, secondAmount, secondAmount),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, orderHash, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[0, 1]], [[1, 1]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith("NOT_AUTHORIZED");

        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );

        // Seller approves marketplace contract to transfer NFT

        await set1155ApprovalForAll(seller, marketplaceContract.address, true);

        const executions = await simulateMatchOrders(
          [order, mirrorOrder],
          fulfillments,
          owner,
          value
        );

        expect(executions.length).to.equal(5);

        const tx = marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value,
          });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: constants.AddressZero,
            },
            {
              order: mirrorOrder,
              orderHash: mirrorOrderHash,
              fulfiller: constants.AddressZero,
            },
          ],
          executions
        );
        return receipt;
      });
      it("Reverts when token account with no code is supplied", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem1155(nftId, amount, amount, undefined)];

        const consideration = [
          getTestItem20(amount, amount, seller.address, constants.AddressZero),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.reverted; // TODO: look into the revert reason more thoroughly
        // Transaction reverted: function returned an unexpected amount of data
      });
      it("Reverts when 721 account with no code is supplied", async () => {
        const offer = [getTestItem721(0, 1, 1, undefined, buyer.address)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              { value }
            )
        ).to.be.revertedWith(`NoContract("${buyer.address}")`);
      });
      it("Reverts when 1155 account with no code is supplied", async () => {
        const amount = toBN(randomBN(2));

        const offer = [
          getTestItem1155(0, amount, amount, constants.AddressZero),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith(`NoContract("${constants.AddressZero}")`);
      });
      it("Reverts when 1155 account with no code is supplied (via conduit)", async () => {
        const amount = toBN(randomBN(2));

        const offer = [
          getTestItem1155(0, amount, amount, constants.AddressZero),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
        ];

        const { order, value } = await createOrder(
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith(`NoContract("${constants.AddressZero}")`);
      });
      it("Reverts when non-token account is supplied as the token", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem1155(nftId, amount, amount, undefined)];

        const consideration = [
          getTestItem20(
            amount,
            amount,
            seller.address,
            marketplaceContract.address
          ),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              toKey(false),
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith(
          `TokenTransferGenericFailure("${marketplaceContract.address}", "${
            buyer.address
          }", "${seller.address}", 0, ${amount.toString()})`
        );
      });
      it("Reverts when non-token account is supplied as the token fulfilled via conduit", async () => {
        // Seller mints nft
        const { nftId, amount } = await mintAndApprove1155(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem1155(nftId, amount, amount, undefined)];

        const consideration = [
          getTestItem20(
            amount,
            amount,
            seller.address,
            marketplaceContract.address
          ),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(
              order,
              [],
              conduitKeyOne,
              constants.AddressZero,
              {
                value,
              }
            )
        ).to.be.revertedWith(
          `TokenTransferGenericFailure("${marketplaceContract.address}", "${
            buyer.address
          }", "${seller.address}", 0, ${amount.toString()})`
        );
      });
      it("Reverts when non-1155 account is supplied as the token", async () => {
        const amount = toBN(randomBN(2));

        const offer = [
          getTestItem1155(0, amount, amount, marketplaceContract.address),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
        ];

        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              )
          ).to.be.revertedWith(
            `TokenTransferGenericFailure("${marketplaceContract.address}", "${
              seller.address
            }", "${buyer.address}", 0, ${amount.toString()})`
          );
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillAdvancedOrder(
                order,
                [],
                toKey(false),
                constants.AddressZero,
                {
                  value,
                }
              )
          ).to.be.reverted;
        }
      });
      it("Reverts when 1155 token is not approved via conduit", async () => {
        // Seller mints first nft
        const { nftId, amount } = await mint1155(seller);

        // Seller mints second nft
        const { nftId: secondNftId, amount: secondAmount } = await mint1155(
          seller
        );

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
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[0, 1]], [[1, 1]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith("NOT_AUTHORIZED");

        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );
      });
      it("Reverts when 1155 token with no code is supplied as the token via conduit", async () => {
        // Seller mints first nft
        const nftId = toBN(randomBN(4));
        const amount = toBN(randomBN(4));

        // Seller mints second nft
        const secondNftId = toBN(randomBN(4));
        const secondAmount = toBN(randomBN(4));

        const offer = [
          getTestItem1155(nftId, amount, amount, constants.AddressZero),
          getTestItem1155(
            secondNftId,
            secondAmount,
            secondAmount,
            constants.AddressZero
          ),
        ];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), zone.address),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
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

        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );

        const fulfillments = [
          [[[0, 0]], [[1, 0]]],
          [[[0, 1]], [[1, 1]]],
          [[[1, 0]], [[0, 0]]],
          [[[1, 0]], [[0, 1]]],
          [[[1, 0]], [[0, 2]]],
        ].map(([offerArr, considerationArr]) =>
          toFulfillment(offerArr, considerationArr)
        );

        await expect(
          marketplaceContract
            .connect(owner)
            .matchOrders([order, mirrorOrder], fulfillments, {
              value,
            })
        ).to.be.revertedWith("NoContract", constants.AddressZero);

        const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

        expect({ ...orderStatus }).to.deep.equal(
          buildOrderStatus(false, false, 0, 0)
        );
      });
      it("Reverts when non-payable ether recipient is supplied", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(
            parseEther("1"),
            parseEther("1"),
            marketplaceContract.address
          ),
          getItemETH(parseEther("1"), parseEther("1"), owner.address),
        ];

        const { order, value } = await createOrder(
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

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillBasicOrder(basicOrderParameters, {
              value,
            })
        ).to.be.revertedWith(
          `EtherTransferGenericFailure("${
            marketplaceContract.address
          }", ${parseEther("1").toString()})`
        );
      });
    });

    describe("Basic Order Calldata", () => {
      let calldata, value;

      before(async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
        ];
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

        await expect(
          buyer.sendTransaction({
            to: marketplaceContract.address,
            data: badData,
            value,
          })
        ).to.be.revertedWith("InvalidBasicOrderParameterEncoding");
      });

      it("Reverts if additionalRecipients has non-default offset", async () => {
        const badData = [
          calldata.slice(0, 1161),
          "1",
          calldata.slice(1162),
        ].join("");

        await expect(
          buyer.sendTransaction({
            to: marketplaceContract.address,
            data: badData,
            value,
          })
        ).to.be.revertedWith("InvalidBasicOrderParameterEncoding");
      });

      it("Reverts if signature has non-default offset", async () => {
        const badData = [
          calldata.slice(0, 1161),
          "2",
          calldata.slice(1162),
        ].join("");

        await expect(
          buyer.sendTransaction({
            to: marketplaceContract.address,
            data: badData,
            value,
          })
        ).to.be.revertedWith("InvalidBasicOrderParameterEncoding");
      });
    });

    describe("Reentrancy", async () => {
      it("Reverts on a reentrant call", async () => {
        // Seller mints nft
        const nftId = await mintAndApprove721(
          seller,
          marketplaceContract.address
        );

        const offer = [getTestItem721(nftId)];

        const consideration = [
          getItemETH(parseEther("10"), parseEther("10"), seller.address),
          getItemETH(parseEther("1"), parseEther("1"), reenterer.address),
        ];

        const { order, value } = await createOrder(
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

        if (!process.env.REFERENCE) {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.revertedWith("NoReentrantCalls");
        } else {
          await expect(
            marketplaceContract
              .connect(buyer)
              .fulfillOrder(order, toKey(false), {
                value,
              })
          ).to.be.reverted;
        }
      });
    });

    describe("ETH offer items", async () => {
      let ethAmount;
      const tokenAmount = minRandom(100);
      let offer;
      let consideration;
      let seller;
      let buyer;

      before(async () => {
        ethAmount = parseEther("1");
        seller = await getWalletWithEther();
        buyer = await getWalletWithEther();
        zone = new ethers.Wallet(randomHex(32), provider);
        offer = [getItemETH(ethAmount, ethAmount)];
        consideration = [
          getTestItem20(tokenAmount, tokenAmount, seller.address),
        ];
      });

      it("fulfillOrder reverts if any offer item is ETH", async () => {
        const { order, value } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillOrder(order, toKey(false), { value })
        ).to.be.revertedWith("InvalidNativeOfferItem");
      });

      it("fulfillAdvancedOrder reverts if any offer item is ETH", async () => {
        const { order } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAdvancedOrder(order, [], toKey(false), buyer.address, {
              value: ethAmount,
            })
        ).to.be.revertedWith("InvalidNativeOfferItem");
      });

      it("fulfillAvailableOrders reverts if any offer item is ETH", async () => {
        const { order } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableOrders(
              [order],
              [[[0, 0]]],
              [[[0, 0]]],
              toKey(false),
              100,
              { value: ethAmount }
            )
        ).to.be.revertedWith("InvalidNativeOfferItem");
      });

      it("fulfillAvailableAdvancedOrders reverts if any offer item is ETH", async () => {
        const { order } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );

        await expect(
          marketplaceContract
            .connect(buyer)
            .fulfillAvailableAdvancedOrders(
              [order],
              [],
              [[[0, 0]]],
              [[[0, 0]]],
              toKey(false),
              buyer.address,
              100,
              { value: ethAmount }
            )
        ).to.be.revertedWith("InvalidNativeOfferItem");
      });

      it("matchOrders allows fulfilling with native offer items", async () => {
        await mintAndApproveERC20(
          buyer,
          marketplaceContract.address,
          tokenAmount
        );

        const { order } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );
        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );
        const fulfillments = [
          toFulfillment([[0, 0]], [[1, 0]]),
          toFulfillment([[1, 0]], [[0, 0]]),
        ];

        await marketplaceContract
          .connect(owner)
          .matchOrders([order, mirrorOrder], fulfillments, {
            value: ethAmount,
          });
      });

      it("matchAdvancedOrders allows fulfilling with native offer items", async () => {
        await mintAndApproveERC20(
          buyer,
          marketplaceContract.address,
          tokenAmount
        );

        const { order } = await createOrder(
          seller,
          zone,
          offer,
          consideration,
          0 // FULL_OPEN
        );
        const { mirrorOrder } = await createMirrorBuyNowOrder(
          buyer,
          zone,
          order
        );
        const fulfillments = [
          toFulfillment([[0, 0]], [[1, 0]]),
          toFulfillment([[1, 0]], [[0, 0]]),
        ];

        await marketplaceContract
          .connect(owner)
          .matchAdvancedOrders([order, mirrorOrder], [], fulfillments, {
            value: ethAmount,
          });
      });
    });
  });
});
