export const Eip712TypeDef = {
  types: {
    Item: [{ name: "value", type: "uint256" }],
    Tree: [{ name: "tree", type: "Item[2][2]" }],
  },
  primaryType: "Tree",
  domain: {
    name: "Domain",
    version: "1",
    chainId: 1,
    verifyingContract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
  },
  message: {
    tree: [{ value: 1 }, { value: 2 }],
  },
};