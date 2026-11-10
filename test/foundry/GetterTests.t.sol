// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import { BaseConsiderationTest } from "./utils/BaseConsiderationTest.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import { Seaport } from "../../contracts/Seaport.sol";

contract TestGetters is BaseConsiderationTest {
    function testGetCorrectName() public {
        assertEq(consideration.name(), "Consideration");
    }

    function testCleanName() public {
        string memory name = consideration.name();

        uint256 rds;
        assembly {
            rds := returndatasize()
        }

        // offset (0x20) + length (0x20) + content (0x20) = 0x60
        assertEq(rds, 0x60);

        uint256 offset;
        uint256 length;
        bytes32 value;
        assembly {
            let freeMemoryPointer := mload(0x40)
            returndatacopy(freeMemoryPointer, 0, returndatasize())
            offset := mload(freeMemoryPointer)
            length := mload(add(freeMemoryPointer, 0x20))
            value := mload(add(freeMemoryPointer, 0x40))
        }

        // Default offset for abi.encode("Consideration")
        assertEq(offset, 0x20);
        // Length of "Consideration"
        assertEq(length, 13);
        // Check if there are dirty bits
        assertEq(value, bytes32(abi.encodePacked(name)));
    }

    function testGetsCorrectVersion() public {
        (string memory version,,) = consideration.information();
        assertEq(version, "1.6");
    }

    function testGetCorrectDomainSeparator() public {
        bytes memory typeName = abi.encodePacked(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 typeHash = keccak256(typeName);
        bytes32 nameHash = keccak256(bytes(consideration.name()));
        (string memory version, bytes32 domainSeparator,) =
            consideration.information();
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

    function testGetCorrectDomainSeparator(uint64 _chainId) public {
        // ignore case where _chainId is the same as block.chainid
        vm.assume(_chainId != block.chainid);
        bytes memory typeName = abi.encodePacked(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 typeHash = keccak256(typeName);
        bytes32 nameHash = keccak256(bytes(consideration.name()));
        (string memory version, bytes32 domainSeparator,) =
            consideration.information();
        bytes32 versionHash = keccak256(bytes(version));
        bytes32 considerationSeparator = domainSeparator;

        // change chainId and check that separator changes
        vm.chainId(_chainId);
        // Repull the domainSeparator
        (, domainSeparator,) = consideration.information();
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

/// @dev Getters on the Seaport wrapper itself. The rest of the suite deploys
///      Consideration, so this is the only place Seaport's name overrides run.
contract TestSeaportGetters is BaseConsiderationTest {
    ConsiderationInterface seaport;

    function setUp() public override {
        super.setUp();
        if (!coverage_or_debug) {
            seaport = ConsiderationInterface(
                deployCode(
                    "optimized-out/Seaport.sol/Seaport.json",
                    abi.encode(address(conduitController))
                )
            );
        } else {
            seaport = new Seaport(address(conduitController));
        }
        vm.label(address(seaport), "seaport");
    }

    function _expectedDomainSeparator(uint256 chainId)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("Seaport"),
                keccak256("1.6"),
                chainId,
                address(seaport)
            )
        );
    }

    function testGetCorrectName() public view {
        assertEq(seaport.name(), "Seaport");
        // The Consideration base contract keeps its own name.
        assertEq(consideration.name(), "Consideration");
    }

    function testCleanName() public view {
        // Seaport returns its name from assembly, so check the raw encoding.
        (bool success, bytes memory returnData) = address(seaport)
            .staticcall(
                abi.encodeWithSelector(ConsiderationInterface.name.selector)
            );
        assertTrue(success);
        assertEq(returnData, abi.encode("Seaport"));
    }

    function testGetCorrectInformation() public view {
        (string memory version, bytes32 domainSeparator, address controller) =
            seaport.information();
        assertEq(version, "1.6");
        assertEq(domainSeparator, _expectedDomainSeparator(block.chainid));
        assertEq(controller, address(conduitController));
    }

    function testGetCorrectDomainSeparator(uint64 _chainId) public {
        vm.assume(_chainId != block.chainid);
        (, bytes32 originalDomainSeparator,) = seaport.information();

        // A new chain id makes Seaport derive the separator again from its
        // name string instead of returning the cached one.
        vm.chainId(_chainId);
        (, bytes32 domainSeparator,) = seaport.information();
        assertFalse(domainSeparator == originalDomainSeparator);
        assertEq(domainSeparator, _expectedDomainSeparator(_chainId));
    }
}

/// @dev The same getters on the reference build, which getter.spec.ts also
///      ran (REFERENCE=true) and the tests above don't touch. The reference
///      build reports version "1.6-reference", so its domain separator
///      differs from the optimized build's even at the same address.
contract TestReferenceGetters is BaseConsiderationTest {
    function testGetCorrectName() public view {
        assertEq(referenceConsideration.name(), "Consideration");
    }

    function testGetCorrectInformation() public view {
        (string memory version, bytes32 domainSeparator, address controller) =
            referenceConsideration.information();
        // The reference build names its version apart from the optimized one.
        assertEq(version, "1.6-reference");
        assertEq(controller, address(referenceConduitController));
        assertEq(domainSeparator, _expectedDomainSeparator(block.chainid));

        (, bytes32 optimizedSeparator,) = consideration.information();
        assertTrue(domainSeparator != optimizedSeparator);
    }

    function testGetCorrectDomainSeparator(uint64 _chainId) public {
        vm.assume(_chainId != block.chainid);
        vm.chainId(_chainId);
        (, bytes32 domainSeparator,) = referenceConsideration.information();
        assertEq(domainSeparator, _expectedDomainSeparator(_chainId));
    }

    function _expectedDomainSeparator(uint256 chainId)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("Consideration"),
                keccak256("1.6-reference"),
                chainId,
                address(referenceConsideration)
            )
        );
    }
}
