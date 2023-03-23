// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import "seaport-sol/SeaportSol.sol";

import {
    AdvancedOrdersSpace,
    AdvancedOrdersSpaceGenerator,
    GeneratorContext,
    TestStateGenerator
} from "./helpers/FuzzGenerators.sol";

import {
    FuzzParams,
    TestContext,
    TestContextLib
} from "./helpers/TestContextLib.sol";

import { FuzzEngine } from "./helpers/FuzzEngine.sol";

import { FuzzHelpers } from "./helpers/FuzzHelpers.sol";

contract FuzzMainTest is FuzzEngine {
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
                caller: address(this), // TODO: read recipient from TestContext
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
