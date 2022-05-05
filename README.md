![Consideration](img/consideration-banner.png)

# Consideration

Consideration is a marketplace contract for safely and efficiently creating and fulfilling orders for ERC721 and ERC1155 items. Each order contains an arbitrary number of items that the offerer is willing to give (the "offer") along with an arbitrary number of items that must be received along with their respective receivers (the "consideration").

## Order

Each order contains eleven key components:
-   The `offerer` of the order supplies all offered items and must either fulfill the order personally (i.e. `msg.sender == offerer`) or approve the order via signature (either standard 65-byte EDCSA, 64-byte EIP-2098, or an EIP-1271 `isValidSignature` check) or by listing the order on-chain (i.e. calling `validate`).
- The `zone` of the order is an optional secondary account attached to the order with two additional privileges:
   - The zone may cancel orders where it is named as the zone by calling `cancel`. (Note that offerers can also cancel their own orders, either individually or for all orders signed with their current nonce at once by calling `incrementNonce`).
   - "Restricted" orders (as specified by the order type) must either be executed by the zone or the offerer, or must be approved as indicated by a call to an `isValidOrder` or `isValidOrderIncludingExtraData` view function on the zone.
- The `offer` contains an array of items that may be transferred from the offerer's account, where each item consists of the following components:
   - The `itemType` designates the type of item, with valid types being Ether (or other native token for the given chain), ERC20, ERC721, ERC1155, ERC721 with "criteria" (explained below), and ERC1155 with criteria.
   - The `token` designates the account of the item's token contract (with the null address used for Ether or other native tokens).
   - The `identifierOrCriteria` represents either the ERC721 or ERC1155 token identifier or, in the case of a criteria-based item type, a merkle root composed of the valid set of token identifiers for the item. This value will be ignored for Ether and ERC20 item types, and can optionally be zero for criteria-based item types to allow for any identifier.
   - The `startAmount` represents the amount of the item in question that will be required should the order be fulfilled at the moment the order becomes active.
   - The `endAmount` represents the amount of the item in question that will be required should the order be fulfilled at the moment the order expires. If this value differs from the item's `startAmount`, the realized amount is calculated linearly based on the time elapsed since the order became active.
- The `consideration` contains an array of items that must be received in order to fulfill the order. It contains all of the same components as an offered item, and additionally includes a `recipient` that will receive each item. This array may be extended by the fulfiller on order fulfillment so as to support "tipping" (e.g. relayer or referral payments).
- The `orderType` designates one of four types for the order depending on two distinct preferences:
   - `FULL` indicates that the order does not support partial fills, whereas `PARTIAL` enables filling some fraction of the order, with the important caveat that each item must be cleanly divisible by the supplied fraction (i.e. no remainder after division).
   - `OPEN` indicates that the call to execute the order can be submitted by any account, whereas `RESTRICTED` requires that the order either be executed by the offerer or the zone of the order, or that a magic value indicating that the order is approved is returned upon calling an `isValidOrder` or `isValidOrderIncludingExtraData` view function on the zone.
- The `startTime` indicates the block timestamp at which the order becomes active.
- The `endTime` indicates the block timestamp at which the order expires. This value and the `startTime` are used in conjunction with the `startAmount` and `endAmount` of each item to derive their current amount.
- The `zoneHash` represents an arbitrary 32-byte value that will be supplied to the zone when fulfilling restricted orders that the zone can utilize when making a determination on whether to authorize the order.
- The `salt` represents an arbitrary source of entropy for the order.
- The `conduit` represents an optional source for token approvals when performing transfers. By default (i.e. when `conduit` is set to the null address), the offerer will grant ERC20, ERC721, and ERC1155 token approvals to Consideration directly so that it can perform any transfers specified by the order during fulfillment. In contrast, a offerer that elects to utilize a conduit will grant token approvals to the supplied conduit, and Consideration will then instruct that conduit to transfer the respective tokens. Finally, the offerer's legacy user proxy (for ERC721 and ERC1155 items) or the legacy token transfer proxy (for ERC20 items) will be utilized when `conduit` is set to `address(1)`.
- The `nonce` indicates a value that must match the current nonce for the given offerer.

