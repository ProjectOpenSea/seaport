import { BigNumber, constants } from "ethers";
import { getAddress, parseEther } from "ethers/lib/utils";
import { BasicOrderParameters, BigNumberish, Order } from "./types";

export const randomHex = () =>
  `0x${[...Array(64)]
    .map(() => Math.floor(Math.random() * 16).toString(16))
    .join("")}`;

export const randomLarge = () =>
  `0x${[...Array(60)]
    .map(() => Math.floor(Math.random() * 16).toString(16))
    .join("")}`;

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

export const toBN = (n: BigNumberish) => BigNumber.from(toHex(n));

export const toAddress = (n: BigNumberish) => getAddress(toHex(n, 20));

export const convertSignatureToEIP2098 = (signature: string) => {
  if (signature.length === 130) {
    return signature;
  }

  if (signature.length !== 132) {
    throw Error("invalid signature length (must be 64 or 65 bytes)");
  }

  signature = signature.toLowerCase();

  // flip signature if malleable
  const secp256k1n = BigNumber.from(
    "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141"
  );
  const maxS = BigNumber.from(
    "0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0"
  );
  let s = BigNumber.from("0x" + signature.slice(66, 130));
  let v = signature.slice(130);

  if (v !== "1b" && v !== "1c") {
    throw Error("invalid v value (must be 27 or 28)");
  }

  if (s.gt(maxS)) {
    s = secp256k1n.sub(s);
    v = v === "1c" ? "1b" : "1c";
  }

  const nonMalleableSig = `${signature.slice(0, 66)}${s
    .toHexString()
    .slice(2)}${v}`;

  // Convert the signature by adding a higher bit
  return nonMalleableSig.slice(-2) === "1b"
    ? nonMalleableSig.slice(0, -2)
    : `${nonMalleableSig.slice(0, 66)}${(
        parseInt("0x" + nonMalleableSig[66]) + 8
      ).toString(16)}${nonMalleableSig.slice(67, -2)}`;
};

export const getBasicOrderParameters = (
  basicOrderRouteType: number,
  order: Order,
  fulfillerConduit = false,
  tips = [],
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
  offererConduit: order.parameters.conduit,
  fulfillerConduit: toAddress(fulfillerConduit),
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
  startAmount: number = 1,
  endAmount: number = 1,
  recipient?: string
) =>
  getOfferOrConsiderationItem(
    0,
    constants.AddressZero,
    0,
    parseEther(startAmount.toString()),
    parseEther(endAmount.toString()),
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
