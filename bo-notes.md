
# Observations
- Why isn't nonce in order params? Would save an arg in ConsiderationInternalView._getOrderHash
- checking the proxy implementation doesn't actually ensure anything, save gas by skipping that step?
- re ConsiderationInternal#2119: if zero space in memory is allocated for return data during an assembly call, then how will subsequent returndatasize and returndatacopy opcodes behave?
- Can stale orders be invalidated by the user?

# Craziest Assembly
1. ConsiderationInternal._prepareBasicFulfillmentFromCalldata
2. ConsiderationInternalView._getOrderHash

# Inheritance

Consideration
- ConsiderationInternal
  - ConsiderationInternalView
    - ConsiderationPure
      - ConsiderationBase
        - ConsiderationEventsAndErrors

# Enums

Order Types:
- FULL_OPEN
- PARTIAL_OPEN
- FULL_RESTRICTED
- PARTIAL_RESTRICTED

For each supported route type: 2 bool modifiers are available:
- Full/Partial: bool re whether or not partial orders are supported
- Open/Restricted: bool re whether or not the offerer/zone is able to perform extra validation

Route Types:
- ETH -> ERC721
- ETH -> ERC1155
- ERC20 -> ERC721
- ERC20 -> ERC1155
- ERC721 -> ERC20
- ERC1155 -> ERC20

6 (routing types) * 2 (full/partial) * 2 (open/restricted) = 24 Basic Order Types

By taking the enum val & dividing by 4 we can remove the routing info & are left with the order type