## Order Fulfillment

Orders are fulfilled via one of four methods:
- Calling one of two "standard" functions, `fulfillOrder` and `fulfillAdvancedOrder`, where a second implied order will be constructed with the caller as the offerer, the consideration of the fulfilled order as the offer, and the offer of the fulfilled order as the consideration (with "advanced" orders containing the fraction that should be filled alongside a set of "criteria resolvers" that designate an identifier and a corresponding inclusion proof for each criteria-based item on the fulfilled order). All offer items will be transferred from the offerer of the order to the fulfiller, then all consideration items will be transferred from the fulfiller to the named recipient.
- Calling the "basic" function, `fulfillBasicOrder` with one of six basic route types supplied (`ETH_TO_ERC721`, `ETH_TO_ERC1155`, `ERC20_TO_ERC721`, `ERC20_TO_ERC1155`, `ERC721_TO_ERC20`, and `ERC1155_TO_ERC20`) will derive the order to fulfill from a subset of components, assuming the order in question adheres to the following:
   - The order only contains a single offer item and contains at least one consideration item.
   - The order contains exactly one ERC721 or ERC1155 item and that item is not criteria-based.
   - The offerer of the order is the recipient of the first consideration item.
   - All other items have the same Ether (or other native tokens) or ERC20 item type and token.
   - The order does not offer an item with Ether (or other native tokens) as its item type.
   - The `startAmount` on each item must match that item's `endAmount` (i.e. items cannot have an ascending/descending amount).
   - All "ignored" item fields (i.e. `token` and `identifierOrCriteria` on native items and `identifierOrCriteria` on ERC20 items) are set to the null address or zero.
   - If the order has an ERC721 item, that item has an amount of `1`.
   - If the order has multiple consideration items and all consideration items other than the first consideration item have the same item type as the offered item, the offered item amount is not less than the sum of all consideration item amounts excluding the first consideration item amount.
- Calling one of two "match" functions, `matchOrders` and `matchAdvancedOrders`, where a group of explicit orders are supplied alongside a group of "fulfillments" specifying which offer items to apply to which consideration items (and with the "advanced" case operating in a similar fashion to the standard method, but supporting partial fills via supplied `numerator` and `denominator` fractional values as well as an optional `extraData` argument that will be supplied as part of a call to the `isValidOrderIncludingExtraData` view function on the zone when fulfilling restricted order types).
- Calling a "fulfill available" function, `fulfillAvailableAdvancedOrders`, where a group of orders are supplied alongside a group of fulfillments specifying which offer items can be aggregated into distinct transfers and which consideration items can be accordingly aggregated, and where any orders that have been cancelled, have an invalid time, or have already been fully filled will be skipped without causing the rest of the available orders to revert. Similar to the standard fulfillment method, all offer items will be transferred from the respective offerer to the fulfiller, then all consideration items will be transferred from the fulfiller to the named recipient.

While the standard method can technically be used for fulfilling any order, it suffers from key efficiency limitations in certain scenarios:
- It requires additional calldata compared to the basic method for simple "hot paths".
- It requires the fulfiller to approve each consideration item, even if the consideration item can be fulfilled using an offer item (as is commonly the case when fulfilling an order that offers ERC20 items for an ERC721 or ERC1155 item and also includes consideration items with the same ERC20 item type for paying fees).
- It can result in unnecessary transfers, whereas in the "match" case those transfers can be reduced to a more minimal set.

### Balance & Approval Requirements

