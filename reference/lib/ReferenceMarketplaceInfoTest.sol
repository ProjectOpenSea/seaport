// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract ReferenceMarketplaceInfoTest {
    function information()
        external
        pure
        returns (
            string memory version,
            bytes32 domainSeparator,
            address conduitController
        )
    {
        return ("rc.1.1", "", address(0));
    }
}
