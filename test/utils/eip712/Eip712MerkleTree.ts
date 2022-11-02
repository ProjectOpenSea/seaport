import { _TypedDataEncoder as TypedDataEncoder } from "@ethersproject/hash";
import { MerkleTree } from "merkletreejs";

import { DefaultGetter } from "./defaults";
import {
  bufferKeccak,
  bufferToHex,
  fillArray,
  getRoot,
  hexToBuffer,
} from "./utils";

import type { EIP712TypeDefinitions } from "./defaults";

const getTree = (leaves: string[], defaultLeafHash: string) =>
  new MerkleTree(leaves.map(hexToBuffer), bufferKeccak, {
    complete: true,
    sort: false,
    hashLeaves: false,
    fillDefaultHash: hexToBuffer(defaultLeafHash),
  });

export class Eip712MerkleTree<BaseType extends Record<string, any> = any> {
  tree: MerkleTree;
  private rootEncoder: (value: any) => string;
  private leafHasher: (value: any) => string;
  private _leaves: string[];
  defaultNode: any;
  defaultLeaf: string;
  encoder: TypedDataEncoder;

  leavesWithDefaults() {
    const completedSize = Math.pow(
      2,
      Math.ceil(Math.log2(this._leaves.length))
    );
    return fillArray([...this._leaves], completedSize, this.defaultLeaf);
  }

  computeRoot() {
    return bufferToHex(
      getRoot(this.leavesWithDefaults().map(hexToBuffer), false)
    );
  }

  get root() {
    return this.tree.getHexRoot();
  }

  getLeaf(i: number) {
    return this._leaves[i];
  }

  getProof(i: number) {
    const leaf = this._leaves[i];
    const proof = this.tree.getHexProof(this._leaves[i], i);
    return { leaf, proof };
  }

  constructor(
    protected types: EIP712TypeDefinitions,
    rootType: string,
    leafType: string,
    protected elements: BaseType[]
  ) {
    const encoder = TypedDataEncoder.from(types);
    this.encoder = encoder;
    this.leafHasher = (leaf: BaseType) => encoder.hashStruct(leafType, leaf);
    this.rootEncoder = encoder.getEncoder(rootType);
    this._leaves = elements.map(this.leafHasher);
    console.log(DefaultGetter.from(types, leafType));
    this.defaultNode = DefaultGetter.from(types, leafType);
    this.defaultLeaf = this.leafHasher(this.defaultNode);
    this.tree = getTree(this._leaves, this.defaultLeaf);
  }

  static fromLeafType<BaseType extends Record<string, any> = any>(
    types: EIP712TypeDefinitions,
    leafType: string,
    depth: number,
    elements: BaseType[]
  ) {
    types.Tree = [{ name: "tree", type: leafType + "[2]".repeat(depth) }];
    return new Eip712MerkleTree(types, "Tree", leafType, elements);
  }
}
