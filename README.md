# Seaport

Seaport is a marketplace contract for safely and efficiently creating and fulfilling orders for ERC721 and ERC1155 items.

## Table of Contents

- [Background](#background)
- [Deployments](#deployments)
- [Install](#install)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

## Background

Seaport is a marketplace contract for safely and efficiently creating and fulfilling orders for ERC721 and ERC1155 items. Each order contains an arbitrary number of items that the offerer is willing to give (the "offer") along with an arbitrary number of items that must be received along with their respective receivers (the "consideration").

For more information and a deeper dive on how Seaport works, check out the repo's [Docs](Docs.md) file, or the full [Seaport Overview Documentation](https://docs.opensea.io/v2.0/reference/seaport-overview).

The Seaport interface can be found [here](reference/lib/SeaportInterface.sol).

## Deployments

Seaport deployment addresses

| Network          | Address                                    |
| ---------------- | ------------------------------------------ |
| Ethereum Mainnet | 0x00000000006ce100a8b5ed8edf18ceef9e500697 |
| Polygon Mainnet  | 0x00000000006ce100a8b5ed8edf18ceef9e500697 |
| Goerli           | 0x00000000006ce100a8b5ed8edf18ceef9e500697 |
| Rinkeby          | 0x00000000006ce100a8b5ed8edf18ceef9e500697 |

## Install

Seaport uses several libraries for testing.

Install dependencies and compile:

```bash
yarn install
yarn build
```

## Usage

To run hardhat tests written in javascript:

```bash
yarn test
yarn coverage
```

To profile gas usage (note that gas usage is mildly non-deterministic at the moment due to random inputs in tests):

```bash
yarn profile
```

### Foundry Tests

Seaport also includes several fuzzing tests written in solidity with Foundry.

To install Foundry (assuming a Linux or macOS system):

```bash
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. To start Foundry, run:

```bash
foundryup
```

To install dependencies:

```
forge install
```

To run tests:

```bash
forge test
```

The following modifiers are also available:

- Level 2 (-vv): Logs emitted during tests are also displayed.
- Level 3 (-vvv): Stack traces for failing tests are also displayed.
- Level 4 (-vvvv): Stack traces for all tests are displayed, and setup traces for failing tests are displayed.
- Level 5 (-vvvvv): Stack traces and setup traces are always displayed.

```bash
forge test  -vv
```

For more information on foundry testing and use, see [Foundry Book installation instructions](https://book.getfoundry.sh/getting-started/installation.html).

## Contributing

Contributions to Seaport are welcome by anyone. If you're interested in writing more tests, creating zones, improving readability, or increasing gas efficiency then we would love to see a Pull Request from you!

When making a pull request, please make sure:

- Everything adheres to the style guide.
- If making a change to the contracts, you've run gas profiling so we know the change is an improvement.
- Follow the PR template

### Linting

You can lint the repo any time with:

```bash
yarn lint:check
```

We use prettier, and prettier-plugin-solidity.

```javascript
"prettier": "^2.5.1",
"prettier-plugin-solidity": "^1.0.0-beta.19",
```

## License

[MIT](LICENSE) Copyright 2022 Ozone Networks, Inc.
