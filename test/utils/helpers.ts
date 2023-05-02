import { ethers } from "ethers";

import { randomBN } from "./encoding";

import type {
  AdvancedOrder,
  CriteriaResolver,
  Fulfillment,
  Order,
} from "./types";

export const VERSION = `1.5${process.env.REFERENCE ? "-reference" : ""}`;

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
