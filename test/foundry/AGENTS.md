# Foundry tests

- Tests deploy precompiled artifacts from `optimized-out/` and `reference-out/`. Build both profiles before running tests, and rebuild them after changing `contracts/`, `reference/`, or a submodule.
- Pick the suite with `FOUNDRY_PROFILE`: `test` (optimized), `reference` with `MOAT_PROFILE=reference`, or `offerers`. Add `--match-path` or `--match-test` while iterating.
- `new/` is the fuzz engine (the MOAT suite). `FOUNDRY_PROFILE=moat_debug` compiles it without the optimizer for faster iteration.
- Read time with `vm.getBlockTimestamp()` in tests that call `vm.warp`, since `block.timestamp` can be cached across the warp under `via_ir`.
- A differential failure means the optimized and reference builds disagree. Check the test's assumptions before the contracts. In #1426, for example, a fuzzed recipient collided with a fixed test address.
