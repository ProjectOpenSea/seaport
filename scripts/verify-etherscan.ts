// Not currently functional. See README
import { task, types } from 'hardhat/config';
import { ethers } from 'hardhat';
import { Contract, ContractFactory } from 'ethers';

interface VerifyArgs {
  address: string;
  instance?: Contract;
  constructorArguments?: (string | number)[];
  libraries?: Record<string, string>;
}

// prettier-ignore

task('verify-etherscan', 'Verify the Solidity contracts on Etherscan')
  .addParam('contracts', 'Contract objects from the deployment', undefined, types.json)
  .setAction(async ({ contracts }: { contracts: Record<string, VerifyArgs> }, hre) => {
    console.log('beginning to verify');
    
    const conduitControllerFactory = await ethers.getContractFactory('ConduitController');
    const conduitControllerInstance = await conduitControllerFactory.attach(
      "0xBf320C8539386d7eEc20C547F4d0456354a9f2c5" // The deployed contract address
    );

    const seaportFactory = await ethers.getContractFactory('Seaport');
    const seaportInstance = await seaportFactory.attach(
      "0x8644e0f67c55a8db5d89D92371ED842fff16A5c5"
    );

    // These contracts require a fully qualified name to be passed because
    // they share bytecode with the underlying contract.
    const nameToFullyQualifiedName: Record<string, string> = {
      ConduitController: 'contracts/conduit/ConduitController.sol:ConduitController',
      Seaport: 'contracts/Seaport.sol:Seaport',
    };

    const nameToDeployedAddress: Record<string, VerifyArgs> = {
      ConduitController: {
        address: '0xBf320C8539386d7eEc20C547F4d0456354a9f2c5',
        instance: conduitControllerInstance,
      },
      Seaport: {
        address: '0x8644e0f67c55a8db5d89D92371ED842fff16A5c5',
        instance: seaportInstance,
      }
    }

    for (const [name, contract] of Object.entries(nameToDeployedAddress)) {
      console.log(`verifying ${name}...`);
      try {
        const code = await contract.instance?.provider.getCode(contract.address);
        // if (code === '0x') {
        //   console.log(`${name} contract deployment has not completed. waiting to verify...`);
        //   await contract.instance?.deployed();
        // }
        await hre.run('verify:verify', {
          ...contract,
          contract: nameToFullyQualifiedName[name],
        });
      } catch ({ message }) {
        if ((message as string).includes('Reason: Already Verified')) {
          continue;
        }
        console.error(message);
      }
    }
  });