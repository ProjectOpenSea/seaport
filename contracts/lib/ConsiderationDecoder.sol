import { BasicOrderParameters, Order, CriteriaResolver, AdvancedOrder, FulfillmentComponent, Execution, Fulfillment, OrderComponents } from "./ConsiderationStructs.sol";
import "./PointerLibraries.sol";

uint256 constant BasicOrderParameters_head_size = 0x0240;
uint256 constant BasicOrderParameters_fixed_segment_0 = 0x0200;
uint256 constant BasicOrderParameters_additionalRecipients_offset = 0x0200;
uint256 constant AdditionalRecipient_mem_tail_size = 0x40;
uint256 constant BasicOrderParameters_signature_offset = 0x0220;
uint256 constant AlmostTwoWords = 0x3f;
uint256 constant OnlyFullWordMask = 0xffffe0;
uint256 constant Order_head_size = 0x40;
uint256 constant OrderParameters_head_size = 0x0160;
uint256 constant OrderParameters_offer_offset = 0x40;
uint256 constant OfferItem_mem_tail_size = 0xa0;
uint256 constant OrderParameters_consideration_offset = 0x60;
uint256 constant ConsiderationItem_mem_tail_size = 0xc0;
uint256 constant Order_signature_offset = 0x20;
uint256 constant AdvancedOrder_head_size = 0xa0;
uint256 constant AdvancedOrder_fixed_segment_0 = 0x40;
uint256 constant AdvancedOrder_numerator_offset = 0x20;
uint256 constant AdvancedOrder_signature_offset = 0x60;
uint256 constant AdvancedOrder_extraData_offset = 0x80;
uint256 constant CriteriaResolver_head_size = 0xa0;
uint256 constant CriteriaResolver_fixed_segment_0 = 0x80;
uint256 constant CriteriaResolver_criteriaProof_offset = 0x80;
uint256 constant FulfillmentComponent_mem_tail_size = 0x40;
uint256 constant Fulfillment_head_size = 0x40;
uint256 constant Fulfillment_considerationComponents_offset = 0x20;
uint256 constant OrderComponents_head_size = 0x0160;
uint256 constant OrderComponents_offer_offset = 0x40;
uint256 constant OrderComponents_consideration_offset = 0x60;

function abi_decode_dyn_array_AdditionalRecipient(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  assembly {
    let arrLength := and(calldataload(cdPtrLength), OffsetOrLengthMask)
    mPtrLength := mload(0x40)
    mstore(mPtrLength, arrLength)
    let mPtrHead := add(mPtrLength, 32)
    let mPtrTail := add(mPtrHead, mul(arrLength, 0x20))
    let mPtrTailNext := mPtrTail
    calldatacopy(mPtrTail, add(cdPtrLength, 0x20), mul(arrLength, AdditionalRecipient_mem_tail_size))
    let mPtrHeadNext := mPtrHead
    for {} lt(mPtrHeadNext, mPtrTail) {} {
      mstore(mPtrHeadNext, mPtrTailNext)
      mPtrHeadNext := add(mPtrHeadNext, 0x20)
      mPtrTailNext := add(mPtrTailNext, AdditionalRecipient_mem_tail_size)
    }
    mstore(0x40, mPtrTailNext)
  }
}

function abi_decode_bytes(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  assembly {
    mPtrLength := mload(0x40)
    let size := and(add(and(calldataload(cdPtrLength), OffsetOrLengthMask), AlmostTwoWords), OnlyFullWordMask)
    calldatacopy(mPtrLength, cdPtrLength, size)
    mstore(0x40, add(mPtrLength, size))
  }
}

function abi_decode_BasicOrderParameters(CalldataPointer cdPtr) pure returns (MemoryPointer mPtr) {
  mPtr = malloc(BasicOrderParameters_head_size);
  cdPtr.copy(mPtr, BasicOrderParameters_fixed_segment_0);
  mPtr.offset(BasicOrderParameters_additionalRecipients_offset).write(abi_decode_dyn_array_AdditionalRecipient(cdPtr.pptr(BasicOrderParameters_additionalRecipients_offset)));
  mPtr.offset(BasicOrderParameters_signature_offset).write(abi_decode_bytes(cdPtr.pptr(BasicOrderParameters_signature_offset)));
}

