// import { _TypedDataEncoder as TypedDataEncoder } from "@ethersproject/hash";
// import { expect } from "chai";
// import { defaultAbiCoder, keccak256, toUtf8Bytes } from "ethers/lib/utils";
// import { ethers, network, waffle } from "hardhat";

// import { deployContract } from "../contracts";
// import { randomBN } from "../encoding";

// import { Eip712MerkleTree } from "./Eip712MerkleTree";
// import { Eip712TypeDef } from "./test-type";
// import {
//   bufferToHex,
//   chunk,
//   fillArray,
//   hashConcat,
//   hexToBuffer,
// } from "./utils";

// import type { SevenLevelMerkleTree } from "../../../typechain-types";

// describe("SevenLevelMerkleTree", () => {
//   const [signer] = waffle.provider.getWallets();
//   let contract: SevenLevelMerkleTree;
//   let tree: Eip712MerkleTree;

//   before(async () => {
//     contract = await deployContract(
//       "SevenLevelMerkleTree",
//       signer,
//       "Item",
//       "Item(uint256 value)"
//     );
//     const arr = [{ value: randomBN() }];
//     while (arr.length < 5) {
//       arr.push({ value: randomBN() });
//     }
//     tree = new Eip712MerkleTree(
//       {
//         Item: [{ name: "value", type: "uint256" }],
//         Tree: [{ name: "tree", type: "Item[2][2][2][2][2][2][2]" }],
//       },
//       "Tree",
//       "Item",
//       arr
//     );
//     expect(tree.tree.getDepth()).to.eq(3);
//   });

//   it("Code size", async () => {
//     console.log(
//       `Deployed Code Size: ${
//         hexToBuffer(await signer.provider.getCode(contract.address)).byteLength
//       }`
//     );
//   });

//   const encodeProof = (
//     key: number,
//     proof: string[],
//     signature = `0x${"ff".repeat(64)}`
//   ) => {
//     return [
//       `0x${key.toString(16).padStart(2, "0")}`,
//       defaultAbiCoder.encode(["uint256[7]"], [proof]).slice(2),
//       signature.slice(2),
//     ].join("");
//   };

//   //   let encodedProof: string;
//   //   before(() => {
//   //     const { proof } = tree.getProof(2) as any;

//   //     const fakeSignature = "aa".repeat(64);

//   //     encodedProof = [
//   //       `0x0203`,
//   //       defaultAbiCoder.encode(["uint256[3]"], [proof]).slice(2),
//   //       fakeSignature,
//   //     ].join("");
//   //   });

//   it("digest", async () => {
//     const arr = [{ value: randomBN() }];
//     while (arr.length < 5) {
//       arr.push({ value: randomBN() });
//     }
//     const newarr = fillArray([...arr], 128, tree.defaultNode);
//     const newTree = new Eip712MerkleTree(
//       tree.encoder.types,
//       "Tree",
//       "Item",
//       newarr
//     );
//     const { proof } = newTree.getProof(2) as any;
//     const data = encodeProof(2, proof);
//     let layer = chunk(newarr, 2);
//     while (layer.length > 2) {
//       layer = chunk(layer, 2);
//     }
//     const rootHash = tree.encoder.hashStruct("Tree", {
//       tree: layer,
//     });
//     const domainSeparator = TypedDataEncoder.hashDomain({
//       ...Eip712TypeDef.domain,
//       verifyingContract: contract.address,
//       chainId: (await ethers.provider.getNetwork()).chainId,
//     });
//     const digest = await contract.getEip712Digest(data, newTree.getLeaf(2));
//     expect(digest).to.eq(
//       bufferToHex(hashConcat(["0x1901", domainSeparator, rootHash]))
//     );
//   });

//   /*   it("verify", async () => {
//     const { leaf, proof } = tree.getProof(2) as any;
//     expect(proof.length).to.eq(3);
//     const contractRoot = await contract.computeMerkleProofLevel4(
//       proof,
//       2,
//       leaf
//     );
//     expect(contractRoot).to.eq(tree.root);
//     const gas = await contract.estimateGas.computeMerkleProofLevel4(
//       proof,
//       2,
//       leaf
//     );
//     console.log(`Gas Used: ${gas.toNumber()}`);
//   }); */

