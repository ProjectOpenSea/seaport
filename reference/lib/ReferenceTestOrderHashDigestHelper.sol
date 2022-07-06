// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "reference/lib/ReferenceDigestHelper.sol";
import "reference/lib/ReferenceOrderHashHelper.sol";

contract ReferenceTestOrderHashDigestHelper is
    ReferenceDigestHelper,
    ReferenceOrderHashHelper
{
    constructor(address marketplaceAddress)
        ReferenceDigestHelper(marketplaceAddress)
    {}

    function testDeriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) external pure returns (bytes32 orderHash) {
        return
            ReferenceOrderHashHelper._deriveOrderHash(orderParameters, counter);
    }

    function testDeriveEIP712Digest(bytes32 orderHash)
        external
        view
        returns (bytes32 value)
    {
        return ReferenceDigestHelper._deriveEIP712Digest(orderHash);
    }

    function testDeriveDomainSeparator()
        external
        view
        returns (bytes32 domainSeparator)
    {
        return ReferenceDigestHelper._deriveDomainSeparator();
    }
}
