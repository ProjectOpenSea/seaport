import { TypedDataDomain } from "@ethersproject/abstract-signer";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";
import { expect } from "chai";
import { time } from "console";
import { constants } from "ethers";
import { ethers } from "hardhat";
import { TypedData, TypedDataUtils } from "ethers-eip712";
import { Consideration, TestERC721 } from "../typechain-types";
import {
  OrderComponentsStruct,
  OrderParametersStruct,
  BasicOrderParametersStruct,
} from "../typechain-types/Consideration";
import { faucet, whileImpersonating } from "./utils/impersonate";

describe("Consideration functional tests", function () {
  const provider = ethers.provider;
  let chainId: number;
  let marketplaceContract: Consideration;
  let testERC721: TestERC721;
  let owner: Wallet;
  let domainData: TypedData["domain"];

  const considerationTypesEip712Hash = {
    OrderComponents: [
      {
        name: "offerer",
        type: "address",
      },
      { name: "zone", type: "address" },
      { name: "offer", type: "OfferedItem[]" },
      { name: "consideration", type: "ReceivedItem[]" },
      { name: "orderType", type: "uint8" },
      { name: "startTime", type: "uint256" },
      { name: "endTime", type: "uint256" },
      { name: "salt", type: "uint256" },
      { name: "nonce", type: "uint256" },
    ],
    OfferedItem: [
      { name: "itemType", type: "uint8" },
      { name: "token", type: "address" },
      { name: "identifierOrCriteria", type: "uint256" },
      { name: "startAmount", type: "uint256" },
      { name: "endAmount", type: "uint256" },
    ],
    ReceivedItem: [
      { name: "itemType", type: "uint8" },
      { name: "token", type: "address" },
      { name: "identifierOrCriteria", type: "uint256" },
      { name: "startAmount", type: "uint256" },
      { name: "endAmount", type: "uint256" },
      { name: "recipient", type: "address" },
    ],
  };

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
    const TestERC721Factory = await ethers.getContractFactory(
      "TestERC721",
      owner
    );
    marketplaceContract = await considerationFactory.deploy(
      ethers.constants.AddressZero, // TODO: use actual proxy factory
      ethers.constants.AddressZero, // TODO: use actual proxy implementation
    );
    testERC721 = await TestERC721Factory.deploy();

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
    let seller: Wallet;
    let buyer: Wallet;

    beforeEach(async () => {
      // Setup basic buyer/seller wallets with ETH
      seller = ethers.Wallet.createRandom().connect(provider);
      buyer = ethers.Wallet.createRandom().connect(provider);
      await Promise.all(
        [owner, seller, buyer].map((wallet) => faucet(wallet.address, provider))
      );
    });

    // Returns signature
    async function signOrder(
      orderComponents: OrderComponentsStruct,
      signer: Wallet
    ) {
      return await signer._signTypedData(
        domainData,
        considerationTypesEip712Hash,
        orderComponents
      );
    }

    async function signOrderWithEip712Lib(
      orderComponents: OrderComponentsStruct,
      signer: Wallet
    ) {
      const typedData: TypedData = {
        types: {
          EIP712Domain: [
            { name: "name", type: "string" },
            { name: "version", type: "string" },
            { name: "chainId", type: "uint256" },
            { name: "verifyingContract", type: "address" },
          ],
          ...considerationTypesEip712Hash,
        },
        primaryType: "OrderComponents" as const,
        domain: domainData,
        message: orderComponents,
      };

      console.log("TypedData:", typedData);

      const digest = TypedDataUtils.encodeDigest(typedData);
      const digestHex = ethers.utils.hexlify(digest);
      console.log("digest: ", digest);
      console.log("DigestHex: ", digestHex);

      // const encodedData = TypedDataUtils.encodeData(typedData);
      return await signer.signMessage(ethers.utils.arrayify(digest));
      /**
       * digest:  Uint8Array(32) [
  144,  8, 170,  95,  35, 140,  11, 225,
  155, 39, 211,  59, 103,  31, 118, 103,
  152, 30, 114, 187, 113, 200,  32, 248,
  181, 51, 116, 137, 120,  45, 189, 158
]
DigestHex:  0x9008aa5f238c0be19b27d33b671f7667981e72bb71c820f8b5337489782dbd9e
sigFromEip712Lib: 0x44f6c0e7d88f980f29da33b3e3ecbef759fbbe80e6b9e94f5b91af589696f20a173e93f5028dcc07c3b4b789e7099ef37013a83dfbd8061d1065115a3bc74e481b
       */
    }

    describe("A single ERC721 is to be transferred", async () => {
      describe("[Buy now] User fullfills a sell order for a single ERC721", async () => {
        it.only("ERC721 <=> ETH", async () => {
          // Seller mints nft
          const nftId = 0;
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const oneHourIntoFutureInSecs = Math.floor(
            new Date().getTime() / 1000 + 60 * 60
          );

          // Seller creates a sell order of 10 eth for nft
          const orderParameters: OrderParametersStruct = {
            offerer: seller.address,
            zone: constants.AddressZero,
            offer: [
              {
                itemType: 2, // ERC721
                token: testERC721.address,
                identifierOrCriteria: nftId,
                startAmount: 1,
                endAmount: 1,
              },
            ],
            consideration: [
              {
                itemType: 0, // ETH
                token: constants.AddressZero,
                identifierOrCriteria: 0, // ignored for ETH
                startAmount: ethers.utils.parseEther("10"),
                endAmount: ethers.utils.parseEther("10"),
                recipient: seller.address,
              },
            ],
            orderType: 0, // FULL_OPEN
            salt: 1,
            startTime: 0,
            endTime: oneHourIntoFutureInSecs,
          };

          const orderComponents = {
            ...orderParameters,
            nonce: 0,
          };

          const flatSig = await signOrder(orderComponents, seller);

          const orderHash = await marketplaceContract
            .connect(buyer.address)
            .getOrderHash(orderComponents);

          const order = {
            parameters: orderParameters,
            signature: flatSig,
          };

          await whileImpersonating(buyer.address, provider, async () => {
            await expect(marketplaceContract.connect(buyer).fulfillOrder(order, false, {value: order.parameters.consideration[0].endAmount}))
              .to.emit(marketplaceContract, "OrderFulfilled")
              .withArgs(orderHash, seller.address, constants.AddressZero);
          });
        });
        it.only("ERC721 <=> ETH (basic)", async () => {
          // Seller mints nft
          const nftId = 1;
          await testERC721.mint(seller.address, nftId);

          // Seller approves marketplace contract to transfer NFT
          await whileImpersonating(seller.address, provider, async () => {
            await expect(testERC721.connect(seller).setApprovalForAll(marketplaceContract.address, true))
              .to.emit(testERC721, "ApprovalForAll")
              .withArgs(seller.address, marketplaceContract.address, true);
          });

          const oneHourIntoFutureInSecs = Math.floor(
            new Date().getTime() / 1000 + 60 * 60
          );

          // Seller creates a sell order of 10 eth for nft
          const orderParameters: OrderParametersStruct = {
            offerer: seller.address,
            zone: constants.AddressZero,
            offer: [
              {
                itemType: 2, // ERC721
                token: testERC721.address,
                identifierOrCriteria: nftId,
                startAmount: 1,
                endAmount: 1,
              },
            ],
            consideration: [
              {
                itemType: 0, // ETH
                token: constants.AddressZero,
                identifierOrCriteria: 0, // ignored for ETH
                startAmount: ethers.utils.parseEther("10"),
                endAmount: ethers.utils.parseEther("10"),
                recipient: seller.address,
              },
            ],
            orderType: 0, // FULL_OPEN
            salt: 1,
            startTime: 0,
            endTime: oneHourIntoFutureInSecs,
          };

          const orderComponents = {
            ...orderParameters,
            nonce: 0,
          };

          const flatSig = await signOrder(orderComponents, seller);

          const orderHash = await marketplaceContract
            .connect(buyer.address)
            .getOrderHash(orderComponents);

          const order = {
            parameters: orderParameters,
            signature: flatSig,
          };

          const basicOrderParameters: BasicOrderParametersStruct = {
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
            additionalRecipients: [],
          };

          await whileImpersonating(buyer.address, provider, async () => {
            await expect(marketplaceContract.connect(buyer).fulfillBasicEthForERC721Order(order.parameters.consideration[0].endAmount, basicOrderParameters, {value: order.parameters.consideration[0].endAmount}))
              .to.emit(marketplaceContract, "OrderFulfilled")
              .withArgs(orderHash, seller.address, constants.AddressZero);
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
