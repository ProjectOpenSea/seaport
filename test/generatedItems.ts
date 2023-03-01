import { randomInt } from "crypto";

import { randomAddress, randomBN, randomHex } from "./utils/encoding";

import type {
  AdvancedOrder,
  OrderComponents,
  OrderParameters,
} from "./utils/types";
import type { BigNumber } from "ethers";

// Fuzzing strategy
// For each type, have a limiting factor

export const fillArray = <T>(length: number, fn: (i?: number) => T): T[] =>
  new Array(length).fill(null).map((_, i) => fn(i));

export const getOfferItem = () => ({
  itemType: randomInt(5),
  token: randomAddress(),
  identifierOrCriteria: randomBN(),
  startAmount: randomBN(),
  endAmount: randomBN(),
});

export const getOffer = (length: number) => fillArray(length, getOfferItem);

export const getConsiderationItem = () => ({
  ...getOfferItem(),
  recipient: randomAddress(),
});
export const getConsideration = (length: number) =>
  fillArray(length, getConsiderationItem);

export const getOrderParameters = (
  offerLength: number,
  considerationLength: number
): OrderParameters => ({
  offerer: randomAddress(),
  zone: randomAddress(),
  offer: fillArray(offerLength, getOfferItem),
  consideration: fillArray(considerationLength, getConsiderationItem),
  orderType: randomInt(4),
  startTime: randomBN(),
  endTime: randomBN(),
  zoneHash: randomHex(32),
  salt: randomHex(32),
  conduitKey: randomHex(32),
  totalOriginalConsiderationItems: randomBN(),
});

export const getOrderComponents = (
  offerLength: number,
  considerationLength: number
): OrderComponents => {
  const { totalOriginalConsiderationItems, ...parameters } = getOrderParameters(
    offerLength,
    considerationLength
  );
  return {
    ...parameters,
    counter: totalOriginalConsiderationItems as BigNumber,
  };
};

export const getOrder = (
  offerLength: number = randomInt(3),
  considerationLength: number = randomInt(3),
  signatureLength = 65
) => ({
  parameters: getOrderParameters(offerLength, considerationLength),
  signature: getBytes(signatureLength),
});

export const getOrders = (length: number) => fillArray(length, getOrder);

export const getAdvancedOrder = (
  offerLength: number = randomInt(3),
  considerationLength: number = randomInt(3),
  signatureLength = 65,
  extraDataLength = 128
): AdvancedOrder => ({
  parameters: getOrderParameters(offerLength, considerationLength),
  numerator: randomBN(15),
  denominator: randomBN(15),
  signature: getBytes(signatureLength),
  extraData: getBytes(extraDataLength),
});

export const getAdvancedOrders = (length: number): AdvancedOrder[] =>
  fillArray(length, getAdvancedOrder);

export const getCriteriaResolver = (proofLength = randomInt(10)) => ({
  orderIndex: randomBN(),
  side: randomInt(1),
  index: randomBN(),
  identifier: randomBN(),
  criteriaProof: fillArray(proofLength, () => randomHex(32)),
});

export const getCriteriaResolvers = (numResolvers = randomInt(10)) =>
  fillArray(numResolvers, () => getCriteriaResolver());

export const getFulfillmentComponent = () => ({
  orderIndex: randomBN(),
  itemIndex: randomBN(),
});

export const getFulfillmentComponents = (length: number) =>
  fillArray(length, getFulfillmentComponent);

export const getNestedFulfillmentComponents = (length: number) =>
  fillArray(length, (i?: number) => getFulfillmentComponents(i as number));

export const getFulfillment = (
  offerLength: number,
  considerationLength: number
) => ({
  offerComponents: getFulfillmentComponents(offerLength),
  considerationComponents: getFulfillmentComponents(considerationLength),
});
export const getFulfillments = (length: number) =>
  fillArray(length, () => getFulfillment(randomInt(5), randomInt(5)));

export const getBytes = (length: number) => randomHex(length);
