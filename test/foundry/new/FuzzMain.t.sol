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
                offerer: offerer1.addr,
                recipient: address(0), // TODO: read recipient from TestContext
                alice: offerer1.addr,
                bob: offerer2.addr,
                dillon: dillon.addr,
                eve: eve.addr,
                frank: frank.addr,
                offererPk: offerer1.key,
                alicePk: offerer1.key,
                bobPk: offerer2.key,
                dillonPk: dillon.key,
                evePk: eve.key,
                frankPk: frank.key,
                starting721offerIndex: 0,
                starting721considerationIndex: 0,
                potential1155TokenIds: potential1155TokenIds,
                orderHashes: new bytes32[](0)
            });
    }

    function test_success(uint256 seed) public {
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
            fuzzParams: FuzzParams({ seed: seed })
        });

        run(context);
    }
}
