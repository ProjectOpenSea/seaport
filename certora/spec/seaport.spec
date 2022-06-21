import "erc20.spec"


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