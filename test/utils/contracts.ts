import { ethers } from "hardhat";
import { Contract } from "ethers";
import { JsonRpcSigner } from "@ethersproject/providers";

export async function deployContract<C extends Contract>(
  name: string,
  signer: JsonRpcSigner,
  ...args: any[]
): Promise<C> {
  const f = await ethers.getContractFactory(name, signer);
  const c = await f.deploy(...args);
  return c as C;
}
