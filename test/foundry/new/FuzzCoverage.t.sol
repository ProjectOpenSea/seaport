// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibPRNG } from "solady/src/utils/LibPRNG.sol";

import { FuzzEngine } from "./helpers/FuzzEngine.sol";
import { FuzzParams } from "./helpers/FuzzTestContextLib.sol";

contract FuzzCoverageTestSuite is FuzzEngine {
    using LibPRNG for LibPRNG.PRNG;

    function xtest_fuzzCoverage_1() public {
        _run(LibPRNG.PRNG({ state: 1 }));
    }

    function xtest_fuzzCoverage_2() public {
        _run(LibPRNG.PRNG({ state: 2 }));
    }

    function xtest_fuzzCoverage_3() public {
        _run(LibPRNG.PRNG({ state: 3 }));
    }

    function xtest_fuzzCoverage_4() public {
        _run(LibPRNG.PRNG({ state: 4 }));
    }

    function xtest_fuzzCoverage_5() public {
        _run(LibPRNG.PRNG({ state: 5 }));
    }

    function xtest_fuzzCoverage_6() public {
        _run(LibPRNG.PRNG({ state: 6 }));
    }

    function xtest_fuzzCoverage_7() public {
        _run(LibPRNG.PRNG({ state: 7 }));
    }

    function xtest_fuzzCoverage_8() public {
        _run(LibPRNG.PRNG({ state: 8 }));
    }

    function xtest_fuzzCoverage_9() public {
        _run(LibPRNG.PRNG({ state: 9 }));
    }

    function xtest_fuzzCoverage_10() public {
        _run(LibPRNG.PRNG({ state: 10 }));
    }

    function xtest_fuzzCoverage_11() public {
        _run(LibPRNG.PRNG({ state: 11 }));
    }

    function xtest_fuzzCoverage_12() public {
        _run(LibPRNG.PRNG({ state: 12 }));
    }

    function xtest_fuzzCoverage_13() public {
        _run(LibPRNG.PRNG({ state: 13 }));
    }

    function xtest_fuzzCoverage_14() public {
        _run(LibPRNG.PRNG({ state: 14 }));
    }

    function xtest_fuzzCoverage_15() public {
        _run(LibPRNG.PRNG({ state: 15 }));
    }

    function xtest_fuzzCoverage_16() public {
        _run(LibPRNG.PRNG({ state: 16 }));
    }

    function xtest_fuzzCoverage_17() public {
        _run(LibPRNG.PRNG({ state: 17 }));
    }

    function xtest_fuzzCoverage_18() public {
        _run(LibPRNG.PRNG({ state: 18 }));
    }

    function xtest_fuzzCoverage_19() public {
        _run(LibPRNG.PRNG({ state: 19 }));
    }

    function xtest_fuzzCoverage_20() public {
        _run(LibPRNG.PRNG({ state: 20 }));
    }

    function xtest_fuzzCoverage_basic() public {
        _runConcrete(76844, 1371, 26280166978556068170591998414085765852193916502969966072599542085467311544375, 77611178969118171921290535202042465157553249771100500343718217148017568496390);
    }

    function test_fuzzCoverage_basic_efficient() public {
        _runConcrete(3, 3, 3, 0);
    }

    function xtest_fuzzCoverage_x() public {
        _runConcrete(0, 0, 0, 0);
    }

    function _run(LibPRNG.PRNG memory prng) internal {
        uint256 seed = prng.next();
        uint256 totalOrders = prng.next();
        uint256 maxOfferItems = prng.next();
        uint256 maxConsiderationItems = prng.next();
        _runConcrete(seed, totalOrders, maxOfferItems, maxConsiderationItems);
    }

    function _runConcrete(uint256 seed, uint256 totalOrders, uint256 maxOfferItems, uint256 maxConsiderationItems) internal {
        run(
            FuzzParams({
                seed: seed,
                totalOrders: bound(totalOrders, 1, 10),
                maxOfferItems: bound(maxOfferItems, 0, 10),
                maxConsiderationItems: bound(maxConsiderationItems, 0, 10),
                seedInput: abi.encodePacked(seed, totalOrders, maxOfferItems, maxConsiderationItems)
            })
        );
    }
}
