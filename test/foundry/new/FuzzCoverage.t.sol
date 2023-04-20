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

    function test_fuzzCoverage_3() public {
        _run(LibPRNG.PRNG({ state: 3 }));
    }

    function test_fuzzCoverage_4() public {
        _run(LibPRNG.PRNG({ state: 4 }));
    }

    function test_fuzzCoverage_5() public {
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

    function test_fuzzCoverage_9() public {
        _run(LibPRNG.PRNG({ state: 9 }));
    }

    function test_fuzzCoverage_10() public {
        _run(LibPRNG.PRNG({ state: 10 }));
    }

    function test_fuzzCoverage_11() public {
        _run(LibPRNG.PRNG({ state: 11 }));
    }

    function test_fuzzCoverage_12() public {
        _run(LibPRNG.PRNG({ state: 12 }));
    }

    function test_fuzzCoverage_13() public {
        _run(LibPRNG.PRNG({ state: 13 }));
    }

    function test_fuzzCoverage_14() public {
        _run(LibPRNG.PRNG({ state: 14 }));
    }

    function test_fuzzCoverage_15() public {
        _run(LibPRNG.PRNG({ state: 15 }));
    }

    function test_fuzzCoverage_16() public {
        _run(LibPRNG.PRNG({ state: 16 }));
    }

    function test_fuzzCoverage_17() public {
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

    function _run(LibPRNG.PRNG memory prng) internal {
        run(
            FuzzParams({
                seed: prng.next(),
                totalOrders: bound(prng.next(), 1, 10),
                maxOfferItems: bound(prng.next(), 0, 10),
                maxConsiderationItems: bound(prng.next(), 0, 10)
            })
        );
    }
}
