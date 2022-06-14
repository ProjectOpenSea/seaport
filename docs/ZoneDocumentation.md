# Zone Documentation

The `zone` of the order is an optional secondary account attached to the order with two additional privileges:

1. The zone may cancel orders where it is named as the zone by calling `cancel`. (Note that offerers can also cancel their own orders, either individually or for all orders signed with their current counter at once by calling `incrementCounter`).
2. "Restricted" orders (as specified by the order type) must either be executed by the zone or the offerer, or must be approved as indicated by a call to an `isValidOrder` or `isValidOrderIncludingExtraData` view function on the zone.

An example zone contract implementation can be found at `/contracts/zones/GlobalPausable.sol`

The `GlobalPausable` contract can be used by its deployer to cancel specific orders, execute fulfillment on restricted order, and pause all orders which use it as a zone.

## Further implementation

We could use something like this, to allow the owner of the zone to execute restricted orders, but its not entirely necessary

```solidity
function executeRestrictedOrderZone(
    address _globalPausableAddress,
    address _seaportAddress,
    OrderComponents[] calldata orders
) external {
    require(msg.sender == deployerOwner, "Only the owner can execute orders with the zone.");

    GlobalPausable gp = GlobalPausable(_globalPausableAddress);
    gp.executeRestrictedOffer(_seaportAddress, orders);
}
```

## Ideas

Zones are a powerful addition to the idea of simple marketplaces. By adding additional logic to approve / reject Seaport orders, many new applications are possible. Zones could potentially be used by new marketplaces built on top of Seaport to:

- Stop sales of stolen assets
- Limit the number of NFTs from a particular collection that can be sold in a given amount of time
- Enforce a particular floor or ceiling price for certain assets
- Make other arbitrary calls to outside price oracles
- Track extra incentives for users completing valid orders

...and probably more that we haven't even thought of yet!

We encourage anyone in the world to build and deploy your own unique zones and help decentralize Seaport as a platform.
