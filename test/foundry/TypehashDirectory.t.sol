// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { TypehashDirectory } from "../../contracts/test/TypehashDirectory.sol";

import {
    BulkOrder_Typehash_Height_One,
    BulkOrder_Typehash_Height_Two,
    BulkOrder_Typehash_Height_Three,
    BulkOrder_Typehash_Height_Four,
    BulkOrder_Typehash_Height_Five,
    BulkOrder_Typehash_Height_Six,
    BulkOrder_Typehash_Height_Seven,
    BulkOrder_Typehash_Height_Eight,
    BulkOrder_Typehash_Height_Nine,
    BulkOrder_Typehash_Height_Ten,
    BulkOrder_Typehash_Height_Eleven,
    BulkOrder_Typehash_Height_Twelve,
    BulkOrder_Typehash_Height_Thirteen,
    BulkOrder_Typehash_Height_Fourteen,
    BulkOrder_Typehash_Height_Fifteen,
    BulkOrder_Typehash_Height_Sixteen,
    BulkOrder_Typehash_Height_Seventeen,
    BulkOrder_Typehash_Height_Eighteen,
    BulkOrder_Typehash_Height_Nineteen,
    BulkOrder_Typehash_Height_Twenty,
    BulkOrder_Typehash_Height_TwentyOne,
    BulkOrder_Typehash_Height_TwentyTwo,
    BulkOrder_Typehash_Height_TwentyThree,
    BulkOrder_Typehash_Height_TwentyFour
} from "seaport-types/src/lib/ConsiderationConstants.sol";

/**
 * @dev Port of typehashdirectory.spec.ts. TypehashDirectory's runtime code is
 *      an INVALID opcode followed by the 24 bulk order typehashes, one per
 *      tree height. This test derives each typehash from the EIP-712 type
 *      strings written out here, compares it with the deployed code, and
 *      also with the constant the optimized build uses for that height.
 */
contract TypehashDirectoryTest is Test {
    string internal constant SUB_TYPES = "ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)"
        "OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)"
        "OrderComponents(address offerer,address zone,OfferItem[] offer,ConsiderationItem[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,bytes32 zoneHash,uint256 salt,bytes32 conduitKey,uint256 counter)";

    function test_codeIsInvalidOpcodeAndBulkOrderTypehashes() public {
        bytes memory code = address(new TypehashDirectory()).code;
        uint256[24] memory seaportConstants = [
            BulkOrder_Typehash_Height_One,
            BulkOrder_Typehash_Height_Two,
            BulkOrder_Typehash_Height_Three,
            BulkOrder_Typehash_Height_Four,
            BulkOrder_Typehash_Height_Five,
            BulkOrder_Typehash_Height_Six,
            BulkOrder_Typehash_Height_Seven,
            BulkOrder_Typehash_Height_Eight,
            BulkOrder_Typehash_Height_Nine,
            BulkOrder_Typehash_Height_Ten,
            BulkOrder_Typehash_Height_Eleven,
            BulkOrder_Typehash_Height_Twelve,
            BulkOrder_Typehash_Height_Thirteen,
            BulkOrder_Typehash_Height_Fourteen,
            BulkOrder_Typehash_Height_Fifteen,
            BulkOrder_Typehash_Height_Sixteen,
            BulkOrder_Typehash_Height_Seventeen,
            BulkOrder_Typehash_Height_Eighteen,
            BulkOrder_Typehash_Height_Nineteen,
            BulkOrder_Typehash_Height_Twenty,
            BulkOrder_Typehash_Height_TwentyOne,
            BulkOrder_Typehash_Height_TwentyTwo,
            BulkOrder_Typehash_Height_TwentyThree,
            BulkOrder_Typehash_Height_TwentyFour
        ];

        bytes memory expected = hex"fe";
        bytes memory brackets;
        for (uint256 height = 1; height <= 24; ++height) {
            brackets = bytes.concat(brackets, "[2]");
            bytes32 typehash = keccak256(
                bytes.concat(
                    "BulkOrder(OrderComponents",
                    brackets,
                    " tree)",
                    bytes(SUB_TYPES)
                )
            );
            assertEq(typehash, bytes32(seaportConstants[height - 1]));
            expected = bytes.concat(expected, typehash);
        }

        assertEq(code.length, 1 + 24 * 32);
        assertEq(code, expected);
    }
}
