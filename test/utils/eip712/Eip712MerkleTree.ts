import { _TypedDataEncoder as TypedDataEncoder } from "@ethersproject/hash";
import {
  defaultAbiCoder,
  hexConcat,
  keccak256,
  toUtf8Bytes,
} from "ethers/lib/utils";
import { MerkleTree } from "merkletreejs";

import { DefaultGetter } from "./defaults";
import {
  bufferKeccak,
  bufferToHex,
  chunk,
  fillArray,
  getRoot,
  hexToBuffer,
} from "./utils";

import type { OrderComponents } from "../types";
import type { EIP712TypeDefinitions } from "./defaults";

type A2<T> = [T, T];
type BulkOrderElements = A2<A2<A2<A2<A2<A2<OrderComponents>>>>>>;

const getTree = (leaves: string[], defaultLeafHash: string) =>
  new MerkleTree(leaves.map(hexToBuffer), bufferKeccak, {
    complete: true,
    sort: false,
    hashLeaves: false,
    fillDefaultHash: hexToBuffer(defaultLeafHash),
  });

const encodeProof = (
  key: number,
  proof: string[],
  signature = `0x${"ff".repeat(64)}`
) => {
  return hexConcat([
    signature,
    `0x${key.toString(16).padStart(2, "0")}`,
    defaultAbiCoder.encode(["uint256[7]"], [proof]),
    // signature,
  ]);
};

export class Eip712MerkleTree<BaseType extends Record<string, any> = any> {
  tree: MerkleTree;
  private leafHasher: (value: any) => string;
  defaultNode: BaseType;
  defaultLeaf: string;
  encoder: TypedDataEncoder;

  get completedSize() {
    return Math.pow(2, this.depth);
  }

  /** Returns the array of elements in the tree, padded to the complete size with empty items. */
  getCompleteElements() {
    const elements = this.elements;
    return fillArray([...elements], this.completedSize, this.defaultNode);
  }

  /** Returns the array of leaf nodes in the tree, padded to the complete size with default hashes. */
  getCompleteLeaves() {
    const leaves = this.elements.map(this.leafHasher);
    return fillArray([...leaves], this.completedSize, this.defaultLeaf);
  }

  get root() {
    return this.tree.getHexRoot();
  }

  getProof(i: number) {
    const leaves = this.getCompleteLeaves();
    const leaf = leaves[i];
    const proof = this.tree.getHexProof(leaf, i);
    const root = this.tree.getHexRoot();
    return { leaf, proof, root };
  }

  getEncodedProofAndSignature(i: number, signature: string) {
    const { proof } = this.getProof(i);
    return encodeProof(i, proof, signature);
  }

  getDataToSign(): BulkOrderElements {
    const elements = this.getCompleteElements();
    let layer: any = chunk(elements, 2);
    while (layer.length > 2) {
      layer = chunk(layer, 2);
    }
    return layer;
  }

  add(element: BaseType) {
    this.elements.push(element);
  }

  getBulkOrderHash() {
    const structHash = this.encoder.hashStruct("BulkOrder", {
      tree: this.getDataToSign(),
    });
    const leaves = this.getCompleteLeaves().map(hexToBuffer);
    const rootHash = bufferToHex(getRoot(leaves, false));
    const typeHash = keccak256(toUtf8Bytes(this.encoder._types.BulkOrder));
    const bulkOrderHash = keccak256(hexConcat([typeHash, rootHash]));
    if (bulkOrderHash !== structHash) {
      throw Error("Bad hash");
    }
    return structHash;
  }

  constructor(
    public types: EIP712TypeDefinitions,
    public rootType: string,
    public leafType: string,
    public elements: BaseType[],
    public depth: number
  ) {
    const encoder = TypedDataEncoder.from(types);
    this.encoder = encoder;
    this.leafHasher = (leaf: BaseType) => encoder.hashStruct(leafType, leaf);
    this.defaultNode = DefaultGetter.from(types, leafType);
    this.defaultLeaf = this.leafHasher(this.defaultNode);
    this.tree = getTree(this.getCompleteLeaves(), this.defaultLeaf);
  }
}
