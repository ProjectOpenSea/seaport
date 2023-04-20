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

    function test_fuzzCoverage_basic() public {
        _runConcrete(
            178895369802638298688828708120387745534448546035048,
            115792089237316195423570985008687907156371697211558590866466387987651832578046,
            115788555543186638654911818413686243610276741452856728755638018087518900060159,
            115792089237316195423570985008687907853269984665640564039457584007913129639932
        );
    }

    function test_fuzzCoverage_basic_efficient() public {
        _runConcrete(
            29020300685662428657477431862397337925543050288008209731004895218611534368269,
            108946692864437767897643210059681608215252615900153618314970988617099153539653,
            95441492369375518072067636467673011372784319594465398859125961731879856573220,
            73755163147900218691916901
        );
    }

    function test_fuzzCoverage_basic_721_bid() public {
        _runConcrete(
            2,
            58918142077643298393727292486084,
            115792089237316195423570985008687907853269984665640564039457584007913129639932,
            6063
        );
    }

    function test_fuzzCoverage_basic_1155_bid() public {
        _runConcrete(
            69168861324106524785789875864565494645014032542526681943174911419438464098666,
            95412220279531865810529664,
            168927009450440624153853407909191465836386478350,
            7239
        );
    }

    function test_fuzzCoverage_match() public {
        _runConcrete(
            115792089237316195423570985008687907853269984665640564039457584007913129639934,
            2,
            21904359833916860366704634193340117785634039947738604189049000886930983,
            3
        );
    }

    function test_fuzzCoverage_1271_badSignature() public {
        _runConcrete(
            27975676071090949886466872194180568464853050579053252702290953588500251901326,
            10548896398720671075011199572618903008178189640236574387530457329807363479926,
            9530,
            81462533578495730624492284768288202099525874404886376737663410123454076655181
        );
    }

    function test_fuzzCoverage_1271_modified() public {
        _runConcrete(
            5087,
            3579,
            2540715214263996510212821941652924980769677577420870707172936130223174207065,
            109551133096459761257299027250794256869704972031009315060165419700454594682748
        );
    }

    function test_fuzzCoverage_1271_missingMagic() public {
        _runConcrete(
            2342388363,
            73546096136405737578683964780285827720112598822927516584487316002982633787118,
            9186,
            73546096136405737578683964780285827720112598822927516584487316002982633787064
        );
    }

    function test_fuzzCoverage_badV() public {
        _runConcrete(
            115792089237316195422001709574841237662311037269273827925897199395245324763135,
            115792089237316195423570985008687907853269984016603456722604130441601088487423,
            15015478129267062861193240965579028812595978164408,
            114852423500779464481378123675
        );
    }

    function test_fuzzCoverage_unresolvedOfferItem() public {
        _runConcrete(
            98998308194491183158249708279525735102968643447268117434,
            399894,
            11287267600594621844119038075138275407,
            1
        );
    }

    function test_fuzzCoverage_unresolvedConsiderationItem() public {
        _runConcrete(
            21031504701540589569684766394491503639894728815570642149193979735617845,
            115792089237316195423570985008687907850542408818289297698239329230080278790107,
            3,
            3
        );
    }

    function test_fuzzCoverage_invalidProof_Merkle() public {
        _runConcrete(
            100244771889532000862301351592862364952144975012761221323650285329251490774354,
            1725540768,
            2610,
            13016
        );
    }

    function test_fuzzCoverage_invalidProof_Wildcard() public {
        _runConcrete(6765, 3223, 574, 3557);
    }

    function test_fuzzCoverage_invalidConduit() public {
        _runConcrete(
            1711342531912953334042413523067739142268234246554074542172904117346,
            2390069440959679864360787221,
            114887352680636697235263059814916479244578286402813028686897646689549365018623,
            3
        );
    }

    function test_fuzzCoverage_invalidMsgValue() public {
        _runConcrete(
            71589350326019319704123178575187720699589599919631073354029606093990768578712,
            12275,
            47188759253344546769326539104081339655535600873772563363498264393888457437529,
            24592032060415969018911138350447678532213331227243625165942216246862580315427
        );
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
