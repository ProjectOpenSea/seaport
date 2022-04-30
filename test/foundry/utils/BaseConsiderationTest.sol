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

    ConduitController conduitController;
    address conduitContorllerAddress;

    address internal _wyvernProxyRegistry;
    address internal _wyvernTokenTransferProxy;
    address internal _wyvernDelegateProxyImplementation;

    function setUp() public virtual {
        _deployLegacyContracts();
        conduitContorllerAddress = address(new ConduitController());
        conduitController = ConduitController(conduitContorllerAddress);

        consideration = new Consideration(
            conduitContorllerAddress,
            _wyvernProxyRegistry,
            _wyvernTokenTransferProxy,
            _wyvernDelegateProxyImplementation
        );
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
        (bytes32 domainSeparator, ) = consideration.information();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _pkOfSigner,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, _orderHash)
            )
        );
        return abi.encodePacked(r, s, v);
    }

    /**
    @dev get and deploy precompiled contracts that depend on legacy versions
        of the solidity compiler
     */
    function _deployLegacyContracts() private {
        /// @dev deploy WyvernProxyRegistry from precompiled source
        bytes memory bytecode = vm.getCode(
            "out/WyvernProxyRegistry.sol/WyvernProxyRegistry.json"
        );
        // TODO: temporary, get this working before dealing with storage .slots
        address registryCopy;
        assembly {
            registryCopy := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        _wyvernProxyRegistry = registryCopy;

        /// @dev deploy WyvernTokenTransferProxy from precompiled source
        bytes memory constructorArgs = abi.encode(registryCopy);
        bytecode = abi.encodePacked(
            vm.getCode(
                "out/WyvernTokenTransferProxy.sol/WyvernTokenTransferProxy.json"
            ),
            constructorArgs
        );
        /// @dev deploy WyvernTokenTransferProxy from precompiled source
        address proxyCopy;
        assembly {
            proxyCopy := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        _wyvernTokenTransferProxy = proxyCopy;

        /// @dev use stdstore to read delegateProxyImplementation from deployed registry
        _wyvernDelegateProxyImplementation = address(
            uint160(
                stdstore
                    .target(_wyvernProxyRegistry)
                    .sig("delegateProxyImplementation()")
                    .find()
            )
        );

        emit log("Deployed legacy Wyvern contracts");
    }
}
