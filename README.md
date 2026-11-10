![Seaport](img/Seaport-banner.png)

[![Version][version-badge]][version-link]
[![Test CI][ci-badge]][ci-link]
[![Code Coverage][coverage-badge]][coverage-link]
[![License][license-badge]][license-link]
[![Docs][docs-badge]][docs-link]
[![Discussions][discussions-badge]][discussions-link]
[![JS Library][js-library-badge]][js-library-link]

# Seaport

Seaport is a marketplace protocol for safely and efficiently buying and selling NFTs. Each order lists the items the offerer will give (the offer) and the items that must be received in return, along with who receives them (the consideration).

This repository holds Seaport's tests, reference implementation, helper contracts, and docs. The core contracts live in [seaport-core][seaport-core] and the shared types in [seaport-types][seaport-types]. [seaport-sol][seaport-sol] has Solidity helpers for building orders, and [seaport-js][seaport-js] is the JavaScript SDK.

## Deployments

Seaport 1.6 is at `0x0000000000000068F116a894984e2DB1123eB395` and the ConduitController at `0x00000000F9490004C11Cef243f5400493c00Ad63`, at the same address on every chain where they are deployed. [docs/Deployments.md](docs/Deployments.md) lists the chains, earlier versions, and helper contracts. [docs/Deploying.md](docs/Deploying.md) covers deploying to a new chain.

## Docs

- [Seaport documentation](docs/SeaportDocumentation.md): orders, fulfillment, and conduits
- [Zones](docs/ZoneDocumentation.md)
- [Order validator](docs/OrderValidator.md)
- [Function signatures](docs/FunctionSignatures.md)
- [Diagrams](diagrams/README.md)
- [Development](docs/Development.md): building, testing, and linting
- [Seaport 1.7 candidates](docs/Seaport-1.7-candidates.md)
- [OpenSea developer docs](https://docs.opensea.io/docs/seaport)

## Quick start

```bash
git clone --recurse-submodules https://github.com/ProjectOpenSea/seaport && cd seaport
FOUNDRY_PROFILE=reference forge build
FOUNDRY_PROFILE=optimized forge build
FOUNDRY_PROFILE=test forge test
```

This needs Foundry v1.9.0. [docs/Development.md](docs/Development.md) covers coverage and linting.

## Audits

These are the public reports on Seaport:

- Trail of Bits reviewed Seaport 1.0 from April 18 to May 12, 2022 and found no significant flaws. [Report](https://github.com/trailofbits/publications/blob/master/reviews/SeaportProtocol.pdf).
- Code4rena ran a public contest on Seaport 1.0 in May and June 2022. The high and medium findings were fixed in Seaport 1.1. [Report](https://code4rena.com/reports/2022-05-opensea-seaport).
- Spearbit reviewed Seaport 1.2 in December 2022. [Report](https://cantina.xyz/portfolio/8a68abac-d90b-43e2-9853-4099f22024de).
- Code4rena ran a public contest on Seaport 1.2 from January 13 to January 23, 2023. [Report](https://code4rena.com/reports/2023-01-opensea).

Report security issues through [Bugcrowd](https://bugcrowd.com/engagements/opensea), not in public issues or PRs.

## Contributing

Contributions are welcome, especially tests, docs, and readability. A PR should pass CI and keep `reference/` in step with any contract change. The deployed Seaport 1.6 bytecode doesn't change, so ideas that would change it go in [docs/Seaport-1.7-candidates.md](docs/Seaport-1.7-candidates.md).

## License

[MIT](LICENSE) Copyright 2023 Ozone Networks, Inc.

[version-badge]: https://img.shields.io/github/v/release/ProjectOpenSea/seaport
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
[seaport-core]: https://github.com/ProjectOpenSea/seaport-core
[seaport-types]: https://github.com/ProjectOpenSea/seaport-types
[seaport-sol]: https://github.com/ProjectOpenSea/seaport-sol
[seaport-js]: https://github.com/ProjectOpenSea/seaport-js
