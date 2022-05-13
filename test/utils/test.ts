import { Logger } from "@ethersproject/logger";

import { Coder, Writer } from "@ethersproject/abi/lib/coders/abstract-coder";
import { TupleCoder } from "@ethersproject/abi/lib/coders/tuple";
import { ArrayCoder } from "@ethersproject/abi/lib/coders/array";
import { DynamicBytesCoder } from "@ethersproject/abi/lib/coders/bytes";

import { AbiCoder, FunctionFragment, Interface } from "ethers/lib/utils";
import { constants } from "ethers";

const logger = new Logger("abi");

TupleCoder.prototype.encode = function (
  writer: Writer,
  value: Array<any> | { [name: string]: any }
): number {
  return pack(writer, this.coders, value);
};

ArrayCoder.prototype.encode = function (
  writer: Writer,
  value: Array<any>
): number {
  if (!Array.isArray(value)) {
    this._throwError("expected array value", value);
  }

  let count = this.length;

  if (count === -1) {
    count = value.length;
    writer.writeValue(value.length);
  }

  logger.checkArgumentCount(
    value.length,
    count,
    "coder array" + (this.localName ? " " + this.localName : "")
  );

  const coders = [];
  for (let i = 0; i < value.length; i++) {
    const coder = this.coder;
    const newCoder = new Proxy(coder, {
      get(target, prop) {
        if (prop === "localName") return `[${i}]`;
        return (target as any)[prop];
      },
    });
    coders.push(newCoder);
  }

  return pack(writer, coders, value);
};
const namesNest: string[] = [];

const getName = () => {
  const nameParts: string[] = [];
  const nest = namesNest.filter(Boolean);
  for (let i = 0; i < nest.length; i++) {
    const name = nest[i];
    if (i > 0 && !name.includes("[")) nameParts.push(".");
    nameParts.push(name);
  }
  return nameParts.join("");
};

const getParentName = () => {
  if (namesNest.length === 0) return "";
  const lastValue = namesNest.pop();
  const name = getName();
  if (lastValue) namesNest.push(lastValue);
  return name;
};

type Offsets = {
  relative: number;
  absolute: number;
};

type ElementOffsets<HeadType = Offsets | undefined> = {
  parent: string;
  head: HeadType;
  tail: Offsets;
};

type DynamicOffsets = ElementOffsets<Offsets>;
type FixedOffsets = ElementOffsets<undefined>;

const relativeOffsets: Record<string, number> = {};
const absoluteOffsets: Record<string, DynamicOffsets | FixedOffsets> = {};

export type ParamOffsets =
  | ElementOffsets
  | Record<string, ElementOffsets>
  | ElementOffsets[];

const updateChildren = (parent: string) => {
  if (!absoluteOffsets[parent]) {
    const headOffset = relativeOffsets[`${parent}@head`];
    const tailOffset = relativeOffsets[parent];
    absoluteOffsets[parent] = {
      parent: "",
      head: {
        relative: headOffset,
        absolute: headOffset,
      },
      tail: {
        relative: tailOffset,
        absolute: tailOffset,
      },
    };
  }
  const parentOffset = (absoluteOffsets[parent] as DynamicOffsets).tail
    .absolute;
  for (const child of children[parent] || []) {
    const headOffset = relativeOffsets[`${child}@head`];
    const tailOffset = relativeOffsets[child];
    absoluteOffsets[child] = {
      parent,
      head: headOffset
        ? {
            relative: headOffset,
            absolute: headOffset + parentOffset,
          }
        : undefined,
      tail: {
        relative: tailOffset,
        absolute: tailOffset + parentOffset,
      },
    };
    updateChildren(child);
  }
};

const createStructuredOffsetsObject = (name: string, coder: Coder): any => {
  const _children = children[name];

  if (!_children) {
    return null;
  }

  const _offsets = absoluteOffsets[name];
  if (coder instanceof TupleCoder) {
    return _children.reduce(
      (obj, child, i) => ({
        ...obj,
        [child.replace(`${name}.`, "")]: createStructuredOffsetsObject(
          child,
          coder.coders[i]
        ),
      }),
      {
        ..._offsets,
      }
    );
  } else if (coder instanceof ArrayCoder) {
    //console.log(name)
    return _children.reduce(
      (obj, child, i) => ({
        ...obj,
        [i]: createStructuredOffsetsObject(child, coder.coder),
      }),
      {
        ..._offsets,
      }
    );
  } else {
    return _offsets;
  }
};

const children: Record<string, string[]> = {};
const finalObj: any = {};
const parentObj = finalObj;

const removeParentName = (parent: string, child: string) => {};

