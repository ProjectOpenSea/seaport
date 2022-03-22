# Consideration

Consideration is a marketplace contract for safely and efficiently composing and fulfilling orders for ERC721 and ERC1155 items. Each order contains an arbitrary number of items that the offerer is willing to give (the "offer") along with an arbitrary number of items that must be received along with their respective receivers (the "consideration").

## Order

Each order contains nine key components:
-   The `offerer` of the order supplies all offered items and must either fulfill the order personally (i.e. `msg.sender == offerer`) or approve the order via ECDSA signature or by listing the order on-chain (i.e. calling `validate`).
- The `zone` of the order is an optional secondary account attached to the order with two additional privileges:
   - The zone may cancel orders where it is named as the zone, either for specific orders (by calling `cancel`) or for a whole category of orders (by calling `incrementNonce`).
   - Only the zone or the offerer can fulfill "restricted" orders if specified by the order type.
- The `offer` contains an array of items that may be transferred from the offerer's account, where each item consists of the following components:
   - The `itemType` designates the type of item, with valid types being Ether (or other native token for the given chain), ERC20, ERC721, ERC1155, ERC721 with "criteria" (explained below), and ERC1155 with criteria.
   - The `token` designates the account of the item's token contract (with the null address used for Ether or other native tokens).
   - The `identifierOrCriteria` represents either the ERC721 or ERC1155 token identifier or, in the case of a criteria-based item type, a merkle root composed of the valid set of token identifiers for the item. This value will always be zero for Ether and ERC20 item types, and can optionally be zero for criteria-based item types to allow for any identifier.
   - The `startAmount` represents the amount of the item in question that will be required should the order be fulfilled at the moment the order becomes active.
   - The `endAmount` represents the amount of the item in question that will be required should the order be fulfilled at the moment the order expires. If this value differs from the item's `startAmount`, the realized amount is calculated linearly based on the time elapsed since the order became active.
- The `consideration` contains an array of items that must be received in order to fulfill the order. It contains all of the same components as an offered item, and additionally includes a `recipient` that will receive each item.
- The `orderType` designates one of eight types for the order depending on three distinct preferences:
   - `FULL` indicates that the order does not support partial fills, whereas `PARTIAL` enables filling some fraction of the order, with the important caveat that each item must be cleanly divisible by the supplied fraction (i.e. no remainder after division).
   - `OPEN` indicates that the call to execute the order can be submitted by any account, whereas `RESTRICTED` requires that the order can only be executed by either the offerer or the zone of the order.
   - `VIA_PROXY` indicates that ERC721 and ERC1155 items on the order should be transferred via the offerer's "proxy" contract where the respective items have already been approved. Otherwise, the offerer will approve Consideration to transfer items on the order directly.
- The `startTime` indicates the block timestamp at which the order becomes active.
- The `endTime` indicates the block timestamp at which the order expires. This value and the `startTime` are used in conjunction with the `startAmount` and `endAmount` of each item to derive their current amount.
- The `salt` represents an arbitrary source of entropy for the order.
- The `nonce` indicates a value that must match the current nonce for the given offerer+zone pair.

## Order Fulfillment

Orders are fulfilled via one of three methods:
- Calling one of two "standard" functions, `fulfillOrder` and `fulfillAdvancedOrder`, where a second implied order will be constructed with the caller as the offerer, the consideration of the fulfilled order as the offer, and the offer of the fulfilled order as the consideration (with "advanced" orders containing the fraction that should be filled alongside a set of "criteria resolvers" that designate an identifier and a corresponding inclusion proof for each criteria-based item on the fulfilled order).
- Calling one of six "basic" functions, `fulfillBasicEthForERC721Order`, `fulfillBasicEthForERC1155Order`, `fulfillBasicERC20ForERC721Order`, `fulfillBasicERC20ForERC1155Order`, `fulfillBasicERC721ForERC20Order`, and `fulfillBasicERC1155ForERC20Order`, that derive the order to fulfill from a subset of components, assuming the order in question adheres to the following:
   - The order only contains a single offer item and contains at least one consideration item.
   - The order contains exactly one ERC721 or ERC1155 item and that item is not criteria-based.
   - The offerer of the order is the recipient of the first consideration item.
   - All other items have the same Ether (or other native tokens) or ERC20 item type and token.
   - The order does not offer an item with Ether (or other native tokens) as its item type.
   - The `startAmount` on each item must match that item's `endAmount` (i.e. items cannot have an ascending/descending amount).
   - All "ignored" item fields (i.e. `token` and `identifierOrCriteria` on native items and `identifierOrCriteria` on ERC20 items) are set to the null address or zero.
   - If the order has an ERC721 item, that item has an amount of `1`.
   - If the order has multiple consideration items and all consideration items other than the first consideration item have the same item type as the offered item, the offered item amount is not less than the sum of all consideration item amounts excluding the first consideration item amount.
