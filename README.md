# Consideration

Consideration is a marketplace contract for safely and efficiently composing and fulfilling orders for ERC721 and ERC1155 items. Each order contains an arbitrary number of items that the offerer is willing to give (the "offer") along with an arbitrary number of items that must be received (the "consideration").

## Order

Each order contains nine key components:
-   The `offerer` of the order supplies all offered items and must either fulfill the order personally (i.e. `msg.sender == offerer`) or approve the order via ECDSA signature or by listing the order on-chain (i.e. calling `validate`).
- The `zone` of the order is an optional secondary account attached to the order with two additional privileges:
   - The zone may cancel orders where it is named as the zone, either for specific orders (by calling `cancel`) or for a whole category of orders (by calling `incrementNonce`).
   - Only the zone or the offerer can fulfill "restricted" orders if specified by the order type.
- The `offer` contains an array of items that may be transferred from the offerer's account, where each item consists of the following components:
   - The `itemType` designates the type of item, with valid types being Ether, ERC20, ERC721, ERC1155, ERC721 with "criteria" (explained below), and ERC1155 with criteria.
   - The `token` designates the account of the item's token contract (with the null address used for Ether).
   - The `identifierOrCriteria` represents either the ERC721 or ERC1155 token identifier or, in the case of a criteria-based item type, a merkle root composed of the valid set of token identifiers for the item. This value will always be zero for Ether and ERC20 item types, and can optionally be zero for criteria-based item types to allow for any identifier.
   - The `startAmount` represents the amount of the item in question that will be required should the order be fulfilled at the moment the order becomes active.
   - The `endAmount` represents the amount of the item in question that will be required should the order be fulfilled at the moment the order expires. If this value differs from the item's `startAmount`, the realized amount is calculated linearly based on the time elapsed since the order became active.
- The `consideration` contains an array of items that must be received in order to fulfill the order. It contains all of the same components as an offered item, and additionally includes a `recipient` that will receive each item.
- The `orderType` designates one of eight types for the order depending on three distinct preferences:
   - `FULL` indicates that the order does not support partial fills, whereas `PARTIAL` enables filling some fraction of the order, with the important caveat that each item must be cleanly divisible by the supplied fraction (i.e. no remainder after division).
   - `OPEN` indicates that the call to execute the order can be submitted by any account, whereas `RESTRICTED` requires that the order can only be executed by either the offerer or the zone of the order.
   - `VIA_PROXY` indicates that items on the order should be transferred via the offerer's "proxy" contract where the respective items have already been approved. Otherwise, the offerer will approve Consideration to transfer items on the order directly.
- The `startTime` indicates the block timestamp at which the order becomes active.
- The `endTime` indicates the block timestamp at which the order expires. This value and the `startTime` are used in conjunction with the `startAmount` and `endAmount` of each item to derive their current amount.
- The `salt` represents an arbitrary source of entropy for the order.
- The `nonce` indicates a value that must match the current nonce for the given offerer+zone pair.

## Order Fulfillment

Orders are fulfilled via one of three methods:
- Calling one of two "standard" functions, `fulfillOrder` and `fulfillAdvancedOrder`, where a second implied order will be constructed with the caller as the offerer, the consideration of the fulfilled order as the offer, and the offer of the fulfilled order as the consideration (with "advanced" orders containing the fraction that should be filled alongside a set of "criteria resolvers" that designate an identifier and a corresponding inclusion proof for each criteria-based item on the fulfilled order).
- Calling one of six "basic" functions that derive the order to fulfill from a subset of components, assuming the order in question adheres to the following:
   - The order only contains a single offer item and contains at least one consideration item
   - The order only contains a single ERC721 or ERC1155 item and that item is not criteria-based
   - All other items have the same Ether or ERC20 item type and token
   - All items have the same `startAmount` and `endAmount`
