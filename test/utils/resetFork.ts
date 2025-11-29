import { network } from "hardhat";

/**
 * Resets the Hardhat network state to prevent nonce reuse errors
 * Call this at the start of test suites that use manually created wallets
 */
export async function resetFork(): Promise<void> {
  await network.provider.request({
    method: "hardhat_reset",
    params: [],
  });
}