When creating an offer, the following requirements should be checked to ensure that the order will be fulfillable:
- The offerer should have sufficient balance of all offered items.
- If the order does not indicate to use a conduit, the offerer should have sufficient approvals set for the Consideration contract for all offered ERC20, ERC721, and ERC1155 items.
- If the order _does_ indicate to use a conduit or a legacy user proxy, the offerer should have sufficient approvals set for the respective conduit contract for all offered ERC20, ERC721 and ERC1155 items. For a conduit of `address(1)`, the offerer should have sufficient approvals set for their legacy user proxy, and on the legacy token transfer proxy for ERC20 items.

When fulfilling a _basic_ order, the following requirements need to be checked to ensure that the order will be fulfillable:
- The above checks need to be performed to ensure that the offerer still has sufficient balance and approvals.
- The fulfiller should have sufficient balance of all consideration items _except for those with an item type that matches the order's offered item type_ — by way of example, if the fulfilled order offers an ERC20 item and requires an ERC721 item to the offerer and the same ERC20 item to another recipient, the fulfiller needs to own the ERC721 item but does not need to own the ERC20 item as it will be sourced from the offerer.
- If the fulfiller does not elect to utilize a conduit, they need to have sufficient approvals set for the Consideration contract for all ERC20, ERC721, and ERC1155 consideration items on the fulfilled order _except for ERC20 items with an item type that matches the order's offered item type_.
- If the fulfiller _does_ elect to utilize a conduit, they need to have sufficient approvals set for their respective conduit, legacy user proxy, and/or legacy token transfer proxy for all ERC20, ERC721, and ERC1155 consideration items on the fulfilled order _except for ERC20 items with an item type that matches the order's offered item type_.
- If the fulfilled order specifies Ether (or other native tokens) as consideration items, the fulfiller must be able to supply the sum total of those items as `msg.value`.

When fulfilling a _standard_ order, the following requirements need to be checked to ensure that the order will be fulfillable:
- The above checks need to be performed to ensure that the offerer still has sufficient balance and approvals.
- The fulfiller should have sufficient balance of all consideration items _after receiving all offered items_ — by way of example, if the fulfilled order offers an ERC20 item and requires an ERC721 item to the offerer and the same ERC20 item to another recipient with an amount less than or equal to the offered amount, the fulfiller does not need to own the ERC20 item as it will first be received from the offerer.
- If the fulfiller does not elect to utilize a conduit, they need to have sufficient approvals set for the Consideration contract for all ERC20, ERC721, and ERC1155 consideration items on the fulfilled order.
- If the fulfiller _does_ elect to utilize a conduit, they need to have sufficient approvals set for their respective conduit, legacy user proxy, and/or legacy token transfer proxy for all ERC20, ERC721, and ERC1155 consideration items on the fulfilled order.
- If the fulfilled order specifies Ether (or other native tokens) as consideration items, the fulfiller must be able to supply the sum total of those items as `msg.value`.

When fulfilling a set of _match_ orders, the following requirements need to be checked to ensure that the order will be fulfillable:
- Each account that sources the ERC20, ERC721, or ERC1155 item for an execution that will be performed as part of the fulfillment must have sufficient balance and approval on Consideration, the respective conduit, or the respective legacy user proxy and/or legacy token transfer proxy at the time the execution is triggered. Note that prior executions may supply the necessary balance for subsequent executions.
- The sum total of all executions involving Ether (or other native tokens) must be supplied as `msg.value`. Note that executions where the offerer and the recipient are the same account will be filtered out of the final execution set.

### Partial Fills

When constructing an order, the offerer may elect to enable partial fills by setting an appropriate order type. Then, orders that support partial fills can be fulfilled for some _fraction_ of the respective order, allowing subsequent fills to bypass signature verification. To summarize a few key points on partial fills:
- When creating orders that support partial fills or determining a fraction to fill on those orders, all items (both offer and consideration) on the order must be cleanly divisible by the supplied fraction (i.e. no remainder after division).
- If the desired fraction to fill would result in more than the full order amount being filled, that fraction will be reduced to the amount remaining to fill. This applies to both partial fill attempts as well as full fill attempts. If this behavior is not desired (i.e. the fill should be "all or none"), the fulfiller can either use a "basic" order method if available (which requires that the full order amount be filled), or use the "match" order method and explicitly provide an order that requires the full desired amount be received back.
   - By way of example: if one fulfiller tries to fill 1/2 of an order but another fulfiller first fills 3/4 of the order, the original fulfiller will end up filling 1/4 of the order.
