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

contract FuzzMainTest is FuzzEngine {
    using FuzzHelpers for AdvancedOrder;
    using FuzzHelpers for AdvancedOrder[];

    function createContext() internal returns (GeneratorContext memory) {
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
                caller: address(this), // TODO: read recipient from TestContext
                offerer: makeAccount("offerer"),
                alice: makeAccount("alice"),
                bob: makeAccount("bob"),
                carol: makeAccount("carol"),
                dillon: makeAccount("dillon"),
                eve: makeAccount("eve"),
                frank: makeAccount("frank"),
                starting721offerIndex: 0,
                starting721considerationIndex: 0,
                potential1155TokenIds: potential1155TokenIds,
                orderHashes: new bytes32[](0)
            });
    }

    function test_success(
        uint256 seed,
        uint256 totalOrders,
        uint256 maxOfferItems,
        uint256 maxConsiderationItems
    ) public {
        totalOrders = bound(totalOrders, 1, 10);
        maxOfferItems = bound(maxOfferItems, 1, 10);
        maxConsiderationItems = bound(maxConsiderationItems, 1, 10);

        vm.warp(1679435965);

        GeneratorContext memory generatorContext = createContext();
        generatorContext.timestamp = block.timestamp;

        AdvancedOrdersSpace memory space = TestStateGenerator.generate(
            totalOrders,
            maxOfferItems,
            maxConsiderationItems,
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
