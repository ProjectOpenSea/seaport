import { expect } from "chai";
import { BigNumber,  } from "ethers";
import { getScuffedContract } from "scuffed-abi";

import {
  fillArray,
  getAdvancedOrder,
  getAdvancedOrders,
  getBytes,
  getConsideration,
  // getConsiderationItem,
  getCriteriaResolver,
  getCriteriaResolvers,
  getFulfillment,
  // getFulfillmentComponent,
  getFulfillmentComponents,
  getFulfillments,
  getNestedFulfillmentComponents,
  getOffer,
  // getOfferItem,
  getOrder,
  getOrderComponents,
  getOrderParameters,
  getOrders,
} from "./generatedItems";
import { deployContract } from "./utils/contracts";
import { toBN, toHex } from "./utils/encoding";

import type { TestDecoder } from "../typechain-types";
import type {
  AdvancedOrder,
  Order,
  OrderComponents,
  OrderParameters,
} from "./utils/types";
import type { ScuffedContract } from "scuffed-abi";
import type { ScuffedWriter } from "scuffed-abi/dist/ethers-overrides";
import type {
  ReplaceableOffsets,
  ScuffedParameter,
} from "scuffed-abi/dist/types";

type ScuffedArrayParameter = Extract<
  ScuffedParameter,
  { length: ReplaceableOffsets }
>;

type ScuffedOrderParameters = {
  offer: ScuffedArrayParameter;
  consideration: ScuffedArrayParameter;
} & Extract<ScuffedParameter, { head: ReplaceableOffsets }>;

type ScuffedOrder = {
  parameters: ScuffedOrderParameters;
  signature: ScuffedArrayParameter;
};
type ScuffedAdvancedOrder = {
  parameters: ScuffedOrderParameters;
  signature: ScuffedArrayParameter;
  extraData: ScuffedArrayParameter;
};

type BaseScuffedCall<
  FunctionName extends keyof TestDecoder["functions"],
  ParameterTypes extends ScuffedParameter
> = ParameterTypes & {
  call: () => ReturnType<TestDecoder["functions"][FunctionName]>;
  encodeArgs: () => string;
  encode: () => string;
  writer: ScuffedWriter;
};

const orderToAdvancedOrder = (order: Order): AdvancedOrder => ({
  ...order,
  numerator: toBN(1),
  denominator: toBN(1),
  extraData: "0x",
});

function addDirtyBitsToAllOffsetsAndLengths(
  someType: any,
  writer: ScuffedWriter,
  skip?: boolean
) {
  if (typeof someType !== "object") return;
  Object.entries(someType).forEach(([key, value]: [string, any]) => {
    if (key === "tail" || value === undefined || value === null) return;
    if (!skip && ["head", "length"].includes(key) && value.read !== undefined) {
      return addDirtyBits(value as ReplaceableOffsets, writer);
    }
    addDirtyBitsToAllOffsetsAndLengths(value, writer);
  });
}

const orderComponentsToOrderParameters = ({
  counter,
  ..._parameters
}: OrderComponents): OrderParameters => ({
  ..._parameters,
  totalOriginalConsiderationItems: toBN(_parameters.consideration.length),
});

function cleanupResultForTest(result: any): any {
  if (!(result instanceof Object) || BigNumber.isBigNumber(result))
    return result;
  const originalKeys = Object.keys(result);
  const isArray = originalKeys.every((key) => key.match(/^\d+$/g));
  if (isArray) {
    return originalKeys.map((key) => cleanupResultForTest(result[key]));
  }
  return originalKeys
    .filter((key) => !key.match(/^\d+$/g))
    .reduce(
      (obj, key) => ({
        ...obj,
        [key]: cleanupResultForTest(result[key]),
      }),
      {}
    );
}
const dirtyBits = BigNumber.from(1).shl(32);

function addDirtyBits(param: ReplaceableOffsets, writer?: ScuffedWriter) {
  const oldValue = toBN(param.read?.() ?? writer?.readWord(param.absolute));
  const write =
    param.replace ??
    ((value: BigNumber) => writer?.replaceWord(param.absolute, value));

  write(toBN(oldValue).or(dirtyBits));
}

function addDirtyBitsToOrderParametersOffsetsAndLengths(
  parameters: ScuffedOrderParameters
) {
  addDirtyBits(parameters.offer.length);
  addDirtyBits(parameters.consideration.length);
  addDirtyBits(parameters.offer.head);
  addDirtyBits(parameters.consideration.head);
}

function addDirtyBitsToOrderOffsetsAndLengths({
  parameters,
  signature,
}: ScuffedOrder) {
  addDirtyBitsToOrderParametersOffsetsAndLengths(parameters);
  addDirtyBits(signature.head);
  addDirtyBits(signature.length);
}