function abi_decode_dyn_array_OfferItem(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  assembly {
    let arrLength := and(calldataload(cdPtrLength), OffsetOrLengthMask)
    mPtrLength := mload(0x40)
    mstore(mPtrLength, arrLength)
    let mPtrHead := add(mPtrLength, 32)
    let mPtrTail := add(mPtrHead, mul(arrLength, 0x20))
    let mPtrTailNext := mPtrTail
    calldatacopy(mPtrTail, add(cdPtrLength, 0x20), mul(arrLength, OfferItem_mem_tail_size))
    let mPtrHeadNext := mPtrHead
    for {} lt(mPtrHeadNext, mPtrTail) {} {
      mstore(mPtrHeadNext, mPtrTailNext)
      mPtrHeadNext := add(mPtrHeadNext, 0x20)
      mPtrTailNext := add(mPtrTailNext, OfferItem_mem_tail_size)
    }
    mstore(0x40, mPtrTailNext)
  }
}

function abi_decode_dyn_array_ConsiderationItem(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  assembly {
    let arrLength := and(calldataload(cdPtrLength), OffsetOrLengthMask)
    mPtrLength := mload(0x40)
    mstore(mPtrLength, arrLength)
    let mPtrHead := add(mPtrLength, 32)
    let mPtrTail := add(mPtrHead, mul(arrLength, 0x20))
    let mPtrTailNext := mPtrTail
    calldatacopy(mPtrTail, add(cdPtrLength, 0x20), mul(arrLength, ConsiderationItem_mem_tail_size))
    let mPtrHeadNext := mPtrHead
    for {} lt(mPtrHeadNext, mPtrTail) {} {
      mstore(mPtrHeadNext, mPtrTailNext)
      mPtrHeadNext := add(mPtrHeadNext, 0x20)
      mPtrTailNext := add(mPtrTailNext, ConsiderationItem_mem_tail_size)
    }
    mstore(0x40, mPtrTailNext)
  }
}

function abi_decode_OrderParameters(CalldataPointer cdPtr) pure returns (MemoryPointer mPtr) {
  mPtr = malloc(OrderParameters_head_size);
  cdPtr.copy(mPtr, OrderParameters_head_size);
  mPtr.offset(OrderParameters_offer_offset).write(abi_decode_dyn_array_OfferItem(cdPtr.pptr(OrderParameters_offer_offset)));
  mPtr.offset(OrderParameters_consideration_offset).write(abi_decode_dyn_array_ConsiderationItem(cdPtr.pptr(OrderParameters_consideration_offset)));
}

function abi_decode_Order(CalldataPointer cdPtr) pure returns (MemoryPointer mPtr) {
  mPtr = malloc(Order_head_size);
  mPtr.write(abi_decode_OrderParameters(cdPtr.pptr()));
  mPtr.offset(Order_signature_offset).write(abi_decode_bytes(cdPtr.pptr(Order_signature_offset)));
}

function abi_decode_AdvancedOrder(CalldataPointer cdPtr) pure returns (MemoryPointer mPtr) {
  mPtr = malloc(AdvancedOrder_head_size);
  cdPtr.offset(AdvancedOrder_numerator_offset).copy(mPtr.offset(AdvancedOrder_numerator_offset), AdvancedOrder_fixed_segment_0);
  mPtr.write(abi_decode_OrderParameters(cdPtr.pptr()));
  mPtr.offset(AdvancedOrder_signature_offset).write(abi_decode_bytes(cdPtr.pptr(AdvancedOrder_signature_offset)));
  mPtr.offset(AdvancedOrder_extraData_offset).write(abi_decode_bytes(cdPtr.pptr(AdvancedOrder_extraData_offset)));
}

function abi_decode_dyn_array_bytes32(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  unchecked {
    uint256 arrLength = cdPtrLength.readMaskedUint256();
    uint256 arrSize = (arrLength + 1) * 32;
    mPtrLength = malloc(arrSize);
    cdPtrLength.copy(mPtrLength, arrSize);
  }
}

function abi_decode_CriteriaResolver(CalldataPointer cdPtr) pure returns (MemoryPointer mPtr) {
  mPtr = malloc(CriteriaResolver_head_size);
  cdPtr.copy(mPtr, CriteriaResolver_fixed_segment_0);
  mPtr.offset(CriteriaResolver_criteriaProof_offset).write(abi_decode_dyn_array_bytes32(cdPtr.pptr(CriteriaResolver_criteriaProof_offset)));
}

function abi_decode_dyn_array_CriteriaResolver(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  unchecked {
    uint256 arrLength = cdPtrLength.readMaskedUint256();
    uint256 tailOffset = arrLength * 32;
    mPtrLength = malloc(tailOffset + 32);
    mPtrLength.write(arrLength);
    MemoryPointer mPtrHead = mPtrLength.next();
    CalldataPointer cdPtrHead = cdPtrLength.next();
    for (uint256 offset; offset < tailOffset; offset += 32) {
      mPtrHead.offset(offset).write(abi_decode_CriteriaResolver(cdPtrHead.pptr(offset)));
    }
  }
}

