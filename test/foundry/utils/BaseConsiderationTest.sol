// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ConduitController } from "../../../contracts/conduit/ConduitController.sol";
import { ConsiderationInterface } from "../../../contracts/interfaces/ConsiderationInterface.sol";
import { OrderType, BasicOrderType, ItemType, Side } from "../../../contracts/lib/ConsiderationEnums.sol";
import { OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../../contracts/lib/ConsiderationStructs.sol";
import { Test } from "forge-std/Test.sol";
import { DifferentialTest } from "./DifferentialTest.sol";
import { StructCopier } from "./StructCopier.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { ReferenceConduitController } from "../../../reference/conduit/ReferenceConduitController.sol";
import { ReferenceConsideration } from "../../../reference/ReferenceConsideration.sol";
import { Conduit } from "../../../contracts/conduit/Conduit.sol";
import { Consideration } from "../../../contracts/lib/Consideration.sol";

/// @dev Base test case that deploys Consideration and its dependencies
contract BaseConsiderationTest is DifferentialTest, StructCopier {
    using stdStorage for StdStorage;

    ConsiderationInterface consideration;
    ConsiderationInterface referenceConsideration;
    bytes32 conduitKeyOne;
    ConduitController conduitController;
    ConduitController referenceConduitController;
    Conduit referenceConduit;
    Conduit conduit;

    function setUp() public virtual {
        conduitKeyOne = bytes32(uint256(uint160(address(this))) << 96);
        _deployAndConfigurePrecompiledOptimizedConsideration();

        emit log("Deploying reference from precompiled source");
        _deployAndConfigurePrecompiledReferenceConsideration();

        vm.label(address(conduitController), "conduitController");
        vm.label(address(consideration), "consideration");
        vm.label(address(conduit), "conduit");
        vm.label(
            address(referenceConduitController),
            "referenceConduitController"
        );
        vm.label(address(referenceConsideration), "referenceConsideration");
        vm.label(address(referenceConduit), "referenceConduit");
        vm.label(address(this), "testContract");
    }

    ///@dev deploy optimized consideration contracts from pre-compiled source
    //      (solc-0.8.14, IR pipeline enabled)
    function _deployAndConfigurePrecompiledOptimizedConsideration() public {
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

        //create conduit, update channel
        conduit = Conduit(
            conduitController.createConduit(conduitKeyOne, address(this))
        );
        conduitController.updateChannel(
            address(conduit),
            address(consideration),
            true
        );
    }

    ///@dev deploy reference consideration contracts from pre-compiled source (solc-0.8.7, IR pipeline disabled)
    function _deployAndConfigurePrecompiledReferenceConsideration() public {
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

        //create conduit, update channel
        referenceConduit = Conduit(
            referenceConduitController.createConduit(
                conduitKeyOne,
                address(this)
            )
        );
        referenceConduitController.updateChannel(
            address(referenceConduit),
            address(referenceConsideration),
            true
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
    ) internal returns (bytes memory) {
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
    ) internal returns (bytes memory) {
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
    )
        internal
        returns (
            bytes32,
            bytes32,
            uint8
        )
    {
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
