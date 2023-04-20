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

    function test_fuzzCoverage_21() public {
        _run(LibPRNG.PRNG({ state: 21 }));
    }

    function test_fuzzCoverage_22() public {
        _run(LibPRNG.PRNG({ state: 22 }));
    }

    function test_fuzzCoverage_23() public {
        _run(LibPRNG.PRNG({ state: 23 }));
    }

    function test_fuzzCoverage_24() public {
        _run(LibPRNG.PRNG({ state: 24 }));
    }

    function test_fuzzCoverage_25() public {
        _run(LibPRNG.PRNG({ state: 25 }));
    }

    function test_fuzzCoverage_26() public {
        _run(LibPRNG.PRNG({ state: 26 }));
    }

    function test_fuzzCoverage_27() public {
        _run(LibPRNG.PRNG({ state: 27 }));
    }

    function test_fuzzCoverage_28() public {
        _run(LibPRNG.PRNG({ state: 28 }));
    }

    function test_fuzzCoverage_29() public {
        _run(LibPRNG.PRNG({ state: 29 }));
    }

    function test_fuzzCoverage_30() public {
        _run(LibPRNG.PRNG({ state: 30 }));
    }

    function test_fuzzCoverage_31() public {
        _run(LibPRNG.PRNG({ state: 31 }));
    }

    function test_fuzzCoverage_32() public {
        _run(LibPRNG.PRNG({ state: 32 }));
    }

    function test_fuzzCoverage_33() public {
        _run(LibPRNG.PRNG({ state: 33 }));
    }

    function test_fuzzCoverage_34() public {
        _run(LibPRNG.PRNG({ state: 34 }));
    }

    function test_fuzzCoverage_35() public {
        _run(LibPRNG.PRNG({ state: 35 }));
    }

    function test_fuzzCoverage_36() public {
        _run(LibPRNG.PRNG({ state: 36 }));
    }

    function test_fuzzCoverage_37() public {
        _run(LibPRNG.PRNG({ state: 37 }));
    }

    function test_fuzzCoverage_38() public {
        _run(LibPRNG.PRNG({ state: 38 }));
    }

    function test_fuzzCoverage_39() public {
        _run(LibPRNG.PRNG({ state: 39 }));
    }

    function test_fuzzCoverage_40() public {
        _run(LibPRNG.PRNG({ state: 40 }));
    }

    function test_fuzzCoverage_41() public {
        _run(LibPRNG.PRNG({ state: 41 }));
    }

    function test_fuzzCoverage_42() public {
        _run(LibPRNG.PRNG({ state: 42 }));
    }

    function test_fuzzCoverage_43() public {
        _run(LibPRNG.PRNG({ state: 43 }));
    }

    function test_fuzzCoverage_44() public {
        _run(LibPRNG.PRNG({ state: 44 }));
    }

    function test_fuzzCoverage_45() public {
        _run(LibPRNG.PRNG({ state: 45 }));
    }

    function test_fuzzCoverage_46() public {
        _run(LibPRNG.PRNG({ state: 46 }));
    }

    function test_fuzzCoverage_47() public {
        _run(LibPRNG.PRNG({ state: 47 }));
    }

    // NOTE: skip
    function xtest_fuzzCoverage_48() public {
        _run(LibPRNG.PRNG({ state: 48 }));
    }

    function test_fuzzCoverage_49() public {
        _run(LibPRNG.PRNG({ state: 49 }));
    }

    function test_fuzzCoverage_50() public {
        _run(LibPRNG.PRNG({ state: 50 }));
    }

    function test_fuzzCoverage_51() public {
        _run(LibPRNG.PRNG({ state: 51 }));
    }

    function test_fuzzCoverage_52() public {
        _run(LibPRNG.PRNG({ state: 52 }));
    }

    function test_fuzzCoverage_53() public {
        _run(LibPRNG.PRNG({ state: 53 }));
    }

    function test_fuzzCoverage_54() public {
        _run(LibPRNG.PRNG({ state: 54 }));
    }

    function test_fuzzCoverage_55() public {
        _run(LibPRNG.PRNG({ state: 55 }));
    }

    function test_fuzzCoverage_56() public {
        _run(LibPRNG.PRNG({ state: 56 }));
    }

    function test_fuzzCoverage_57() public {
        _run(LibPRNG.PRNG({ state: 57 }));
    }

    function test_fuzzCoverage_58() public {
        _run(LibPRNG.PRNG({ state: 58 }));
    }

    function test_fuzzCoverage_59() public {
        _run(LibPRNG.PRNG({ state: 59 }));
    }

    function test_fuzzCoverage_60() public {
        _run(LibPRNG.PRNG({ state: 60 }));
    }

    function test_fuzzCoverage_61() public {
        _run(LibPRNG.PRNG({ state: 61 }));
    }

    function test_fuzzCoverage_62() public {
        _run(LibPRNG.PRNG({ state: 62 }));
    }

    function test_fuzzCoverage_63() public {
        _run(LibPRNG.PRNG({ state: 63 }));
    }

    function test_fuzzCoverage_64() public {
        _run(LibPRNG.PRNG({ state: 64 }));
    }

    function test_fuzzCoverage_65() public {
        _run(LibPRNG.PRNG({ state: 65 }));
    }

    function test_fuzzCoverage_66() public {
        _run(LibPRNG.PRNG({ state: 66 }));
    }

    function test_fuzzCoverage_67() public {
        _run(LibPRNG.PRNG({ state: 67 }));
    }

    function test_fuzzCoverage_68() public {
        _run(LibPRNG.PRNG({ state: 68 }));
    }

    function test_fuzzCoverage_69() public {
        _run(LibPRNG.PRNG({ state: 69 }));
    }

    function test_fuzzCoverage_70() public {
        _run(LibPRNG.PRNG({ state: 70 }));
    }

    function test_fuzzCoverage_71() public {
        _run(LibPRNG.PRNG({ state: 71 }));
    }

    function test_fuzzCoverage_72() public {
        _run(LibPRNG.PRNG({ state: 72 }));
    }

    function test_fuzzCoverage_73() public {
        _run(LibPRNG.PRNG({ state: 73 }));
    }

    function test_fuzzCoverage_74() public {
        _run(LibPRNG.PRNG({ state: 74 }));
    }

    function test_fuzzCoverage_75() public {
        _run(LibPRNG.PRNG({ state: 75 }));
    }

    function test_fuzzCoverage_76() public {
        _run(LibPRNG.PRNG({ state: 76 }));
    }

    function test_fuzzCoverage_77() public {
        _run(LibPRNG.PRNG({ state: 77 }));
    }

    function test_fuzzCoverage_78() public {
        _run(LibPRNG.PRNG({ state: 78 }));
    }

    function test_fuzzCoverage_79() public {
        _run(LibPRNG.PRNG({ state: 79 }));
    }

    function test_fuzzCoverage_80() public {
        _run(LibPRNG.PRNG({ state: 80 }));
    }

    function test_fuzzCoverage_81() public {
        _run(LibPRNG.PRNG({ state: 81 }));
    }

    function test_fuzzCoverage_82() public {
        _run(LibPRNG.PRNG({ state: 82 }));
    }

    function test_fuzzCoverage_83() public {
        _run(LibPRNG.PRNG({ state: 83 }));
    }

    function test_fuzzCoverage_84() public {
        _run(LibPRNG.PRNG({ state: 84 }));
    }

    function test_fuzzCoverage_85() public {
        _run(LibPRNG.PRNG({ state: 85 }));
    }

    function test_fuzzCoverage_86() public {
        _run(LibPRNG.PRNG({ state: 86 }));
    }

    // NOTE: skip
    function xtest_fuzzCoverage_87() public {
        _run(LibPRNG.PRNG({ state: 87 }));
    }

    function test_fuzzCoverage_88() public {
        _run(LibPRNG.PRNG({ state: 88 }));
    }

    function test_fuzzCoverage_89() public {
        _run(LibPRNG.PRNG({ state: 89 }));
    }

    function test_fuzzCoverage_90() public {
        _run(LibPRNG.PRNG({ state: 90 }));
    }

    function test_fuzzCoverage_91() public {
        _run(LibPRNG.PRNG({ state: 91 }));
    }

    function test_fuzzCoverage_92() public {
        _run(LibPRNG.PRNG({ state: 92 }));
    }

    function test_fuzzCoverage_93() public {
        _run(LibPRNG.PRNG({ state: 93 }));
    }

    function test_fuzzCoverage_94() public {
        _run(LibPRNG.PRNG({ state: 94 }));
    }

    function test_fuzzCoverage_95() public {
        _run(LibPRNG.PRNG({ state: 95 }));
    }

    function test_fuzzCoverage_96() public {
        _run(LibPRNG.PRNG({ state: 96 }));
    }

    function test_fuzzCoverage_97() public {
        _run(LibPRNG.PRNG({ state: 97 }));
    }

    function test_fuzzCoverage_98() public {
        _run(LibPRNG.PRNG({ state: 98 }));
    }

    function test_fuzzCoverage_99() public {
        _run(LibPRNG.PRNG({ state: 99 }));
    }

    function test_fuzzCoverage_100() public {
        _run(LibPRNG.PRNG({ state: 100 }));
    }

    function test_fuzzCoverage_101() public {
        _run(LibPRNG.PRNG({ state: 101 }));
    }

    function test_fuzzCoverage_102() public {
        _run(LibPRNG.PRNG({ state: 102 }));
    }

    function test_fuzzCoverage_103() public {
        _run(LibPRNG.PRNG({ state: 103 }));
    }

    function test_fuzzCoverage_104() public {
        _run(LibPRNG.PRNG({ state: 104 }));
    }

    function test_fuzzCoverage_105() public {
        _run(LibPRNG.PRNG({ state: 105 }));
    }

    function test_fuzzCoverage_106() public {
        _run(LibPRNG.PRNG({ state: 106 }));
    }

    function test_fuzzCoverage_107() public {
        _run(LibPRNG.PRNG({ state: 107 }));
    }

    function test_fuzzCoverage_108() public {
        _run(LibPRNG.PRNG({ state: 108 }));
    }

    function test_fuzzCoverage_109() public {
        _run(LibPRNG.PRNG({ state: 109 }));
    }

    function test_fuzzCoverage_110() public {
        _run(LibPRNG.PRNG({ state: 110 }));
    }

    function test_fuzzCoverage_111() public {
        _run(LibPRNG.PRNG({ state: 111 }));
    }

    function test_fuzzCoverage_112() public {
        _run(LibPRNG.PRNG({ state: 112 }));
    }

    function test_fuzzCoverage_113() public {
        _run(LibPRNG.PRNG({ state: 113 }));
    }

    function test_fuzzCoverage_114() public {
        _run(LibPRNG.PRNG({ state: 114 }));
    }

    function test_fuzzCoverage_115() public {
        _run(LibPRNG.PRNG({ state: 115 }));
    }

    function test_fuzzCoverage_116() public {
        _run(LibPRNG.PRNG({ state: 116 }));
    }

    function test_fuzzCoverage_117() public {
        _run(LibPRNG.PRNG({ state: 117 }));
    }

    function test_fuzzCoverage_118() public {
        _run(LibPRNG.PRNG({ state: 118 }));
    }

    function test_fuzzCoverage_119() public {
        _run(LibPRNG.PRNG({ state: 119 }));
    }

    function test_fuzzCoverage_120() public {
        _run(LibPRNG.PRNG({ state: 120 }));
    }

    function test_fuzzCoverage_121() public {
        _run(LibPRNG.PRNG({ state: 121 }));
    }

    function test_fuzzCoverage_122() public {
        _run(LibPRNG.PRNG({ state: 122 }));
    }

    function test_fuzzCoverage_123() public {
        _run(LibPRNG.PRNG({ state: 123 }));
    }

    function test_fuzzCoverage_124() public {
        _run(LibPRNG.PRNG({ state: 124 }));
    }

    function test_fuzzCoverage_125() public {
        _run(LibPRNG.PRNG({ state: 125 }));
    }

    // NOTE: skip
    function xtest_fuzzCoverage_126() public {
        _run(LibPRNG.PRNG({ state: 126 }));
    }

    function test_fuzzCoverage_127() public {
        _run(LibPRNG.PRNG({ state: 127 }));
    }

    function test_fuzzCoverage_128() public {
        _run(LibPRNG.PRNG({ state: 128 }));
    }

    function test_fuzzCoverage_129() public {
        _run(LibPRNG.PRNG({ state: 129 }));
    }

    function test_fuzzCoverage_130() public {
        _run(LibPRNG.PRNG({ state: 130 }));
    }

    function test_fuzzCoverage_131() public {
        _run(LibPRNG.PRNG({ state: 131 }));
    }

    function test_fuzzCoverage_132() public {
        _run(LibPRNG.PRNG({ state: 132 }));
    }

    function test_fuzzCoverage_133() public {
        _run(LibPRNG.PRNG({ state: 133 }));
    }

    function test_fuzzCoverage_134() public {
        _run(LibPRNG.PRNG({ state: 134 }));
    }

    function test_fuzzCoverage_135() public {
        _run(LibPRNG.PRNG({ state: 135 }));
    }

    function test_fuzzCoverage_136() public {
        _run(LibPRNG.PRNG({ state: 136 }));
    }

    function test_fuzzCoverage_137() public {
        _run(LibPRNG.PRNG({ state: 137 }));
    }

    function test_fuzzCoverage_138() public {
        _run(LibPRNG.PRNG({ state: 138 }));
    }

    function test_fuzzCoverage_139() public {
        _run(LibPRNG.PRNG({ state: 139 }));
    }

    function test_fuzzCoverage_140() public {
        _run(LibPRNG.PRNG({ state: 140 }));
    }

    function test_fuzzCoverage_141() public {
        _run(LibPRNG.PRNG({ state: 141 }));
    }

    function test_fuzzCoverage_142() public {
        _run(LibPRNG.PRNG({ state: 142 }));
    }

    function test_fuzzCoverage_143() public {
        _run(LibPRNG.PRNG({ state: 143 }));
    }

    function test_fuzzCoverage_144() public {
        _run(LibPRNG.PRNG({ state: 144 }));
    }

    function test_fuzzCoverage_145() public {
        _run(LibPRNG.PRNG({ state: 145 }));
    }

    function test_fuzzCoverage_146() public {
        _run(LibPRNG.PRNG({ state: 146 }));
    }

    function test_fuzzCoverage_147() public {
        _run(LibPRNG.PRNG({ state: 147 }));
    }

    function test_fuzzCoverage_148() public {
        _run(LibPRNG.PRNG({ state: 148 }));
    }

    function test_fuzzCoverage_149() public {
        _run(LibPRNG.PRNG({ state: 149 }));
    }

    function test_fuzzCoverage_150() public {
        _run(LibPRNG.PRNG({ state: 150 }));
    }

    function test_fuzzCoverage_151() public {
        _run(LibPRNG.PRNG({ state: 151 }));
    }

    function test_fuzzCoverage_152() public {
        _run(LibPRNG.PRNG({ state: 152 }));
    }

    function test_fuzzCoverage_153() public {
        _run(LibPRNG.PRNG({ state: 153 }));
    }

    function test_fuzzCoverage_154() public {
        _run(LibPRNG.PRNG({ state: 154 }));
    }

    // NOTE: skip
    function xtest_fuzzCoverage_155() public {
        _run(LibPRNG.PRNG({ state: 155 }));
    }

    function test_fuzzCoverage_156() public {
        _run(LibPRNG.PRNG({ state: 156 }));
    }

    function test_fuzzCoverage_157() public {
        _run(LibPRNG.PRNG({ state: 157 }));
    }

    function test_fuzzCoverage_158() public {
        _run(LibPRNG.PRNG({ state: 158 }));
    }

    function test_fuzzCoverage_159() public {
        _run(LibPRNG.PRNG({ state: 159 }));
    }

    function test_fuzzCoverage_160() public {
        _run(LibPRNG.PRNG({ state: 160 }));
    }

    function test_fuzzCoverage_161() public {
        _run(LibPRNG.PRNG({ state: 161 }));
    }

    function test_fuzzCoverage_162() public {
        _run(LibPRNG.PRNG({ state: 162 }));
    }

    function test_fuzzCoverage_163() public {
        _run(LibPRNG.PRNG({ state: 163 }));
    }

    function test_fuzzCoverage_164() public {
        _run(LibPRNG.PRNG({ state: 164 }));
    }

    function test_fuzzCoverage_165() public {
        _run(LibPRNG.PRNG({ state: 165 }));
    }

    function test_fuzzCoverage_166() public {
        _run(LibPRNG.PRNG({ state: 166 }));
    }

    function test_fuzzCoverage_167() public {
        _run(LibPRNG.PRNG({ state: 167 }));
    }

    function test_fuzzCoverage_168() public {
        _run(LibPRNG.PRNG({ state: 168 }));
    }

    function test_fuzzCoverage_169() public {
        _run(LibPRNG.PRNG({ state: 169 }));
    }

    function test_fuzzCoverage_170() public {
        _run(LibPRNG.PRNG({ state: 170 }));
    }

    function test_fuzzCoverage_171() public {
        _run(LibPRNG.PRNG({ state: 171 }));
    }

    function test_fuzzCoverage_172() public {
        _run(LibPRNG.PRNG({ state: 172 }));
    }

    function test_fuzzCoverage_173() public {
        _run(LibPRNG.PRNG({ state: 173 }));
    }

    function test_fuzzCoverage_174() public {
        _run(LibPRNG.PRNG({ state: 174 }));
    }

    function test_fuzzCoverage_175() public {
        _run(LibPRNG.PRNG({ state: 175 }));
    }

    function test_fuzzCoverage_176() public {
        _run(LibPRNG.PRNG({ state: 176 }));
    }

    function test_fuzzCoverage_177() public {
        _run(LibPRNG.PRNG({ state: 177 }));
    }

    function test_fuzzCoverage_178() public {
        _run(LibPRNG.PRNG({ state: 178 }));
    }

    function test_fuzzCoverage_179() public {
        _run(LibPRNG.PRNG({ state: 179 }));
    }

    function test_fuzzCoverage_180() public {
        _run(LibPRNG.PRNG({ state: 180 }));
    }

    function test_fuzzCoverage_181() public {
        _run(LibPRNG.PRNG({ state: 181 }));
    }

    function test_fuzzCoverage_182() public {
        _run(LibPRNG.PRNG({ state: 182 }));
    }

    function test_fuzzCoverage_183() public {
        _run(LibPRNG.PRNG({ state: 183 }));
    }

    function test_fuzzCoverage_184() public {
        _run(LibPRNG.PRNG({ state: 184 }));
    }

    function test_fuzzCoverage_185() public {
        _run(LibPRNG.PRNG({ state: 185 }));
    }

    function test_fuzzCoverage_186() public {
        _run(LibPRNG.PRNG({ state: 186 }));
    }

    function test_fuzzCoverage_187() public {
        _run(LibPRNG.PRNG({ state: 187 }));
    }

    function test_fuzzCoverage_188() public {
        _run(LibPRNG.PRNG({ state: 188 }));
    }

    function test_fuzzCoverage_189() public {
        _run(LibPRNG.PRNG({ state: 189 }));
    }

    function test_fuzzCoverage_190() public {
        _run(LibPRNG.PRNG({ state: 190 }));
    }

    function test_fuzzCoverage_191() public {
        _run(LibPRNG.PRNG({ state: 191 }));
    }

    function test_fuzzCoverage_192() public {
        _run(LibPRNG.PRNG({ state: 192 }));
    }

    function test_fuzzCoverage_193() public {
        _run(LibPRNG.PRNG({ state: 193 }));
    }

    function test_fuzzCoverage_194() public {
        _run(LibPRNG.PRNG({ state: 194 }));
    }

    function test_fuzzCoverage_195() public {
        _run(LibPRNG.PRNG({ state: 195 }));
    }

    function test_fuzzCoverage_196() public {
        _run(LibPRNG.PRNG({ state: 196 }));
    }

    function test_fuzzCoverage_197() public {
        _run(LibPRNG.PRNG({ state: 197 }));
    }

    function test_fuzzCoverage_198() public {
        _run(LibPRNG.PRNG({ state: 198 }));
    }

    function test_fuzzCoverage_199() public {
        _run(LibPRNG.PRNG({ state: 199 }));
    }

    function test_fuzzCoverage_200() public {
        _run(LibPRNG.PRNG({ state: 200 }));
    }

    function test_fuzzCoverage_201() public {
        _run(LibPRNG.PRNG({ state: 201 }));
    }

    function test_fuzzCoverage_202() public {
        _run(LibPRNG.PRNG({ state: 202 }));
    }

    function test_fuzzCoverage_203() public {
        _run(LibPRNG.PRNG({ state: 203 }));
    }

    function test_fuzzCoverage_204() public {
        _run(LibPRNG.PRNG({ state: 204 }));
    }

    function test_fuzzCoverage_205() public {
        _run(LibPRNG.PRNG({ state: 205 }));
    }

    function test_fuzzCoverage_206() public {
        _run(LibPRNG.PRNG({ state: 206 }));
    }

    function test_fuzzCoverage_207() public {
        _run(LibPRNG.PRNG({ state: 207 }));
    }

    function test_fuzzCoverage_208() public {
        _run(LibPRNG.PRNG({ state: 208 }));
    }

    function test_fuzzCoverage_209() public {
        _run(LibPRNG.PRNG({ state: 209 }));
    }

    function test_fuzzCoverage_210() public {
        _run(LibPRNG.PRNG({ state: 210 }));
    }

    function test_fuzzCoverage_211() public {
        _run(LibPRNG.PRNG({ state: 211 }));
    }

    function test_fuzzCoverage_212() public {
        _run(LibPRNG.PRNG({ state: 212 }));
    }

    function test_fuzzCoverage_213() public {
        _run(LibPRNG.PRNG({ state: 213 }));
    }

    function test_fuzzCoverage_214() public {
        _run(LibPRNG.PRNG({ state: 214 }));
    }

    function test_fuzzCoverage_215() public {
        _run(LibPRNG.PRNG({ state: 215 }));
    }

    function test_fuzzCoverage_216() public {
        _run(LibPRNG.PRNG({ state: 216 }));
    }

    function test_fuzzCoverage_217() public {
        _run(LibPRNG.PRNG({ state: 217 }));
    }

    function test_fuzzCoverage_218() public {
        _run(LibPRNG.PRNG({ state: 218 }));
    }

    function test_fuzzCoverage_219() public {
        _run(LibPRNG.PRNG({ state: 219 }));
    }

    function test_fuzzCoverage_220() public {
        _run(LibPRNG.PRNG({ state: 220 }));
    }

    function test_fuzzCoverage_221() public {
        _run(LibPRNG.PRNG({ state: 221 }));
    }

    function test_fuzzCoverage_222() public {
        _run(LibPRNG.PRNG({ state: 222 }));
    }

    function test_fuzzCoverage_223() public {
        _run(LibPRNG.PRNG({ state: 223 }));
    }

    function test_fuzzCoverage_224() public {
        _run(LibPRNG.PRNG({ state: 224 }));
    }

    function test_fuzzCoverage_225() public {
        _run(LibPRNG.PRNG({ state: 225 }));
    }

    function test_fuzzCoverage_226() public {
        _run(LibPRNG.PRNG({ state: 226 }));
    }

    function test_fuzzCoverage_227() public {
        _run(LibPRNG.PRNG({ state: 227 }));
    }

    function test_fuzzCoverage_228() public {
        _run(LibPRNG.PRNG({ state: 228 }));
    }

    function test_fuzzCoverage_229() public {
        _run(LibPRNG.PRNG({ state: 229 }));
    }

    function test_fuzzCoverage_230() public {
        _run(LibPRNG.PRNG({ state: 230 }));
    }

    function test_fuzzCoverage_231() public {
        _run(LibPRNG.PRNG({ state: 231 }));
    }

    function test_fuzzCoverage_232() public {
        _run(LibPRNG.PRNG({ state: 232 }));
    }

    function test_fuzzCoverage_233() public {
        _run(LibPRNG.PRNG({ state: 233 }));
    }

    function test_fuzzCoverage_234() public {
        _run(LibPRNG.PRNG({ state: 234 }));
    }

    function test_fuzzCoverage_235() public {
        _run(LibPRNG.PRNG({ state: 235 }));
    }

    function test_fuzzCoverage_236() public {
        _run(LibPRNG.PRNG({ state: 236 }));
    }

    function test_fuzzCoverage_237() public {
        _run(LibPRNG.PRNG({ state: 237 }));
    }

    function test_fuzzCoverage_238() public {
        _run(LibPRNG.PRNG({ state: 238 }));
    }

    function test_fuzzCoverage_239() public {
        _run(LibPRNG.PRNG({ state: 239 }));
    }

    function test_fuzzCoverage_240() public {
        _run(LibPRNG.PRNG({ state: 240 }));
    }

    function test_fuzzCoverage_241() public {
        _run(LibPRNG.PRNG({ state: 241 }));
    }

    function test_fuzzCoverage_242() public {
        _run(LibPRNG.PRNG({ state: 242 }));
    }

    function test_fuzzCoverage_243() public {
        _run(LibPRNG.PRNG({ state: 243 }));
    }

    // NOTE: skip
    function xtest_fuzzCoverage_244() public {
        _run(LibPRNG.PRNG({ state: 244 }));
    }

    function test_fuzzCoverage_245() public {
        _run(LibPRNG.PRNG({ state: 245 }));
    }

    function test_fuzzCoverage_246() public {
        _run(LibPRNG.PRNG({ state: 246 }));
    }

    function test_fuzzCoverage_247() public {
        _run(LibPRNG.PRNG({ state: 247 }));
    }

    function test_fuzzCoverage_248() public {
        _run(LibPRNG.PRNG({ state: 248 }));
    }

    function test_fuzzCoverage_249() public {
        _run(LibPRNG.PRNG({ state: 249 }));
    }

    function test_fuzzCoverage_250() public {
        _run(LibPRNG.PRNG({ state: 250 }));
    }

    function test_fuzzCoverage_251() public {
        _run(LibPRNG.PRNG({ state: 251 }));
    }

    function test_fuzzCoverage_252() public {
        _run(LibPRNG.PRNG({ state: 252 }));
    }

    function test_fuzzCoverage_253() public {
        _run(LibPRNG.PRNG({ state: 253 }));
    }

    function test_fuzzCoverage_254() public {
        _run(LibPRNG.PRNG({ state: 254 }));
    }

    function test_fuzzCoverage_255() public {
        _run(LibPRNG.PRNG({ state: 255 }));
    }

    function test_fuzzCoverage_256() public {
        _run(LibPRNG.PRNG({ state: 256 }));
    }

    function test_fuzzCoverage_257() public {
        _run(LibPRNG.PRNG({ state: 257 }));
    }

    function test_fuzzCoverage_258() public {
        _run(LibPRNG.PRNG({ state: 258 }));
    }

    function test_fuzzCoverage_259() public {
        _run(LibPRNG.PRNG({ state: 259 }));
    }

    function test_fuzzCoverage_260() public {
        _run(LibPRNG.PRNG({ state: 260 }));
    }

    function test_fuzzCoverage_261() public {
        _run(LibPRNG.PRNG({ state: 261 }));
    }

    function test_fuzzCoverage_262() public {
        _run(LibPRNG.PRNG({ state: 262 }));
    }

    function test_fuzzCoverage_263() public {
        _run(LibPRNG.PRNG({ state: 263 }));
    }

    function test_fuzzCoverage_264() public {
        _run(LibPRNG.PRNG({ state: 264 }));
    }

    function test_fuzzCoverage_265() public {
        _run(LibPRNG.PRNG({ state: 265 }));
    }

    function test_fuzzCoverage_266() public {
        _run(LibPRNG.PRNG({ state: 266 }));
    }

    function test_fuzzCoverage_267() public {
        _run(LibPRNG.PRNG({ state: 267 }));
    }

    function test_fuzzCoverage_268() public {
        _run(LibPRNG.PRNG({ state: 268 }));
    }

    function test_fuzzCoverage_269() public {
        _run(LibPRNG.PRNG({ state: 269 }));
    }

    // NOTE: skip
    function xtest_fuzzCoverage_270() public {
        _run(LibPRNG.PRNG({ state: 270 }));
    }

    function test_fuzzCoverage_271() public {
        _run(LibPRNG.PRNG({ state: 271 }));
    }

    function test_fuzzCoverage_272() public {
        _run(LibPRNG.PRNG({ state: 272 }));
    }

    // NOTE: skip
    function xtest_fuzzCoverage_273() public {
        _run(LibPRNG.PRNG({ state: 273 }));
    }

    function test_fuzzCoverage_274() public {
        _run(LibPRNG.PRNG({ state: 274 }));
    }

    function test_fuzzCoverage_275() public {
        _run(LibPRNG.PRNG({ state: 275 }));
    }

    function test_fuzzCoverage_276() public {
        _run(LibPRNG.PRNG({ state: 276 }));
    }

    function test_fuzzCoverage_277() public {
        _run(LibPRNG.PRNG({ state: 277 }));
    }

    function test_fuzzCoverage_278() public {
        _run(LibPRNG.PRNG({ state: 278 }));
    }

    function test_fuzzCoverage_279() public {
        _run(LibPRNG.PRNG({ state: 279 }));
    }

    function test_fuzzCoverage_280() public {
        _run(LibPRNG.PRNG({ state: 280 }));
    }

    function test_fuzzCoverage_281() public {
        _run(LibPRNG.PRNG({ state: 281 }));
    }

    function test_fuzzCoverage_282() public {
        _run(LibPRNG.PRNG({ state: 282 }));
    }

    function test_fuzzCoverage_283() public {
        _run(LibPRNG.PRNG({ state: 283 }));
    }

    function test_fuzzCoverage_284() public {
        _run(LibPRNG.PRNG({ state: 284 }));
    }

    function test_fuzzCoverage_285() public {
        _run(LibPRNG.PRNG({ state: 285 }));
    }

    function test_fuzzCoverage_286() public {
        _run(LibPRNG.PRNG({ state: 286 }));
    }

    function test_fuzzCoverage_287() public {
        _run(LibPRNG.PRNG({ state: 287 }));
    }

    function test_fuzzCoverage_288() public {
        _run(LibPRNG.PRNG({ state: 288 }));
    }

    function test_fuzzCoverage_289() public {
        _run(LibPRNG.PRNG({ state: 289 }));
    }

    function test_fuzzCoverage_290() public {
        _run(LibPRNG.PRNG({ state: 290 }));
    }

    function test_fuzzCoverage_291() public {
        _run(LibPRNG.PRNG({ state: 291 }));
    }

    function test_fuzzCoverage_292() public {
        _run(LibPRNG.PRNG({ state: 292 }));
    }

    function test_fuzzCoverage_293() public {
        _run(LibPRNG.PRNG({ state: 293 }));
    }

    function test_fuzzCoverage_294() public {
        _run(LibPRNG.PRNG({ state: 294 }));
    }

    function test_fuzzCoverage_295() public {
        _run(LibPRNG.PRNG({ state: 295 }));
    }

    function test_fuzzCoverage_296() public {
        _run(LibPRNG.PRNG({ state: 296 }));
    }

    function test_fuzzCoverage_297() public {
        _run(LibPRNG.PRNG({ state: 297 }));
    }

    function test_fuzzCoverage_298() public {
        _run(LibPRNG.PRNG({ state: 298 }));
    }

    function test_fuzzCoverage_299() public {
        _run(LibPRNG.PRNG({ state: 299 }));
    }

    function test_fuzzCoverage_300() public {
        _run(LibPRNG.PRNG({ state: 300 }));
    }

    function test_fuzzCoverage_301() public {
        _run(LibPRNG.PRNG({ state: 301 }));
    }

    function test_fuzzCoverage_302() public {
        _run(LibPRNG.PRNG({ state: 302 }));
    }

    function test_fuzzCoverage_303() public {
        _run(LibPRNG.PRNG({ state: 303 }));
    }

    function test_fuzzCoverage_304() public {
        _run(LibPRNG.PRNG({ state: 304 }));
    }

    function test_fuzzCoverage_305() public {
        _run(LibPRNG.PRNG({ state: 305 }));
    }

    function test_fuzzCoverage_306() public {
        _run(LibPRNG.PRNG({ state: 306 }));
    }

    function test_fuzzCoverage_307() public {
        _run(LibPRNG.PRNG({ state: 307 }));
    }

    function test_fuzzCoverage_308() public {
        _run(LibPRNG.PRNG({ state: 308 }));
    }

    // NOTE: skip
    function xtest_fuzzCoverage_309() public {
        _run(LibPRNG.PRNG({ state: 309 }));
    }

    function test_fuzzCoverage_310() public {
        _run(LibPRNG.PRNG({ state: 310 }));
    }

    function test_fuzzCoverage_311() public {
        _run(LibPRNG.PRNG({ state: 311 }));
    }

    function test_fuzzCoverage_312() public {
        _run(LibPRNG.PRNG({ state: 312 }));
    }

    function test_fuzzCoverage_313() public {
        _run(LibPRNG.PRNG({ state: 313 }));
    }

    function test_fuzzCoverage_314() public {
        _run(LibPRNG.PRNG({ state: 314 }));
    }

    function test_fuzzCoverage_315() public {
        _run(LibPRNG.PRNG({ state: 315 }));
    }

    function test_fuzzCoverage_316() public {
        _run(LibPRNG.PRNG({ state: 316 }));
    }

    function test_fuzzCoverage_317() public {
        _run(LibPRNG.PRNG({ state: 317 }));
    }

    function test_fuzzCoverage_318() public {
        _run(LibPRNG.PRNG({ state: 318 }));
    }

    function test_fuzzCoverage_319() public {
        _run(LibPRNG.PRNG({ state: 319 }));
    }

    function test_fuzzCoverage_320() public {
        _run(LibPRNG.PRNG({ state: 320 }));
    }

    function test_fuzzCoverage_321() public {
        _run(LibPRNG.PRNG({ state: 321 }));
    }

    function test_fuzzCoverage_322() public {
        _run(LibPRNG.PRNG({ state: 322 }));
    }

    function test_fuzzCoverage_323() public {
        _run(LibPRNG.PRNG({ state: 323 }));
    }

    function test_fuzzCoverage_324() public {
        _run(LibPRNG.PRNG({ state: 324 }));
    }

    function test_fuzzCoverage_325() public {
        _run(LibPRNG.PRNG({ state: 325 }));
    }

    function test_fuzzCoverage_326() public {
        _run(LibPRNG.PRNG({ state: 326 }));
    }

    function test_fuzzCoverage_327() public {
        _run(LibPRNG.PRNG({ state: 327 }));
    }

    function test_fuzzCoverage_328() public {
        _run(LibPRNG.PRNG({ state: 328 }));
    }

    function test_fuzzCoverage_329() public {
        _run(LibPRNG.PRNG({ state: 329 }));
    }

    function test_fuzzCoverage_330() public {
        _run(LibPRNG.PRNG({ state: 330 }));
    }

    function test_fuzzCoverage_331() public {
        _run(LibPRNG.PRNG({ state: 331 }));
    }

    function test_fuzzCoverage_332() public {
        _run(LibPRNG.PRNG({ state: 332 }));
    }

    function test_fuzzCoverage_333() public {
        _run(LibPRNG.PRNG({ state: 333 }));
    }

    function test_fuzzCoverage_334() public {
        _run(LibPRNG.PRNG({ state: 334 }));
    }

    function test_fuzzCoverage_335() public {
        _run(LibPRNG.PRNG({ state: 335 }));
    }

    function test_fuzzCoverage_336() public {
        _run(LibPRNG.PRNG({ state: 336 }));
    }

    function test_fuzzCoverage_337() public {
        _run(LibPRNG.PRNG({ state: 337 }));
    }

    function test_fuzzCoverage_338() public {
        _run(LibPRNG.PRNG({ state: 338 }));
    }

    function test_fuzzCoverage_339() public {
        _run(LibPRNG.PRNG({ state: 339 }));
    }

    function test_fuzzCoverage_340() public {
        _run(LibPRNG.PRNG({ state: 340 }));
    }

    function test_fuzzCoverage_341() public {
        _run(LibPRNG.PRNG({ state: 341 }));
    }

    function test_fuzzCoverage_342() public {
        _run(LibPRNG.PRNG({ state: 342 }));
    }

    function test_fuzzCoverage_343() public {
        _run(LibPRNG.PRNG({ state: 343 }));
    }

    function test_fuzzCoverage_344() public {
        _run(LibPRNG.PRNG({ state: 344 }));
    }

    function test_fuzzCoverage_345() public {
        _run(LibPRNG.PRNG({ state: 345 }));
    }

    function test_fuzzCoverage_346() public {
        _run(LibPRNG.PRNG({ state: 346 }));
    }

    function test_fuzzCoverage_347() public {
        _run(LibPRNG.PRNG({ state: 347 }));
    }

    function test_fuzzCoverage_348() public {
        _run(LibPRNG.PRNG({ state: 348 }));
    }

    function test_fuzzCoverage_349() public {
        _run(LibPRNG.PRNG({ state: 349 }));
    }

    function test_fuzzCoverage_350() public {
        _run(LibPRNG.PRNG({ state: 350 }));
    }

    function test_fuzzCoverage_351() public {
        _run(LibPRNG.PRNG({ state: 351 }));
    }

    function test_fuzzCoverage_352() public {
        _run(LibPRNG.PRNG({ state: 352 }));
    }

    function test_fuzzCoverage_353() public {
        _run(LibPRNG.PRNG({ state: 353 }));
    }

    function test_fuzzCoverage_354() public {
        _run(LibPRNG.PRNG({ state: 354 }));
    }

    function test_fuzzCoverage_355() public {
        _run(LibPRNG.PRNG({ state: 355 }));
    }

    function test_fuzzCoverage_356() public {
        _run(LibPRNG.PRNG({ state: 356 }));
    }

    function test_fuzzCoverage_357() public {
        _run(LibPRNG.PRNG({ state: 357 }));
    }

    function test_fuzzCoverage_358() public {
        _run(LibPRNG.PRNG({ state: 358 }));
    }

    function test_fuzzCoverage_359() public {
        _run(LibPRNG.PRNG({ state: 359 }));
    }

    // NOTE: skip
    function xtest_fuzzCoverage_360() public {
        _run(LibPRNG.PRNG({ state: 360 }));
    }

    function test_fuzzCoverage_361() public {
        _run(LibPRNG.PRNG({ state: 361 }));
    }

    function test_fuzzCoverage_362() public {
        _run(LibPRNG.PRNG({ state: 362 }));
    }

    function test_fuzzCoverage_363() public {
        _run(LibPRNG.PRNG({ state: 363 }));
    }

    function test_fuzzCoverage_364() public {
        _run(LibPRNG.PRNG({ state: 364 }));
    }

    function test_fuzzCoverage_365() public {
        _run(LibPRNG.PRNG({ state: 365 }));
    }

    function test_fuzzCoverage_366() public {
        _run(LibPRNG.PRNG({ state: 366 }));
    }

    function test_fuzzCoverage_367() public {
        _run(LibPRNG.PRNG({ state: 367 }));
    }

    function test_fuzzCoverage_368() public {
        _run(LibPRNG.PRNG({ state: 368 }));
    }

    function test_fuzzCoverage_369() public {
        _run(LibPRNG.PRNG({ state: 369 }));
    }

    function test_fuzzCoverage_370() public {
        _run(LibPRNG.PRNG({ state: 370 }));
    }

    function test_fuzzCoverage_371() public {
        _run(LibPRNG.PRNG({ state: 371 }));
    }

    function test_fuzzCoverage_372() public {
        _run(LibPRNG.PRNG({ state: 372 }));
    }

    function test_fuzzCoverage_373() public {
        _run(LibPRNG.PRNG({ state: 373 }));
    }

    function test_fuzzCoverage_374() public {
        _run(LibPRNG.PRNG({ state: 374 }));
    }

    function test_fuzzCoverage_375() public {
        _run(LibPRNG.PRNG({ state: 375 }));
    }

    function test_fuzzCoverage_376() public {
        _run(LibPRNG.PRNG({ state: 376 }));
    }

    function test_fuzzCoverage_377() public {
        _run(LibPRNG.PRNG({ state: 377 }));
    }

    function test_fuzzCoverage_378() public {
        _run(LibPRNG.PRNG({ state: 378 }));
    }

    function test_fuzzCoverage_379() public {
        _run(LibPRNG.PRNG({ state: 379 }));
    }

    function test_fuzzCoverage_380() public {
        _run(LibPRNG.PRNG({ state: 380 }));
    }

    function test_fuzzCoverage_381() public {
        _run(LibPRNG.PRNG({ state: 381 }));
    }

    function test_fuzzCoverage_382() public {
        _run(LibPRNG.PRNG({ state: 382 }));
    }

    function test_fuzzCoverage_383() public {
        _run(LibPRNG.PRNG({ state: 383 }));
    }

    function test_fuzzCoverage_384() public {
        _run(LibPRNG.PRNG({ state: 384 }));
    }

    function test_fuzzCoverage_385() public {
        _run(LibPRNG.PRNG({ state: 385 }));
    }

    function test_fuzzCoverage_386() public {
        _run(LibPRNG.PRNG({ state: 386 }));
    }

    function test_fuzzCoverage_387() public {
        _run(LibPRNG.PRNG({ state: 387 }));
    }

    function test_fuzzCoverage_388() public {
        _run(LibPRNG.PRNG({ state: 388 }));
    }

    function test_fuzzCoverage_389() public {
        _run(LibPRNG.PRNG({ state: 389 }));
    }

    function test_fuzzCoverage_390() public {
        _run(LibPRNG.PRNG({ state: 390 }));
    }

    function test_fuzzCoverage_391() public {
        _run(LibPRNG.PRNG({ state: 391 }));
    }

    function test_fuzzCoverage_392() public {
        _run(LibPRNG.PRNG({ state: 392 }));
    }

    function test_fuzzCoverage_393() public {
        _run(LibPRNG.PRNG({ state: 393 }));
    }

    function test_fuzzCoverage_394() public {
        _run(LibPRNG.PRNG({ state: 394 }));
    }

    function test_fuzzCoverage_395() public {
        _run(LibPRNG.PRNG({ state: 395 }));
    }

    function test_fuzzCoverage_396() public {
        _run(LibPRNG.PRNG({ state: 396 }));
    }

    function test_fuzzCoverage_397() public {
        _run(LibPRNG.PRNG({ state: 397 }));
    }

    function test_fuzzCoverage_398() public {
        _run(LibPRNG.PRNG({ state: 398 }));
    }

    function test_fuzzCoverage_399() public {
        _run(LibPRNG.PRNG({ state: 399 }));
    }

    function test_fuzzCoverage_400() public {
        _run(LibPRNG.PRNG({ state: 400 }));
    }

    function test_fuzzCoverage_401() public {
        _run(LibPRNG.PRNG({ state: 401 }));
    }

    function test_fuzzCoverage_402() public {
        _run(LibPRNG.PRNG({ state: 402 }));
    }

    function test_fuzzCoverage_403() public {
        _run(LibPRNG.PRNG({ state: 403 }));
    }

    function test_fuzzCoverage_404() public {
        _run(LibPRNG.PRNG({ state: 404 }));
    }

    function test_fuzzCoverage_405() public {
        _run(LibPRNG.PRNG({ state: 405 }));
    }

    function test_fuzzCoverage_406() public {
        _run(LibPRNG.PRNG({ state: 406 }));
    }

    function test_fuzzCoverage_407() public {
        _run(LibPRNG.PRNG({ state: 407 }));
    }

    function test_fuzzCoverage_408() public {
        _run(LibPRNG.PRNG({ state: 408 }));
    }

    function test_fuzzCoverage_409() public {
        _run(LibPRNG.PRNG({ state: 409 }));
    }

    function test_fuzzCoverage_410() public {
        _run(LibPRNG.PRNG({ state: 410 }));
    }

    function test_fuzzCoverage_411() public {
        _run(LibPRNG.PRNG({ state: 411 }));
    }

    function test_fuzzCoverage_412() public {
        _run(LibPRNG.PRNG({ state: 412 }));
    }

    // NOTE: skip
    function xtest_fuzzCoverage_413() public {
        _run(LibPRNG.PRNG({ state: 413 }));
    }

    function test_fuzzCoverage_414() public {
        _run(LibPRNG.PRNG({ state: 414 }));
    }

    function test_fuzzCoverage_415() public {
        _run(LibPRNG.PRNG({ state: 415 }));
    }

    function test_fuzzCoverage_416() public {
        _run(LibPRNG.PRNG({ state: 416 }));
    }

    function test_fuzzCoverage_417() public {
        _run(LibPRNG.PRNG({ state: 417 }));
    }

    function test_fuzzCoverage_418() public {
        _run(LibPRNG.PRNG({ state: 418 }));
    }

    function test_fuzzCoverage_419() public {
        _run(LibPRNG.PRNG({ state: 419 }));
    }

    function test_fuzzCoverage_420() public {
        _run(LibPRNG.PRNG({ state: 420 }));
    }

    function test_fuzzCoverage_421() public {
        _run(LibPRNG.PRNG({ state: 421 }));
    }

    function test_fuzzCoverage_422() public {
        _run(LibPRNG.PRNG({ state: 422 }));
    }

    function test_fuzzCoverage_423() public {
        _run(LibPRNG.PRNG({ state: 423 }));
    }

    function test_fuzzCoverage_424() public {
        _run(LibPRNG.PRNG({ state: 424 }));
    }

    function test_fuzzCoverage_425() public {
        _run(LibPRNG.PRNG({ state: 425 }));
    }

    function test_fuzzCoverage_426() public {
        _run(LibPRNG.PRNG({ state: 426 }));
    }

    function test_fuzzCoverage_427() public {
        _run(LibPRNG.PRNG({ state: 427 }));
    }

    function test_fuzzCoverage_428() public {
        _run(LibPRNG.PRNG({ state: 428 }));
    }

    function test_fuzzCoverage_429() public {
        _run(LibPRNG.PRNG({ state: 429 }));
    }

    function test_fuzzCoverage_430() public {
        _run(LibPRNG.PRNG({ state: 430 }));
    }

    function test_fuzzCoverage_431() public {
        _run(LibPRNG.PRNG({ state: 431 }));
    }

    function test_fuzzCoverage_432() public {
        _run(LibPRNG.PRNG({ state: 432 }));
    }

    function test_fuzzCoverage_433() public {
        _run(LibPRNG.PRNG({ state: 433 }));
    }

    function test_fuzzCoverage_434() public {
        _run(LibPRNG.PRNG({ state: 434 }));
    }

    function test_fuzzCoverage_435() public {
        _run(LibPRNG.PRNG({ state: 435 }));
    }

    function test_fuzzCoverage_436() public {
        _run(LibPRNG.PRNG({ state: 436 }));
    }

    function test_fuzzCoverage_437() public {
        _run(LibPRNG.PRNG({ state: 437 }));
    }

    function test_fuzzCoverage_438() public {
        _run(LibPRNG.PRNG({ state: 438 }));
    }

    function test_fuzzCoverage_439() public {
        _run(LibPRNG.PRNG({ state: 439 }));
    }

    function test_fuzzCoverage_440() public {
        _run(LibPRNG.PRNG({ state: 440 }));
    }

    function test_fuzzCoverage_441() public {
        _run(LibPRNG.PRNG({ state: 441 }));
    }

    function test_fuzzCoverage_442() public {
        _run(LibPRNG.PRNG({ state: 442 }));
    }

    function test_fuzzCoverage_443() public {
        _run(LibPRNG.PRNG({ state: 443 }));
    }

    function test_fuzzCoverage_444() public {
        _run(LibPRNG.PRNG({ state: 444 }));
    }

    function test_fuzzCoverage_445() public {
        _run(LibPRNG.PRNG({ state: 445 }));
    }

    function test_fuzzCoverage_446() public {
        _run(LibPRNG.PRNG({ state: 446 }));
    }

    function test_fuzzCoverage_447() public {
        _run(LibPRNG.PRNG({ state: 447 }));
    }

    function test_fuzzCoverage_448() public {
        _run(LibPRNG.PRNG({ state: 448 }));
    }

    function test_fuzzCoverage_449() public {
        _run(LibPRNG.PRNG({ state: 449 }));
    }

    function test_fuzzCoverage_450() public {
        _run(LibPRNG.PRNG({ state: 450 }));
    }

    function test_fuzzCoverage_451() public {
        _run(LibPRNG.PRNG({ state: 451 }));
    }

    function test_fuzzCoverage_452() public {
        _run(LibPRNG.PRNG({ state: 452 }));
    }

    function test_fuzzCoverage_453() public {
        _run(LibPRNG.PRNG({ state: 453 }));
    }

    function test_fuzzCoverage_454() public {
        _run(LibPRNG.PRNG({ state: 454 }));
    }

    function test_fuzzCoverage_455() public {
        _run(LibPRNG.PRNG({ state: 455 }));
    }

    function test_fuzzCoverage_456() public {
        _run(LibPRNG.PRNG({ state: 456 }));
    }

    function test_fuzzCoverage_457() public {
        _run(LibPRNG.PRNG({ state: 457 }));
    }

    function test_fuzzCoverage_458() public {
        _run(LibPRNG.PRNG({ state: 458 }));
    }

    function test_fuzzCoverage_459() public {
        _run(LibPRNG.PRNG({ state: 459 }));
    }

    function test_fuzzCoverage_460() public {
        _run(LibPRNG.PRNG({ state: 460 }));
    }

    function test_fuzzCoverage_461() public {
        _run(LibPRNG.PRNG({ state: 461 }));
    }

    function test_fuzzCoverage_462() public {
        _run(LibPRNG.PRNG({ state: 462 }));
    }

    function test_fuzzCoverage_463() public {
        _run(LibPRNG.PRNG({ state: 463 }));
    }

    function test_fuzzCoverage_464() public {
        _run(LibPRNG.PRNG({ state: 464 }));
    }

    function test_fuzzCoverage_465() public {
        _run(LibPRNG.PRNG({ state: 465 }));
    }

    function test_fuzzCoverage_466() public {
        _run(LibPRNG.PRNG({ state: 466 }));
    }

    function test_fuzzCoverage_467() public {
        _run(LibPRNG.PRNG({ state: 467 }));
    }

    function test_fuzzCoverage_468() public {
        _run(LibPRNG.PRNG({ state: 468 }));
    }

    function test_fuzzCoverage_469() public {
        _run(LibPRNG.PRNG({ state: 469 }));
    }

    function test_fuzzCoverage_470() public {
        _run(LibPRNG.PRNG({ state: 470 }));
    }

    function test_fuzzCoverage_471() public {
        _run(LibPRNG.PRNG({ state: 471 }));
    }

    function test_fuzzCoverage_472() public {
        _run(LibPRNG.PRNG({ state: 472 }));
    }

    function test_fuzzCoverage_473() public {
        _run(LibPRNG.PRNG({ state: 473 }));
    }

    function test_fuzzCoverage_474() public {
        _run(LibPRNG.PRNG({ state: 474 }));
    }

    function test_fuzzCoverage_475() public {
        _run(LibPRNG.PRNG({ state: 475 }));
    }

    function test_fuzzCoverage_476() public {
        _run(LibPRNG.PRNG({ state: 476 }));
    }

    function test_fuzzCoverage_477() public {
        _run(LibPRNG.PRNG({ state: 477 }));
    }

    function test_fuzzCoverage_478() public {
        _run(LibPRNG.PRNG({ state: 478 }));
    }

    function test_fuzzCoverage_479() public {
        _run(LibPRNG.PRNG({ state: 479 }));
    }

    function test_fuzzCoverage_480() public {
        _run(LibPRNG.PRNG({ state: 480 }));
    }

    function test_fuzzCoverage_481() public {
        _run(LibPRNG.PRNG({ state: 481 }));
    }

    function test_fuzzCoverage_482() public {
        _run(LibPRNG.PRNG({ state: 482 }));
    }

    function test_fuzzCoverage_483() public {
        _run(LibPRNG.PRNG({ state: 483 }));
    }

    function test_fuzzCoverage_484() public {
        _run(LibPRNG.PRNG({ state: 484 }));
    }

    function test_fuzzCoverage_485() public {
        _run(LibPRNG.PRNG({ state: 485 }));
    }

    function test_fuzzCoverage_486() public {
        _run(LibPRNG.PRNG({ state: 486 }));
    }

    function test_fuzzCoverage_487() public {
        _run(LibPRNG.PRNG({ state: 487 }));
    }

    function test_fuzzCoverage_488() public {
        _run(LibPRNG.PRNG({ state: 488 }));
    }

    function test_fuzzCoverage_489() public {
        _run(LibPRNG.PRNG({ state: 489 }));
    }

    function test_fuzzCoverage_490() public {
        _run(LibPRNG.PRNG({ state: 490 }));
    }

    function test_fuzzCoverage_491() public {
        _run(LibPRNG.PRNG({ state: 491 }));
    }

    function test_fuzzCoverage_492() public {
        _run(LibPRNG.PRNG({ state: 492 }));
    }

    function test_fuzzCoverage_493() public {
        _run(LibPRNG.PRNG({ state: 493 }));
    }

    function test_fuzzCoverage_494() public {
        _run(LibPRNG.PRNG({ state: 494 }));
    }

    function test_fuzzCoverage_495() public {
        _run(LibPRNG.PRNG({ state: 495 }));
    }

    function test_fuzzCoverage_496() public {
        _run(LibPRNG.PRNG({ state: 496 }));
    }

    function test_fuzzCoverage_497() public {
        _run(LibPRNG.PRNG({ state: 497 }));
    }

    function test_fuzzCoverage_498() public {
        _run(LibPRNG.PRNG({ state: 498 }));
    }

    function test_fuzzCoverage_499() public {
        _run(LibPRNG.PRNG({ state: 499 }));
    }

    function test_fuzzCoverage_500() public {
        _run(LibPRNG.PRNG({ state: 500 }));
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
