# Deployments

Seaport and its supporting contracts live at the same address on every chain they're deployed to. Each chain's Seaport 1.6 bytecode matches Ethereum's except for the chain ID and domain separator that the constructor stores.

## Canonical addresses

| Contract          | Address                                      |
| ----------------- | -------------------------------------------- |
| Seaport 1.6       | `0x0000000000000068F116a894984e2DB1123eB395` |
| ConduitController | `0x00000000F9490004C11Cef243f5400493c00Ad63` |
| SeaportValidator  | `0x00e5F120f500006757E984F1DED400fc00370000` |
| SeaportNavigator  | `0x0000f00000627D293Ab4Dfb40082001724dB006F` |
| Seaport 1.5       | `0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC` |
| Seaport 1.4       | `0x00000000000001ad428e4906aE43D8F9852d0dD6` |
| Seaport 1.3       | `0x0000000000000aD24e80fd803C6ac37206a45f15` |
| Seaport 1.2       | `0x00000000000006c7676171937C444f6BDe3D6282` |
| Seaport 1.1       | `0x00000000006c3852cbEf3e08E8dF289169EdE581` |

Seaport 1.2 through 1.4 have known limitations, particularly around restricted and contract orders. Use 1.6.

To check whether a contract exists on a chain, run `cast code <address> --rpc-url <rpc>`. To deploy to a new chain, see [Deploying.md](Deploying.md).

## Seaport 1.6

These chains had Seaport 1.6 at the canonical address when checked onchain in November 2026.

### Mainnets

