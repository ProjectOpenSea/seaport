import { expect } from "chai";
import { ethers } from "hardhat";

import type { Contract } from "ethers";

describe("Test Errors and Warnings", function () {
  let testEw: Contract;

  beforeEach(async function () {
    const testEWFactory = await ethers.getContractFactory("TestEW");
    testEw = await testEWFactory.deploy();
  });

  it("Test EW", async function () {
    expect(await testEw.hasWarnings()).to.be.false;
    await testEw.addWarning("15");
    expect(await testEw.hasWarnings()).to.be.true;
  });
});
