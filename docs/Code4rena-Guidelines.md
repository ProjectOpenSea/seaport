# Code4rena Guidelines

## Overview:

Seaport is a marketplace protocol for safely and efficiently buying and selling NFTs. Each listing contains an arbitrary number of items that the offerer is willing to give (the "offer") along with an arbitrary number of items that must be received along with their respective receivers (the "consideration").

## In Scope

At a high level, the core invariants that we expect to be upheld are that:

- Only items that are explicitly offered as part of a valid order may be transferred from an offerer’s account as long as they only set token approvals on either Seaport directly or on a conduit that only has Seaport set as a channel.
- No order fulfillment may spend more than the offer items that are explicitly set for the order in question. Note that not all offer items need to be spent.
- All consideration items (or fractions thereof in the case of orders that support partial fills) must be received in full by the named recipients in order for the corresponding offer items (or fractions thereof) to be spent. Note that additional consideration items may be added to any order on fulfillment as “tips”. Note also that when calling any fulfillment method other than `matchOrders` or `matchAdvancedOrders` that an implied “mirror” order is created for the fulfiller and so offer items on fulfilled orders should be treated as consideration items for the fulfiller (with the exception of `fulfillBasicOrder` where ERC721 ⇒ ERC20 and ERC1155 ⇒ ERC20 route types will use a portion of the offered item on the fulfilled order to pay out consideration items on that order).
- In all cases, assume that that all items contain standard ERC20/721/1155 behavior. This may include popular tokens or contracts (though reporting particular tokens that would violate these invariants would be categorized as a low-severity finding).

## Out of scope

There are a number of known limitations that are explicitly out of scope for the context of the competition:

- As a malicious or vulnerable conduit owner may set a channel on a conduit that allows for approved tokens to be taken at will, we make the assumption in the context of this contest that only the Seaport contract will be added as a channel to any conduit.
- As all offer and consideration items are allocated against one another in memory, there are scenarios in which the actual received item amount will differ from the amount specified by the order — notably, this includes items with a fee-on-transfer mechanic.
- As all offer items are taken directly from the offerer and all consideration items are given directly to the named recipient, there are scenarios where those accounts can increase the gas cost of order fulfillment or block orders from being fulfilled outright depending on the item being transferred. If the item in question is Ether or a similar native token, a recipient can throw in the payable fallback or even spend excess gas from the submitter. Similar mechanics can be leveraged by both offerers and receives if the item in question is a token with a transfer hook (like ERC1155 and ERC777) or a non-standard token implementation.
- As fulfillments may be executed in whatever sequence the fulfiller specifies as long as the fulfillments are all executable, as restricted orders are validated via zones prior to execution, and as orders may be combined with other orders or have additional consideration items supplied, **any items with modifiable state are at risk of having that state modified during execution** if a payable Ether recipient or onReceived 1155 transfer hook is able to modify that state. By way of example, imagine an offerer offers WETH and requires some ERC721 item as consideration, where the ERC721 should have some additional property like not having been used to mint some other ERC721 item. Then, even if the offerer enforces that the ERC721 have that property via a restricted order that checks for the property, a malicious fulfiller could include a second order (or even just an additional consideration item) that uses the ERC721 item being sold to mint before it is transferred to the offerer.
- As all consideration items are supplied at the time of order creation, dynamic adjustment of recipients or amounts after creation (e.g. modifications to royalty payout info) is not supported.
- As all criteria-based items are tied to a particular token, there is no native way to construct orders where items specify cross-token criteria. Additionally, each potential identifier for a particular criteria-based item must have the same amount as any other identifier.
- As orders that contain items with ascending or descending amounts may not be filled as quickly as a fulfiller would like (e.g. transactions taking longer than expected to be included), there is a risk that fulfillment on those orders will supply a larger item amount, or receive back a smaller item amount, than they intended or expected.
- As all items on orders supporting partial fills must be "cleanly divisible" when performing a partial fill, orders with multiple items should to be constructed with care. A straightforward heuristic is to start with a "unit" bundle (e.g. 1 NFT item A, 3 NFT item B, and 5 NFT item C for 2 ETH) then applying a multiple to that unit bundle (e.g. 7 of those units results in a partial order for 7 NFT item A, 21 NFT item B, and 35 NFT item C for 14 ETH).
- As Ether cannot be "taken" from an account, any order that contains Ether or other native tokens as an offer item (including "implied" mirror orders) must be supplied by the caller executing the order(s) as msg.value. This also explains why there are no `ERC721_TO_ERC20` and `ERC1155_TO_ERC20` basic order route types, as Ether cannot be taken from the offerer in these cases. One important takeaway from this mechanic is that, technically, anyone can supply Ether on behalf of a given offerer (whereas the offerer themselves must supply all other items). It also means that all Ether must be supplied at the time the order or group of orders is originally called (and the amount available to spend by offer items cannot be increased by an external source during execution as is the case for token balances).
- As extensions to the consideration array on fulfillment (i.e. "tipping") can be arbitrarily set by the caller, fulfillments where all matched orders have already been signed for or validated can be frontrun on submission, with the frontrunner modifying any tips. Therefore, it is important that orders fulfilled in this manner either leverage "restricted" order types with a zone that enforces appropriate allocation of consideration extensions, or that each offer item is fully spent and each consideration item is appropriately declared on order creation.
- As orders that have been verified (via a call to `validate`) or partially filled will skip signature validation on subsequent fulfillments, orders that utilize EIP-1271 for verifying orders may end up in an inconsistent state where the original signature is no longer valid but the order is still fulfillable. In these cases, the offerer must explicitly cancel the previously verified order in question if they no longer wish for the order to be fulfillable.
- As orders filled by the "fulfill available" method will only be skipped if those orders have been cancelled, fully filled, or are inactive, fulfillments may still be attempted on unfulfillable orders (examples include revoked approvals or insufficient balances). This scenario (as well as issues with order formatting) will result in the full batch failing.
- As order parameters must be supplied upon cancellation, orders that were meant to remain private (e.g. were not published publicly) will be made visible upon cancellation. While these orders would not be *fulfillable* without a corresponding signature, cancellation of private orders without broadcasting intent currently requires the offerer (or the zone, if the order type is restricted and the zone supports it) to increment the nonce.
- As order fulfillment attempts may become public before being included in a block, there is a risk of those orders being front-run. This risk is magnified in cases where offered items contain ascending amounts or consideration items contain descending amounts, as there is added incentive to leave the order unfulfilled until another interested fulfiller attempts to fulfill the order in question.
- As validated orders may still be unfulfillable due to invalid item amounts or other factors, callers should determine whether validated orders are fulfillable by simulating the fulfillment call prior to execution. Also note that anyone can validate a signed order, but only the offerer can validate an order without supplying a signature.
- As the offerer or the zone of a given order may cancel an order that differs from the intended order, callers should ensure that the intended order was cancelled by calling `getOrderStatus` and confirming that `isCancelled` returns `true`.
- As all derived amounts of partial fills and ascending/descending orders need to be derived without integer overflows, some categories of order may end up in a state where they can no longer be fulfilled due to reverting amount calculations.
- As many functions expect the default ABI encoding to be used, calling functions with non-standard encoding should not be expected to succeed.
- As ERC1271-compliant wallets implement their own signature verification, there is a risk that an improperly configured ERC1271 offerer could have funds stolen due to overly permissive signature verification.
- More generally, any finding reported in the Trail of Bits audit is additionally out of scope.

