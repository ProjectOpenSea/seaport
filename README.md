![Seaport](img/Seaport-banner.png)

[![Version][version-badge]][version-link]
[![Test CI][ci-badge]][ci-link]
[![Code Coverage][coverage-badge]][coverage-link]
[![License][license-badge]][license-link]
[![Docs][docs-badge]][docs-link]
[![Discussions][discussions-badge]][discussions-link]
[![JS Library][js-library-badge]][js-library-link]

# Seaport

Seaport is a new marketplace protocol for safely and efficiently buying and selling NFTs.

## Table of Contents

- [Seaport](#seaport)
  - [Table of Contents](#table-of-contents)
  - [Background](#background)
  - [Deployments](#deployments)
  - [Diagram](#diagram)
  - [Install](#install)
  - [Usage](#usage)
    - [Foundry Tests](#foundry-tests)
  - [Audits](#audits)
  - [Contributing](#contributing)
  - [License](#license)

## Background

Seaport is a marketplace protocol for safely and efficiently buying and selling NFTs. Each listing contains an arbitrary number of items that the offerer is willing to give (the "offer") along with an arbitrary number of items that must be received along with their respective receivers (the "consideration").

See the [documentation](docs/SeaportDocumentation.md), the [interface](contracts/interfaces/SeaportInterface.sol), and the full [interface documentation](https://docs.opensea.io/v2.0/reference/seaport-overview) for more information on Seaport.

## Deployments

<table>
<tr>
<th>Network</th>
<th>Seaport 1.1</th>
<th>ConduitController</th>
</tr>

<tr><td>Ethereum</td><td rowspan="14">

[0x00000000006c3852cbEf3e08E8dF289169EdE581](https://etherscan.io/address/0x00000000006c3852cbEf3e08E8dF289169EdE581#code)

</td><td rowspan="14">

[0x00000000F9490004C11Cef243f5400493c00Ad63](https://etherscan.io/address/0x00000000F9490004C11Cef243f5400493c00Ad63#code)

</td></tr>

<tr><td>Rinkeby</td></tr>
<tr><td>Goerli</td></tr>
<tr><td>Kovan</td></tr>
<tr><td>Polygon</td></tr>
<tr><td>Mumbai</td></tr>
<tr><td>Optimism</td></tr>
<tr><td>Optimistic Kovan</td></tr>
<tr><td>Arbitrum</td></tr>
<tr><td>Arbitrum Nova</td></tr>
<tr><td>Arbitrum Rinkeby</td></tr>
<tr><td>Avalanche Fuji</td></tr>
<tr><td>Avalanche C-Chain</td></tr>
<tr><td>Gnosis Chain</td></tr>
<tr><td>BSC</td></tr>
</table>

To be deployed on other EVM chains, such as:

- Klaytn
- Baobab
- Skale
- Celo
- Fantom
- RSK

To deploy to a new EVM chain, follow the [steps outlined here](docs/Deployment.md).

## Diagram

```mermaid
graph TD
    Offer & Consideration --> Order
    zone & conduitKey --> Order

    subgraph Seaport[ ]
    Order --> Fulfill & Match
    Order --> Validate & Cancel
    end

    Validate --> Verify
    Cancel --> OrderStatus

    Fulfill & Match --> OrderCombiner --> OrderFulfiller

    OrderCombiner --> BasicOrderFulfiller --> OrderValidator
    OrderCombiner --> FulfillmentApplier

    OrderFulfiller --> CriteriaResolution
    OrderFulfiller --> AmountDeriver
    OrderFulfiller --> OrderValidator

    OrderValidator --> ZoneInteraction
    OrderValidator --> Executor --> TokenTransferrer
    Executor --> Conduit --> TokenTransferrer
    Executor --> Verify

    subgraph Verifiers[ ]
    Verify --> Time & Signature & OrderStatus
    end
```

For a more thorough flowchart see [Seaport diagram](./diagrams/Seaport.drawio.svg).

## Install

To install dependencies and compile contracts:

```bash
git clone https://github.com/ProjectOpenSea/seaport && cd seaport
yarn install
yarn build
```

## Usage

To run hardhat tests written in javascript:

```bash
yarn test
yarn coverage
```

> Note: artifacts and cache folders may occasionally need to be removed between standard and coverage test runs.

To run hardhat tests against reference contracts:

```bash
yarn test:ref
yarn coverage:ref
```

To profile gas usage:

```bash
yarn profile
```

### Foundry Tests

Seaport also includes a suite of fuzzing tests written in solidity with Foundry.

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

To precompile contracts:

The optimized contracts are compiled using the IR pipeline, which can take a long time to compile. By default, the differential test suite deploys precompiled versions of both the optimized and reference contracts. Precompilation can be done by specifying specific Foundry profiles.

```bash
FOUNDRY_PROFILE=optimized forge build
FOUNDRY_PROFILE=reference forge build
```

There are three Foundry profiles for running the test suites, which bypass the IR pipeline to speed up compilation. To run tests, run any of the following:

```bash
FOUNDRY_PROFILE=test forge test # with 5000 fuzz runs
FOUNDRY_PROFILE=lite forge test # with 1000 fuzz runs
FOUNDRY_PROFILE=local-ffi forge test # compiles and deploys ReferenceConsideration normally, with 1000 fuzz runs
```

You may wish to include a `.env` file that `export`s a specific profile when developing locally.

**Note** that stack+debug traces will not be available for precompiled contracts. To facilitate local development, specifying `FOUNDRY_PROFILE=local-ffi` will compile and deploy the reference implementation normally, allowing for stack+debug traces.

**Note** the `local-ffi` profile uses Forge's `ffi` flag. `ffi` can potentially be unsafe, as it allows Forge to execute arbitrary code. Use with caution, and always ensure you trust the code in this repository, especially when working on third-party forks.

The following modifiers are also available:

- Level 2 (-vv): Logs emitted during tests are also displayed.
- Level 3 (-vvv): Stack traces for failing tests are also displayed.
- Level 4 (-vvvv): Stack traces for all tests are displayed, and setup traces for failing tests are displayed.
- Level 5 (-vvvvv): Stack traces and setup traces are always displayed.

```bash
FOUNDRY_PROFILE=test forge test  -vv
```

For more information on foundry testing and use, see [Foundry Book installation instructions](https://book.getfoundry.sh/getting-started/installation.html).

To run lint checks:

```bash
yarn lint:check
```

Lint checks utilize prettier, prettier-plugin-solidity, and solhint.

```javascript
"prettier": "^2.5.1",
"prettier-plugin-solidity": "^1.0.0-beta.19",
```

## Audits

OpenSea engaged Trail of Bits to audit the security of Seaport. From April 18th to May 12th 2022, a team of Trail of Bits consultants conducted a security review of Seaport. The audit did not uncover significant flaws that could result in the compromise of a smart contract, loss of funds, or unexpected behavior in the target system. Their [full report is available here](https://github.com/trailofbits/publications/blob/master/reviews/SeaportProtocol.pdf).

## Contributing

Contributions to Seaport are welcome by anyone interested in writing more tests, improving readability, optimizing for gas efficiency, or extending the protocol via new zone contracts or other features.

When making a pull request, ensure that:

- All tests pass.
- Code coverage remains at 100% (coverage tests must currently be written in hardhat).
- All new code adheres to the style guide:
  - All lint checks pass.
  - Code is thoroughly commented with natspec where relevant.
- If making a change to the contracts:
  - Gas snapshots are provided and demonstrate an improvement (or an acceptable deficit given other improvements).
  - Reference contracts are modified correspondingly if relevant.
  - New tests (ideally via foundry) are included for all new features or code paths.
- If making a modification to third-party dependencies, `yarn audit` passes.
- A descriptive summary of the PR has been provided.

## License

[MIT](LICENSE) Copyright 2022 Ozone Networks, Inc.

[version-badge]: https://img.shields.io/github/package-json/v/ProjectOpenSea/seaport
[version-link]: https://github.com/ProjectOpenSea/seaport/releases
[ci-badge]: https://github.com/ProjectOpenSea/seaport/actions/workflows/test.yml/badge.svg
[ci-link]: https://github.com/ProjectOpenSea/seaport/actions/workflows/test.yml
[coverage-badge]: https://codecov.io/gh/ProjectOpenSea/seaport/branch/main/graph/badge.svg
[coverage-link]: https://codecov.io/gh/ProjectOpenSea/seaport
[license-badge]: https://img.shields.io/github/license/ProjectOpenSea/seaport
[license-link]: https://github.com/ProjectOpenSea/seaport/blob/main/LICENSE
[docs-badge]: https://img.shields.io/badge/Seaport-documentation-informational
[docs-link]: https://github.com/ProjectOpenSea/seaport/tree/main/docs
[discussions-badge]: https://img.shields.io/badge/Seaport-discussions-blueviolet
[discussions-link]: https://github.com/ProjectOpenSea/seaport/discussions
[js-library-badge]: https://img.shields.io/badge/Seaport.js-library-red
[js-library-link]: https://github.com/ProjectOpenSea/seaport-js
