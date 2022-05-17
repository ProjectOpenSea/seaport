pragma solidity 0.8.13;
import "../../test/TestERC20.sol";

// echidna-test-2.0 . --contract ExtcodeSize  --test-mode assertion
contract ExtcodeSize {
    // https://github.com/trailofbits/audit-opensea-consideration/blob/dfb7130f97f803dd1069140abe92e5207777a923/contracts/lib/ConsiderationInternal.sol#L1824
    function original_extcodesize(address tokenAddress, bool success)
        private
        view
        returns (bool result)
    {
        assembly {
            result := iszero(
                and(iszero(iszero(extcodesize(tokenAddress))), success)
            )
        }
    }

    function more_readable_extcodesize(address tokenAddress, bool success)
        private
        view
        returns (bool result)
    {
        assembly {
            result := or(iszero(extcodesize(tokenAddress)), iszero(success))
        }
    }

    function test_equivalence(uint128 num, bool success) public {
        address tokenAddress = address(0);
        if (num % 2 == 0) {
            tokenAddress = address(new TestERC20());
        }
        assert(
            original_extcodesize(tokenAddress, success) ==
                more_readable_extcodesize(tokenAddress, success)
        );
    }
}
