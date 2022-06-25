/* eslint-disable camelcase */
import { JsonRpcSigner } from "@ethersproject/providers";
import { expect } from "chai";
import { BigNumber, constants, ethers, Wallet } from "ethers";
import { ethers as hardhatEthers } from "hardhat";

import { TestERC1155, TestERC20, TestERC721 } from "../../../typechain-types";
import { deployContract } from "../contracts";
import {
  randomBN,
  toBN,
  BigNumberish,
  getOfferOrConsiderationItem,
  random128,
} from "../encoding";
import { whileImpersonating } from "../impersonate";

export const fixtureERC20 = async (signer: JsonRpcSigner | ethers.Wallet) => {
  const testERC20: TestERC20 = await deployContract("TestERC20", signer);

  const mintAndApproveERC20 = async (
    signer: Wallet,
    spender: string,
    tokenAmount: BigNumberish
  ) => {
    const amount = toBN(tokenAmount);
    // Offerer mints ERC20
    await testERC20.mint(signer.address, amount);

    // Offerer approves marketplace contract to tokens
    await expect(testERC20.connect(signer).approve(spender, amount))
      .to.emit(testERC20, "Approval")
      .withArgs(signer.address, spender, tokenAmount);
  };

  const getTestItem20 = (
    startAmount: BigNumberish = 50,
    endAmount: BigNumberish = 50,
    recipient?: string,
    token = testERC20.address
  ) =>
    getOfferOrConsiderationItem(1, token, 0, startAmount, endAmount, recipient);

  return {
    testERC20,
    mintAndApproveERC20,
    getTestItem20,
  };
};

export const fixtureERC721 = async (signer: JsonRpcSigner | ethers.Wallet) => {
  const testERC721: TestERC721 = await deployContract("TestERC721", signer);

  const set721ApprovalForAll = (
    signer: Wallet,
    spender: string,
    approved = true,
    contract = testERC721
  ) => {
    return expect(contract.connect(signer).setApprovalForAll(spender, approved))
      .to.emit(contract, "ApprovalForAll")
      .withArgs(signer.address, spender, approved);
  };

  const mint721 = async (signer: Wallet, id?: BigNumberish) => {
    const nftId = id ? toBN(id) : randomBN();
    await testERC721.mint(signer.address, nftId);
    return nftId;
  };

  const mint721s = async (signer: Wallet, count: number) => {
    const arr = [];
    for (let i = 0; i < count; i++) arr.push(await mint721(signer));
    return arr;
  };

  const mintAndApprove721 = async (
    signer: Wallet,
    spender: string,
    id?: BigNumberish
  ) => {
    await set721ApprovalForAll(signer, spender, true);
    return mint721(signer, id);
  };

  const getTestItem721 = (
    identifierOrCriteria: BigNumberish,
    startAmount: BigNumberish = 1,
    endAmount: BigNumberish = 1,
    recipient?: string,
    token = testERC721.address
  ) =>
    getOfferOrConsiderationItem(
      2,
      token,
      identifierOrCriteria,
      startAmount,
      endAmount,
      recipient
    );

  const getTestItem721WithCriteria = (
    identifierOrCriteria: BigNumberish,
    startAmount: BigNumberish = 1,
    endAmount: BigNumberish = 1,
    recipient?: string
  ) =>
    getOfferOrConsiderationItem(
      4,
      testERC721.address,
      identifierOrCriteria,
      startAmount,
      endAmount,
      recipient
    );

  return {
    testERC721,
    set721ApprovalForAll,
    mint721,
    mint721s,
    mintAndApprove721,
    getTestItem721,
    getTestItem721WithCriteria,
  };
};

