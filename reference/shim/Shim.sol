// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @dev HardHat doesn't support multiple source folders; so import everything
 * extra that reference tests rely on so they get compiled. Allows for faster
 * feedback than running an extra yarn build
 */
import { EIP1271Wallet } from "contracts/test/EIP1271Wallet.sol";
import { Reenterer } from "contracts/test/Reenterer.sol";
import { TestERC20 } from "contracts/test/TestERC20.sol";
import { TestERC721 } from "contracts/test/TestERC721.sol";
import { TestERC1155 } from "contracts/test/TestERC1155.sol";
import { TestZone } from "contracts/test/TestZone.sol";
import { DeployerGlobalPausable } from "contracts/zones/DeployerGlobalPausable.sol";
import { TransferHelper } from "contracts/helpers/TransferHelper.sol";
// prettier-ignore
import {
    ImmutableCreate2FactoryInterface
} from "contracts/interfaces/ImmutableCreate2FactoryInterface.sol";
