import { JsonRpcProvider } from "@ethersproject/providers";
import { parseEther } from "@ethersproject/units";

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

export const stopImpersonation = async (
  address: string,
  provider: JsonRpcProvider
) => {
  await provider.send("hardhat_stopImpersonatingAccount", [address]);
};

export type AccountLike = string | { address: string };

export const whileImpersonating = async <T>(
  account: AccountLike,
  provider: JsonRpcProvider,
  fn: () => T
) => {
  const address = typeof account === "string" ? account : account.address;
  await impersonate(address, provider);
  const result = await fn();
  await stopImpersonation(address, provider);
  return result;
};