- Calling one of two "match" functions, `matchOrders` and `matchAdvancedOrders`, where a group of explicit orders are supplied alongside a group of "fulfillments" specifying which offer items to apply to which consideration items (and with the "advanced" case operating in a similar fashion to the standard method).

While the standard method can technically be used for fulfilling any order, it suffers from key efficiency limitations:
- It requires significantly more calldata than the basic method for simple "hot paths".
- It requires the fulfiller to approve each consideration item, even if the consideration item can be fulfilled using an offer item (as is commonly the case when fulfilling an order that offers ERC20 items for an ERC721 or ERC1155 item and also includes consideration items with the same ERC20 item type for paying fees).
- It can result in unnecessary transfers, whereas in the "match" case those transfers can be reduced to a more minimal set.

### Balance & Approval Requirements
When creating an offer, the following requirements should be checked to ensure that the order will be fulfillable:
- The offerer should have sufficient balance of all offered items.
- If the order does not indicate proxy utilization, the offerer should have sufficient approvals set for the Consideration contract for all offered ERC20, ERC721, and ERC1155 items.
- If the order _does_ indicate proxy utilization, the offerer should have sufficient approvals set for their respective proxy contract for all offered ERC20, ERC721, and ERC1155 items.

When fulfilling a _basic_ order, the following requirements need to be checked to ensure that the order will be fulfillable:
- The above checks need to be performed to ensure that the offerer still has sufficient balance and approvals.
- The fulfiller should have sufficient balance of all consideration items _except for those with an item type that matches the order's offered item type_ — by way of example, if the fulfilled order offers an ERC20 item and requires an ERC721 item to the offerer and the same ERC20 item to another recipient, the fulfiller needs to own the ERC721 item but does not need to own the ERC20 item as it will be sourced from the offerer.
- If the fulfiller does not elect to utilize a proxy, they need to have sufficient approvals set for the Consideration contract for all ERC20, ERC721, and ERC1155 consideration items on the fulfilled order _except for ERC20 items with an item type that matches the order's offered item type_.
- If the fulfiller _does_ elect to utilize a proxy, they need to have sufficient approvals set for their respective proxy contract for all ERC20, ERC721, and ERC1155 consideration items on the fulfilled order _except for ERC20 items with an item type that matches the order's offered item type_.
- If the fulfilled order specifies Ether (or other native tokens) as consideration items, the fulfiller must be able to supply the sum total of those items as `msg.value`.

When fulfilling a _standard_ order, the following requirements need to be checked to ensure that the order will be fulfillable:
- The above checks need to be performed to ensure that the offerer still has sufficient balance and approvals.
- The fulfiller should have sufficient balance of all consideration items _after receiving all offered items_ — by way of example, if the fulfilled order offers an ERC20 item and requires an ERC721 item to the offerer and the same ERC20 item to another recipient with an amount less than or equal to the offered amount, the fulfiller does not need to own the ERC20 item as it will first be received from the offerer.
- If the fulfiller does not elect to utilize a proxy, they need to have sufficient approvals set for the Consideration contract for all ERC20, ERC721, and ERC1155 consideration items on the fulfilled order.
- If the fulfiller _does_ elect to utilize a proxy, they need to have sufficient approvals set for their respective proxy contract for all ERC20, ERC721, and ERC1155 consideration items on the fulfilled order.
- If the fulfilled order specifies Ether (or other native tokens) as consideration items, the fulfiller must be able to supply the sum total of those items as `msg.value`.

