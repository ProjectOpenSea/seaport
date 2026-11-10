# Seaport

Tests, docs, and tooling for Seaport 1.6, deployed at `0x0000000000000068F116a894984e2DB1123eB395` on every supported chain. No 1.7 release is planned.

## Rule

The deployed bytecode must not change. Don't change `contracts/Seaport.sol`, the `lib/seaport-core` and `lib/seaport-types` pins, or any compiler setting the `optimized` profile uses, including the `solc`, `evm_version`, `optimizer_runs`, and remappings it inherits from `[profile.default]`. `test/foundry/DeployedBytecode.t.sol` fails if a change alters the build; revert the change rather than the test. Ideas that would change bytecode go in `docs/Seaport-1.7-candidates.md`.

## Layout

- `contracts/`: the `Seaport` wrapper (core logic is in `lib/seaport-core`), helpers, zones, and test mocks in `contracts/test/`.
- `reference/`: an unoptimized implementation that differential tests compare against.
- `test/foundry/`: Foundry tests. `test/*.spec.ts` is the legacy Hardhat suite, being ported.

## Commands

Foundry v1.9.0, submodules checked out recursively.

```bash
FOUNDRY_PROFILE=reference forge build
FOUNDRY_PROFILE=optimized forge build
FOUNDRY_PROFILE=test forge test
scripts/install-tools.sh   # pinned Biome, taplo, lefthook, shellcheck, shfmt, actionlint
scripts/lint.sh check
```

Tests load both builds, so run both `forge build` commands first. To check only the bytecode: `FOUNDRY_PROFILE=test forge test --match-path test/foundry/DeployedBytecode.t.sol`.

Node from `.nvmrc` runs the Hardhat suite: `yarn install --frozen-lockfile && yarn build && yarn test`.
