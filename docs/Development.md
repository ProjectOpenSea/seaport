# Development

## Setup

Install [Foundry](https://getfoundry.sh) v1.9.0 (`foundryup --install v1.9.0`), the version CI uses, and clone with submodules:

```bash
git clone --recurse-submodules https://github.com/ProjectOpenSea/seaport && cd seaport
```

The Hardhat suite and the JavaScript tooling also need Node from `.nvmrc` and yarn:

```bash
yarn install --frozen-lockfile
```

## Foundry tests

The tests deploy precompiled artifacts, so build both profiles first. Rebuild them after changing `contracts/`, `reference/`, or a submodule.

```bash
FOUNDRY_PROFILE=reference forge build   # reference-out/, via_ir off
FOUNDRY_PROFILE=optimized forge build   # optimized-out/, via_ir on
```

The optimized build reproduces the deployed Seaport 1.6 init code byte for byte, and `test/foundry/DeployedBytecode.t.sol` fails if that ever changes.

```bash
FOUNDRY_PROFILE=test forge test                              # against the optimized build
FOUNDRY_PROFILE=reference MOAT_PROFILE=reference forge test  # against the reference build
FOUNDRY_PROFILE=offerers forge test                          # contract offerer tests
```

- `FOUNDRY_PROFILE=debug` compiles everything without `via_ir` or the optimizer, for full traces and source in the debugger. It doesn't match the deployed bytecode.
- `FOUNDRY_PROFILE=moat_debug` compiles the fuzz engine in `test/foundry/new/` about twice as fast.

Coverage, with an HTML report:

```bash
SEAPORT_COVERAGE=true forge coverage --report summary --report lcov
lcov -o lcov.info --remove lcov.info --rc lcov_branch_coverage=1 --rc lcov_function_coverage=1 "test/*" "script/*"
genhtml lcov.info -o html --branch && open html/index.html
```

## Hardhat tests

The TypeScript suite in `test/*.spec.ts` predates the Foundry tests and is being ported to Foundry.

```bash
yarn build && yarn test              # optimized contracts
yarn build:ref && yarn test:ref      # reference contracts
yarn coverage && yarn coverage:ref   # coverage reports in coverage/
yarn profile                         # gas report
```

## Linting

```bash
yarn lint:check
yarn lint:fix
```

Solidity uses `forge fmt` and `forge lint`. TypeScript, JavaScript, JSON, Markdown, and YAML use Biome, and TOML uses taplo. CI also runs shellcheck and shfmt on shell scripts and actionlint on the workflows. `yarn install` adds a lefthook pre-commit hook that formats staged files.

The deployed contracts (`contracts/Seaport.sol`, `conduit/`, `helpers/`, `interfaces/`, `zones/`) are excluded from `forge fmt` and `forge lint`, so their source stays identical to what was verified onchain.