## Tiers:

**Low / Informational:** 

- Informational issues, like returning the wrong error type.
- Issues with the reference implementation where behavior does not map 1:1 with the optimized contracts (with the exception of revert reasons as some are not reproducible without optimizations)
- Gas optimizations.

**Medium:**

- Any behavior that is not in line with expected behavior on standard interaction with the protocol (bearing in mind all known limitations) — this would include a halt of functionality where orders that should succeed revert, or edge cases that do not result in widespread loss of funds but might lead to a small subset of funds being at risk.

**High / Critical**

- Any of the core invariants listed above being exploitable in a manner that places most or all user funds at risk.

### **Areas of focus**

While wardens should submit any bugs they identify for review, we particularly encourage review of code which has any of the following:

- transfer of multiple assets
- arithmetic for order amounts
- aggregation of fulfillments
    - FulfillmentApplier.sol
- transfer accumulation
    - Executor.sol
    - OrderCombiner.sol
    - OrderFulfiller.sol
    - BasicOrderFulfiller.sol
- low-level handling of nested dynamic types in calldata or loaded from calldata
    - OrderFulfiller.sol
    - BasicOrderFulfiller.sol
    - FulfillmentApplier.sol
    - GettersAndDerivers.sol
    - CriteriaResolution.sol
- order matching / fulfillment validation
    - OrderFulfiller.sol
    - BasicOrderFulfiller.sol
    - OrderCombiner.sol
    - FulfillmentApplier.sol
    - CriteriaResolution.sol

## **Tests**

A full suite of unit tests using Hardhat and Foundry have been provided in this repo, found in the `test` folder.

## Information:

[https://docs.opensea.io/v2.0/reference/seaport-overview](https://docs.opensea.io/v2.0/reference/seaport-overview)

### Reference Implementation:

The reference folder has its own implementation of Seaport which is designed to be readable and have feature parity with the Seaport.sol. We created the Reference implementation because a lot of Seaport is optimized by using assembly and interesting memory management techniques, that often make the code hard to read and understand. The Reference should be easy to read and work the same exact way, but it is NOT what is deployed. So if you find an issue with parity or a bug / vulnerability in the reference implementation, please report it but be advised that it will not classify as a medium or high-severity finding.

## Test contracts

Test contracts and non-solidity files are explicitly out of scope for the competition, though issues and PRs with any new tests you write as part of your investigation are greatly appreciated.