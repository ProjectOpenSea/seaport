# Seaport

Guidance for coding agents and new contributors working in this repository.

## The one rule

The deployed Seaport 1.6 bytecode must not change. Seaport lives at `0x0000000000000068F116a894984e2DB1123eB395` on every supported chain, and this repo exists to test, document, and reproduce that deployment. No 1.7 release is planned.

- Don't edit `contracts/Seaport.sol` or move the `lib/seaport-core` or `lib/seaport-types` submodule pins. seaport-core v1.6.6 is the exact verified source.
- Don't change the solc version, `evm_version`, `via_ir`, `optimizer_runs`, or `bytecode_hash` of the `optimized` profile.
- `test/foundry/DeployedBytecode.t.sol` checks the optimized build against the deployed init code. If it fails, the change altered the contract. Revert it rather than updating the expected hash.
- Ideas that would change the bytecode go in [docs/Seaport-1.7-candidates.md](docs/Seaport-1.7-candidates.md).

Tests, tooling, docs, and the reference implementation can change freely.

## Layout

- `contracts/Seaport.sol` is a thin wrapper over `Consideration` from `lib/seaport-core`, where the core logic lives.
- `contracts/helpers/` holds the order validator, the navigator, `TransferHelper`, and `SeaportRouter`. `contracts/zones/` holds the pausable zone.
- `reference/` is a readable, unoptimized implementation of the same protocol. The differential tests run both and compare results.
- `test/foundry/` holds the Foundry tests. `test/foundry/new/` is the fuzz engine (the "MOAT" suite). `test/*.spec.ts` is the older Hardhat suite, which is being ported to Foundry.
- `script/` holds Foundry deploy scripts.

## Toolchain

- Foundry v1.9.0 (`foundryup --install v1.9.0`), the version CI pins.
- Node from `.nvmrc` with yarn, needed only for the Hardhat suite and the current linters until they move to Foundry and Biome.
- Clone with submodules: `git clone --recurse-submodules`, or `git submodule update --init --recursive` in an existing checkout.

## Build and test

The Foundry tests deploy precompiled artifacts, so build both profiles first:

```bash
FOUNDRY_PROFILE=reference forge build
FOUNDRY_PROFILE=optimized forge build
```

Then run the suite you need:

```bash
FOUNDRY_PROFILE=test forge test
FOUNDRY_PROFILE=reference MOAT_PROFILE=reference forge test
FOUNDRY_PROFILE=offerers forge test
FOUNDRY_PROFILE=test forge test --match-path test/foundry/DeployedBytecode.t.sol
```

The optimized build takes a couple of minutes because of `via_ir`. Re-run it only after changing `contracts/` or a submodule. For fast iteration on the fuzz engine, `FOUNDRY_PROFILE=moat_debug` compiles without the optimizer.

The Hardhat suite and linters:

```bash
yarn install --frozen-lockfile
yarn build && yarn test
yarn build:ref && yarn test:ref
yarn lint:check
```

## Conventions

- Keep PRs small and focused. CI runs every suite above on each pull request.
- Write onchain as one word.
