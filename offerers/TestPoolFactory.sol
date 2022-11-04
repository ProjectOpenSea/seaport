// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { EnumerableSet } from
    "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { IERC721 } from
    "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { TestPoolOfferer } from "./TestPoolOfferer.sol";

contract TestPoolFactory {
    address immutable seaport;

    constructor(address _seaport) {
        seaport = _seaport;
    }

    function createPoolOfferer(
        address erc721,
        uint256[] calldata tokenIds,
        address erc20,
        uint256 amount
    ) external returns (address newPool) {
        newPool = address(
            new TestPoolOfferer(seaport, erc721, tokenIds, erc20, amount)
        );
        IERC20(erc20).transferFrom(msg.sender, newPool, amount);
        for (uint256 i; i < tokenIds.length; i++) {
            IERC721(erc721).transferFrom(msg.sender, newPool, tokenIds[i]);
        }
    }
}
