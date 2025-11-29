/**
 * @title Order Fuzzing Security Tests
 * @notice Fuzz testing for Seaport 1.6 with randomly generated orders
 * @dev Generates 50-200 random orders and attempts to fulfill them to discover edge cases
 */

import { expect } from "chai";
import { ethers } from "hardhat";
import { parseEther, randomBytes } from "ethers/lib/utils";

import { deployContract } from "./utils/contracts";
import { randomHex, toBN, toKey } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { seaportFixture } from "./utils/fixtures";
import { VERSION } from "./utils/helpers";

import type {
  ConsiderationInterface,
  TestERC20,
  TestERC721,
  TestERC1155,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type {
  AdvancedOrder,
  OfferItem,
  ConsiderationItem,
  OrderParameters,
} from "./utils/types";
import type { Wallet, BigNumber } from "ethers";

const { parseEther: parseEtherUtil } = ethers.utils;

// Helper to generate random number in range
function randomInRange(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// Helper to generate random BigNumber in range
function randomBNInRange(min: BigNumber, max: BigNumber): BigNumber {
  const range = max.sub(min);
  const random = toBN(randomHex(16));
  return min.add(random.mod(range.add(1)));
}

describe(`Order Fuzzing Security Tests (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);
  const fulfiller = new ethers.Wallet(randomHex(32), provider);

  let marketplaceContract: ConsiderationInterface;
  let testERC20: TestERC20;
  let testERC721: TestERC721;
  let testERC1155: TestERC1155;
  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let getTestItem1155: SeaportFixtures["getTestItem1155"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
  let mintAndApprove1155: SeaportFixtures["mintAndApprove1155"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];
  let signOrder: SeaportFixtures["signOrder"];
  let stubZone: any;

  // Track statistics
  let totalTests = 0;
  let successfulFulfills = 0;
  let expectedReverts = 0;
  let unexpectedSuccesses = 0;
  let unexpectedFailures = 0;

  before(async () => {
    await faucet(owner.address, provider);
    await faucet(fulfiller.address, provider);

    ({
      createOrder,
      getTestItem20,
      getTestItem721,
      getTestItem1155,
      marketplaceContract,
      mintAndApprove721,
      mintAndApprove1155,
      mintAndApproveERC20,
      signOrder,
      testERC20,
      testERC721,
      testERC1155,
    } = await seaportFixture(owner));
  });

  after(function () {
    console.log("\n=== Fuzzing Statistics ===");
    console.log(`Total tests run: ${totalTests}`);
    console.log(`Successful fulfills: ${successfulFulfills}`);
    console.log(`Expected reverts: ${expectedReverts}`);
    console.log(`Unexpected successes: ${unexpectedSuccesses}`);
    console.log(`Unexpected failures: ${unexpectedFailures}`);
  });

  describe("Fuzz Test: Random Order Generation (50 iterations)", function () {
    const ITERATIONS = 50;

    it(`Should handle ${ITERATIONS} randomly generated orders`, async function () {
      this.timeout(600000); // 10 minutes for fuzzing

      for (let i = 0; i < ITERATIONS; i++) {
        totalTests++;
        try {
          // Generate random order parameters
          const numOfferItems = randomInRange(1, 10);
          const numConsiderationItems = randomInRange(1, 10);
          const itemTypes = [0, 1, 2, 3]; // ETH, ERC20, ERC721, ERC1155

          const offerItems: OfferItem[] = [];
          const considerationItems: ConsiderationItem[] = [];

          // Generate offer items
          for (let j = 0; j < numOfferItems; j++) {
            const itemType = itemTypes[randomInRange(0, itemTypes.length - 1)];
            let item: OfferItem;

            switch (itemType) {
              case 0: // ETH
                item = {
                  itemType: 0,
                  token: ethers.constants.AddressZero,
                  identifierOrCriteria: toBN(0),
                  startAmount: parseEther(
                    randomInRange(1, 100).toString()
                  ),
                  endAmount: parseEther(randomInRange(1, 100).toString()),
                };
                break;
              case 1: // ERC20
                const erc20Amount = parseEther(
                  randomInRange(1, 1000).toString()
                );
                await mintAndApproveERC20(
                  owner,
                  testERC20.address,
                  erc20Amount.mul(10)
                );
                item = getTestItem20(
                  testERC20.address,
                  erc20Amount,
                  erc20Amount
                );
                break;
              case 2: // ERC721
                const tokenId = toBN(i * 1000 + j);
                await mintAndApprove721(owner, testERC721.address, tokenId);
                item = getTestItem721(
                  testERC721.address,
                  tokenId,
                  toBN(1),
                  toBN(1)
                );
                break;
              case 3: // ERC1155
                const tokenId1155 = toBN(i * 1000 + j + 100);
                const amount1155 = toBN(randomInRange(1, 100));
                await mintAndApprove1155(
                  owner,
                  testERC1155.address,
                  tokenId1155,
                  amount1155.mul(10)
                );
                item = getTestItem1155(
                  testERC1155.address,
                  tokenId1155,
                  amount1155,
                  amount1155
                );
                break;
              default:
                continue;
            }
            offerItems.push(item);
          }

          // Generate consideration items
          let totalConsiderationValue = toBN(0);
          for (let j = 0; j < numConsiderationItems; j++) {
            const itemType = itemTypes[randomInRange(0, itemTypes.length - 1)];
            let item: ConsiderationItem;

            switch (itemType) {
              case 0: // ETH
                const ethAmount = parseEther(
                  randomInRange(1, 100).toString()
                );
                totalConsiderationValue = totalConsiderationValue.add(
                  ethAmount
                );
                item = {
                  itemType: 0,
                  token: ethers.constants.AddressZero,
                  identifierOrCriteria: toBN(0),
                  startAmount: ethAmount,
                  endAmount: ethAmount,
                  recipient: owner.address,
                };
                break;
              case 1: // ERC20
                const erc20Amount = parseEther(
                  randomInRange(1, 1000).toString()
                );
                await mintAndApproveERC20(
                  fulfiller,
                  testERC20.address,
                  erc20Amount.mul(10)
                );
                item = {
                  itemType: 1,
                  token: testERC20.address,
                  identifierOrCriteria: toBN(0),
                  startAmount: erc20Amount,
                  endAmount: erc20Amount,
                  recipient: owner.address,
                };
                break;
              case 2: // ERC721 (unlikely in consideration, but test it)
                const tokenId = toBN(i * 1000 + j + 200);
                await mintAndApprove721(
                  fulfiller,
                  testERC721.address,
                  tokenId
                );
                item = {
                  itemType: 2,
                  token: testERC721.address,
                  identifierOrCriteria: tokenId,
                  startAmount: toBN(1),
                  endAmount: toBN(1),
                  recipient: owner.address,
                };
                break;
              case 3: // ERC1155
                const tokenId1155 = toBN(i * 1000 + j + 300);
                const amount1155 = toBN(randomInRange(1, 100));
                await mintAndApprove1155(
                  fulfiller,
                  testERC1155.address,
                  tokenId1155,
                  amount1155.mul(10)
                );
                item = {
                  itemType: 3,
                  token: testERC1155.address,
                  identifierOrCriteria: tokenId1155,
                  startAmount: amount1155,
                  endAmount: amount1155,
                  recipient: owner.address,
                };
                break;
              default:
                continue;
            }
            considerationItems.push(item);
          }

          // Set approvals
          await testERC721
            .connect(owner)
            .setApprovalForAll(marketplaceContract.address, true);
          await testERC1155
            .connect(owner)
            .setApprovalForAll(marketplaceContract.address, true);
          await testERC20
            .connect(fulfiller)
            .approve(marketplaceContract.address, ethers.constants.MaxUint256);

          // Create order
          const { order } = await createOrder(
            owner,
            undefined,
            offerItems,
            considerationItems,
            0,
            [],
            null,
            owner,
            ethers.constants.HashZero,
            ethers.constants.HashZero
          );

          // Try to fulfill
          try {
            const tx = await marketplaceContract
              .connect(fulfiller)
              .fulfillAdvancedOrder(
                {
                  ...order,
                  numerator: toBN(1),
                  denominator: toBN(1),
                  extraData: "0x",
                },
                [],
                toKey(0),
                fulfiller.address,
                {
                  value: totalConsiderationValue,
                }
              );
            const receipt = await tx.wait();
            successfulFulfills++;
            if (i % 10 === 0) {
              console.log(
                `[FUZZ] Iteration ${i}: Order fulfilled successfully. Gas: ${receipt.gasUsed.toString()}`
              );
            }
          } catch (error: any) {
            expectedReverts++;
            // Most reverts are expected (invalid orders, insufficient approvals, etc.)
            if (i % 10 === 0) {
              console.log(
                `[FUZZ] Iteration ${i}: Order reverted (expected): ${error.message.substring(0, 100)}`
              );
            }
          }
        } catch (error: any) {
          unexpectedFailures++;
          console.error(
            `[FUZZ ERROR] Iteration ${i} failed unexpectedly: ${error.message}`
          );
        }
      }
    });
  });

  describe("Fuzz Test: Extreme Values (100 iterations)", function () {
    const ITERATIONS = 100;

    it(`Should handle ${ITERATIONS} orders with extreme values`, async function () {
      this.timeout(1200000); // 20 minutes

      for (let i = 0; i < ITERATIONS; i++) {
        totalTests++;
        try {
          // Test with extreme values
          const extremeAmounts = [
            toBN(1), // Minimum
            parseEther("1000000"), // Very large
            ethers.constants.MaxUint256.div(2), // Near max
            toBN(0), // Zero (should revert)
          ];

          const amount =
            extremeAmounts[randomInRange(0, extremeAmounts.length - 1)];

          // Randomly choose item type
          const itemTypeChoice = randomInRange(0, 3);
          let offerItem: OfferItem;
          let considerationItem: ConsiderationItem;

          switch (itemTypeChoice) {
            case 0: // ETH
              offerItem = {
                itemType: 0,
                token: ethers.constants.AddressZero,
                identifierOrCriteria: toBN(0),
                startAmount: amount,
                endAmount: amount,
              };
              considerationItem = {
                itemType: 0,
                token: ethers.constants.AddressZero,
                identifierOrCriteria: toBN(0),
                startAmount: amount,
                endAmount: amount,
                recipient: owner.address,
              };
              break;
            case 1: // ERC20
              if (!amount.isZero()) {
                await mintAndApproveERC20(
                  owner,
                  testERC20.address,
                  amount.mul(10)
                );
                await mintAndApproveERC20(
                  fulfiller,
                  testERC20.address,
                  amount.mul(10)
                );
              }
              offerItem = getTestItem20(
                testERC20.address,
                amount,
                amount
              );
              considerationItem = {
                itemType: 1,
                token: testERC20.address,
                identifierOrCriteria: toBN(0),
                startAmount: amount,
                endAmount: amount,
                recipient: owner.address,
              };
              break;
            case 2: // ERC721
              const tokenId = toBN(i * 2000);
              await mintAndApprove721(owner, testERC721.address, tokenId);
              offerItem = getTestItem721(
                testERC721.address,
                tokenId,
                toBN(1),
                toBN(1)
              );
              considerationItem = {
                itemType: 0, // ETH consideration
                token: ethers.constants.AddressZero,
                identifierOrCriteria: toBN(0),
                startAmount: parseEther("1"),
                endAmount: parseEther("1"),
                recipient: owner.address,
              };
              break;
            case 3: // ERC1155
              const tokenId1155 = toBN(i * 2000 + 1000);
              const amount1155 = amount.isZero() ? toBN(1) : amount;
              await mintAndApprove1155(
                owner,
                testERC1155.address,
                tokenId1155,
                amount1155.mul(10)
              );
              offerItem = getTestItem1155(
                testERC1155.address,
                tokenId1155,
                amount1155,
                amount1155
              );
              considerationItem = {
                itemType: 0, // ETH consideration
                token: ethers.constants.AddressZero,
                identifierOrCriteria: toBN(0),
                startAmount: parseEther("1"),
                endAmount: parseEther("1"),
                recipient: owner.address,
              };
              break;
            default:
              continue;
          }

          // Set approvals
          await testERC721
            .connect(owner)
            .setApprovalForAll(marketplaceContract.address, true);
          await testERC1155
            .connect(owner)
            .setApprovalForAll(marketplaceContract.address, true);

          const { order } = await createOrder(
            owner,
            undefined,
            [offerItem],
            [considerationItem],
            0,
            [],
            null,
            owner,
            ethers.constants.HashZero,
            ethers.constants.HashZero
          );

          // Try to fulfill
          try {
            const tx = await marketplaceContract
              .connect(fulfiller)
              .fulfillAdvancedOrder(
                {
                  ...order,
                  numerator: toBN(1),
                  denominator: toBN(1),
                  extraData: "0x",
                },
                [],
                toKey(0),
                fulfiller.address,
                {
                  value:
                    considerationItem.itemType === 0
                      ? considerationItem.startAmount
                      : toBN(0),
                }
              );
            const receipt = await tx.wait();
            successfulFulfills++;
            if (amount.isZero()) {
              unexpectedSuccesses++;
              console.log(
                `[WARNING] Zero-amount order fulfilled! Iteration ${i}`
              );
            }
          } catch (error: any) {
            expectedReverts++;
            // Expected for zero amounts and other invalid cases
          }
        } catch (error: any) {
          unexpectedFailures++;
          console.error(
            `[FUZZ ERROR] Extreme value test ${i} failed: ${error.message}`
          );
        }
      }
    });
  });

  describe("Fuzz Test: Partial Fill Fractions (50 iterations)", function () {
    const ITERATIONS = 50;

    it(`Should handle ${ITERATIONS} orders with random partial fill fractions`, async function () {
      this.timeout(600000);

      for (let i = 0; i < ITERATIONS; i++) {
        totalTests++;
        try {
          // Create a partially fillable order
          const tokenId = toBN(i * 3000);
          const totalAmount = toBN(100);
          await mintAndApprove1155(
            owner,
            testERC1155.address,
            tokenId,
            totalAmount.mul(10)
          );

          const { order } = await createOrder(
            owner,
            undefined,
            [
              getTestItem1155(
                tokenId,
                totalAmount,
                totalAmount,
                undefined,
                testERC1155.address
              ),
            ],
            [
              {
                itemType: 0, // ETH
                token: ethers.constants.AddressZero,
                identifierOrCriteria: toBN(0),
                startAmount: parseEther("100"),
                endAmount: parseEther("100"),
                recipient: owner.address,
              },
            ],
            0,
            [],
            null,
            owner,
            ethers.constants.HashZero,
            ethers.constants.HashZero
          );

          await testERC1155
            .connect(owner)
            .setApprovalForAll(marketplaceContract.address, true);

          // Generate random fraction
          const denominator = toBN(randomInRange(1, 100));
          const numerator = toBN(randomInRange(1, denominator.toNumber()));

          const advancedOrder: AdvancedOrder = {
            ...order,
            numerator,
            denominator,
            extraData: "0x",
          };

          // Calculate expected ETH value
          const expectedEth = parseEther("100")
            .mul(numerator)
            .div(denominator);

          try {
            const tx = await marketplaceContract
              .connect(fulfiller)
              .fulfillAdvancedOrder(
                advancedOrder,
                [],
                toKey(0),
                fulfiller.address,
                {
                  value: expectedEth,
                }
              );
            const receipt = await tx.wait();
            successfulFulfills++;
            if (i % 10 === 0) {
              console.log(
                `[FUZZ] Partial fill ${i}: ${numerator.toString()}/${denominator.toString()} fulfilled. Gas: ${receipt.gasUsed.toString()}`
              );
            }
          } catch (error: any) {
            expectedReverts++;
            // Some fractions may not divide evenly
          }
        } catch (error: any) {
          unexpectedFailures++;
          console.error(
            `[FUZZ ERROR] Partial fill test ${i} failed: ${error.message}`
          );
        }
      }
    });
  });
});

