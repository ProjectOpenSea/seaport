# Seaport function signatures

Function selectors for Seaport 1.6, generated from the build that matches the deployed bytecode. The order functions have kept the selectors they had in Seaport 1.2; `__activateTstore` was added in 1.6.

| Function                             | Selector     |
| ------------------------------------ | ------------ |
| `__activateTstore`                   | `0x7423eb3c` |
| `cancel`                             | `0xfd9f1e10` |
| `fulfillAdvancedOrder`               | `0xe7acab24` |
| `fulfillAvailableAdvancedOrders`     | `0x87201b41` |
| `fulfillAvailableOrders`             | `0xed98a574` |
| `fulfillBasicOrder`                  | `0xfb0f3ee1` |
| `fulfillBasicOrder_efficient_6GL6yc` | `0x00000000` |
| `fulfillOrder`                       | `0xb3a34c4c` |
| `getContractOffererNonce`            | `0xa900866b` |
| `getCounter`                         | `0xf07ec373` |
| `getOrderHash`                       | `0x79df72bd` |
| `getOrderStatus`                     | `0x46423aa7` |
| `incrementCounter`                   | `0x5b34b966` |
| `information`                        | `0xf47b7740` |
| `matchAdvancedOrders`                | `0xf2d12b12` |
| `matchOrders`                        | `0xa8174404` |
| `name`                               | `0x06fdde03` |
| `validate`                           | `0x88147732` |

`fulfillBasicOrder_efficient_6GL6yc` is the same function as `fulfillBasicOrder` under a selector of `0x00000000`, which costs slightly less calldata gas. `__activateTstore` switches the reentrancy guard to transient storage once the chain supports it.