- Calling one of two "match" functions, `matchOrders` and `matchAdvancedOrders`, where a group of explicit orders are supplied alongside a group of "fulfillments" specifying which offer items to apply to which consideration items (and with the "advanced" case operating in a similar fashion to the standard method).

While the standard method can technically be used for fulfilling any order, it suffers from key efficiency limitations:
- It requires significantly more calldata than the basic method for simple "hot paths".
- It requires the fulfiller to approve each consideration item, even if the consideration item can be fulfilled using an offer item (as is commonly the case when fulfilling an order that offers ERC20 tokens for an ERC721 or ERC1155 token and also includes consideration items in the same ERC20 tokens for paying fees).
- It can result in unnecessary transfers, whereas in the "match" case those transfers can be reduced to a more minimal set.

## Sequence of Events

### Fulfill Order
When fulfilling an order via `fulfillOrder` or `fulfillAdvancedOrder`:
  1. Perform initial validation
     - Ensure current time is inside order range
  2. Hash order
     - Derive hashes for offer items and consideration items
     - Retrieve current nonce for offerer and zone
     - Derive hash for order
  3. Perform context-dependent validation
      - Ensure valid caller for the order type
  4. Retrieve and update order status
     - Ensure order is not cancelled
     - Ensure order is not fully filled
       - If the order is _partially_ filled, reduce the supplied fill amount if necessary so that the order is not overfilled
     - Perform additional validation if not performed previously
       - verify signature
       - other general order validation?
     - Determine fraction to fill based on preference + available amount
     - Update order status (validated + fill fraction)
  5. Determine amount for each item
     - Compare start amount and end amount
       - if they are equal: apply fill fraction to either one, ensure it divides cleanly, and use that amount
       - if not: apply fill fraction to both, ensuring they both divide cleanly, then find linear fit based on current time
  6. Apply criteria resolvers
     - Ensure each criteria resolver refers to a criteria-based order item
     - Ensure the supplied identifier for each item is valid via inclusion proof if the item has a non-zero criteria root
     - Update each item type and identifier
     - Ensure all remaining items are non-criteria-based
  7. Emit OrderFulfilled event
     - Include updated items (i.e. after amount adjustment and criteria resolution)
  8. Transfer offer items from offerer to caller
     - Use either proxy or Consideration directly to source approvals, depending on order type
  9. Transfer consideration items from caller to respective recipients
     - Use either proxy or Consideration directly to source approvals, depending on the fulfiller's stated preference

> Note: the six "basic" fulfillment methods work in a similar fashion, with a few exceptions: they reconstruct the order from a subset of order elements, they skip linear fit amount adjustment and criteria resolution, they require that the full order amount be fillable, and they perform a more minimal set of transfers by default when the offer item shares the same type and token as additional consideration items.

### Match Orders

When matching a group of orders via `matchOrders` or `matchAdvancedOrders`, steps 1 through 7 are nearly identical but are performed for _each_ supplied order. From there, the implementation diverges from standard fulfillments:

  8. Apply fulfillments
     - Ensure each fulfillment refers to one or more offer items and one or more consideration items, all with the same type and token, and with the same approval source for each offer item and the same recipient for each consideration item
     - Reduce the amount on each offer item and each consideration item to zero and track total reduced amounts for each
     - Compare total amounts for each and add back the remaining amount to the first item on the appropriate side of the order
     - Return a single execution for each fulfillment
  9. Scan each consideration item and ensure that none still have a nonzero amount remaining
  10. "Compress" executions into normal executions and "Batch" ERC1155 executions
      - Return early if there are < 2 items or < 2 ERC1155 items
      - Compare ERC1155 items to determine if they can be batched
      - Condense any matching ERC1155 items into batch executions
  11. Perform transfers as part of each execution
      - Use either proxy or Consideration directly to source approvals, depending on the original order type
      - Ignore each execution where `to == from` or `amount == 0` *(NOTE: the current implementation does not perform this last optimization)*

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
