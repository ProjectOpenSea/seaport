import { JsonRpcProvider } from "@ethersproject/providers";
import { parseEther } from "@ethersproject/units";
import { ethers } from "hardhat";
import { randomHex } from "./encoding";

const TEN_THOUSAND_ETH = parseEther("10000").toHexString().replace("0x0", "0x");

export const impersonate = async (
  address: string,
  provider: JsonRpcProvider
) => {
  await provider.send("hardhat_impersonateAccount", [address]);
  await faucet(address, provider);
};

export const faucet = async (address: string, provider: JsonRpcProvider) => {
  await provider.send("hardhat_setBalance", [address, TEN_THOUSAND_ETH]);
};

export const getWalletWithEther = async () => {
  const wallet = new ethers.Wallet(randomHex(32), ethers.provider);
  await faucet(wallet.address, ethers.provider);
  return wallet;
};

export const stopImpersonation = async (
  address: string,
  provider: JsonRpcProvider
) => {
  await provider.send("hardhat_stopImpersonatingAccount", [address]);
};

export const whileImpersonating = async <T>(
  address: string,
  provider: JsonRpcProvider,
  fn: () => T
) => {
  await impersonate(address, provider);
  const result = await fn();
  await stopImpersonation(address, provider);
  return result;
};