- If any of the items on a partially fillable order specify a different "startAmount" and "endAmount (e.g. they are ascending-amount or descending-amount items), the fraction will be applied to _both_ amounts prior to determining the current price. This ensures that cleanly divisible amounts can be chosen when constructing the order without a dependency on the time when the order is ultimately fulfilled.
- Partial fills can be combined with criteria-based items to enable constructing orders that offer or receive multiple items that would otherwise not be partially fillable (e.g. ERC721 items).
   - By way of example: an offerer can create a partially fillable order to supply up to 10 ETH for up to 10 ERC721 items from a given collection; then, any fulfiller can fill a portion of that order until it has been fully filled (or cancelled).

## Sequence of Events

### Fulfill Order

When fulfilling an order via `fulfillOrder` or `fulfillAdvancedOrder`:
  1. Hash order
     - Derive hashes for offer items and consideration items
     - Retrieve current nonce for the offerer
     - Derive hash for order
  2. Perform initial validation
      - Ensure current time is inside order range
      - Ensure valid caller for the order type; if the order type is restricted and the caller is not the offerer or the zone, call the zone to determine whether the order is valid
  3. Retrieve and update order status
     - Ensure order is not cancelled
     - Ensure order is not fully filled
       - If the order is _partially_ filled, reduce the supplied fill amount if necessary so that the order is not overfilled
     - Verify the order signature if not already validated
     - Determine fraction to fill based on preference + available amount
     - Update order status (validated + fill fraction)
  4. Determine amount for each item
     - Compare start amount and end amount
       - if they are equal: apply fill fraction to either one, ensure it divides cleanly, and use that amount
       - if not: apply fill fraction to both, ensuring they both divide cleanly, then find linear fit based on current time
  5. Apply criteria resolvers
     - Ensure each criteria resolver refers to a criteria-based order item
     - Ensure the supplied identifier for each item is valid via inclusion proof if the item has a non-zero criteria root
     - Update each item type and identifier
     - Ensure all remaining items are non-criteria-based
  6. Emit OrderFulfilled event
     - Include updated items (i.e. after amount adjustment and criteria resolution)
  7. Transfer offer items from offerer to caller
     - Use either conduit, legacy proxy, or Consideration directly to source approvals, depending on order type
  8. Transfer consideration items from caller to respective recipients
     - Use either conduit, legacy proxy, or Consideration directly to source approvals, depending on the fulfiller's stated preference

> Note: `fulfillBasicOrder` works in a similar fashion, with a few exceptions: it reconstructs the order from a subset of order elements, skips linear fit amount adjustment and criteria resolution, requires that the full order amount be fillable, and performs a more minimal set of transfers by default when the offer item shares the same type and token as additional consideration items.

### Match Orders

When matching a group of orders via `matchOrders` or `matchAdvancedOrders`, steps 1 through 6 are nearly identical but are performed for _each_ supplied order. From there, the implementation diverges from standard fulfillments:

  7. Apply fulfillments
     - Ensure each fulfillment refers to one or more offer items and one or more consideration items, all with the same type and token, and with the same approval source for each offer item and the same recipient for each consideration item
     - Reduce the amount on each offer item and each consideration item to zero and track total reduced amounts for each
     - Compare total amounts for each and add back the remaining amount to the first item on the appropriate side of the order
     - Return a single execution for each fulfillment
  8. Scan each consideration item and ensure that none still have a nonzero amount remaining
  9. "Compress" executions into normal executions and "Batch" ERC1155 executions
      - Return early if there are < 2 items or < 2 ERC1155 items
      - Compare ERC1155 items to determine if they can be batched
      - Condense any matching ERC1155 items into batch executions
  10. Perform transfers as part of each execution
      - Use either conduit, legacy proxy, or Consideration directly to source approvals, depending on the original order type
      - Ignore each execution where `to == from` or `amount == 0` *(NOTE: the current implementation does not perform this last optimization)*

