// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ConduitController as CoreConduitController } from "seaport-core/src/conduit/ConduitController.sol";

/**
 * @title ConduitController
 * @author 0age
 * @notice ConduitController enables deploying and managing new conduits, or
 *         contracts that allow registered callers (or open "channels") to
 *         transfer approved ERC20/721/1155 tokens on their behalf.
 */
contract LocalConduitController is CoreConduitController {}