function abi_decode_dyn_array_Order(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  unchecked {
    uint256 arrLength = cdPtrLength.readMaskedUint256();
    uint256 tailOffset = arrLength * 32;
    mPtrLength = malloc(tailOffset + 32);
    mPtrLength.write(arrLength);
    MemoryPointer mPtrHead = mPtrLength.next();
    CalldataPointer cdPtrHead = cdPtrLength.next();
    for (uint256 offset; offset < tailOffset; offset += 32) {
      mPtrHead.offset(offset).write(abi_decode_Order(cdPtrHead.pptr(offset)));
    }
  }
}

function abi_decode_dyn_array_FulfillmentComponent(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  assembly {
    let arrLength := and(calldataload(cdPtrLength), OffsetOrLengthMask)
    mPtrLength := mload(0x40)
    mstore(mPtrLength, arrLength)
    let mPtrHead := add(mPtrLength, 32)
    let mPtrTail := add(mPtrHead, mul(arrLength, 0x20))
    let mPtrTailNext := mPtrTail
    calldatacopy(mPtrTail, add(cdPtrLength, 0x20), mul(arrLength, FulfillmentComponent_mem_tail_size))
    let mPtrHeadNext := mPtrHead
    for {} lt(mPtrHeadNext, mPtrTail) {} {
      mstore(mPtrHeadNext, mPtrTailNext)
      mPtrHeadNext := add(mPtrHeadNext, 0x20)
      mPtrTailNext := add(mPtrTailNext, FulfillmentComponent_mem_tail_size)
    }
    mstore(0x40, mPtrTailNext)
  }
}

function abi_decode_dyn_array_dyn_array_FulfillmentComponent(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  unchecked {
    uint256 arrLength = cdPtrLength.readMaskedUint256();
    uint256 tailOffset = arrLength * 32;
    mPtrLength = malloc(tailOffset + 32);
    mPtrLength.write(arrLength);
    MemoryPointer mPtrHead = mPtrLength.next();
    CalldataPointer cdPtrHead = cdPtrLength.next();
    for (uint256 offset; offset < tailOffset; offset += 32) {
      mPtrHead.offset(offset).write(abi_decode_dyn_array_FulfillmentComponent(cdPtrHead.pptr(offset)));
    }
  }
}

function abi_decode_dyn_array_AdvancedOrder(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  unchecked {
    uint256 arrLength = cdPtrLength.readMaskedUint256();
    uint256 tailOffset = arrLength * 32;
    mPtrLength = malloc(tailOffset + 32);
    mPtrLength.write(arrLength);
    MemoryPointer mPtrHead = mPtrLength.next();
    CalldataPointer cdPtrHead = cdPtrLength.next();
    for (uint256 offset; offset < tailOffset; offset += 32) {
      mPtrHead.offset(offset).write(abi_decode_AdvancedOrder(cdPtrHead.pptr(offset)));
    }
  }
}

function abi_decode_Fulfillment(CalldataPointer cdPtr) pure returns (MemoryPointer mPtr) {
  mPtr = malloc(Fulfillment_head_size);
  mPtr.write(abi_decode_dyn_array_FulfillmentComponent(cdPtr.pptr()));
  mPtr.offset(Fulfillment_considerationComponents_offset).write(abi_decode_dyn_array_FulfillmentComponent(cdPtr.pptr(Fulfillment_considerationComponents_offset)));
}

function abi_decode_dyn_array_Fulfillment(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  unchecked {
    uint256 arrLength = cdPtrLength.readMaskedUint256();
    uint256 tailOffset = arrLength * 32;
    mPtrLength = malloc(tailOffset + 32);
    mPtrLength.write(arrLength);
    MemoryPointer mPtrHead = mPtrLength.next();
    CalldataPointer cdPtrHead = cdPtrLength.next();
    for (uint256 offset; offset < tailOffset; offset += 32) {
      mPtrHead.offset(offset).write(abi_decode_Fulfillment(cdPtrHead.pptr(offset)));
    }
  }
}

function abi_decode_OrderComponents(CalldataPointer cdPtr) pure returns (MemoryPointer mPtr) {
  mPtr = malloc(OrderComponents_head_size);
  cdPtr.copy(mPtr, OrderComponents_head_size);
  mPtr.offset(OrderComponents_offer_offset).write(abi_decode_dyn_array_OfferItem(cdPtr.pptr(OrderComponents_offer_offset)));
  mPtr.offset(OrderComponents_consideration_offset).write(abi_decode_dyn_array_ConsiderationItem(cdPtr.pptr(OrderComponents_consideration_offset)));
}

