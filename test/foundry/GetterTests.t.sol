// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import { BaseConsiderationTest } from "./utils/BaseConsiderationTest.sol";

contract TestGetters is BaseConsiderationTest {
    /**function tesGetCorrectName() public {
        assertEq(consideration.name(), "Consideration");
    }

    function testGetsCorrectVersion() public {
        assertEq(consideration.version(), "rc.1");
    }


    function testGetCorrectDomainSeparator() public {
        bytes memory typeName = abi.encodePacked(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 typeHash = keccak256(typeName);
        /**bytes32 nameHash = keccak256(bytes(consideration.name()));
        bytes32 versionHash = keccak256(bytes(consideration.version()));
        bytes32 considerationSeparator = consideration.DOMAIN_SEPARATOR();

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
        bytes32 versionHash = keccak256(bytes(consideration.version()));
        bytes32 considerationSeparator = consideration.DOMAIN_SEPARATOR();

        // change chainId and check that separator changes
        vm.chainId(_chainId);
        assertFalse(consideration.DOMAIN_SEPARATOR() == considerationSeparator);
        assertEq(
            consideration.DOMAIN_SEPARATOR(),
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
    **/
}