function pack(
  writer: Writer,
  coders: ReadonlyArray<Coder>,
  values: Array<any> | { [name: string]: any }
): number {
  let arrayValues: Array<any> = [];

  if (Array.isArray(values)) {
    arrayValues = values;
  } else if (values && typeof values === "object") {
    const unique: { [name: string]: boolean } = {};

    arrayValues = coders.map((coder) => {
      const name = coder.localName;
      if (!name) {
        logger.throwError(
          "cannot encode object for signature with missing names",
          Logger.errors.INVALID_ARGUMENT,
          {
            argument: "values",
            coder: coder,
            value: values,
          }
        );
      }

      if (unique[name]) {
        logger.throwError(
          "cannot encode object for signature with duplicate names",
          Logger.errors.INVALID_ARGUMENT,
          {
            argument: "values",
            coder: coder,
            value: values,
          }
        );
      }

      unique[name] = true;

      return values[name];
    });
  } else {
    logger.throwArgumentError("invalid tuple value", "tuple", values);
  }

  if (coders.length !== arrayValues.length) {
    logger.throwArgumentError("types/value length mismatch", "tuple", values);
  }

  const staticWriter = new Writer(32);
  const dynamicWriter = new Writer(32);
  const updateFuncs: Array<(baseOffset: number) => void> = [];

  const parentName = getName();
  if (parentName && !children[parentName]) children[parentName] = [];

  coders.forEach((coder, index) => {
    const value = arrayValues[index];
    namesNest.push(coder.localName);

    const thisName = getName();
    if (parentName) {
      children[parentName].push(thisName);
    }
    if (coder.dynamic) {
      // Get current dynamic offset (for the future pointer)
      const dynamicOffset = dynamicWriter.length;
      const headOffset = staticWriter.length;

      // Encode the dynamic value into the dynamicWriter
      coder.encode(dynamicWriter, value);

      // Prepare to populate the correct offset once we are done
      const updateFunc = staticWriter.writeUpdatableValue();
      updateFuncs.push((baseOffset: number) => {
        // console.log(
        //   `dyn ${thisName} : ${
        //     baseOffset + dynamicOffset
        //   } (${baseOffset} + ${dynamicOffset}) Head: ${headOffset}`
        // );
        relativeOffsets[`${thisName}@head`] = headOffset;
        relativeOffsets[thisName] = baseOffset + dynamicOffset;
        updateFunc(baseOffset + dynamicOffset);
      });
    } else {
      relativeOffsets[thisName] = staticWriter.length;
      //console.log(`${thisName}: ${staticWriter.length}`);
      coder.encode(staticWriter, value);
    }
    namesNest.pop();
  });

  // Backfill all the dynamic offsets, now that we know the static length
  updateFuncs.forEach((func) => {
    func(staticWriter.length);
  });

  let length = writer.appendWriter(staticWriter);
  length += writer.appendWriter(dynamicWriter);
  return length;
}

const val = FunctionFragment.from({
  inputs: [
    {
      components: [
        {
          internalType: "enum ConduitItemType",
          name: "itemType",
          type: "uint8",
        },
        {
          internalType: "address",
          name: "token",
          type: "address",
        },
        {
          internalType: "address",
          name: "from",
          type: "address",
        },
        {
          internalType: "address",
          name: "to",
          type: "address",
        },
        {
          internalType: "uint256",
          name: "identifier",
          type: "uint256",
        },
        {
          internalType: "uint256",
          name: "amount",
          type: "uint256",
        },
      ],
      internalType: "struct ConduitTransfer[]",
      name: "standardTransfers",
      type: "tuple[]",
    },
    {
      components: [
        {
          internalType: "address",
          name: "token",
          type: "address",
        },
        {
          internalType: "address",
          name: "from",
          type: "address",
        },
        {
          internalType: "address",
          name: "to",
          type: "address",
        },
        {
          internalType: "uint256[]",
          name: "ids",
          type: "uint256[]",
        },
        {
          internalType: "uint256[]",
          name: "amounts",
          type: "uint256[]",
        },
      ],
      internalType: "struct ConduitBatch1155Transfer[]",
      name: "batchTransfers",
      type: "tuple[]",
    },
  ],
  name: "executeWithBatch1155",
  outputs: [
    {
      internalType: "bytes4",
      name: "magicValue",
      type: "bytes4",
    },
  ],
  stateMutability: "nonpayable",
  type: "function",
});

const coder = new AbiCoder();
const values = {
  standardTransfers: [
    {
      itemType: 1, // ERC20
      token: constants.AddressZero,
      from: constants.AddressZero, // ignored for ETH
      to: constants.AddressZero,
      identifier: 0,
      amount: 0,
    }
  ],
  batchTransfers: [
    {
      token: constants.AddressZero,
      from: constants.AddressZero,
      to: constants.AddressZero,
      ids: [100, 100],
      amounts: [5, 5],
    },
  ],
};

// new Interface([]).getError("Invalid1155BatchTransferEncoding")
//getError('Invalid1155BatchTransferEncoding()').format()
const coders = val.inputs.map((i) => coder._getCoder(i));
const writer = new Writer(32);
//console.log(pack(writer, coders, values));
coders.map((coder) => coder.localName).map(updateChildren);
const output: any = coders.reduce(
  (obj, coder) => ({
    ...obj,
    [coder.localName]: createStructuredOffsetsObject(coder.localName, coder),
  }),
  {}
);

//console.log(output.batchTransfers[0].ids.head);

// console.log(coders.length);
// console.log(writer.data.slice(2).match(/.{0,64}/g));
