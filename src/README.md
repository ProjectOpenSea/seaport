# Foundry Docs

## General
The `/src` folder is for code related to Foundry and testing.

The `/src/test` folder is home to Foundry tests, including fuzzing tests, written in solidity.

For general info about Foundry check out its docs here: https://onbjerg.github.io/foundry-book/

## Running the tests

First, install Foundry. On Linux and macOS systems, this is done as follows:
```bash
curl -L https://foundry.paradigm.xyz | bash
```
This will download foundryup. To start install Foundry, run:
```bash
foundryup
```

Next, run the tests with:
```bash
forge test
```

To run just the Consideration specified tests, which skips the automated generated tests for the token standards that are imported, try:
```bash
forge test  --match-contract ConsiderationTest
```

## Notes

One weird decision... since this repo has hardhat & foundry tests, we want to keep the foundry together in one section so the testing libraries know which code to run. So we put the foundry `lib` section in side the `/src` folder. It's cleaner and noted in the `foundry.toml` where the default locations of everything is set:
```js
libs = ['src/lib']
```
