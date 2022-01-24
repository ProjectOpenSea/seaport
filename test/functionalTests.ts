import { Wallet } from "@ethersproject/wallet";
import { expect } from "chai";
import { constants } from "ethers";
import { ethers } from "hardhat";
import { Consideration, TestERC721 } from "../typechain-types";
import { OrderParametersStruct } from "../typechain-types/Consideration";

describe("Consideration functional tests", function () {
  const provider = ethers.getDefaultProvider();
  let marketplaceContract: Consideration;
  let testERC721: TestERC721;

  // Buy now or accept offer for a single ERC721 or ERC1155 in exchange for
  // ETH, WETH or ERC20
  describe("Basic buy now or accept offer flows", async () => {
    let owner: Wallet;
    let seller: Wallet;
    let buyer: Wallet;

    beforeEach(async () => {
      owner = ethers.Wallet.createRandom().connect(provider);
      seller = ethers.Wallet.createRandom().connect(provider);
      buyer = ethers.Wallet.createRandom().connect(provider);
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

    describe("A single ERC721 is to be transferred", async () => {
      describe("[Buy now] User fullfills a sell order for a single ERC721", async () => {
        describe("ERC721 <=> ETH", async () => {
          // Seller mints nft
          const nftId = 0;
          await testERC721.mint(seller.address, nftId);
          // Seller creates a sell order of 10 eth for nft
          const orderParameters: OrderParametersStruct = {
            offerer: seller.address,
            facilitator: "0x",
            orderType: 0, // FULL_OPEN
            salt: 1,
            startTime: 0,
            endTime: 0, // TODO
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
                identifierOrCriteria: 0, // 'what is this?',
                amount: 10, // TODO: is it in wei?
                account: seller.address,
              },
            ],
          };
          const order = {
            parameters: orderParameters,
            signature: "",
          };
          // TODO: buyer gets eth
          // Buyer requests to purchase the nft
          marketplaceContract.connect(buyer.address).fulfillOrder(order);
        });
        describe("ERC721 <=> WETH", async () => {});
        describe("ERC721 <=> ERC20", async () => {});
      });
      describe("[Accept offer] User accepts a buy offer on a single ERC721", async () => {
        // Note: ETH is not a possible case
        describe("ERC721 <=> WETH", async () => {});
        describe("ERC721 <=> ERC20", async () => {});
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
