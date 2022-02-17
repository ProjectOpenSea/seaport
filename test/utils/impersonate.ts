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