//   it("merkleTypeString & merkleTypeHash", async () => {
//     expect(await contract.merkleTypeString()).to.eq(
//       "Tree(Item[2][2][2][2][2][2][2] tree)Item(uint256 value)"
//     );
//     const typeHash = keccak256(toUtf8Bytes(tree.encoder._types.Tree));
//     expect(await contract.eip712MerkleTypeHash()).to.eq(typeHash);
//   });

//   // describe("getMerkleTypeString", () => {
//   //   const baseTypeString = "Item(uint256 value)";

//   //   it("One level", async () => {
//   //     const newTypeString = `Tree(Item[2] tree)${baseTypeString}`;
//   //     expect(
//   //       await contract.getMerkleTypeString("Item", baseTypeString, 1)
//   //     ).to.eq(newTypeString);

//   //     const newTypeHash = keccak256(
//   //       toUtf8Bytes(
//   //         TypedDataEncoder.from({
//   //           ...Eip712TypeDef.types,
//   //           Tree: [{ name: "tree", type: `Item[2]` }],
//   //         })._types.Tree
//   //       )
//   //     );
//   //     expect(await contract.getMerkleTypeHash("Item", baseTypeString, 1)).to.eq(
//   //       newTypeHash
//   //     );
//   //   });

//   //   it("Two levels", async () => {
//   //     const newTypeString = `Tree(Item[2][2] tree)${baseTypeString}`;
//   //     expect(
//   //       await contract.getMerkleTypeString("Item", baseTypeString, 2)
//   //     ).to.eq(newTypeString);

//   //     const newTypeHash = keccak256(
//   //       toUtf8Bytes(
//   //         TypedDataEncoder.from({
//   //           ...Eip712TypeDef.types,
//   //           Tree: [{ name: "tree", type: `Item[2][2]` }],
//   //         })._types.Tree
//   //       )
//   //     );
//   //     expect(await contract.getMerkleTypeHash("Item", baseTypeString, 2)).to.eq(
//   //       newTypeHash
//   //     );
//   //   });
//   // });

//   // describe("computeMerkleProofDynamic", () => {
//   //   let encodedProof: string;
//   //   before(() => {
//   //     const { proof } = tree.getProof(2) as any;

//   //     const fakeSignature = "aa".repeat(64);

//   //     encodedProof = [
//   //       `0x0203`,
//   //       defaultAbiCoder.encode(["uint256[3]"], [proof]).slice(2),
//   //       fakeSignature,
//   //     ].join("");
//   //   });
//   //   it("Derive root when signature is 64 bytes", async () => {
//   //     const leaf = tree.getLeaf(2);
//   //     const contractRoot = await contract.computeMerkleProofDynamic(
//   //       encodedProof,
//   //       leaf
//   //     );
//   //     expect(contractRoot).to.eq(tree.root);
//   //     const gas = await contract.estimateGas.computeMerkleProofDynamic(
//   //       encodedProof,
//   //       leaf
//   //     );
//   //     console.log(`Gas Used: ${gas.toNumber()}`);
//   //   });

//   //   it("Derive root when signature is 65 bytes", async () => {
//   //     const leaf = tree.getLeaf(2);
//   //     const contractRoot = await contract.computeMerkleProofDynamic(
//   //       encodedProof.concat("ff"),
//   //       leaf
//   //     );
//   //     expect(contractRoot).to.eq(tree.root);
//   //     const gas = await contract.estimateGas.computeMerkleProofDynamic(
//   //       encodedProof.concat("ff"),
//   //       leaf
//   //     );
//   //     console.log(`Gas Used: ${gas.toNumber()}`);
//   //   });

//   //   it("Revert when signature is >65 bytes", async () => {
//   //     const leaf = tree.getLeaf(2);
//   //     await expect(
//   //       contract.computeMerkleProofDynamic(encodedProof.concat("ffff"), leaf)
//   //     ).to.be.reverted;
//   //   });

//   //   it("Revert when signature is <64 bytes", async () => {
//   //     const leaf = tree.getLeaf(2);
//   //     await expect(
//   //       contract.computeMerkleProofDynamic(
//   //         encodedProof.slice(0, encodedProof.length - 2),
//   //         leaf
//   //       )
//   //     ).to.be.reverted;
//   //   });
//   // });
// });
