// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConduitController
} from "../../../../contracts/conduit/ConduitController.sol";

import {
    ReferenceConduitController
} from "../../../../reference/conduit/ReferenceConduitController.sol";

import {
    ConduitControllerInterface
} from "../../../../contracts/interfaces/ConduitControllerInterface.sol";

import {
    ConsiderationInterface
} from "../../../../contracts/interfaces/ConsiderationInterface.sol";

import { ItemType } from "../../../../contracts/lib/ConsiderationEnums.sol";

import {
    OfferItem,
    ConsiderationItem
} from "../../../../contracts/lib/ConsiderationStructs.sol";

import { DifferentialTest } from "./DifferentialTest.sol";

import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { Conduit } from "../../../../contracts/conduit/Conduit.sol";

import { Consideration } from "../../../../contracts/lib/Consideration.sol";

import {
    ReferenceConsideration
} from "../../../../reference/ReferenceConsideration.sol";

/// @dev Base test case that deploys Consideration and its dependencies
contract BaseSeaportTest is DifferentialTest {
    using stdStorage for StdStorage;

    ConsiderationInterface seaport;
    ConsiderationInterface referenceSeaport;
    bytes32 conduitKey;
    ConduitControllerInterface conduitController;
    ConduitControllerInterface referenceConduitController;
    Conduit referenceConduit;
    Conduit conduit;
    bool coverage_or_debug;

    function stringEq(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function debugEnabled() internal returns (bool) {
        return
            vm.envOr("SEAPORT_COVERAGE", false) ||
            stringEq(vm.envOr("FOUNDRY_PROFILE", string("")), "debug");
    }

    function setUp() public virtual {
        // conditionally deploy contracts normally or from precompiled source
        // deploys normally when SEAPORT_COVERAGE is true for coverage analysis
        // or when FOUNDRY_PROFILE is "debug" for debugging with source maps
        // deploys from precompiled source when both are false
        coverage_or_debug = debugEnabled();

        conduitKey = bytes32(uint256(uint160(address(this))) << 96);
        _deployAndConfigurePrecompiledOptimizedConsideration();
        _deployAndConfigurePrecompiledReferenceConsideration();

        vm.label(address(conduitController), "conduitController");
        vm.label(address(seaport), "seaport");
        vm.label(address(conduit), "conduit");
        vm.label(
            address(referenceConduitController),
            "referenceConduitController"
        );
        vm.label(address(referenceSeaport), "referenceSeaport");
        vm.label(address(referenceConduit), "referenceConduit");
        vm.label(address(this), "testContract");
    }

    ///@dev deploy optimized consideration contracts from pre-compiled source
    //      (solc-0.8.17, IR pipeline enabled, unless running coverage or debug)
    function _deployAndConfigurePrecompiledOptimizedConsideration() public {
        if (!coverage_or_debug) {
            conduitController = ConduitController(
                deployCode(
                    "optimized-out/ConduitController.sol/ConduitController.json"
                )
            );
            seaport = ConsiderationInterface(
                deployCode(
                    "optimized-out/Consideration.sol/Consideration.json",
                    abi.encode(address(conduitController))
                )
            );
        } else {
            conduitController = new ConduitController();
            seaport = new Consideration(address(conduitController));
        }
        //create conduit, update channel
        conduit = Conduit(
            conduitController.createConduit(conduitKey, address(this))
        );
        conduitController.updateChannel(
            address(conduit),
            address(seaport),
            true
        );
    }

    ///@dev deploy reference consideration contracts from pre-compiled source
    /// (solc-0.8.13, IR pipeline disabled, unless running coverage or debug)
    function _deployAndConfigurePrecompiledReferenceConsideration() public {
        if (!coverage_or_debug) {
            referenceConduitController = ConduitController(
                deployCode(
                    "reference-out/ReferenceConduitController.sol/ReferenceConduitController.json"
                )
            );
            referenceSeaport = ConsiderationInterface(
                deployCode(
                    "reference-out/ReferenceConsideration.sol/ReferenceConsideration.json",
                    abi.encode(address(referenceConduitController))
                )
            );
        } else {
            referenceConduitController = new ReferenceConduitController();
            // for debugging
            referenceSeaport = new ReferenceConsideration(
                address(referenceConduitController)
            );
        }

        //create conduit, update channel
        referenceConduit = Conduit(
            referenceConduitController.createConduit(conduitKey, address(this))
        );
        referenceConduitController.updateChannel(
            address(referenceConduit),
            address(referenceSeaport),
            true
        );
    }

    function signOrder(
        ConsiderationInterface _consideration,
        uint256 _pkOfSigner,
        bytes32 _orderHash
    ) internal view returns (bytes memory) {
        (bytes32 r, bytes32 s, uint8 v) = getSignatureComponents(
            _consideration,
            _pkOfSigner,
            _orderHash
        );
        return abi.encodePacked(r, s, v);
    }

    function signOrder2098(
        ConsiderationInterface _consideration,
        uint256 _pkOfSigner,
        bytes32 _orderHash
    ) internal view returns (bytes memory) {
        (bytes32 r, bytes32 s, uint8 v) = getSignatureComponents(
            _consideration,
            _pkOfSigner,
            _orderHash
        );
        uint256 yParity;
        if (v == 27) {
            yParity = 0;
        } else {
            yParity = 1;
        }
        uint256 yParityAndS = (yParity << 255) | uint256(s);
        return abi.encodePacked(r, yParityAndS);
    }

    function getSignatureComponents(
        ConsiderationInterface _consideration,
        uint256 _pkOfSigner,
        bytes32 _orderHash
    ) internal view returns (bytes32, bytes32, uint8) {
        (, bytes32 domainSeparator, ) = _consideration.information();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _pkOfSigner,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, _orderHash)
            )
        );
        return (r, s, v);
    }
}
