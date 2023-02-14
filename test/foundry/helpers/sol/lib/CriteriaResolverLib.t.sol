// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    CriteriaResolverLib
} from "../../../../../contracts/helpers/sol/lib/CriteriaResolverLib.sol";
import {
    CriteriaResolver
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { Side } from "../../../../../contracts/lib/ConsiderationEnums.sol";

contract CriteriaResolverLibTest is BaseTest {
    using CriteriaResolverLib for CriteriaResolver;

    function testRetrieveDefault(
        uint256 orderIndex,
        bool side,
        uint256 index,
        uint256 identifier,
        bytes32[] memory criteriaProof
    ) public {
        CriteriaResolver memory criteriaResolver = CriteriaResolver({
            orderIndex: orderIndex,
            side: Side(side ? 1 : 0),
            index: index,
            identifier: identifier,
            criteriaProof: criteriaProof
        });
        CriteriaResolverLib.saveDefault(criteriaResolver, "default");
        CriteriaResolver memory defaultCriteriaResolver = CriteriaResolverLib
            .fromDefault("default");
        assertEq(criteriaResolver, defaultCriteriaResolver);
    }

    function testComposeEmpty(
        uint256 orderIndex,
        bool side,
        uint256 index,
        uint256 identifier,
        bytes32[] memory criteriaProof
    ) public {
        CriteriaResolver memory criteriaResolver = CriteriaResolverLib
            .empty()
            .withOrderIndex(orderIndex)
            .withSide(Side(side ? 1 : 0))
            .withIndex(index)
            .withIdentifier(identifier)
            .withCriteriaProof(criteriaProof);
        assertEq(
            criteriaResolver,
            CriteriaResolver({
                orderIndex: orderIndex,
                side: Side(side ? 1 : 0),
                index: index,
                identifier: identifier,
                criteriaProof: criteriaProof
            })
        );
    }

    function testCopy() public {
        CriteriaResolver memory criteriaResolver = CriteriaResolver({
            orderIndex: 1,
            side: Side(1),
            index: 1,
            identifier: 1,
            criteriaProof: new bytes32[](0)
        });
        CriteriaResolver memory copy = criteriaResolver.copy();
        assertEq(criteriaResolver, copy);
        criteriaResolver.index = 2;
        assertEq(copy.index, 1);
    }

    function testRetrieveDefaultMany(
        uint256[3] memory orderIndex,
        bool[3] memory side,
        uint256[3] memory index,
        uint256[3] memory identifier,
        bytes32[][3] memory criteriaProof
    ) public {
        CriteriaResolver[] memory criteriaResolvers = new CriteriaResolver[](3);
        for (uint256 i = 0; i < 3; i++) {
            criteriaResolvers[i] = CriteriaResolver({
                orderIndex: orderIndex[i],
                side: Side(side[i] ? 1 : 0),
                index: index[i],
                identifier: identifier[i],
                criteriaProof: criteriaProof[i]
            });
        }
        CriteriaResolverLib.saveDefaultMany(criteriaResolvers, "default");
        CriteriaResolver[] memory defaultCriteriaResolvers = CriteriaResolverLib
            .fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(criteriaResolvers[i], defaultCriteriaResolvers[i]);
        }
    }
}
