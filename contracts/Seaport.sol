// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { Consideration } from "./lib/Consideration.sol";

/**
 * @title Seaport
 * @author 0age
 * @custom:coauthor d1ll0n
 * @custom:coauthor transmissions11
 * @custom:version 1
 * @notice Seaport is a generalized ETH/ERC20/ERC721/ERC1155 marketplace. It
 *         minimizes external calls to the greatest extent possible and provides
 *         lightweight methods for common routes as well as more flexible
 *         methods for composing advanced orders or groups of orders. Each order
 *         contains an arbitrary number of items that may be spent (the "offer")
 *         along with an arbitrary number of items that must be received back by
 *         the indicated recipients (the "consideration").
 */
contract Seaport is Consideration {
    /**
     * @notice Derive and set hashes, reference chainId, and associated domain
     *         separator during deployment.
     *
     * @param conduitController A contract that deploys conduits, or proxies
     *                          that may optionally be used to transfer approved
     *                          ERC20/721/1155 tokens.
     *
     * @dev You can cut out 10 opcodes in the creation-time EVM bytecode
     * if you declare a constructor `payable`.
     *
     * For more in-depth information see here:
     * https://forum.openzeppelin.com/t/a-collection-of-gas-optimisation-tricks/19966/5
     */
    constructor(address conduitController)
        payable
        Consideration(conduitController)
    {}

    /**
     * @dev Internal pure function to retrieve and return the name of this
     *      contract.
     *
     * @return The name of this contract.
     */
    function _name() internal pure override returns (string memory) {
        // Return the name of the contract.
        assembly {
            mstore(0, 0x20)
            mstore(0x27, 0x07536561706f7274)
            return(0, 0x60)
        }
    }

    /**
     * @dev Internal pure function to retrieve the name of this contract as a
     *      string that will be used to derive the name hash in the constructor.
     *
     * @return The name of this contract as a string.
     */
    function _nameString() internal pure override returns (string memory) {
        // Return the name of the contract.
        return "Seaport";
    }
}
