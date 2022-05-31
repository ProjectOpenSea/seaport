// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13;

import { BaseConsiderationTest } from "./utils/BaseConsiderationTest.sol";

contract TestGetters is BaseConsiderationTest {
    function tesGetCorrectName() public {
        assertEq(consideration.name(), "Consideration");
    }

    function testGetsCorrectVersion() public {
        (string memory version, , ) = consideration.information();
        assertEq(version, "1");
    }

    function testGetCorrectDomainSeparator() public {
        bytes memory typeName = abi.encodePacked(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 typeHash = keccak256(typeName);
        bytes32 nameHash = keccak256(bytes(consideration.name()));
        (string memory version, bytes32 domainSeparator, ) = consideration
            .information();
        bytes32 versionHash = keccak256(bytes(version));
        bytes32 considerationSeparator = domainSeparator;

        // manually construct separator and compare
        assertEq(
            considerationSeparator,
            keccak256(
                abi.encode(
                    typeHash,
                    nameHash,
                    versionHash,
                    block.chainid,
                    address(consideration)
                )
            )
        );
    }

    function testGetCorrectDomainSeparator(uint256 _chainId) public {
        // ignore case where _chainId is the same as block.chainid
        vm.assume(_chainId != block.chainid);
        bytes memory typeName = abi.encodePacked(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 typeHash = keccak256(typeName);
        bytes32 nameHash = keccak256(bytes(consideration.name()));
        (string memory version, bytes32 domainSeparator, ) = consideration
            .information();
        bytes32 versionHash = keccak256(bytes(version));
        bytes32 considerationSeparator = domainSeparator;

        // change chainId and check that separator changes
        vm.chainId(_chainId);
        // Repull the domainSeparator
        (, domainSeparator, ) = consideration.information();
        assertFalse(domainSeparator == considerationSeparator);
        assertEq(
            domainSeparator,
            keccak256(
                abi.encode(
                    typeHash,
                    nameHash,
                    versionHash,
                    _chainId,
                    address(consideration)
                )
            )
        );
    }
}
