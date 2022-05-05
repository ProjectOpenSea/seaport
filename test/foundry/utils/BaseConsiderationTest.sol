// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../../../contracts/conduit/ConduitController.sol";

import { Consideration } from "../../../contracts/Consideration.sol";
import { ReferenceConsideration } from "../../../contracts/reference/ReferenceConsideration.sol";
import { OrderType, BasicOrderType, ItemType, Side } from "../../../contracts/lib/ConsiderationEnums.sol";
import { OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../../contracts/lib/ConsiderationStructs.sol";

import { DSTestPlusPlus } from "./DSTestPlusPlus.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

/// @dev Base test case that deploys Consideration and its dependencies
contract BaseConsiderationTest is DSTestPlusPlus {
    using stdStorage for StdStorage;

    Consideration consideration;
    Consideration referenceConsideration;
    bytes32 conduitKeyOne;
    ConduitController conduitController;
    address conduit;

    function setUp() public virtual {
        vm.label(address(this), "testContract");

        conduitController = new ConduitController();
        vm.label(address(conduitController), "conduitController");
        emit log_named_address(
            "Deployed conduitController at",
            address(conduitController)
        );

        conduitKeyOne = bytes32(uint256(uint160(address(this))));

        conduit = conduitController.createConduit(conduitKeyOne, address(this));
        vm.label(conduit, "conduit");
        emit log_named_address("Deployed conduit at", conduit);

        consideration = new Consideration(address(conduitController));
        vm.label(address(consideration), "reference");
        emit log_named_address(
            "Deployed Consideration at",
            address(consideration)
        );

        referenceConsideration = Consideration(
            address(new ReferenceConsideration(address(conduitController)))
        );
        vm.label(address(referenceConsideration), "consideration");
        emit log_named_address(
            "Deployed referenceConsideration at",
            address(referenceConsideration)
        );

        conduitController.updateChannel(conduit, address(consideration), true);
        conduitController.updateChannel(
            conduit,
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
}
