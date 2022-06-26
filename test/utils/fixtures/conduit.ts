import { expect } from "chai";
import { constants } from "ethers";
import { getCreate2Address, keccak256 } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";

import { deployContract } from "../contracts";
import { randomHex } from "../encoding";
import { whileImpersonating } from "../impersonate";

import type {
  ConduitControllerInterface,
  ImmutableCreate2FactoryInterface,
} from "../../../typechain-types";
import type { Wallet } from "ethers";

const deployConstants = require("../../../constants/constants");

export const conduitFixture = async (
  create2Factory: ImmutableCreate2FactoryInterface,
  owner: Wallet
) => {
  let conduitController: ConduitControllerInterface;
  let conduitImplementation: any;
  if (process.env.REFERENCE) {
    conduitImplementation = await ethers.getContractFactory("ReferenceConduit");
    conduitController = await deployContract("ConduitController", owner as any);
  } else {
    conduitImplementation = await ethers.getContractFactory("Conduit");

    // Deploy conduit controller through efficient create2 factory
    const conduitControllerFactory = await ethers.getContractFactory(
      "ConduitController"
    );

    const conduitControllerAddress = await create2Factory.findCreate2Address(
      deployConstants.CONDUIT_CONTROLLER_CREATION_SALT,
      conduitControllerFactory.bytecode
    );

    let { gasLimit } = await ethers.provider.getBlock("latest");

    if ((hre as any).__SOLIDITY_COVERAGE_RUNNING) {
      gasLimit = ethers.BigNumber.from(300_000_000);
    }
    await create2Factory.safeCreate2(
      deployConstants.CONDUIT_CONTROLLER_CREATION_SALT,
      conduitControllerFactory.bytecode,
      {
        gasLimit,
      }
    );

    conduitController = (await ethers.getContractAt(
      "ConduitController",
      conduitControllerAddress,
      owner
    )) as any;
  }
  const conduitCodeHash = keccak256(conduitImplementation.bytecode);

  const conduitKeyOne = `${owner.address}000000000000000000000000`;

  await conduitController.createConduit(conduitKeyOne, owner.address);

  const { conduit: conduitOneAddress, exists } =
    await conduitController.getConduit(conduitKeyOne);

  // eslint-disable-next-line no-unused-expressions
  expect(exists).to.be.true;

  const conduitOne = conduitImplementation.attach(conduitOneAddress);

  const getTransferSender = (account: string, conduitKey: string) => {
    if (!conduitKey || conduitKey === constants.HashZero) {
      return account;
    }
    return getCreate2Address(
      conduitController.address,
      conduitKey,
      conduitCodeHash
    );
  };

  const deployNewConduit = async (owner: Wallet, conduitKey?: string) => {
    // Create a conduit key with a random salt
    const assignedConduitKey =
      conduitKey || owner.address + randomHex(12).slice(2);

    const { conduit: tempConduitAddress } = await conduitController.getConduit(
      assignedConduitKey
    );

    await whileImpersonating(owner.address, ethers.provider, async () => {
      await expect(
        conduitController
          .connect(owner)
          .createConduit(assignedConduitKey, constants.AddressZero)
      ).to.be.revertedWith("InvalidInitialOwner");

      await conduitController
        .connect(owner)
        .createConduit(assignedConduitKey, owner.address);
    });

    const tempConduit = conduitImplementation.attach(tempConduitAddress);
    return tempConduit;
  };

  return {
    conduitController,
    conduitImplementation,
    conduitCodeHash,
    conduitKeyOne,
    conduitOne,
    getTransferSender,
    deployNewConduit,
  };
};
