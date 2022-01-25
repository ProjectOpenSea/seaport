// import { Wallet } from "@ethersproject/wallet";
// import { expect } from "chai";
// import { constants } from "ethers";
// import { ethers } from "hardhat";
// // eslint-disable-next-line node/no-missing-import
// import { Consideration, TestERC721 } from "../typechain-types";
// import { OrderParametersStruct } from "../typechain-types/Consideration";

// describe("Consideration", function () {
//   const provider = ethers.getDefaultProvider();
//   let marketplaceContract: Consideration;
//   let testERC721: TestERC721;

//   it("Should deploy the contract", async function () {
//     const Consideration = await ethers.getContractFactory("Consideration");
//     const consideration = await Consideration.deploy();
//     await consideration.deployed();

//     expect(await consideration.name()).to.equal("Consideration");
//   });

//   describe("Unit tests", async () => {
//     describe(".fulfillOrder", async () => {
//       describe("invalid params");
//       describe("valid params");
//     });

//     describe(".fulfillOrderWithCriteria", async () => {
//       describe("invalid params");
//       describe("valid params");
//     });

//     describe(".cancel", async () => {
//       describe("invalid params");
//       describe("valid params");
//     });

//     // Etc...
//   });
// });
