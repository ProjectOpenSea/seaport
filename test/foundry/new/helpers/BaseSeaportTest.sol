// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { DifferentialTest } from "./DifferentialTest.sol";

import {
    ConduitControllerInterface
} from "seaport-sol/src/ConduitControllerInterface.sol";

import {
    ConduitController
} from "seaport-core/src/conduit/ConduitController.sol";

import {
    ReferenceConduitController
} from "../../../../reference/conduit/ReferenceConduitController.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import { Consideration } from "seaport-core/src/lib/Consideration.sol";

import {
    ReferenceConsideration
} from "../../../../reference/ReferenceConsideration.sol";

import { Conduit } from "seaport-core/src/conduit/Conduit.sol";

import { setLabel } from "./Labeler.sol";

/// @dev Base test case that deploys Consideration and its dependencies.
contract BaseSeaportTest is DifferentialTest {
    using stdStorage for StdStorage;

    bool coverage_or_debug;
    bytes32 conduitKey;

    Conduit conduit;
    Conduit referenceConduit;
    ConduitControllerInterface conduitController;
    ConduitControllerInterface referenceConduitController;
    ConsiderationInterface referenceSeaport;
    ConsiderationInterface seaport;

    function stringEq(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function debugEnabled() internal returns (bool) {
        return vm.envOr("SEAPORT_COVERAGE", false) || debugProfileEnabled();
    }

    function debugProfileEnabled() internal returns (bool) {
        string memory env = vm.envOr("FOUNDRY_PROFILE", string(""));
        return stringEq(env, "debug") || stringEq(env, "moat_debug");
    }

    function setUp() public virtual {
        // Conditionally deploy contracts normally or from precompiled source
        // deploys normally when SEAPORT_COVERAGE is true for coverage analysis
        // or when FOUNDRY_PROFILE is "debug" for debugging with source maps
        // deploys from precompiled source when both are false.
        coverage_or_debug = debugEnabled();

        conduitKey = bytes32(uint256(uint160(address(this))) << 96);
        _deployAndConfigurePrecompiledOptimizedConsideration();
        _deployAndConfigurePrecompiledReferenceConsideration();

        setLabel(address(conduitController), "conduitController");
        setLabel(address(seaport), "seaport");
        setLabel(address(conduit), "conduit");
        setLabel(
            address(referenceConduitController),
            "referenceConduitController"
        );
        setLabel(address(referenceSeaport), "referenceSeaport");
        setLabel(address(referenceConduit), "referenceConduit");
        setLabel(address(this), "testContract");
    }

    /**
     * @dev Get the configured preferred Seaport
     */
    function getSeaport() internal returns (ConsiderationInterface seaport_) {
        string memory profile = vm.envOr("MOAT_PROFILE", string("optimized"));

        if (stringEq(profile, "reference")) {
            emit log("Using reference Seaport and ConduitController");
            seaport_ = referenceSeaport;
        } else {
            seaport_ = seaport;
        }
    }

    /**
     * @dev Get the configured preferred ConduitController
     */
    function getConduitController()
        internal
        returns (ConduitControllerInterface conduitController_)
    {
        string memory profile = vm.envOr("MOAT_PROFILE", string("optimized"));

        if (stringEq(profile, "reference")) {
            conduitController_ = referenceConduitController;
        } else {
            conduitController_ = conduitController;
        }
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
