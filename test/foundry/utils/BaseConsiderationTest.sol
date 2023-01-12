// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ConduitController } from
    "../../../contracts/conduit/ConduitController.sol";
import { ReferenceConduitController } from
    "../../../reference/conduit/ReferenceConduitController.sol";
import { ConduitControllerInterface } from
    "../../../contracts/interfaces/ConduitControllerInterface.sol";
import { ConsiderationInterface } from
    "../../../contracts/interfaces/ConsiderationInterface.sol";
import {
    OrderType,
    BasicOrderType,
    ItemType,
    Side
} from "../../../contracts/lib/ConsiderationEnums.sol";
import {
    OfferItem,
    ConsiderationItem,
    OrderComponents,
    BasicOrderParameters
} from "../../../contracts/lib/ConsiderationStructs.sol";
import { DifferentialTest } from "./DifferentialTest.sol";

import { StructCopier } from "./StructCopier.sol";

import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { Conduit } from "../../../contracts/conduit/Conduit.sol";

import { Consideration } from "../../../contracts/lib/Consideration.sol";

import { ReferenceConsideration } from
    "../../../reference/ReferenceConsideration.sol";

/// @dev Base test case that deploys Consideration and its dependencies
contract BaseConsiderationTest is DifferentialTest, StructCopier {
    using stdStorage for StdStorage;

    ConsiderationInterface consideration;
    ConsiderationInterface referenceConsideration;
    bytes32 conduitKeyOne;
    ConduitControllerInterface conduitController;
    ConduitControllerInterface referenceConduitController;
    Conduit referenceConduit;
    Conduit conduit;
    bool coverage_or_debug;

    function tryEnvBool(string memory envVar) internal view returns (bool) {
        try vm.envBool(envVar) returns (bool _value) {
            return _value;
        } catch {
            return false;
        }
    }

    function tryEnvString(string memory envVar)
        internal
        view
        returns (string memory)
    {
        try vm.envString(envVar) returns (string memory _value) {
            return _value;
        } catch {
            return "";
        }
    }

    function stringEq(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function debugEnabled() internal view returns (bool) {
        return tryEnvBool("SEAPORT_COVERAGE")
            || stringEq(tryEnvString("FOUNDRY_PROFILE"), "debug");
    }

    function setUp() public virtual {
        // conditionally deploy contracts normally or from precompiled source
        // deploys normally when SEAPORT_COVERAGE is true for coverage analysis
        // or when FOUNDRY_PROFILE is "debug" for debugging with source maps
        // deploys from precompiled source when both are false
        coverage_or_debug = debugEnabled();

        conduitKeyOne = bytes32(uint256(uint160(address(this))) << 96);
        _deployAndConfigurePrecompiledOptimizedConsideration();

        _deployAndConfigurePrecompiledReferenceConsideration();

        vm.label(address(conduitController), "conduitController");
        vm.label(address(consideration), "consideration");
        vm.label(address(conduit), "conduit");
        vm.label(
            address(referenceConduitController), "referenceConduitController"
        );
        vm.label(address(referenceConsideration), "referenceConsideration");
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
            consideration = ConsiderationInterface(
                deployCode(
                    "optimized-out/Consideration.sol/Consideration.json",
                    abi.encode(address(conduitController))
                )
            );
        } else {
            conduitController = new ConduitController();
            consideration = new Consideration(address(conduitController));
        }
        //create conduit, update channel
        conduit = Conduit(
            conduitController.createConduit(conduitKeyOne, address(this))
        );
        conduitController.updateChannel(
            address(conduit), address(consideration), true
        );
    }

    ///@dev deploy reference consideration contracts from pre-compiled source
    /// (solc-0.8.7, IR pipeline disabled,  unless running coverage or debug)
    function _deployAndConfigurePrecompiledReferenceConsideration() public {
        if (!coverage_or_debug) {
            referenceConduitController = ConduitController(
                deployCode(
                    "reference-out/ReferenceConduitController.sol/ReferenceConduitController.json"
                )
            );
            referenceConsideration = ConsiderationInterface(
                deployCode(
                    "reference-out/ReferenceConsideration.sol/ReferenceConsideration.json",
                    abi.encode(address(referenceConduitController))
                )
            );
        } else {
            referenceConduitController = new ReferenceConduitController();
            // for debugging
            referenceConsideration = new ReferenceConsideration(
                address(referenceConduitController)
            );
        }

        //create conduit, update channel
        referenceConduit = Conduit(
            referenceConduitController.createConduit(
                conduitKeyOne, address(this)
            )
        );
        referenceConduitController.updateChannel(
            address(referenceConduit), address(referenceConsideration), true
        );
    }

    function singleOfferItem(
        ItemType _itemType,
        address _tokenAddress,
        uint256 _identifierOrCriteria,
        uint256 _startAmount,
        uint256 _endAmount
    ) internal pure returns (OfferItem[] memory offerItem) {
        offerItem = new OfferItem[](1);
        offerItem[0] = OfferItem(
            _itemType,
            _tokenAddress,
            _identifierOrCriteria,
            _startAmount,
            _endAmount
        );
    }

    function singleConsiderationItem(
        ItemType _itemType,
        address _tokenAddress,
        uint256 _identifierOrCriteria,
        uint256 _startAmount,
        uint256 _endAmount,
        address _recipient
    ) internal pure returns (ConsiderationItem[] memory considerationItem) {
        considerationItem = new ConsiderationItem[](1);
        considerationItem[0] = ConsiderationItem(
            _itemType,
            _tokenAddress,
            _identifierOrCriteria,
            _startAmount,
            _endAmount,
            payable(_recipient)
        );
    }

    function signOrder(
        ConsiderationInterface _consideration,
        uint256 _pkOfSigner,
        bytes32 _orderHash
    ) internal view returns (bytes memory) {
        (bytes32 r, bytes32 s, uint8 v) =
            getSignatureComponents(_consideration, _pkOfSigner, _orderHash);
        return abi.encodePacked(r, s, v);
    }

    function signOrder2098(
        ConsiderationInterface _consideration,
        uint256 _pkOfSigner,
        bytes32 _orderHash
    ) internal view returns (bytes memory) {
        (bytes32 r, bytes32 s, uint8 v) =
            getSignatureComponents(_consideration, _pkOfSigner, _orderHash);
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
        (, bytes32 domainSeparator,) = _consideration.information();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _pkOfSigner,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, _orderHash)
            )
        );
        return (r, s, v);
    }
}
