// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { FuzzEngine } from "./helpers/FuzzEngine.sol";
import { FuzzParams } from "./helpers/FuzzTestContextLib.sol";

contract FuzzCoverageTestSuite is FuzzEngine {
    using LibPRNG for LibPRNG.PRNG;

    function test_fuzzCoverage_1() public {
        _run(LibPRNG.PRNG({ state: 1 }));
    }

    function test_fuzzCoverage_2() public {
        _run(LibPRNG.PRNG({ state: 2 }));
    }

    // NOTE: this state trips an assume; skip it
    function xtest_fuzzCoverage_3() public {
        _run(LibPRNG.PRNG({ state: 3 }));
    }

    function test_fuzzCoverage_4() public {
        _run(LibPRNG.PRNG({ state: 4 }));
    }

    // NOTE: this state trips an assume; skip it
    function xtest_fuzzCoverage_5() public {
        _run(LibPRNG.PRNG({ state: 5 }));
    }

    function test_fuzzCoverage_6() public {
        _run(LibPRNG.PRNG({ state: 6 }));
    }

    function test_fuzzCoverage_7() public {
        _run(LibPRNG.PRNG({ state: 7 }));
    }

    function test_fuzzCoverage_8() public {
        _run(LibPRNG.PRNG({ state: 8 }));
    }

    // NOTE: this state trips an assume; skip it
    function xtest_fuzzCoverage_9() public {
        _run(LibPRNG.PRNG({ state: 9 }));
    }

    // NOTE: this state trips an assume; skip it
    function xtest_fuzzCoverage_10() public {
        _run(LibPRNG.PRNG({ state: 10 }));
    }

    function test_fuzzCoverage_11() public {
        _run(LibPRNG.PRNG({ state: 11 }));
    }

    function test_fuzzCoverage_12() public {
        _run(LibPRNG.PRNG({ state: 12 }));
    }

    // NOTE: this state trips an assume; skip it
    function xtest_fuzzCoverage_13() public {
        _run(LibPRNG.PRNG({ state: 13 }));
    }

    // NOTE: this state trips a `no_explicit_executions_match` assume; skip it
    function xtest_fuzzCoverage_14() public {
        _run(LibPRNG.PRNG({ state: 14 }));
    }

    function test_fuzzCoverage_15() public {
        _run(LibPRNG.PRNG({ state: 15 }));
    }

    function test_fuzzCoverage_16() public {
        _run(LibPRNG.PRNG({ state: 16 }));
    }

    // NOTE: this state trips a `no_explicit_executions_match` assume; skip it
    function xtest_fuzzCoverage_17() public {
        _run(LibPRNG.PRNG({ state: 17 }));
    }

    function test_fuzzCoverage_18() public {
        _run(LibPRNG.PRNG({ state: 18 }));
    }

    function test_fuzzCoverage_19() public {
        _run(LibPRNG.PRNG({ state: 19 }));
    }

    function test_fuzzCoverage_20() public {
        _run(LibPRNG.PRNG({ state: 20 }));
    }

    function test_fuzzCoverage_x() public {
        _runConcrete(0, 0, 0, 0);
    }

    function _run(LibPRNG.PRNG memory prng) internal {
        uint256 seed = prng.next();
        uint256 totalOrders = prng.next();
        uint256 maxOfferItems = prng.next();
        uint256 maxConsiderationItems = prng.next();
        _runConcrete(seed, totalOrders, maxOfferItems, maxConsiderationItems);
    }

    function _runConcrete(
        uint256 seed,
        uint256 totalOrders,
        uint256 maxOfferItems,
        uint256 maxConsiderationItems
    ) internal {
        run(
            FuzzParams({
                seed: seed,
                totalOrders: bound(totalOrders, 1, 10),
                maxOfferItems: bound(maxOfferItems, 0, 10),
                maxConsiderationItems: bound(maxConsiderationItems, 0, 10),
                seedInput: abi.encodePacked(
                    seed,
                    totalOrders,
                    maxOfferItems,
                    maxConsiderationItems
                )
            })
        );
    }
}