| Chain             | Chain ID | Explorer                                                                                          |
| ----------------- | -------- | ------------------------------------------------------------------------------------------------- |
| Abstract          | 2741     | [view](https://abscan.org/address/0x0000000000000068F116a894984e2DB1123eB395)                     |
| Animechain        | 69000    | [view](https://explorer.anime.xyz/address/0x0000000000000068F116a894984e2DB1123eB395)             |
| ApeChain          | 33139    | [view](https://apescan.io/address/0x0000000000000068F116a894984e2DB1123eB395)                     |
| Arbitrum Nova     | 42170    | [view](https://arbitrum-nova.blockscout.com/address/0x0000000000000068F116a894984e2DB1123eB395)   |
| Arbitrum One      | 42161    | [view](https://arbiscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)                    |
| Avalanche C-Chain | 43114    | [view](https://snowtrace.io/address/0x0000000000000068F116a894984e2DB1123eB395)                   |
| Base              | 8453     | [view](https://basescan.org/address/0x0000000000000068F116a894984e2DB1123eB395)                   |
| Berachain         | 80094    | [view](https://berascan.com/address/0x0000000000000068F116a894984e2DB1123eB395)                   |
| BNB Chain         | 56       | [view](https://bscscan.com/address/0x0000000000000068F116a894984e2DB1123eB395)                    |
| Core              | 1116     | [view](https://scan.coredao.org/address/0x0000000000000068F116a894984e2DB1123eB395)               |
| Cyber             | 7560     | [view](https://cyberscan.co/address/0x0000000000000068F116a894984e2DB1123eB395)                   |
| Ethereum          | 1        | [view](https://etherscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)                   |
| Flow EVM          | 747      | [view](https://evm.flowscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)                |
| Fraxtal           | 252      | [view](https://fraxscan.com/address/0x0000000000000068F116a894984e2DB1123eB395)                   |
| Fuse              | 122      | [view](https://explorer.fuse.io/address/0x0000000000000068F116a894984e2DB1123eB395)               |
| HyperEVM          | 999      | [view](https://hyperevmscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)                |
| Ink               | 57073    | [view](https://explorer.inkonchain.com/address/0x0000000000000068F116a894984e2DB1123eB395)        |
| Kaia              | 8217     | [view](https://kaiascan.io/address/0x0000000000000068F116a894984e2DB1123eB395)                    |
| Katana            | 747474   | [view](https://katanascan.com/address/0x0000000000000068F116a894984e2DB1123eB395)                 |
| Linea             | 59144    | [view](https://lineascan.build/address/0x0000000000000068F116a894984e2DB1123eB395)                |
| Manta Pacific     | 169      | [view](https://pacific-explorer.manta.network/address/0x0000000000000068F116a894984e2DB1123eB395) |
| Mantle            | 5000     | [view](https://mantlescan.xyz/address/0x0000000000000068F116a894984e2DB1123eB395)                 |
| MegaETH           | 4326     | [view](https://mega.etherscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)              |
| Monad             | 143      | [view](https://monadscan.com/address/0x0000000000000068F116a894984e2DB1123eB395)                  |
| OP Mainnet        | 10       | [view](https://optimistic.etherscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)        |
| opBNB             | 204      | [view](https://opbnb.bscscan.com/address/0x0000000000000068F116a894984e2DB1123eB395)              |
| Plasma            | 9745     | [view](https://plasmascan.to/address/0x0000000000000068F116a894984e2DB1123eB395)                  |
| Polygon PoS       | 137      | [view](https://polygonscan.com/address/0x0000000000000068F116a894984e2DB1123eB395)                |
| Ronin             | 2020     | [view](https://app.roninchain.com/address/0x0000000000000068F116a894984e2DB1123eB395)             |
| Scroll            | 534352   | [view](https://scrollscan.com/address/0x0000000000000068F116a894984e2DB1123eB395)                 |
| Sei               | 1329     | [view](https://seiscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)                     |
| Shape             | 360      | [view](https://shapescan.xyz/address/0x0000000000000068F116a894984e2DB1123eB395)                  |
| Soneium           | 1868     | [view](https://soneium.blockscout.com/address/0x0000000000000068F116a894984e2DB1123eB395)         |
| Sonic             | 146      | [view](https://sonicscan.org/address/0x0000000000000068F116a894984e2DB1123eB395)                  |
| Stable            | 988      | [view](https://stablescan.xyz/address/0x0000000000000068F116a894984e2DB1123eB395)                 |
| Story             | 1514     |                                                                                                   |
| Taiko             | 167000   | [view](https://taikoscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)                   |
| Unichain          | 130      | [view](https://uniscan.xyz/address/0x0000000000000068F116a894984e2DB1123eB395)                    |
| X Layer           | 196      | [view](https://www.oklink.com/xlayer/address/0x0000000000000068F116a894984e2DB1123eB395)          |
| zkSync Era        | 324      | [view](https://era.zksync.network/address/0x0000000000000068F116a894984e2DB1123eB395)             |
| Zora              | 7777777  | [view](https://explorer.zora.energy/address/0x0000000000000068F116a894984e2DB1123eB395)           |

### Testnets

| Chain             | Chain ID  | Explorer                                                                                           |
| ----------------- | --------- | -------------------------------------------------------------------------------------------------- |
| Abstract Testnet  | 11124     | [view](https://sepolia.abscan.org/address/0x0000000000000068F116a894984e2DB1123eB395)              |
| Arbitrum Sepolia  | 421614    | [view](https://sepolia.arbiscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)             |
| Avalanche Fuji    | 43113     | [view](https://testnet.snowtrace.io/address/0x0000000000000068F116a894984e2DB1123eB395)            |
| Base Sepolia      | 84532     | [view](https://sepolia.basescan.org/address/0x0000000000000068F116a894984e2DB1123eB395)            |
| BNB Chain Testnet | 97        | [view](https://testnet.bscscan.com/address/0x0000000000000068F116a894984e2DB1123eB395)             |
| Curtis            | 33111     | [view](https://curtis.apescan.io/address/0x0000000000000068F116a894984e2DB1123eB395)               |
| Flow EVM Testnet  | 545       | [view](https://evm-testnet.flowscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)         |
| GUNZ Testnet      | 49321     |                                                                                                    |
| HyperEVM Testnet  | 998       |                                                                                                    |
| Ink Sepolia       | 763373    | [view](https://explorer-sepolia.inkonchain.com/address/0x0000000000000068F116a894984e2DB1123eB395) |
| Kaia Kairos       | 1001      | [view](https://kairos.kaiascan.io/address/0x0000000000000068F116a894984e2DB1123eB395)              |
| Monad Testnet     | 10143     | [view](https://testnet.monadscan.com/address/0x0000000000000068F116a894984e2DB1123eB395)           |
| OP Sepolia        | 11155420  | [view](https://sepolia-optimism.etherscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)   |
| Polygon Amoy      | 80002     | [view](https://amoy.polygonscan.com/address/0x0000000000000068F116a894984e2DB1123eB395)            |
| Ronin Saigon      | 202601    | [view](https://saigon-app.roninchain.com/address/0x0000000000000068F116a894984e2DB1123eB395)       |
| Sei Testnet       | 1328      | [view](https://testnet.seiscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)              |
| Sepolia           | 11155111  | [view](https://sepolia.etherscan.io/address/0x0000000000000068F116a894984e2DB1123eB395)            |
| Shape Sepolia     | 11011     | [view](https://sepolia.shapescan.xyz/address/0x0000000000000068F116a894984e2DB1123eB395)           |
| Soneium Minato    | 1946      | [view](https://soneium-minato.blockscout.com/address/0x0000000000000068F116a894984e2DB1123eB395)   |
| Unichain Sepolia  | 1301      | [view](https://sepolia.uniscan.xyz/address/0x0000000000000068F116a894984e2DB1123eB395)             |
| zkSync Sepolia    | 300       | [view](https://sepolia.explorer.zksync.io/address/0x0000000000000068F116a894984e2DB1123eB395)      |
| Zora Sepolia      | 999999999 | [view](https://sepolia.explorer.zora.energy/address/0x0000000000000068F116a894984e2DB1123eB395)    |

## Seaport 1.5 only

Gnosis, Gnosis Chiado, Celo, Moonbeam, Moonriver, and Fantom (now Sonic) have Seaport 1.5 and the ConduitController but not Seaport 1.6.