export const fixtureERC1155 = async (signer: JsonRpcSigner | ethers.Wallet) => {
  const testERC1155: TestERC1155 = await deployContract("TestERC1155", signer);

  const set1155ApprovalForAll = (
    signer: Wallet,
    spender: string,
    approved = true,
    token = testERC1155
  ) => {
    return expect(token.connect(signer).setApprovalForAll(spender, approved))
      .to.emit(token, "ApprovalForAll")
      .withArgs(signer.address, spender, approved);
  };

  const mint1155 = async (
    signer: Wallet,
    multiplier = 1,
    token = testERC1155,
    id?: BigNumberish,
    amt?: BigNumberish
  ) => {
    const nftId = id ? toBN(id) : randomBN();
    const amount = amt ? toBN(amt) : toBN(randomBN(4));
    await token.mint(signer.address, nftId, amount.mul(multiplier));
    return { nftId, amount };
  };

  const mintAndApprove1155 = async (
    signer: Wallet,
    spender: string,
    multiplier = 1,
    id?: BigNumberish,
    amt?: BigNumberish
  ) => {
    const { nftId, amount } = await mint1155(
      signer,
      multiplier,
      testERC1155,
      id,
      amt
    );
    await set1155ApprovalForAll(signer, spender, true);
    return { nftId, amount };
  };

  const getTestItem1155WithCriteria = (
    identifierOrCriteria: BigNumberish,
    startAmount: BigNumberish = 1,
    endAmount: BigNumberish = 1,
    recipient?: string
  ) =>
    getOfferOrConsiderationItem(
      5,
      testERC1155.address,
      identifierOrCriteria,
      startAmount,
      endAmount,
      recipient
    );

  const getTestItem1155 = (
    identifierOrCriteria: BigNumberish,
    startAmount: BigNumberish,
    endAmount: BigNumberish,
    token = testERC1155.address,
    recipient?: string
  ) =>
    getOfferOrConsiderationItem(
      3,
      token,
      identifierOrCriteria,
      startAmount,
      endAmount,
      recipient
    );

  return {
    testERC1155,
    set1155ApprovalForAll,
    mint1155,
    mintAndApprove1155,
    getTestItem1155WithCriteria,
    getTestItem1155,
  };
};

const minRandom = (min: number) => randomBN(10).add(min);

export const tokensFixture = async (signer: JsonRpcSigner) => {
  const erc20 = await fixtureERC20(signer);
  const erc721 = await fixtureERC721(signer);
  const erc1155 = await fixtureERC1155(signer);
  const { testERC1155: testERC1155Two } = await fixtureERC1155(signer);
  const tokenByType = [
    {
      address: constants.AddressZero,
    } as any, // ETH
    erc20.testERC20,
    erc721.testERC721,
    erc1155.testERC1155,
  ];
  const createTransferWithApproval = async (
    contract: TestERC20 | TestERC1155 | TestERC721,
    receiver: Wallet,
    itemType: 0 | 1 | 2 | 3 | 4 | 5,
    approvalAddress: string,
    from: string,
    to: string
  ) => {
    let identifier: BigNumber = toBN(0);
    let amount: BigNumber = toBN(0);
    const token = contract.address;

    switch (itemType) {
      case 0:
        break;
      case 1: // ERC20
        amount = minRandom(100);
        await (contract as TestERC20).mint(receiver.address, amount);

        // Receiver approves contract to transfer tokens
        await whileImpersonating(
          receiver.address,
          hardhatEthers.provider,
          async () => {
            await expect(
              (contract as TestERC20)
                .connect(receiver)
                .approve(approvalAddress, amount)
            )
              .to.emit(contract, "Approval")
              .withArgs(receiver.address, approvalAddress, amount);
          }
        );
        break;
      case 2: // ERC721
      case 4: // ERC721_WITH_CRITERIA
        amount = toBN(1);
        identifier = randomBN();
        await (contract as TestERC721).mint(receiver.address, identifier);

        // Receiver approves contract to transfer tokens
        await erc721.set721ApprovalForAll(
          receiver,
          approvalAddress,
          true,
          contract as TestERC721
        );
        break;
      case 3: // ERC1155
      case 5: // ERC1155_WITH_CRITERIA
        identifier = random128();
        amount = minRandom(1);
        await contract.mint(receiver.address, identifier, amount);

        // Receiver approves contract to transfer tokens
        await erc1155.set1155ApprovalForAll(
          receiver,
          approvalAddress,
          true,
          contract as TestERC1155
        );
        break;
    }
    return { itemType, token, from, to, identifier, amount };
  };
  return {
    ...erc20,
    ...erc721,
    ...erc1155,
    testERC1155Two,
    tokenByType,
    createTransferWithApproval,
  };
};
