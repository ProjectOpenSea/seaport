import { parseEther } from "@ethersproject/units";
import { ethers } from "hardhat";

import { randomHex } from "./encoding";

import type { JsonRpcProvider } from "@ethersproject/providers";

const TEN_THOUSAND_ETH = parseEther("10000").toHexString().replace("0x0", "0x");

export const faucet = async (address: string, provider: JsonRpcProvider) => {
  await provider.send("hardhat_setBalance", [address, TEN_THOUSAND_ETH]);
};

export const getWalletWithEther = async () => {
  const wallet = new ethers.Wallet(randomHex(32), ethers.provider);
  await faucet(wallet.address, ethers.provider);
  return wallet;
};
