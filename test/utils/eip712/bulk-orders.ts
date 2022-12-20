import { _TypedDataEncoder, keccak256, toUtf8Bytes } from "ethers/lib/utils";

import { Eip712MerkleTree } from "./Eip712MerkleTree";
import { DefaultGetter } from "./defaults";
import { fillArray } from "./utils";

import type { OrderComponents } from "../types";
import type { EIP712TypeDefinitions } from "./defaults";

export const bulkOrderType = {
  BulkOrder: [{ name: "tree", type: "OrderComponents[2][2][2][2][2][2][2]" }],
  OrderComponents: [
    { name: "offerer", type: "address" },
    { name: "zone", type: "address" },
    { name: "offer", type: "OfferItem[]" },
    { name: "consideration", type: "ConsiderationItem[]" },
    { name: "orderType", type: "uint8" },
    { name: "startTime", type: "uint256" },
    { name: "endTime", type: "uint256" },
    { name: "zoneHash", type: "bytes32" },
    { name: "salt", type: "uint256" },
    { name: "conduitKey", type: "bytes32" },
    { name: "counter", type: "uint256" },
  ],
  OfferItem: [
    { name: "itemType", type: "uint8" },
    { name: "token", type: "address" },
    { name: "identifierOrCriteria", type: "uint256" },
    { name: "startAmount", type: "uint256" },
    { name: "endAmount", type: "uint256" },
  ],
  ConsiderationItem: [
    { name: "itemType", type: "uint8" },
    { name: "token", type: "address" },
    { name: "identifierOrCriteria", type: "uint256" },
    { name: "startAmount", type: "uint256" },
    { name: "endAmount", type: "uint256" },
    { name: "recipient", type: "address" },
  ],
};

function getBulkOrderTypes(height: number): EIP712TypeDefinitions {
  const types = { ...bulkOrderType };
  types.BulkOrder = [
    { name: "tree", type: `OrderComponents${`[2]`.repeat(height)}` },
  ];
  return types;
}

export function getBulkOrderTreeHeight(length: number): number {
  return Math.max(Math.ceil(Math.log2(length)), 1);
}

export function getBulkOrderTree(
  orderComponents: OrderComponents[],
  startIndex = 0,
  height = getBulkOrderTreeHeight(orderComponents.length + startIndex)
) {
  const types = getBulkOrderTypes(height);
  const defaultNode = DefaultGetter.from(types, "OrderComponents");
  let elements = [...orderComponents];

  if (startIndex > 0) {
    elements = [
      ...fillArray([] as OrderComponents[], startIndex, defaultNode),
      ...orderComponents,
    ];
  }
  const tree = new Eip712MerkleTree(
    types,
    "BulkOrder",
    "OrderComponents",
    elements,
    height
  );
  return tree;
}

export function getBulkOrderTypeHash(height: number): string {
  const types = getBulkOrderTypes(height);
  const encoder = _TypedDataEncoder.from(types);
  const typeString = toUtf8Bytes(encoder._types.BulkOrder);
  return keccak256(typeString);
}

export function getBulkOrderTypeHashes(maxHeight: number): string[] {
  const typeHashes: string[] = [];
  for (let i = 0; i < maxHeight; i++) {
    typeHashes.push(getBulkOrderTypeHash(i + 1));
  }
  return typeHashes;
}
