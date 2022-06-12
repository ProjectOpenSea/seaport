// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "../helpers/DigestHelper.sol";
import "../helpers/OrderHashHelper.sol";

contract TestOrderHashDigestHelper is DigestHelper, OrderHashHelper {
    constructor(address marketplaceAddress) DigestHelper(marketplaceAddress) {}
    
    function testDeriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) external pure returns (bytes32 orderHash) {
        return OrderHashHelper.deriveOrderHash(orderParameters, counter);
    }  

    function testDeriveEIP712Digest(bytes32 orderHash)
        external
        view
        returns (bytes32 value)
    {
        return DigestHelper.deriveEIP712Digest(orderHash);
    }
}
