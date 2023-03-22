// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";
import "seaport-sol/SeaportSol.sol";
import "forge-std/console.sol";

import {
    TestStateGenerator,
    GeneratorContext,
    AdvancedOrdersSpace,
    AdvancedOrdersSpaceGenerator
} from "./helpers/FuzzGenerators.sol";
import {
    TestContextLib,
    TestContext,
    FuzzParams
} from "./helpers/TestContextLib.sol";
import { FuzzEngine } from "./helpers/FuzzEngine.sol";
import { FuzzHelpers, Family } from "./helpers/FuzzHelpers.sol";

contract FuzzMainTest is FuzzEngine, FulfillAvailableHelper {
    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];

    Account bob2 = makeAccount("bob2");
    Account alice2 = makeAccount("alice2");

    function createContext() internal view returns (GeneratorContext memory) {
        LibPRNG.PRNG memory prng = LibPRNG.PRNG({ state: 0 });

        uint256[] memory potential1155TokenIds = new uint256[](3);
        potential1155TokenIds[0] = 1;
        potential1155TokenIds[1] = 2;
        potential1155TokenIds[2] = 3;

        return
            GeneratorContext({
                vm: vm,
                prng: prng,
                timestamp: block.timestamp,
                seaport: seaport,
                erc20s: erc20s,
                erc721s: erc721s,
                erc1155s: erc1155s,
                self: address(this),
                offerer: alice2.addr,
                recipient: address(0), // TODO: read recipient from TestContext
                alice: alice2.addr,
                bob: bob2.addr,
                dillon: dillon.addr,
                eve: eve.addr,
                frank: frank.addr,
                offererPk: alice2.key,
                alicePk: alice2.key,
                bobPk: bob2.key,
                dillonPk: dillon.key,
                evePk: eve.key,
                frankPk: frank.key,
                starting721offerIndex: 0,
                starting721considerationIndex: 0,
                potential1155TokenIds: potential1155TokenIds,
                orderHashes: new bytes32[](0)
            });
    }

    function test_success() public {
        vm.warp(1679435965);
        GeneratorContext memory generatorContext = createContext();
        generatorContext.timestamp = block.timestamp;

        AdvancedOrdersSpace memory space = TestStateGenerator.generate(
            1, // total orders
            10, // max offer items/order
            5, // max consideration items/order
            generatorContext
        );
        AdvancedOrder[] memory orders = AdvancedOrdersSpaceGenerator.generate(
            space,
            generatorContext
        );

        TestContext memory context = TestContextLib.from({
            orders: orders,
            seaport: seaport,
            caller: address(this),
            // Fixed seed for now
            fuzzParams: FuzzParams({ seed: 0 })
        });

        run(context);
    }
}
