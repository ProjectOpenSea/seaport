// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { Consideration } from "../../../contracts/Consideration.sol";
import { OrderType, BasicOrderType, ItemType, Side } from "../../../contracts/lib/ConsiderationEnums.sol";
import { OfferItem, ConsiderationItem, OrderComponents, BasicOrderParameters } from "../../../contracts/lib/ConsiderationStructs.sol";

import { DSTestPlusPlus } from "./DSTestPlusPlus.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";

/// @dev Base test case that deploys Consideration and its dependencies
contract BaseConsiderationTest is DSTestPlusPlus {
    using stdStorage for StdStorage;

    Consideration consideration;
    bytes32 conduitKeyOne;
    ConduitController conduitController;
    address conduit;

    address internal _wyvernProxyRegistry;
    address internal _wyvernTokenTransferProxy;
    address internal _wyvernDelegateProxyImplementation;

    function setUp() public virtual {
        conduitController = new ConduitController();
        emit log_named_address(
            "Deployed conduitController at",
            address(conduitController)
        );
        conduitKeyOne = bytes32(uint256(uint160(address(this))));
        conduit = conduitController.createConduit(conduitKeyOne, address(this));
        emit log_named_address("Deployed conduit at", conduit);
        consideration = new Consideration(address(conduitController));
        emit log_named_address(
            "Deployed Consideration at",
            address(consideration)
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

    function signOrder(uint256 _pkOfSigner, bytes32 _orderHash)
        internal
        returns (bytes memory)
    {
        (, bytes32 domainSeparator, ) = consideration.information();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _pkOfSigner,
            keccak256(
                abi.encodePacked(
                    bytes2(0x1901),
                    consideration.DOMAIN_SEPARATOR(),
                    _orderHash
                )
            )
        );
        return abi.encodePacked(r, s, v);
    }
}
