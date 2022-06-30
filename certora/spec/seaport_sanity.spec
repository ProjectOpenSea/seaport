import "erc20.spec"



// methods {
//     _getFraction(uint256, uint256, uint256) returns(uint256) => ALWAYS(11)
//     _applyFraction() returns(uint256) => ALWAYS(13)
//     _greatestCommonDivisor(uint256, uint256) returns(uint256) => ALWAYS(14)
//     _locateCurrentAmount(uint256, uint256, uint256, uint256, bool) returns(uint256) => ALWAYS(15)

// }

// methods {
//     _getFraction(uint256, uint256, uint256) returns(uint256) => NONDET
//     // _applyFraction(uint256,uint256,(uint256,uint256,bytes32,uint256,uint256),bool) returns(uint256) => NONDET
//     _applyFraction() returns(uint256) => NONDET
//     // _assertValidSignature(address, bytes32, bytes) => NONDET
//     _greatestCommonDivisor(uint256, uint256) returns(uint256) => NONDET
//     _doesNotSupportPartialFills(uint8) returns(bool) => NONDET
//     _locateCurrentAmount(uint256, uint256, uint256, uint256, bool) returns(uint256) => NONDET
// }

rule sanity(method f)
{
	env e;
	calldataarg args;
	f(e,args);
	assert false;
}


//rule sanity_fulfillAvailableAdvancedOrders(method f) filtered { f -> f.selector == fulfillAvailableAdvancedOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes)[],(uint256,uint8,uint256,uint256,bytes32[])[],(uint256,uint256)[][],(uint256,uint256)[][],bytes32,address,uint256).selector }
rule sanity_fulfillOrder_fields_method(method f) filtered { f -> f.selector == fulfillOrder_fields(bytes32).selector }
{
	env e;
	calldataarg args;
	f(e,args);
	assert false;
}

rule sanity_fulfillOrder(method f) filtered { f ->  f.selector == fulfillOrder(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes),bytes32).selector}
{	env e;
	calldataarg args;
	fulfillOrder(e, args);
	assert false;
}


//rule sanity_name(method f) filtered { f -> f.selector == fulfillOrder(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes),bytes32).selector }
rule sanity_fulfillOrder_fields(){
	env e;
	bytes32 fulfillerConduitKey1;
	
	
	fulfillOrder_fields(e, fulfillerConduitKey1);
	
	
	assert false;
}
// rule sanity_fulfillOrder() 
// {
// 	env e;
// 	calldataarg args;
// 	address a1;
// 	uint8 i3;
// 	uint256 i8;
// 	bytes b1;
// 	bytes32 b5;

	

// //	fulfillOrder(((e, address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes),bytes32);
// //	fulfillOrder(((e, a1,a1,(i3,a1,i8,i8,i8),(i3,a1,i8,i8,i8,i8),i3,i8,i8,b5,i8,b5,i8),b1),b5);
// 	assert false;
// }

rule sanity_6functions(method f) filtered  { f -> 
f.selector == fulfillOrder(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes),bytes32).selector ||
f.selector == matchAdvancedOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes)[],(uint256,uint8,uint256,uint256,bytes32[])[],((uint256,uint256)[],(uint256,uint256)[])[]).selector ||
f.selector == fulfillAvailableAdvancedOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes)[],(uint256,uint8,uint256,uint256,bytes32[])[],(uint256,uint256)[][],(uint256,uint256)[][],bytes32,address,uint256).selector ||
f.selector == matchOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes)[],((uint256,uint256)[],(uint256,uint256)[])[]).selector ||
f.selector == fulfillAdvancedOrder(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes),(uint256,uint8,uint256,uint256,bytes32[])[],bytes32,address).selector ||
f.selector == fulfillAvailableOrders(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),bytes)[],(uint256,uint256)[][],(uint256,uint256)[][],bytes32,uint256).selector
}
{
	env e;
	calldataarg args;
	f(e,args);
	assert false;
}

/*
This rule find which functions never reverts.

*/


rule noRevert(method f)
description "$f has reverting paths"
{
	env e;
	calldataarg arg;
	require e.msg.value == 0; 
	f@withrevert(e, arg); 
	assert !lastReverted, "${f.selector} can revert";
}


rule alwaysRevert(method f)
description "$f has reverting paths"
{
	env e;
	calldataarg arg;
	f@withrevert(e, arg); 
	assert lastReverted, "${f.selector} succeeds";
}


/*
This rule find which functions that can be called, may fail due to someone else calling a function right before.

This is n expensive rule - might fail on the demo site on big contracts
*/

rule simpleFrontRunning(method f, address privileged) filtered { f-> !f.isView }
description "$f can no longer be called after it had been called by someone else"
{
	env e1;
	calldataarg arg;
	require e1.msg.sender == privileged;  

	storage initialStorage = lastStorage;
	f(e1, arg); 
	bool firstSucceeded = !lastReverted;

	env e2;
	calldataarg arg2;
	require e2.msg.sender != e1.msg.sender;
	f(e2, arg2) at initialStorage; 
	f@withrevert(e1, arg);
	bool succeeded = !lastReverted;

	assert succeeded, "${f.selector} can be not be called if was called by someone else";
}


/*
This rule find which functions are privileged.
A function is privileged if there is only one address that can call it.

The rules finds this by finding which functions can be called by two different users.

*/


rule privilegedOperation(method f, address privileged)
description "$f can be called by more than one user without reverting"
{
	env e1;
	calldataarg arg;
	require e1.msg.sender == privileged;

	storage initialStorage = lastStorage;
	f@withrevert(e1, arg); // privileged succeeds executing candidate privileged operation.
	bool firstSucceeded = !lastReverted;

	env e2;
	calldataarg arg2;
	require e2.msg.sender != privileged;
	f@withrevert(e2, arg2) at initialStorage; // unprivileged
	bool secondSucceeded = !lastReverted;

	assert  !(firstSucceeded && secondSucceeded), "${f.selector} can be called by both ${e1.msg.sender} and ${e2.msg.sender}, so it is not privileged";
}

rule whoChangedBalanceOf(method f, address u) {
    env eB;
    env eF;
    calldataarg args;
    uint256 before = balanceOf(eB, u);
    f(eF,args);
    assert balanceOf(eB, u) == before, "balanceOf changed";
}