function addDirtyBitsToAdvancedOrderOffsetsAndLengths({
  parameters,
  signature,
  extraData,
}: ScuffedAdvancedOrder) {
  addDirtyBitsToOrderParametersOffsetsAndLengths(parameters);
  addDirtyBits(signature.head);
  addDirtyBits(signature.length);
  addDirtyBits(extraData.head);
  addDirtyBits(extraData.length);
}

describe("ConsiderationDecoder", () => {
  let decoder: TestDecoder;
  let scuffedDecoder: ScuffedContract<TestDecoder>;

  before(async () => {
    decoder = await deployContract("TestDecoder");
    scuffedDecoder = getScuffedContract(decoder);
  });

  describe("decodeBytes", () => {
    it("Returns provided bytes", async () => {
      const data = getBytes(100);
      const result = await decoder.decodeBytes(data);
      expect(result).to.deep.equal(data);
    });

    it("Top-level validation by solidity reverts if length exceeds calldatasize", async () => {
      const data = getBytes(100);
      const scuffedCall = scuffedDecoder.decodeBytes(data);
      (scuffedCall as ScuffedArrayParameter).length.replace(200);
      await expect(scuffedCall.call()).to.be.reverted;
    });
  });

  describe("decodeOffer", () => {
    it("decodeOffer", async () => {
      const data = getOffer(1);
      const result = await decoder.decodeOffer(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("Top-level validation by solidity reverts if length exceeds calldatasize", async () => {
      const data = getOffer(1);
      const scuffedCall = scuffedDecoder.decodeOffer(data);
      (scuffedCall as ScuffedArrayParameter).length.replace(10);
      await expect(scuffedCall.call()).to.be.reverted;
    });
  });

  describe("decodeConsideration", () => {
    it("decodeConsideration", async () => {
      const data = getConsideration(1);
      const result = await decoder.decodeConsideration(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("Top-level validation by solidity reverts if calldatasize not padded to words", async () => {
      const data = getConsideration(1);
      const scuffedCall = scuffedDecoder.decodeConsideration(data);
      (scuffedCall as ScuffedArrayParameter).length.replace(10);
      await expect(scuffedCall.call()).to.be.reverted;
    });
  });

  describe("decodeOrderParameters", () => {
    it("decodeOrderParameters", async () => {
      const data = getOrderParameters(1, 1);
      const result = await decoder.decodeOrderParameters(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("Top-level validation by solidity reverts if length exceeds calldatasize", async () => {
      const data = getOrderParameters(0, 0);
      const scuffedCall = scuffedDecoder.decodeOrderParameters(
        data
      ) as any as BaseScuffedCall<
        "decodeOrderParameters",
        ScuffedOrderParameters
      >;
      // Remove length of offer and consideration, should still decode with empty arrays
      scuffedCall.writer.spliceData(scuffedCall.writer._dataLength - 64, 64);
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal(
        data
      );
      // Remove 1 additional byte - now it has less than min data for OrderParameters
      scuffedCall.writer.spliceData(scuffedCall.writer._dataLength - 1, 1);
      await expect(scuffedCall.call()).to.be.reverted;
    });

    it("For embedded types, copies even if length exceeds calldatasize", async () => {
      const data = getOrderParameters(1, 0);
      const scuffedCall = scuffedDecoder.decodeOrderParameters(
        data
      ) as any as BaseScuffedCall<
        "decodeOrderParameters",
        ScuffedOrderParameters
      >;
      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      const emptyConsideration = fillArray(10, () => ({
        itemType: 0,
        token: toHex(0, 20),
        identifierOrCriteria: toBN(0),
        startAmount: toBN(0),
        endAmount: toBN(0),
        recipient: toHex(0, 20),
      }));
      (scuffedCall.consideration as ScuffedArrayParameter).length.replace(10);
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal({
        ...data,
        consideration: emptyConsideration,
      });
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getOrderParameters(1, 1);
      const scuffedCall = scuffedDecoder.decodeOrderParameters(
        data
      ) as any as BaseScuffedCall<
        "decodeOrderParameters",
        ScuffedOrderParameters
      >;
      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal(
        data
      );
      // Does not ignore dirty bits in the last 4 bytes
      scuffedCall.consideration.head.replace(
        toBN(scuffedCall.consideration.head.read()).or(dirtyBits.shr(2))
      );
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal({
        ...data,
        consideration: [],
      });
    });
  });

  describe("decodeOrder", () => {
    it("decodeOrder", async () => {
      const data = getOrder();
      const result = await decoder.decodeOrder(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getOrder(1, 1);
      const scuffedCall = scuffedDecoder.decodeOrder(
        data
      ) as any as BaseScuffedCall<"decodeOrder", ScuffedOrder>;

      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal(
        data
      );

      scuffedCall.parameters.consideration.head.replace(
        toBN(scuffedCall.parameters.consideration.head.read()).or(
          dirtyBits.shr(2)
        )
      );
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal({
        ...data,
        parameters: {
          ...data.parameters,
          consideration: [],
        },
      });
    });
  });

  describe("decodeAdvancedOrder", () => {
    it("decodeAdvancedOrder", async () => {
      const data = getAdvancedOrder();
      const result = await decoder.decodeAdvancedOrder(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getAdvancedOrder(1, 1);
      const scuffedCall = scuffedDecoder.decodeAdvancedOrder(
        data
      ) as any as BaseScuffedCall<"decodeAdvancedOrder", ScuffedAdvancedOrder>;

      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      const dirtyBits = BigNumber.from(1).shl(32);

      addDirtyBitsToOrderParametersOffsetsAndLengths(scuffedCall.parameters);
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal(
        data
      );
      // Does not ignore dirty bits in the last 4 bytes
      scuffedCall.parameters.consideration.head.replace(
        toBN(scuffedCall.parameters.consideration.head.read()).or(
          dirtyBits.shr(2)
        )
      );
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal({
        ...data,
        parameters: {
          ...data.parameters,
          consideration: [],
        },
      });
    });
  });

  describe("decodeOrderAsAdvancedOrder", () => {
    it("decodeOrderAsAdvancedOrder", async () => {
      const data = getOrder();
      const result = await decoder.decodeOrderAsAdvancedOrder(data);
      expect(cleanupResultForTest(result)).to.deep.equal(
        orderToAdvancedOrder(data)
      );
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getOrder(1, 1);
      const scuffedCall = scuffedDecoder.decodeOrderAsAdvancedOrder(
        data
      ) as any as BaseScuffedCall<"decodeAdvancedOrder", ScuffedOrder>;

      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal(
        orderToAdvancedOrder(data)
      );
      // Does not ignore dirty bits in the last 4 bytes
      scuffedCall.parameters.consideration.head.replace(
        toBN(scuffedCall.parameters.consideration.head.read()).or(
          dirtyBits.shr(2)
        )
      );
      const advancedOrder = orderToAdvancedOrder(data);
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal({
        ...advancedOrder,
        parameters: {
          ...advancedOrder.parameters,
          consideration: [],
        },
      });
    });
  });

  describe("decodeOrdersAsAdvancedOrders", () => {
    it("decodeOrdersAsAdvancedOrders", async () => {
      const data = getOrders(3);
      const result = await decoder.decodeOrdersAsAdvancedOrders(data);
      expect(cleanupResultForTest(result)).to.deep.equal(
        data.map(orderToAdvancedOrder)
      );
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getOrders(10);
      const scuffedCall = scuffedDecoder.decodeOrdersAsAdvancedOrders(
        data
      ) as any as BaseScuffedCall<
        "decodeOrdersAsAdvancedOrders",
        ScuffedOrder[] & ScuffedArrayParameter
      >;

      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal(
        data.map(orderToAdvancedOrder)
      );
    });
  });

  describe("decodeCriteriaResolver", () => {
    it("decodeCriteriaResolver", async () => {
      const data = getCriteriaResolver(1);
      const result = await decoder.decodeCriteriaResolver(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });
  });

  describe("decodeCriteriaResolvers", () => {
    it("decodeCriteriaResolvers", async () => {
      const data = getCriteriaResolvers(1);
      const result = await decoder.decodeCriteriaResolvers(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });
    it("Top-level validation by solidity reverts if length exceeds calldatasize", async () => {
      const data = getCriteriaResolvers(1);
      const scuffedCall = scuffedDecoder.decodeCriteriaResolvers(
        data
      ) as any as BaseScuffedCall<
        "decodeCriteriaResolvers",
        ScuffedArrayParameter
      >;
      addDirtyBits(scuffedCall.length);
      await expect(scuffedCall.call()).to.be.reverted;
    });
  });

  describe("decodeOrders", () => {
    it("decodeOrders", async () => {
      const data = getOrders(5);
      const result = await decoder.decodeOrders(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getOrders(5);
      const scuffedCall = scuffedDecoder.decodeOrders(
        data
      ) as any as BaseScuffedCall<
        "decodeOrders",
        ScuffedOrder[] & ScuffedArrayParameter
      >;

      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      const result = await decoder.decodeOrders(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });
  });

  describe("decodeFulfillmentComponents", () => {
    it("decodeFulfillmentComponents", async () => {
      const data = getFulfillmentComponents(1);
      const result = await decoder.decodeFulfillmentComponents(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getFulfillmentComponents(5);
      const scuffedCall = scuffedDecoder.decodeFulfillmentComponents(
        data
      ) as any as BaseScuffedCall<
        "decodeFulfillmentComponents",
        ScuffedArrayParameter
      >;

      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      const result = await decoder.decodeFulfillmentComponents(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });
  });

  describe("decodeNestedFulfillmentComponents", () => {
    it("decodeNestedFulfillmentComponents", async () => {
      const data = getNestedFulfillmentComponents(1);
      const result = await decoder.decodeNestedFulfillmentComponents(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getNestedFulfillmentComponents(5);
      const scuffedCall = scuffedDecoder.decodeNestedFulfillmentComponents(
        data
      ) as any as BaseScuffedCall<
        "decodeNestedFulfillmentComponents",
        ScuffedArrayParameter
      >;

      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      const result = await decoder.decodeNestedFulfillmentComponents(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });
  });

  describe("decodeAdvancedOrders", () => {
    it("decodeAdvancedOrders", async () => {
      const data = getAdvancedOrders(1);
      const result = await decoder.decodeAdvancedOrders(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getFulfillment(1, 1);
      const scuffedCall = scuffedDecoder.decodeFulfillment(data) as any as {
        call: () => ReturnType<TestDecoder["functions"]["decodeFulfillment"]>;
        offerComponents: ScuffedArrayParameter;
        considerationComponents: ScuffedArrayParameter;
        writer: ScuffedWriter;
      };

      addDirtyBits(scuffedCall.offerComponents.length);
      addDirtyBits(scuffedCall.considerationComponents.length);
      // Add dirty bits to offerComponents head, not added by scuffed-abi
      // for unknown reason atm.
      scuffedCall.writer.replaceWord(
        32,
        toBN(scuffedCall.writer.readWord(32)).or(dirtyBits)
      );
      addDirtyBits(scuffedCall.considerationComponents.head);
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal(
        data
      );
    });
  });

  describe("decodeFulfillment", () => {
    it("decodeFulfillment", async () => {
      const data = getFulfillment(1, 1);
      const result = await decoder.decodeFulfillment(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getFulfillment(1, 1);
      const scuffedCall = scuffedDecoder.decodeFulfillment(
        data
      ) as any as BaseScuffedCall<
        "decodeFulfillment",
        {
          offerComponents: ScuffedArrayParameter;
          considerationComponents: ScuffedArrayParameter;
        }
      >;
      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal(
        data
      );

      // Add dirty bits to offerComponents head, not added by scuffed-abi
      // for unknown reason atm.
      scuffedCall.writer.replaceWord(
        32,
        toBN(scuffedCall.writer.readWord(32)).or(dirtyBits)
      );
      addDirtyBits(scuffedCall.considerationComponents.head);

      expect(cleanupResultForTest(await scuffedCall.call())).to.deep.equal(
        data
      );
    });
  });

  describe("decodeFulfillments", () => {
    it("decodeFulfillments", async () => {
      const data = getFulfillments(1);
      const result = await decoder.decodeFulfillments(data);
      expect(cleanupResultForTest(result)).to.deep.equal(data);
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getFulfillments(10);
      const scuffedCall = scuffedDecoder.decodeFulfillments(
        data
      ) as any as BaseScuffedCall<
        "decodeFulfillments",
        {
          offerComponents: ScuffedArrayParameter;
          considerationComponents: ScuffedArrayParameter;
        }[] &
          ScuffedArrayParameter
      >;
      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer);
    });
  });

  describe("decodeOrderComponentsAsOrderParameters", () => {
    it("decodeOrderComponentsAsOrderParameters", async () => {
      const data = getOrderComponents(1, 1);
      const result = await decoder.decodeOrderComponentsAsOrderParameters(data);
      expect(cleanupResultForTest(result)).to.deep.equal(
        orderComponentsToOrderParameters(data)
      );
    });

    it("For embedded types, ignores length/offset dirty bits before last 4 bytes", async () => {
      const data = getOrderComponents(5, 5);
      const scuffedCall = scuffedDecoder.decodeOrderComponentsAsOrderParameters(
        data
      ) as any as BaseScuffedCall<
        "decodeOrderComponentsAsOrderParameters",
        ScuffedOrderParameters
      >;

      addDirtyBitsToAllOffsetsAndLengths(scuffedCall, scuffedCall.writer, true);
      const result = await decoder.decodeOrderComponentsAsOrderParameters(data);
      expect(cleanupResultForTest(result)).to.deep.equal(
        orderComponentsToOrderParameters(data)
      );
    });
  });
});
