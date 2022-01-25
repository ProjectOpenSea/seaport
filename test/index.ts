import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "@ethersproject/wallet";
import { expect } from "chai";
import { time } from "console";
import { constants } from "ethers";
import { ethers } from "hardhat";
import { Consideration, TestERC721 } from "../typechain-types";
import { OrderParametersStruct } from "../typechain-types/Consideration";
import { faucet, whileImpersonating } from "./utils/impersonate";

describe("Consideration functional tests", function () {
  const provider = ethers.provider;
  let chainId: number;
  let marketplaceContract: Consideration;
  let testERC721: TestERC721;

  // Buy now or accept offer for a single ERC721 or ERC1155 in exchange for
  // ETH, WETH or ERC20
  describe("Basic buy now or accept offer flows", async () => {
    let owner: Wallet;
    let seller: Wallet;
    let buyer: Wallet;

    beforeEach(async () => {
      const network = await provider.getNetwork();
      chainId = network.chainId;
      // Setup basic buyer/seller wallets with ETH
      owner = ethers.Wallet.createRandom().connect(provider);
      seller = ethers.Wallet.createRandom().connect(provider);
      buyer = ethers.Wallet.createRandom().connect(provider);
      await Promise.all(
        [owner, seller, buyer].map((wallet) => faucet(wallet.address, provider))
      );
      const considerationFactory = await ethers.getContractFactory(
        "Consideration"
      );
      const TestERC721Factory = await ethers.getContractFactory(
        "TestERC721",
        owner
      );
      marketplaceContract = await considerationFactory.deploy();
      testERC721 = await TestERC721Factory.deploy();
    });

    const considerationOrderTypesHash = {
      OrderComponents: [
        {
          name: "offerer",
          type: "address",
        },
        { name: "facilitator", type: "address" },
        { name: "orderType", type: "uint8" },
        { name: "startTime", type: "uint256" },
        { name: "endTime", type: "uint256" },
        { name: "salt", type: "uint256" },
        { name: "offer", type: "Asset[]" },
        { name: "consideration", type: "ReceivedAsset[]" },
        { name: "nonce", type: "uint256" },
      ],
      Asset: [
        { name: "assetType", type: "uint8" },
        { name: "token", type: "address" },
        { name: "identifierOrCriteria", type: "uint256" },
        { name: "amount", type: "uint256" },
      ],
      ReceivedAsset: [
        { name: "assetType", type: "uint8" },
        { name: "token", type: "address" },
        { name: "identifierOrCriteria", type: "uint256" },
        { name: "amount", type: "uint256" },
        { name: "account", type: "address" },
      ],
    };

    describe("A single ERC721 is to be transferred", async () => {
      describe("[Buy now] User fullfills a sell order for a single ERC721", async () => {
        it.only("ERC721 <=> ETH", async () => {
          // Seller mints nft
          const nftId = 0;
          await testERC721.mint(seller.address, nftId);
          const oneHourIntoFutureInSecs = Math.floor(
            new Date().getTime() / 1000 + 60 * 60
          );
          // Seller creates a sell order of 10 eth for nft
          const orderParameters: OrderParametersStruct = {
            offerer: seller.address,
            facilitator: constants.AddressZero,
            orderType: 0, // FULL_OPEN
            salt: 1,
            startTime: 0,
            endTime: oneHourIntoFutureInSecs,
            offer: [
              {
                assetType: 2, // ERC721
                token: testERC721.address,
                identifierOrCriteria: nftId,
                amount: 1,
              },
            ],
            consideration: [
              {
                assetType: 0, // ETH
                token: constants.AddressZero,
                identifierOrCriteria: 0, // ignored for ETH
                amount: ethers.utils.parseEther("10"),
                account: seller.address,
              },
            ],
          };

          const domainData = {
            name: "Consideration",
            version: "1",
            chainId,
            verifyingContract: marketplaceContract.address,
          };
          const orderComponent = {
            ...orderParameters,
            nonce: 0,
          };
          console.log("Ordercomponent:", orderComponent);
          const flatSig = await seller._signTypedData(
            domainData,
            considerationOrderTypesHash,
            ethers.utils.arrayify(orderComponent)
          );
          console.log("flatsig:", flatSig);
          const order = {
            parameters: orderParameters,
            signature: flatSig,
          };
          const orderHash = await marketplaceContract
            .connect(buyer.address)
            .getOrderHash(orderComponent);
          console.log("orderHash", orderHash);

          await whileImpersonating(buyer.address, provider, async () => {
            await expect(marketplaceContract.connect(buyer).fulfillOrder(order))
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