function abi_decode_dyn_array_OrderComponents(CalldataPointer cdPtrLength) pure returns (MemoryPointer mPtrLength) {
  unchecked {
    uint256 arrLength = cdPtrLength.readMaskedUint256();
    uint256 tailOffset = arrLength * 32;
    mPtrLength = malloc(tailOffset + 32);
    mPtrLength.write(arrLength);
    MemoryPointer mPtrHead = mPtrLength.next();
    CalldataPointer cdPtrHead = cdPtrLength.next();
    for (uint256 offset; offset < tailOffset; offset += 32) {
      mPtrHead.offset(offset).write(abi_decode_OrderComponents(cdPtrHead.pptr(offset)));
    }
  }
}

function to_BasicOrderParameters_ReturnType(function(CalldataPointer) internal pure returns (MemoryPointer) inFn) pure returns (function(CalldataPointer) internal pure returns (BasicOrderParameters memory) outFn) {
  assembly {
    outFn := inFn
  }
}

function to_Order_ReturnType(function(CalldataPointer) internal pure returns (MemoryPointer) inFn) pure returns (function(CalldataPointer) internal pure returns (Order memory) outFn) {
  assembly {
    outFn := inFn
  }
}

function to_AdvancedOrder_ReturnType(function(CalldataPointer) internal pure returns (MemoryPointer) inFn) pure returns (function(CalldataPointer) internal pure returns (AdvancedOrder memory) outFn) {
  assembly {
    outFn := inFn
  }
}

function to_dyn_array_CriteriaResolver_ReturnType(function(CalldataPointer) internal pure returns (MemoryPointer) inFn) pure returns (function(CalldataPointer) internal pure returns (CriteriaResolver[] memory) outFn) {
  assembly {
    outFn := inFn
  }
}

function to_dyn_array_Order_ReturnType(function(CalldataPointer) internal pure returns (MemoryPointer) inFn) pure returns (function(CalldataPointer) internal pure returns (Order[] memory) outFn) {
  assembly {
    outFn := inFn
  }
}

function to_dyn_array_dyn_array_FulfillmentComponent_ReturnType(function(CalldataPointer) internal pure returns (MemoryPointer) inFn) pure returns (function(CalldataPointer) internal pure returns (FulfillmentComponent[][] memory) outFn) {
  assembly {
    outFn := inFn
  }
}

function to_dyn_array_AdvancedOrder_ReturnType(function(CalldataPointer) internal pure returns (MemoryPointer) inFn) pure returns (function(CalldataPointer) internal pure returns (AdvancedOrder[] memory) outFn) {
  assembly {
    outFn := inFn
  }
}

function to_dyn_array_Fulfillment_ReturnType(function(CalldataPointer) internal pure returns (MemoryPointer) inFn) pure returns (function(CalldataPointer) internal pure returns (Fulfillment[] memory) outFn) {
  assembly {
    outFn := inFn
  }
}

function to_dyn_array_OrderComponents_ReturnType(function(CalldataPointer) internal pure returns (MemoryPointer) inFn) pure returns (function(CalldataPointer) internal pure returns (OrderComponents[] memory) outFn) {
  assembly {
    outFn := inFn
  }
}

function to_OrderComponents_ReturnType(function(CalldataPointer) internal pure returns (MemoryPointer) inFn) pure returns (function(CalldataPointer) internal pure returns (OrderComponents memory) outFn) {
  assembly {
    outFn := inFn
  }
}

function return_bool(bool fulfilled) pure {
  bytes memory returnData = abi.encode(fulfilled);
  assembly {
    return(add(returnData, 32), mload(returnData))
  }
}

function return_uint256(uint256 newCounter) pure {
  bytes memory returnData = abi.encode(newCounter);
  assembly {
    return(add(returnData, 32), mload(returnData))
  }
}

function return_bytes32(bytes32 orderHash) pure {
  bytes memory returnData = abi.encode(orderHash);
  assembly {
    return(add(returnData, 32), mload(returnData))
  }
}

function return_tuple_bool_bool_uint256_uint256(bool isValidated, bool isCancelled, uint256 totalFilled, uint256 totalSize) pure {
  bytes memory returnData = abi.encode(isValidated, isCancelled, totalFilled, totalSize);
  assembly {
    return(add(returnData, 32), mload(returnData))
  }
}

function return_tuple_string_bytes32_address(string memory version, bytes32 domainSeparator, address conduitController) pure {
  bytes memory returnData = abi.encode(version, domainSeparator, conduitController);
  assembly {
    return(add(returnData, 32), mload(returnData))
  }
}

function return_string(string memory value0) pure {
  bytes memory returnData = abi.encode(value0);
  assembly {
    return(add(returnData, 32), mload(returnData))
  }
}