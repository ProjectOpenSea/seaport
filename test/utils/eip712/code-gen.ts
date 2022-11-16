import { writeFileSync } from "fs";
import path from "path";

import { toHex } from "../encoding";

const readCode = (index: number, length: number) => {
  const [shiftKey, letMaybe, prevNode, sibling] =
    index > 0
      ? [
          `shr(${index}, key)`,
          ``,
          `keccak256(0, TwoWords)`,
          `add(proof, ${toHex(index * 32)})`,
        ]
      : [`key`, `let `, `leaf`, `proof`];

  const getPtr = `${letMaybe}scratch := shl(5, and(${shiftKey}, 1))`;
  const writePrevNode = `mstore(scratch, ${prevNode})`;
  const code = [
    getPtr,
    writePrevNode,
    `mstore(xor(scratch, OneWord), calldataload(${sibling}))`,
  ];
  if (index + 1 === length) {
    code.push(`root := keccak256(0, TwoWords)`);
  }
  return code;
};

const depth = 7;

const allCode = [
  `\tfunction _computeMerkleProofDepth${depth}(Eip712MerkleProof proofPtr, uint256 leaf) pure returns (bytes32 root) {`,
  `\t\tassembly{`,
  `\t\tlet key := shr(248, proofPtr)`,
  `\t\tlet proof := add(proofPtr, 1)`,
];
for (let i = 0; i < depth; i++) {
  if (i === depth - 1) allCode.push("\t\t\t// Compute root hash");
  else allCode.push(`\t\t\t// Compute level ${i + 1}`);
  allCode.push(...readCode(i, depth).map((ln) => "\t\t\t" + ln));
  if (i !== depth - 1) allCode.push("");
}
allCode.push("\t\t}", "\t}");

writeFileSync(path.join(__dirname, "gen.sol"), allCode.join("\n"));
