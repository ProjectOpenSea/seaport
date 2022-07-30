// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from 'hardhat';
import { Contract, ContractFactory } from 'ethers';

async function main(): Promise<void> {
  // Hardhat always runs the compile task when running scripts through it.
  // If this runs in a standalone fashion you may want to call compile manually
  // to make sure everything is compiled
  // await run("compile");
  // We get the contract to deploy
  // const ConduitController: ContractFactory = await ethers.getContractFactory(
  //   'ConduitController',
  // );
  // const conduitControllerContract: Contract = await ConduitController.deploy();
  // await conduitControllerContract.deployed();
  // console.log('ConduitController deployed to: ', conduitControllerContract.address);

  const Seaport: ContractFactory = await ethers.getContractFactory(
    'Seaport',
  );
  const seaportContract: Contract = await Seaport.deploy('0x6C7FAE2e9cBED1987Bec2DFF08afc48A92604307', { gasLimit: 11000000 });
  await seaportContract.deployed();
  console.log('Seaport deployed to: ', seaportContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
