import { JsonRpcSigner } from "@ethersproject/providers";
import * as dotenv from "dotenv";
import { Contract, ethers } from "ethers";
import { ethers as hardhatEthers } from "hardhat";

dotenv.config();

export const deployContract = async <C extends Contract>(
  name: string,
  signer: JsonRpcSigner | ethers.Wallet,
  ...args: any[]
): Promise<C> => {
  const references = new Map<string, string>([
    ["Consideration", "ReferenceConsideration"],
    ["Conduit", "ReferenceConduit"],
    ["ConduitController", "ReferenceConduitController"],
  ]);

  const nameWithReference =
    process.env.REFERENCE && references.has(name)
      ? references.get(name) || name
      : name;

  const f = await hardhatEthers.getContractFactory(nameWithReference, signer);
  const c = await f.deploy(...args);
  return c as C;
};
