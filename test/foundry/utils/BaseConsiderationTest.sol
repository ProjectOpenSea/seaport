// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { ConduitController } from "../../../contracts/conduit/ConduitController.sol";
import { Consideration } from "../../../contracts/Consideration.sol";
import { OrderType, BasicOrderType, ItemType, Side } from "../../../contracts/lib/ConsiderationEnums.sol";
import { OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../../contracts/lib/ConsiderationStructs.sol";
import { Test } from "forge-std/Test.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { ReferenceConduitController } from "../../../reference/conduit/ReferenceConduitController.sol";
import { ReferenceConsideration } from "../../../reference/ReferenceConsideration.sol";
import { Conduit } from "../../../contracts/conduit/Conduit.sol";

/// @dev Base test case that deploys Consideration and its dependencies
contract BaseConsiderationTest is Test {
    using stdStorage for StdStorage;

    Consideration consideration;
    Consideration referenceConsideration;
    bytes32 conduitKeyOne;
    ConduitController conduitController;
    ConduitController referenceConduitController;
    Conduit referenceConduit;
    Conduit conduit;

    function setUp() public virtual {
        conduitKeyOne = bytes32(uint256(uint160(address(this))));
        vm.label(address(this), "testContract");
        _deployAndConfigurePrecompiledOptimizedConsideration();

        string[] memory args = new string[](2);
        args[0] = "echo";
        args[1] = "-n";
        // if ffi is enabled, this will not enter the catch block.
        // assume that the local foundry profile is specified, and deploy
        // reference normally, so stack traces and debugger have source map,
        // with the caveat that reference contracts will have been compiled
        // with 0.8.13
        try vm.ffi(args) {
            emit log("Deploying reference from import");
            _deployAndConfigureReferenceConsideration();
        } catch (bytes memory) {
            emit log("Deploying reference from precompiled source");
            _deployAndConfigurePrecompiledReferenceConsideration();
        }

        vm.label(address(conduitController), "conduitController");
        vm.label(address(consideration), "consideration");
        vm.label(address(conduit), "conduit");
        vm.label(
            address(referenceConduitController),
            "referenceConduitController"
        );
        vm.label(address(referenceConsideration), "referenceConsideration");
        vm.label(address(referenceConduit), "referenceConduit");
    }

    function _deployAndConfigureReferenceConsideration() public {
        referenceConduitController = ConduitController(
            address(new ReferenceConduitController())
        );
        referenceConsideration = Consideration(
            address(
                new ReferenceConsideration(address(referenceConduitController))
            )
        );
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

    function _deployAndConfigureConsideration() public {
        conduitController = new ConduitController();
        consideration = new Consideration(address(conduitController));
        conduit = Conduit(
            conduitController.createConduit(conduitKeyOne, address(this))
        );
        conduitController.updateChannel(
            address(conduit),
            address(consideration),
            true
        );
    }

    ///@dev deploy optimized consideration contracts from pre-compiled source (solc-0.8.13, IR pipeline enabled)
    function _deployAndConfigurePrecompiledOptimizedConsideration() public {
        conduitController = ConduitController(
            deployCode(
                "optimized-out/ConduitController.sol/ConduitController.json"
            )
        );
        consideration = Consideration(
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
        referenceConsideration = Consideration(
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
        Consideration _consideration,
        uint256 _pkOfSigner,
        bytes32 _orderHash
    ) internal returns (bytes memory) {
        (, bytes32 domainSeparator, ) = _consideration.information();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _pkOfSigner,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, _orderHash)
            )
        );
        return abi.encodePacked(r, s, v);
    }

    /**
     * @dev reset all storage written at an address thus far to 0; will overwrite totalSupply()for ERC20s but that should be fine
     *      with the goal of resetting the balances and owners of tokens - but note: should be careful about approvals, etc
     *
     *      note: must be called in conjunction with vm.record()
     */
    function _resetStorage(address _addr) internal {
        (, bytes32[] memory writeSlots) = vm.accesses(_addr);
        for (uint256 i = 0; i < writeSlots.length; i++) {
            vm.store(_addr, writeSlots[i], bytes32(0));
        }
    }
}
