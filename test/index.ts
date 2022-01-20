import { expect } from "chai";
import { ethers } from "hardhat";

describe("Consideration", function () {
  it("Should deploy the contract", async function () {
    const Consideration = await ethers.getContractFactory("Consideration");
    const consideration = await Consideration.deploy();
    await consideration.deployed();

    expect(await consideration.name()).to.equal("Consideration");
  });
});