When fulfilling a set of _match_ orders, the following requirements need to be checked to ensure that the order will be fulfillable:
- Each account that sources the ERC20, ERC721, or ERC1155 item for an execution that will be performed as part of the fulfillment must have sufficient balance and approval on the relevant operator (depending on the order's proxy utilization preference) at the time the execution is triggered. Note that prior executions may supply the necessary balance for subsequent executions.
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
     - Retrieve current nonce for offerer and zone
     - Derive hash for order
  2. Perform initial validation
      - Ensure current time is inside order range
      - Ensure valid caller for the order type
  3. Retrieve and update order status
     - Ensure order is not cancelled
     - Ensure order is not fully filled
       - If the order is _partially_ filled, reduce the supplied fill amount if necessary so that the order is not overfilled
     - Perform additional validation if not performed previously
       - verify signature
       - other general order validation?
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
     - Use either proxy or Consideration directly to source approvals, depending on order type
  8. Transfer consideration items from caller to respective recipients
     - Use either proxy or Consideration directly to source approvals, depending on the fulfiller's stated preference

> Note: the six "basic" fulfillment methods work in a similar fashion, with a few exceptions: they reconstruct the order from a subset of order elements, they skip linear fit amount adjustment and criteria resolution, they require that the full order amount be fillable, and they perform a more minimal set of transfers by default when the offer item shares the same type and token as additional consideration items.

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
      - Use either proxy or Consideration directly to source approvals, depending on the original order type
      - Ignore each execution where `to == from` or `amount == 0` *(NOTE: the current implementation does not perform this last optimization)*

## Known Limitations
- As all offer and consideration items are allocated against one another in memory, there are scenarios in which the actual received item amount will differ from the amount specified by the order — notably, this includes items with a fee-on-transfer mechanic. Orders that contain items of this nature (or, more broadly, items that have some post-fulfillment state that should be met) should leverage "restricted" order types and route the order fulfillment through a zone contract that performs the necessary checks.
- As all offer items are taken directly from the offerer and all consideration items are given directly to the named recipient, there are scenarios where those accounts can increase the gas cost of order fulfillment or block orders from being fulfilled outright depending on the item being transferred. If the item in question is Ether or a similar native token, a recipient can throw in the payable fallback or even spend excess gas from the submitter. Similar mechanics can be leveraged by both offerers and receives if the item in question is a token with a transfer hook (like ERC1155 and ERC777) or a non-standard token implementation. Potential remediations to this category of issue include wrapping Ether as WETH as a fallback if the initial transfer fails and allowing submitters to specify the amount of gas that should be allocated as part of a given fulfillment.
- As all consideration items are supplied at the time of order creation, dynamic adjustment of recipients or amounts after creation (e.g. modifications to royalty payout info) is not supported. A workaround would be to name a zone as a consideration recipient and have the zone compute the intended recipient or amount and use that to relay the item in question, returning any excess to the fulfiller.
- As all criteria-based items are tied to a particular token, there is no native way to construct orders where items specify cross-token criteria. Additionally, each potential identifier for a particular criteria-based item must have the same amount as any other identifier.
- As orders with ascending and descending amounts may not be filled as quickly as a fulfiller would like (e.g. transactions taking longer than expected to be included), there is a risk that fulfillment on those orders will supply a larger item amount, or receive back a smaller item amount, than they intended or expected. One way to prevent these outcomes is to utilize matchOrders, supplying a contrasting order for the fulfiller that explicitly specifies the maximum allowable offer items to be spent and consideration items to be received back.
- As all items on orders supporting partial fills must be "cleanly divisible" when performing a partial fill, orders with multiple items should to be constructed with care. A straightforward heuristic is to start with a "unit" bundle (e.g. 1 NFT item A, 3 NFT item B, and 5 NFT item C for 2 ETH) then applying a multiple to that unit bundle (e.g. 7 of those units results in a partial order for 7 NFT item A, 21 NFT item B, and 35 NFT item C for 14 ETH).
- As Ether cannot be "taken" from an account, any order that contains Ether or other native tokens as an offer item (including "implied" mirror orders) must be supplied by the caller executing the order(s) as msg.value. This also explains why there are no `fulfillBasicERC721ForEthOrder` and `fulfillBasicERC1155ForEthOrder` functions, as Ether cannot be taken from the offerer in these cases. One important takeaway from this mechanic is that, technically, anyone can supply Ether on behalf of a given offerer (whereas the offerer themselves must supply all other items).
- As restricted orders must be fulfilled by the named zone, multiple restricted orders with differing zones cannot be composed via `matchOrders` — they must either be fulfilled independently or make use of a shared zone that routes orders in accordance with the requirements of each original zone.

## Local Development

1. Installing Packages:
   `yarn install`

2. Running Tests:
   `REPORT_GAS=true npx hardhat test`

3. Other commands
   `npx hardhat coverage`
   `npx hardhat compile`
   `npx solhint 'contracts/**/*.sol'`
   `npx hardhat node`

## Deploying

`npx hardhat run scripts/deploy.ts`
