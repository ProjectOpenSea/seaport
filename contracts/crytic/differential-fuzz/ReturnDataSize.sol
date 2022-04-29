pragma solidity 0.8.13;
// echidna-test-2.0 . --contract Rds  --test-mode assertion
contract Rds {
	function original_version(uint256 rds,bool success) private pure returns(bool result){
		assembly { 
			result := iszero(and(success, iszero(iszero(rds))))
		}
	}
	function more_readable_version(uint256 rds,bool success) private pure returns(bool result){ 
		assembly { 
			result := or(iszero(success), iszero(rds))
		}
	}

	function test_equivalence(uint256 returndatasize, bool success) public pure{
		assert(original_version(returndatasize,success) == more_readable_version(returndatasize,success));
	}
}
