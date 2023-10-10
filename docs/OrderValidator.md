---
title: Order Validation
category: 6520398b749af50013f52ff4
slug: seaport-order-validator
parentDocSlug: seaport-overview
order: 3
hidden: false
---

# Seaport Order Validator

The SeaportValidator contract offers various validation methods to ensure that supplied Seaport orders are being constructed correctly. Most contract calls return an `ErrorsAndWarnings` struct with two `uint16` arrays to help developers debug issues with their orders.

See below for the full list of Errors and Warnings.

The contract is deployed to the following addresses:

<table>
<tr>
<th>Contract</th>
<th>Canonical Cross-chain Deployment Address</th>
</tr>
<td>SeaportValidator</td>
<td><code>0x00e5F120f500006757E984F1DED400fc00370000</code></td>
</tr>
<tr>
<td>SeaportValidator 1.1 (legacy)</td>
<td><code>0xF75194740067D6E4000000003b350688DD770000</code></td>
</tr>
<tr>
<td>SeaportValidator 1.4 (legacy)</td>
<td><code>0x00000000BE3Af6882A06323fd3f400A9e6A0DC42</code></td>
</tr>
<td>SeaportValidator 1.5 (legacy)</td>
<td><code>0x000000000DD1F1B245b936b2771408555CF8B8af</code></td>
</tr>
</table>

Special thanks to:
- [arr00](https://github.com/arr00), who deployed an earlier version of a SeaportValidator contract which can be found [here](https://etherscan.io/address/0xF75194740067D6E4000000003b350688DD770000#code)
- [stephankmin](https://github.com/stephankmin), who extended the SeaportValidator contract to support more errors/warnings and arbitary Seaport instances with compatible versions
- [horsefacts](https://github.com/horsefacts), who implemented support for a ready-only version of the helper contract

## Errors and Warnings
| Code | Issue | Type
| - | ----------- | - |
| 100 | Invalid order format. Ensure offer/consideration follow requirements | Error |
| 200 | ERC20 identifier must be zero | Error |
| 201 | ERC20 invalid token | Error |
| 202 | ERC20 insufficient allowance to conduit | Error |
| 203 | ERC20 insufficient balance | Error |
| 300 | ERC721 amount must be one | Error |
| 301 | ERC721 token is invalid | Error |
| 302 | ERC721 token with identifier does not exist | Error |
| 303 | ERC721 not owner of token | Error |
| 304 | ERC721 conduit not approved | Error |
| 305 | ERC721 offer item using criteria and more than amount of one requires partial fills | Error |
| 400 | ERC1155 invalid token | Error |
| 401 | ERC1155 conduit not approved | Error |
| 402 | ERC1155 insufficient balance | Error |
| 500 | Consideration amount must not be zero | Error |
| 501 | Consideration recipient must not be null address | Error |
| 502 | Consideration contains extra items | Error |
| 503 | Private sale cannot be to self | Error |
| 504 | Zero consideration items | Warning |
| 505 | Duplicate consideration items | Warning |
| 506 | Offerer is not receiving at least one item | Warning |
| 507 | Private Sale Order. Be careful on fulfillment | Warning |
| 508 | Amount velocity is too high. Amount changes over 5% per 30 min if warning and over 50% per 30 min if error | Both |
| 509 | Amount step large. The steps between each step may be more than expected. Offer items are rounded down and consideration items are rounded up. | Warning |
| 600 | Zero offer items | Warning |
| 601 | Offer amount must not be zero | Error |
| 602 | More than one offer item | Warning |
| 603 | Native offer item | Warning |
| 604 | Duplicate offer item | Error |
| 605 | Amount velocity is too high. Amount changes over 5% per 30 min if warning and over 50% per 30 min if error | Both |
| 606 | Amount step large. The steps between each step may be more than expected. Offer items are rounded down and consideration items are rounded up. | Warning |
| 700 | Primary fee missing | Error |
| 701 | Primary fee item type incorrect | Error |
| 702 | Primary fee token incorrect | Error |
| 703 | Primary fee start amount too low | Error |
| 704 | Primary fee end amount too low | Error |
| 705 | Primary fee recipient incorrect | Error |
| 800 | Order cancelled | Error |
| 801 | Order fully filled | Error |
| 802 | Cannot validate status of contract order | Warning |
| 900 | End time is before start time | Error |
| 901 | Order expired | Error |
| 902 | Order expiration in too long (default 26 weeks) | Warning |
| 903 | Order not active | Warning |
| 904 | Short order duration (default 30 min) | Warning |
| 1000 | Conduit key invalid | Error |
| 1001 | Conduit does not have canonical Seaport as an open channel | Error |
| 1100 | Signature invalid | Error |
| 1101 | Contract orders do not have signatures | Warning |
| 1102 | Signature counter below current counter | Error |
| 1103 | Signature counter above current counter | Error |
| 1104 | Signature may be invalid since `totalOriginalConsiderationItems` is not set correctly | Warning |
| 1200 | Creator fee missing | Error |
| 1201 | Creator fee item type incorrect | Error |
| 1202 | Creator fee token incorrect | Error |
| 1203 | Creator fee start amount too low | Error |
| 1204 | Creator fee end amount too low | Error |
| 1205 | Creator fee recipient incorrect | Error |
| 1300 | Native token address must be null address | Error |
| 1301 | Native token identifier must be zero | Error |
| 1302 | Native token insufficient balance | Error |
| 1400 | Zone is invalid | Warning |
| 1401 | Zone rejected order. This order must be fulfilled by the zone. | Warning |
| 1402 | Zone not set. Order unfulfillable | Error |
| 1500 | Merkle input only has one leaf | Error |
| 1501 | Merkle input not sorted correctly | Error |
| 1600 | Contract offerer is invalid | Warning |
