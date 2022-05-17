pragma solidity 0.8.13;
// echidna-test-2.0 . --contract MultiplyLeftShift  --test-mode assertion
contract MultiplyLeftShift { 
	function os_version(uint i) private pure returns(uint result) { 
		assembly {  
			result := add(644, mul(64, i))
		}
	}
	function ir_version(uint i) private pure returns (uint result) { 
		assembly {
			result := add(644, shl(6, i))
		}
	}
	function test_equivalence(uint i) public pure { 
		assert(os_version(i) == ir_version(i));
	}
}