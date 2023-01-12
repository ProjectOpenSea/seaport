// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Script.sol";
import { TransferHelper } from "../contracts/helpers/TransferHelper.sol";

interface ImmutableCreate2Factory {
    function safeCreate2(bytes32, bytes memory) external;
}

contract TransferHelperDeployer is Script {
    function setUp() public { }

    function run() public {
        vm.broadcast();
        ImmutableCreate2Factory factory =
            ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);
        bytes32 salt = bytes32(0);
        factory.safeCreate2(
            salt,
            abi.encodePacked(
                type(TransferHelper).creationCode,
                abi.encode(address(0x00000000F9490004C11Cef243f5400493c00Ad63))
            )
        );
    }
}
