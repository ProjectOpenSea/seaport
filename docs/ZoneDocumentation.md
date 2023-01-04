# Zone Documentation

The `zone` of the order is an optional secondary account attached to the order with two additional privileges:

1. The zone may cancel orders where it is named as the zone by calling `cancel`. (Note that offerers can also cancel their own orders, either individually or for all orders signed with their current counter at once by calling `incrementCounter`).
2. "Restricted" orders (as specified by the order type) must be approved as indicated by a call to a `validateOrder` when the caller is not the zone.

An example zone contract implementation can be found at `/contracts/zones/PausableZone.sol`.

The `PausableZone` contract can be used by its controller to cancel orders, execute fulfillment on restricted order, and pause all orders which use it as a zone.

## Ideas

New zones can be permissionlessly deployed and utilized to extend the feature set of the core Seaport marketplace. Examples include:

- Helping to prevent sales of compromised items
- Pausing orders in case of an emergency without invalidating approvals
- Limiting the number of NFTs from a particular collection that can be sold in a given amount of time
- Enforcing a particular floor or ceiling price for certain items
- Making arbitrary calls to outside data sources
- Tracking additional incentives for completing valid orders
