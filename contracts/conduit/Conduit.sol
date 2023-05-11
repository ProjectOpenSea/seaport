// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Conduit as CoreConduit } from "seaport-core/src/conduit/Conduit.sol";

/**
 * @title Conduit
 * @author 0age
 * @notice This contract serves as an originator for "proxied" transfers. Each
 *         conduit is deployed and controlled by a "conduit controller" that can
 *         add and remove "channels" or contracts that can instruct the conduit
 *         to transfer approved ERC20/721/1155 tokens. *IMPORTANT NOTE: each
 *         conduit has an owner that can arbitrarily add or remove channels, and
 *         a malicious or negligent owner can add a channel that allows for any
 *         approved ERC20/721/1155 tokens to be taken immediately — be extremely
 *         cautious with what conduits you give token approvals to!*
 */
contract LocalConduit is CoreConduit {}
