import { expect } from "chai";
import { Wallet } from "ethers";
import hre, { ethers } from "hardhat";
import { ImmutableCreate2FactoryInterface } from "../../../typechain-types";
import { faucet } from "../impersonate";

const deployConstants = require("../../../constants/constants");

export const create2FactoryFixture = async(owner: Wallet) => {
  // Deploy keyless create2 deployer
  await faucet(
    deployConstants.KEYLESS_CREATE2_DEPLOYER_ADDRESS,
    ethers.provider
  );
  await ethers.provider.sendTransaction(
    deployConstants.KEYLESS_CREATE2_DEPLOYMENT_TRANSACTION
  );
  let deployedCode = await ethers.provider.getCode(
    deployConstants.KEYLESS_CREATE2_ADDRESS
  );
  expect(deployedCode).to.equal(deployConstants.KEYLESS_CREATE2_RUNTIME_CODE);

  let { gasLimit } = await ethers.provider.getBlock("latest");

  if ((hre as any).__SOLIDITY_COVERAGE_RUNNING) {
    gasLimit = ethers.BigNumber.from(300_000_000);
  }

  // Deploy inefficient deployer through keyless
  await owner.sendTransaction({
    to: deployConstants.KEYLESS_CREATE2_ADDRESS,
    data: deployConstants.IMMUTABLE_CREATE2_FACTORY_CREATION_CODE,
    gasLimit,
  });
  deployedCode = await ethers.provider.getCode(
    deployConstants.INEFFICIENT_IMMUTABLE_CREATE2_FACTORY_ADDRESS
  );
  expect(ethers.utils.keccak256(deployedCode)).to.equal(
    deployConstants.IMMUTABLE_CREATE2_FACTORY_RUNTIME_HASH
  );

  const inefficientFactory = await ethers.getContractAt(
    "ImmutableCreate2FactoryInterface",
    deployConstants.INEFFICIENT_IMMUTABLE_CREATE2_FACTORY_ADDRESS,
    owner
  );

  // Deploy effecient deployer through inefficient deployer
  await inefficientFactory
    .connect(owner)
    .safeCreate2(
      deployConstants.IMMUTABLE_CREATE2_FACTORY_SALT,
      deployConstants.IMMUTABLE_CREATE2_FACTORY_CREATION_CODE,
      {
        gasLimit,
      }
    );

  deployedCode = await ethers.provider.getCode(
    deployConstants.IMMUTABLE_CREATE2_FACTORY_ADDRESS
  );
  expect(ethers.utils.keccak256(deployedCode)).to.equal(
    deployConstants.IMMUTABLE_CREATE2_FACTORY_RUNTIME_HASH
  );
  const create2Factory: ImmutableCreate2FactoryInterface =
    await ethers.getContractAt(
      "ImmutableCreate2FactoryInterface",
      deployConstants.IMMUTABLE_CREATE2_FACTORY_ADDRESS,
      owner
    );

  return create2Factory;
}