## Known Limitations and Workarounds

- As all offer and consideration items are allocated against one another in memory, there are scenarios in which the actual received item amount will differ from the amount specified by the order — notably, this includes items with a fee-on-transfer mechanic. Orders that contain items of this nature (or, more broadly, items that have some post-fulfillment state that should be met) should leverage "restricted" order types and route the order fulfillment through a zone contract that performs the necessary checks after order fulfillment is completed.
- As all offer items are taken directly from the offerer and all consideration items are given directly to the named recipient, there are scenarios where those accounts can increase the gas cost of order fulfillment or block orders from being fulfilled outright depending on the item being transferred. If the item in question is Ether or a similar native token, a recipient can throw in the payable fallback or even spend excess gas from the submitter. Similar mechanics can be leveraged by both offerers and receives if the item in question is a token with a transfer hook (like ERC1155 and ERC777) or a non-standard token implementation. Potential remediations to this category of issue include wrapping Ether as WETH as a fallback if the initial transfer fails and allowing submitters to specify the amount of gas that should be allocated as part of a given fulfillment. Orders that support explicit fulfillments can also elect to leave problematic or unwanted offer items unspent as long as all consideration items are received in full.
- As fulfillments may be executed in whatever sequence the fulfiller specifies as long as the fulfillments are all executable, as restricted orders are validated via zones prior to execution, and as orders may be combined with other orders or have additional consideration items supplied, any items with modifiable state are at risk of having that state modified during execution if a payable Ether recipient or onReceived 1155 transfer hook is able to modify that state. By way of example, imagine an offerer offers WETH and requires some ERC721 item as consideration, where the ERC721 should have some additional property like not having been used to mint some other ERC721 item. Then, even if the offerer enforces that the ERC721 have that property via a restricted order that checks for the property, a malicious fulfiller could include a second order (or even just an additional consideration item) that uses the ERC721 item being sold to mint before it is transferred to the offerer. One category of remediation for this problem is to use restricted orders that do not implement `isValidOrder` and actually require that order fulfillment is routed through them so that they can perform post-fulfillment validation. Another interesting solution to this problem that retains order composability is to "fight fire with fire" and have the offerer include a "validator" ERC1155 consideration item on orders that require additional assurances; this would be a contract that contains the ERC1155 interface but is not actually an 1155 token, and instead leverages the `onReceived` hook as a means to validate that the expected invariants were upheld, reverting the "transfer" if the check fails (so in the case of the example above, this hook would ensure that the offerer was the owner of the ERC721 item in question and that it had not yet been used to mint the other ERC721). The key limitation to this mechanic is the amount of data that can be supplied in-band via this route; only three arguments ("from", "identifier", and "amount") are available to utilize.
- As all consideration items are supplied at the time of order creation, dynamic adjustment of recipients or amounts after creation (e.g. modifications to royalty payout info) is not supported. However, a zone can enforce that a given restricted order contains _new_ dynamically computed consideration items by deriving them and either supplying them manually or ensuring that they are present via `isValidZoneIncludingExtraData` since consideration items can be extended arbitrarily, with the important caveat that no more than the original offer item amounts can be spent.
- As all criteria-based items are tied to a particular token, there is no native way to construct orders where items specify cross-token criteria. Additionally, each potential identifier for a particular criteria-based item must have the same amount as any other identifier.
- As orders that contain items with ascending or descending amounts may not be filled as quickly as a fulfiller would like (e.g. transactions taking longer than expected to be included), there is a risk that fulfillment on those orders will supply a larger item amount, or receive back a smaller item amount, than they intended or expected. One way to prevent these outcomes is to utilize `matchOrders`, supplying a contrasting order for the fulfiller that explicitly specifies the maximum allowable offer items to be spent and consideration items to be received back. Special care should be taken when handling orders that contain both brief durations as well as items with ascending or descending amounts, as realized amounts may shift appreciably in a short window of time.
- As all items on orders supporting partial fills must be "cleanly divisible" when performing a partial fill, orders with multiple items should to be constructed with care. A straightforward heuristic is to start with a "unit" bundle (e.g. 1 NFT item A, 3 NFT item B, and 5 NFT item C for 2 ETH) then applying a multiple to that unit bundle (e.g. 7 of those units results in a partial order for 7 NFT item A, 21 NFT item B, and 35 NFT item C for 14 ETH).
- As Ether cannot be "taken" from an account, any order that contains Ether or other native tokens as an offer item (including "implied" mirror orders) must be supplied by the caller executing the order(s) as msg.value. This also explains why there are no `ERC721_TO_ERC20` and `ERC1155_TO_ERC20` basic order route types, as Ether cannot be taken from the offerer in these cases. One important takeaway from this mechanic is that, technically, anyone can supply Ether on behalf of a given offerer (whereas the offerer themselves must supply all other items). It also means that all Ether must be supplied at the time the order or group of orders is originally called (and the amount available to spend by offer items cannot be increased by an external source during execution as is the case for token balances).
- As extensions to the consideration array on fulfillment (i.e. "tipping") can be arbitrarily set by the caller, fulfillments where all matched orders have already been signed for or validated can be frontrun on submission, with the frontrunner modifying any tips. Therefore, it is important that orders fulfilled in this manner either leverage "restricted" order types with a zone that enforces appropriate allocation of consideration extensions, or that each offer item is fully spent and each consideration item is appropriately declared on order creation.
- As orders that have been verified (via a call to `validate`) or partially filled will skip signature validation on subsequent fulfillments, orders that utilize EIP-1271 for verifying orders may end up in an inconsistent state where the original signature is no longer valid but the order is still fulfillable. In these cases, the offerer must explicitly cancel the previously verified order in question if they no longer wish for the order to be fulfillable.
- As orders filled by the "fulfill available" method will only be skipped if those orders have been cancelled, fully filled, or are inactive, fulfillments may still be attempted on unfulfillable orders (examples include revoked approvals or insufficient balances). This scenario (as well as issues with order formatting) will result in the full batch failing. One remediation to this failure condition is to perform additional checks from an executing zone or wrapper contract when constructing the call and filtering orders based on those checks.
- As order parameters must be supplied upon cancellation, orders that were meant to remain private (e.g. were not published publically) will be made visible upon cancellation. While these orders would not be _fulfillable_ without a corresponding signature, cancellation of private orders without broadcasting intent currently requires the offerer (or the zone, if the order type is restricted and the zone supports it) to increment the nonce.


## Planned Future Development

Conduits other than `address(0)` (i.e. no conduit) and `address(1)` (the legacy user proxy and legacy token transfer proxy) are not currently supported. This feature still needs to be built out in an efficient and safe manner, including working out an effective methodology for submitting token transfer instructions in batches to cut down on per-conduit calls. This same technique, combined with `HowToCall.delegatecall`, could also be applied to user proxies for ERC721/1155 transfers, as currently each transferred item performs a distinct internal call to the respective user proxy (note that the legacy token transfer proxy does not support call batching).

## Usage

First, install dependencies and compile:
```bash
yarn install
yarn build
```

Next, run linters and tests:
```bash
yarn lint:check
yarn test
yarn coverage
```

To profile gas usage (note that gas usage is mildly non-deterministic at the moment due to random inputs in tests):
```bash
yarn profile
```

### Foundry Test dependencies 
To install dependencies:

```
forge install Rari-Capital/solmate
```

For more information, see [Foundry Book installation instructions](https://book.getfoundry.sh/getting-started/installation.html).
