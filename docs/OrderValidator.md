# Seaport Order Validator

The SeaportValidator contract offers various validation methods to ensure that supplied Seaport orders are being constructed correctly. Most contract calls return an `ErrorsAndWarnings` struct with two `uint16` arrays to help developers debug issues with their orders.

See below for the full list of Errors and Warnings.

The contract has been verified and deployed to [0x00000000be3af6882a06323fd3f400a9e6a0dc42](https://etherscan.io/address/0x00000000be3af6882a06323fd3f400a9e6a0dc42#code).

Special thanks to [arr00](https://github.com/arr00), who deployed an earlier version of a SeaportValidator contract which can be found [here](https://etherscan.io/address/0xF75194740067D6E4000000003b350688DD770000#code).

## Errors and Warnings
| Code | Issue |
| - | ----------- |
| 100 | Invalid order format. Ensure offer/consideration follow requirements |
| 200 | ERC20 identifier must be zero |
| 201 | ERC20 invalid token |
| 202 | ERC20 insufficient allowance to conduit |
| 203 | ERC20 insufficient balance |
| 300 | ERC721 amount must be one |
| 301 | ERC721 token is invalid |
| 302 | ERC721 token with identifier does not exist |
| 303 | ERC721 not owner of token |
| 304 | ERC721 conduit not approved |
| 305 | ERC721 offer item using criteria and more than amount of one requires partial fills |
| 400 | ERC1155 invalid token |
| 401 | ERC1155 conduit not approved |
| 402 | ERC1155 insufficient balance |
| 500 | Consideration amount must not be zero |
| 501 | Consideration recipient must not be null address |
| 502 | Consideration contains extra items |
| 503 | Private sale cannot be to self |
| 504 | Zero consideration items |
| 505 | Duplicate consideration items |
| 506 | Offerer is not receiving at least one item |
| 507 | Private Sale Order. Be careful on fulfillment |
| 508 | Amount velocity is too high. Amount changes over 5% per 30 min if warning and over 50% per 30 min if error |
| 509 | Amount step large. The steps between each step may be more than expected. Offer items are rounded down and consideration items are rounded up. |
| 600 | Zero offer items |
| 601 | Offer amount must not be zero |
| 602 | More than one offer item |
| 603 | Native offer item |
| 604 | Duplicate offer item |
| 605 | Amount velocity is too high. Amount changes over 5% per 30 min if warning and over 50% per 30 min if error |
| 606 | Amount step large. The steps between each step may be more than expected. Offer items are rounded down and consideration items are rounded up. |
| 700 | Primary fee missing |
| 701 | Primary fee item type incorrect |
| 702 | Primary fee token incorrect |
| 703 | Primary fee start amount too low |
| 704 | Primary fee end amount too low |
| 705 | Primary fee recipient incorrect |
| 800 | Order cancelled |
| 801 | Order fully filled |
| 802 | Cannot validate status of contract order
| 900 | End time is before start time |
| 901 | Order expired |
| 902 | Order expiration in too long (default 26 weeks) |
| 903 | Order not active |
| 904 | Short order duration (default 30 min) |
| 1000 | Conduit key invalid |
| 1001 | Conduit does not have canonical Seaport as an open channel |
| 1100 | Signature invalid |
| 1101 | Contract orders do not have signatures |
| 1102 | Signature counter below current counter |
| 1103 | Signature counter above current counter |
| 1104 | Signature may be invalid since `totalOriginalConsiderationItems` is not set correctly |
| 1200 | Creator fee missing |
| 1201 | Creator fee item type incorrect |
| 1202 | Creator fee token incorrect |
| 1203 | Creator fee start amount too low |
| 1204 | Creator fee end amount too low |
| 1205 | Creator fee recipient incorrect |
| 1300 | Native token address must be null address |
| 1301 | Native token identifier must be zero |
| 1302 | Native token insufficient balance |
| 1400 | Zone is invalid |
| 1401 | Zone rejected order. This order must be fulfilled by the zone. |
| 1401 | Zone not set. Order unfulfillable |
| 1500 | Merkle input only has one leaf |
| 1501 | Merkle input not sorted correctly |
| 1600 | Contract offerer is invalid |