import { randomBytes as nodeRandomBytes } from "crypto";
import { utils, BigNumber, constants, ContractTransaction } from "ethers";
import { getAddress } from "ethers/lib/utils";
import { BasicOrderParameters, BigNumberish, Order } from "./types";
const SeededRNG = require("./seeded-rng");

const GAS_REPORT_MODE = process.env.REPORT_GAS;

let randomBytes: (n: number) => string;
if (GAS_REPORT_MODE) {
  const srng = SeededRNG.create("gas-report");
  randomBytes = srng.randomBytes;
} else {
  randomBytes = (n: number) => nodeRandomBytes(n).toString("hex");
}

// const randomBytes

export const randomHex = (bytes = 32) => `0x${randomBytes(bytes)}`;

export const random128 = () => randomHex(16);

const hexRegex = /[A-Fa-fx]/g;

export const toHex = (n: BigNumberish, numBytes: number = 0) => {
  const asHexString = BigNumber.isBigNumber(n)
    ? n.toHexString().slice(2)
    : typeof n === "string"
    ? hexRegex.test(n)
      ? n.replace(/0x/, "")
      : (+n).toString(16)
    : (+n).toString(16);
  return `0x${asHexString.padStart(numBytes * 2, "0")}`;
};

export const baseFee = async (tx: ContractTransaction) => {
  const data = tx.data;
  const { gasUsed } = await tx.wait();
  const bytes = toHex(data)
    .slice(2)
    .match(/.{1,2}/g) as string[];
  const numZero = bytes.filter((b) => b === "00").length;
  return (
    gasUsed.toNumber() - (21000 + (numZero * 4 + (bytes.length - numZero) * 16))
  );
};

export const randomBN = (bytes: number = 32) => toBN(randomHex(bytes));

export const toBN = (n: BigNumberish) => BigNumber.from(toHex(n));

export const toAddress = (n: BigNumberish) => getAddress(toHex(n, 20));

export const toKey = (n: BigNumberish) => toHex(n, 32);

export const convertSignatureToEIP2098 = (signature: string) => {
  if (signature.length === 130) {
    return signature;
  }

  if (signature.length !== 132) {
    throw Error("invalid signature length (must be 64 or 65 bytes)");
  }

  return utils.splitSignature(signature).compact;
};

export const getBasicOrderParameters = (
  basicOrderRouteType: number,
  order: Order,
  fulfillerConduitKey = false,
  tips = []
): BasicOrderParameters => ({
  offerer: order.parameters.offerer,
  zone: order.parameters.zone,
  basicOrderType: order.parameters.orderType + 4 * basicOrderRouteType,
  offerToken: order.parameters.offer[0].token,
  offerIdentifier: order.parameters.offer[0].identifierOrCriteria,
  offerAmount: order.parameters.offer[0].endAmount,
  considerationToken: order.parameters.consideration[0].token,
  considerationIdentifier:
    order.parameters.consideration[0].identifierOrCriteria,
  considerationAmount: order.parameters.consideration[0].endAmount,
  startTime: order.parameters.startTime,
  endTime: order.parameters.endTime,
  zoneHash: order.parameters.zoneHash,
  salt: order.parameters.salt,
  totalOriginalAdditionalRecipients: BigNumber.from(
    order.parameters.consideration.length - 1
  ),
  signature: order.signature,
  offererConduitKey: order.parameters.conduitKey,
  fulfillerConduitKey: toKey(fulfillerConduitKey),
  additionalRecipients: [
    ...order.parameters.consideration
      .slice(1)
      .map(({ endAmount, recipient }) => ({ amount: endAmount, recipient })),
    ...tips,
  ],
});

export const getOfferOrConsiderationItem = (
  itemType: number = 0,
  token: string = constants.AddressZero,
  identifierOrCriteria: BigNumberish = 0,
  startAmount: BigNumberish = 1,
  endAmount: BigNumberish = 1,
  recipient?: string
) => ({
  ...{
    itemType,
    token,
    identifierOrCriteria: toBN(identifierOrCriteria),
    startAmount: toBN(startAmount),
    endAmount: toBN(endAmount),
  },
  ...(recipient ? { recipient } : {}),
});

export const getItemETH = (
  startAmount: BigNumberish = 1,
  endAmount: BigNumberish = 1,
  recipient?: string
) =>
  getOfferOrConsiderationItem(
    0,
    constants.AddressZero,
    0,
    toBN(startAmount),
    toBN(endAmount),
    recipient
  );

export const getItem721 = (
  token: string,
  identifierOrCriteria: BigNumberish,
  startAmount: number = 1,
  endAmount: number = 1,
  recipient?: string
) =>
  getOfferOrConsiderationItem(
    2,
    token,
    identifierOrCriteria,
    startAmount,
    endAmount,
    recipient
  );
