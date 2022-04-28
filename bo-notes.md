_lets go

# Observations
- checking the proxy implementation doesn't actually ensure anything, save gas by skipping that step? BUT WAIT if the proxy implementation code hash 
- re ConsiderationInternal#2119: if zero space in memory is allocated for return data during an assembly call, then how will subsequent returndatasize and returndatacopy opcodes behave?
- Can stale orders be invalidated by the user? YES by calling incrementNonce()

# Validate Trace
- op#147  => sload _reentrancyGuard on ConsiderationInternalView#65
- op#1059 => sload _nonces on ConsiderationInternalView#514
- op#1063 => jump into _getOrderHash on ConsiderationInternalView#346
- op#1075 => mload FreeMemoryPointerSlot (0x0040=>0x03c0) on ConsiderationInternalView#371
- op#1080 => mload offerArrPtr (0x00c0=>0x01e0) on ConsiderationInternalView#371
- op#1083 => mload offerLength (0x01e0=>0x0001) on ConsiderationInternalView#377
- op#1106 => mload ptr (0x0200=>0x0220) on ConsiderationInternalView#389
- op#1109 => mload value (0x0200=>0x0220) on ConsiderationInternalView#392 (WARNING: same as prev mload)
- op#1116 => hash EIP712 type on ConsiderationInternalView#398
- op#1142 => mload FreeMemoryPointerSlot (0x0040=>0x03c0) on ConsiderationInternalView#410
- op#1147 => hash offer on ConsiderationInternalView#409
- WARNING: FreeMemoryPointerSlot mload was optimized out on ConsiderationInternalView#424
- op#1158 => mload orderParameters + offset (0x00e0=>0x02c0) on ConsiderationInternalView#428
- op#1177 => mload considerationArrPtr (0x02e0=>0x0300) on ConsiderationInternalView#439
- op#1180 => mload ptr (0x02e0=>0x0300) on ConsiderationInternalView#442 (WARNING: same as prev mload)
- op#1187 => hash EIP712 type on ConsiderationInternalView#448
- op#1215 => mload FreeMemoryPointerSlot (0x0040=>0x03c0) on ConsiderationInternalView#460
- op#1216 => hash consideration on ConsiderationInternalView#459
- op#1223 => mload previousValue (0x0060=>0x0000) on ConsiderationInternalView#471
- op#1229 => mload offerDataPtr (0x00c0=>0x01e0) on ConsiderationInternalView#475
- op#1234 => mload considerationDataPtr (0x00e0=>0x02c0) on ConsiderationInternalView#479
- op#1242 => hash order on ConsiderationInternalView#485
- op#1248 => jump out of _getOrderHash on ConsiderationInternalView#491
- op#1304 => sload _orderStatus on Consideration#739
- op#1561 => get msg.sender on ConsiderationInternalView#186
- op#1589 => sload _orderStatus on Consideration#755
- op#1596 => sstore _orderStatus on Consideration#755

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
