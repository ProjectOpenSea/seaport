import { JsonRpcSigner } from "@ethersproject/providers";
import { constants } from "ethers";
import { deployContract } from "./contracts";

export const fixtureERC20 = (signer: JsonRpcSigner) =>
  deployContract("TestERC20", signer);

export const fixtureERC721 = (signer: JsonRpcSigner) =>
  deployContract("TestERC721", signer);

export const fixtureERC1155 = (signer: JsonRpcSigner) =>
  deployContract("TestERC1155", signer);

export const tokensFixture = async (signer: JsonRpcSigner) => {
  const testERC20 = await fixtureERC20(signer);
  const testERC721 = await fixtureERC721(signer);
  const testERC1155 = await fixtureERC1155(signer);
  const testERC1155Two = await fixtureERC1155(signer);
  const tokenByType = [
    {
      address: constants.AddressZero,
    }, // ETH
    testERC20,
    testERC721,
    testERC1155,
  ];

  return {
    testERC20,
    testERC721,
    testERC1155,
    testERC1155Two,
    tokenByType,
  };
};
