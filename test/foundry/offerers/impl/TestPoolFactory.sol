// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    IERC721
} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

import {
    IERC20
} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { TestPoolOfferer } from "./TestPoolOfferer.sol";

contract TestPoolFactory {
    // The address of the Seaport contract.
    address immutable seaport;

    // Constructor that takes the Seaport contract address as an argument.
    constructor(address _seaport) {
        seaport = _seaport;
    }

    // Function to create a new TestPoolOfferer contract.
    function createPoolOfferer(
        address erc721,
        uint256[] calldata tokenIds,
        address erc20,
        uint256 amount
    ) external returns (TestPoolOfferer newPool) {
        // Create a new TestPoolOfferer contract
        newPool = new TestPoolOfferer(
            seaport,
            erc721,
            tokenIds,
            erc20,
            amount,
            msg.sender
        );

        // Transfer the specified amount of ERC20 tokens from the caller to the
        // new contract.
        IERC20(erc20).transferFrom(msg.sender, address(newPool), amount);

        // Transfer the specified ERC721 tokens from the caller to the new
        // contract.
        for (uint256 i; i < tokenIds.length; i++) {
            IERC721(erc721).transferFrom(
                msg.sender,
                address(newPool),
                tokenIds[i]
            );
        }
    }
}
