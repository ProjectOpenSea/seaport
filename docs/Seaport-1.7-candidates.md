# Seaport 1.7 candidates

No Seaport 1.7 release is planned. This file collects ideas from past PRs and issues that would change the deployed Seaport bytecode, so they are in one place if a 1.7 effort ever starts.

Changes that leave the deployed 1.6 bytecode alone (tests, tooling, docs, the reference implementation) don't belong here. They can land on `main` at any time, and `test/foundry/DeployedBytecode.t.sol` fails if one of them changes the build.

## Zone interface

- Add `orderType` to `ZoneParameters` so a zone can tell full, partial, and contract orders apart without extra data. This changes the zone ABI. reNFT proposed it for rentals, and it was closed without review in 2025. [Include `OrderType` in `ZoneParameters`](https://github.com/ProjectOpenSea/seaport-core/pull/14)
- Give the zone every execution in the fulfillment (`ReceivedItem[]`), not only the order's own consideration. This is the earlier form of the same reNFT proposal, closed by its author in favor of the one above. [Rental](https://github.com/ProjectOpenSea/seaport-core/pull/13)

## Signatures and accounts

- Support bulk order signatures from ERC-1271 smart accounts whose signatures are longer than 65 bytes. Deriving `bulkOrderHash` assumes a 64 or 65 byte ECDSA signature, so the docs tell smart accounts to fall back to single orders. [1271 signature verification fails when used for bulk signature](https://github.com/ProjectOpenSea/seaport/issues/1273)
- Evaluate ERC-2771 trusted forwarder support for gasless fulfillment. It touches every `msg.sender` check and would need its own security review. [Support OpenZeppelin Forwarder on Seaport for gasless experience](https://github.com/ProjectOpenSea/seaport/issues/1275)

## Token transfers

- Offer an ERC721 path that uses `safeTransferFrom`, so receiving contracts get `onERC721Received`. Seaport uses `transferFrom` to save gas and limit reentrancy surface. [Why not use safeTransferFrom for ECR721 ?](https://github.com/ProjectOpenSea/seaport/issues/647), [Allow safeTransfer/safeTransferFrom for ERC721](https://github.com/ProjectOpenSea/seaport/issues/1081)

## Gas and bytecode size

- Use pointer library memory copies wherever more than three words are copied in a row. This was a 1.2 work in progress, closed without discussion. [[WIP] 1.2 copy optimizations](https://github.com/ProjectOpenSea/seaport/pull/718)
- Free bytecode headroom with small rewrites: drop single-use locals, fold the order typehash construction, and filter zero-amount executions in assembly. This was an experiment, closed without merging. [WIP - experiment with freeing up headroom](https://github.com/ProjectOpenSea/seaport-core/pull/10)
- Move loop invariants such as `orderParameters.offerer` and `conduitKey` out of the loop in `_applyFractionsAndTransferEach`. The issue is still open. [move loop invariant code out from loop to save gas](https://github.com/ProjectOpenSea/seaport-core/issues/9)
- Load `OrderStatus` into memory once in `Verifiers` instead of reading storage several times. The fields share one slot, so the saving is only on warm reads, and it hasn't been measured. [change SLOAD to MLOAD to save gas](https://github.com/ProjectOpenSea/seaport-core/pull/6)

## Conduits

- The canonical ConduitController, and every conduit it creates, is the 1.1 build. A conduit that is asked to move an ERC721 with an amount other than 1 reverts with `InvalidERC721TransferAmount()` (selector `0xefcc00b1`). Seaport 1.2 added the amount to that error, so seaport-core's `Conduit`, Seaport 1.6 itself and the `TokenTransferrerErrors` interface in seaport-types all use `InvalidERC721TransferAmount(uint256)` (selector `0x69f95827`). Tools that decode conduit reverts with the seaport-types ABI won't recognize the deployed conduit's error. Building from current source gives a different ConduitController, and its conduits would have different addresses from the existing ones, so this only ships if a release redeploys the conduit system. [InvalidERC721TransferAmount amount param](https://github.com/ProjectOpenSea/seaport/commit/114c6aae)

## Helpers

- Fix `SeaportRouter`'s tally loop. It only advances its index when an order was filled, so a batch where one Seaport returns a skipped order (or hits `maximumFulfilled` partway through) loops until it runs out of gas. The fix ships with a new router deployment, since the deployed router is frozen. [fix(SeaportRouter): terminate tally loop on partially-available batches](https://github.com/ProjectOpenSea/seaport/pull/1415)

## Process

- Move files between this repo and seaport-core in a way that keeps git history, so diffs between versions stay readable. The 1.5 split recreated the core files instead of moving them. [Repo does not seem to be setup properly to track changes/diffs](https://github.com/ProjectOpenSea/seaport-core/issues/3)
- Ship a changelog and release notes with the release tag. [changelog file](https://github.com/ProjectOpenSea/seaport/issues/1248), [Release notes and change logs in GitHub release tags](https://github.com/ProjectOpenSea/seaport/issues/1233)
