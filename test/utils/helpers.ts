import { ethers } from "ethers";

import { randomBN } from "./encoding";

import type {
  AdvancedOrder,
  CriteriaResolver,
  Fulfillment,
  Order,
} from "./types";

export const VERSION = `1.4${process.env.REFERENCE ? "-reference" : ""}`;

export const minRandom = (min: ethers.BigNumberish) => randomBN(10).add(min);

export const getCustomRevertSelector = (customErrorString: string) =>
  ethers.utils
    .keccak256(ethers.utils.toUtf8Bytes(customErrorString))
    .slice(0, 10);

export const simulateMatchOrders = async (
  marketplaceContract: ethers.Contract,
  orders: Order[],
  fulfillments: Fulfillment[],
  caller: ethers.Wallet,
  value: ethers.BigNumberish
) =>
  marketplaceContract
    .connect(caller)
    .callStatic.matchOrders(orders, fulfillments, {
      value,
    });

export const simulateAdvancedMatchOrders = async (
  marketplaceContract: ethers.Contract,
  orders: AdvancedOrder[],
  criteriaResolvers: CriteriaResolver[],
  fulfillments: Fulfillment[],
  caller: ethers.Wallet,
  value: ethers.BigNumberish,
  recipient: string = ethers.constants.AddressZero
) =>
  marketplaceContract
    .connect(caller)
    .callStatic.matchAdvancedOrders(
      orders,
      criteriaResolvers,
      fulfillments,
      recipient,
      {
        value,
      }
    );

/**
 * Change chainId in-flight to test branch coverage for _deriveDomainSeparator()
 * (hacky way, until https://github.com/NomicFoundation/hardhat/issues/3074 is added)
 */
export const changeChainId = (hre: any) => {
  const recurse = (obj: any) => {
    for (const [key, value] of Object.entries(obj ?? {})) {
      if (key === "transactions") continue;
      if (key === "chainId") {
        obj[key] = typeof value === "bigint" ? BigInt(1) : 1;
      } else if (typeof value === "object") {
        recurse(obj[key]);
      }
    }
  };
  const hreProvider = hre.network.provider;
  recurse(
    hreProvider._wrapped._wrapped._wrapped?._node?._vm ??
      // When running coverage, there was an additional layer of wrapping
      hreProvider._wrapped._wrapped._wrapped._wrapped._node._vm
  );
};
