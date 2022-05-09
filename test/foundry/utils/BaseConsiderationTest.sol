// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../../../contracts/conduit/ConduitController.sol";

import { Consideration } from "../../../contracts/Consideration.sol";
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
        vm.label(address(consideration), "consideration");
        emit log_named_address(
            "Deployed Consideration at",
            address(consideration)
        );

        bytes memory bytecode = abi.encodePacked(
            vm.getCode(
                "reference-out/ReferenceConsideration.sol/ReferenceConsideration.json"
            ),
            abi.encode(address(conduitController))
        );
        assembly {
            sstore(
                referenceConsideration.slot,
                create(0, add(bytecode, 0x20), mload(bytecode))
            )
        }

        vm.label(address(referenceConsideration), "reference");
        emit log_named_address(
            "Deployed Reference Consideration at",
            address(referenceConsideration)
        );
        conduitController.updateChannel(conduit, address(consideration), true);
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

    function signOrder(uint256 _pkOfSigner, bytes32 _orderHash)
        internal
        returns (bytes memory)
    {
        (, bytes32 domainSeparator, ) = consideration.information();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _pkOfSigner,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, _orderHash)
            )
        );
        return abi.encodePacked(r, s, v);
    }
}
