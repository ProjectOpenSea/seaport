# Development

## Setup

Install [Foundry](https://getfoundry.sh) v1.9.0 (`foundryup --install v1.9.0`), the version CI uses, and clone with submodules:

```bash
git clone --recurse-submodules https://github.com/ProjectOpenSea/seaport && cd seaport
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

Fuzz engine call counts, and the optimized build's distance from the 24,576-byte size limit:

```bash
SEAPORT_COLLECT_FUZZ_METRICS=true FOUNDRY_PROFILE=test forge test --match-path test/foundry/new/FuzzMain.t.sol
scripts/plot-metrics.sh call-metrics.txt
FOUNDRY_PROFILE=optimized forge build --sizes
```

## Linting

```bash
scripts/install-tools.sh     # once: pinned tools into .tools/bin
scripts/lint.sh check
scripts/lint.sh fix
.tools/bin/lefthook install  # optional pre-commit hook
```

Solidity uses `forge fmt` and `forge lint`. TypeScript, JavaScript, JSON, Markdown, and YAML use Biome, TOML uses taplo, shell scripts use shellcheck and shfmt, and workflows use actionlint.

The install script downloads each tool from its GitHub release and checks it against a pinned SHA-256, so linting needs nothing from npm. It supports macOS and Linux; on Windows, use WSL. `scripts/lint.sh` runs the same checks as CI and warns when your Foundry version differs from CI's.

The deployed contracts (`contracts/Seaport.sol`, `conduit/`, `helpers/`, `interfaces/`, `zones/`) are excluded from `forge fmt` and `forge lint`, so their source stays identical to what was verified onchain. `scripts/frozen-contracts.sha256` pins each of those files, and CI fails if one changes. After a deliberate change, regenerate it with `scripts/lint.sh freeze`.
