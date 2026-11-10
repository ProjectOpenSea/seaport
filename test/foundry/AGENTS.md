# Foundry tests

- Tests deploy precompiled artifacts from `optimized-out/` and `reference-out/`. Build both profiles before running tests, and rebuild them after changing `contracts/`, `reference/`, or a submodule.
- Pick the suite with `FOUNDRY_PROFILE`: `test` (optimized), `reference` with `MOAT_PROFILE=reference`, or `offerers`. Add `--match-path` or `--match-test` while iterating.
- `new/` is the fuzz engine (the MOAT suite). `FOUNDRY_PROFILE=moat_debug` compiles it without the optimizer for faster iteration.
- Read time with `vm.getBlockTimestamp()` in tests that call `vm.warp`, since `block.timestamp` can be cached across the warp under `via_ir`.
- `DifferentialTestAssertionFailed()` wraps any run that didn't end in the expected passing status (see `assertPass` in `utils/DifferentialTest.sol`). It doesn't mean the optimized and reference builds disagree. Find the underlying assertion or revert, and check the test's own assumptions first: in #1426 a fuzzed recipient collided with a fixed test address.
