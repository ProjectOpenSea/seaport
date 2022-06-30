import "erc20.spec"

methods {
    _getFraction(uint256, uint256, uint256) returns(uint256) => ALWAYS(11) uuu
    _applyFraction() returns(uint256) => ALWAYS(13)
    _greatestCommonDivisor(uint256, uint256) returns(uint256) => ALWAYS(14)
    _locateCurrentAmount(uint256, uint256, uint256, uint256, bool) returns(uint256) => ALWAYS(15)

}


// methods {
//     _getFraction(uint256, uint256, uint256) returns(uint256) => NONDET
//     // _applyFraction(uint256,uint256,(uint256,uint256,bytes32,uint256,uint256),bool) returns(uint256) => NONDET
//     _applyFraction() returns(uint256) => NONDET
//     // _assertValidSignature(address, bytes32, bytes) => NONDET
//     _greatestCommonDivisor(uint256, uint256) returns(uint256) => NONDET
//     _doesNotSupportPartialFills(uint8) returns(bool) => NONDET
//     _locateCurrentAmount(uint256, uint256, uint256, uint256, bool) returns(uint256) => NONDET
// }
// rule sanity(method f)
// {
// 	env e;
// 	calldataarg args;
// 	f(e,args);
// 	assert false;
// }


rule whoChangedOrder(method f, address u) {
    env eB;
    env eF;
	calldataarg args;
	bytes32 orderHash;
	bool isValidatedBefore; bool isCancelledBefore;
    uint256 totalFilledBefore; uint256 totalSizeBefore; 
    
    address offerer;
    uint256 counterBefore;

    isValidatedBefore,isCancelledBefore,totalFilledBefore,totalSizeBefore = getOrderStatus(eB, orderHash);
    counterBefore = getCounter(eB, offerer);

    f(eF,args);

	bool isValidatedAfter; bool isCancelledAfter;
    uint256 totalFilledAfter; uint256 totalSizeAfter;

    uint256 counterAfter;

    isValidatedAfter,isCancelledAfter,totalFilledAfter,totalSizeAfter = getOrderStatus(eB, orderHash);
    counterAfter = getCounter(eB, offerer);

    assert isValidatedAfter == isValidatedBefore;
    assert isCancelledAfter == isCancelledBefore;
    assert totalFilledAfter == totalFilledBefore;
    assert totalSizeAfter == totalSizeBefore;
    assert counterBefore == counterAfter;
}



rule whoChangedOrder_fulfillOrder(method f, address u) filtered { f -> 
f.selector == fulfillOrder(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes),bytes32).selector
} {
//    require u==0x12345;
    env eB;
    env eF;
    calldataarg args;
    bytes32 orderHash;
    bool isValidatedBefore; bool isCancelledBefore;
    uint256 totalFilledBefore; uint256 totalSizeBefore; 
    
    address offerer;
    uint256 counterBefore;
    isValidatedBefore,isCancelledBefore,totalFilledBefore,totalSizeBefore = getOrderStatus(eB, orderHash);
    counterBefore = getCounter(eB, offerer);
    f(eF,args);
    bool isValidatedAfter; bool isCancelledAfter;
    uint256 totalFilledAfter; uint256 totalSizeAfter;
    uint256 counterAfter;
    isValidatedAfter,isCancelledAfter,totalFilledAfter,totalSizeAfter = getOrderStatus(eB, orderHash);
    counterAfter = getCounter(eB, offerer);
    assert isValidatedAfter == isValidatedBefore;
    assert isCancelledAfter == isCancelledBefore;
    assert totalFilledAfter == totalFilledBefore;
    assert totalSizeAfter == totalSizeBefore;
    assert counterBefore == counterAfter;
}
