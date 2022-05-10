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
    ConduitController referenceConduitController;
    address referenceConduit;
    address conduit;

    function _deployAndConfigureConsideration() public {
        conduitController = new ConduitController();
        consideration = new Consideration(address(conduitController));
        conduit = conduitController.createConduit(conduitKeyOne, address(this));
        conduitController.updateChannel(conduit, address(consideration), true);

        vm.label(address(conduitController), "conduitController");
        vm.label(address(consideration), "consideration");
        vm.label(conduit, "conduit");

        emit log_named_address(
            "Deployed conduitController at",
            address(conduitController)
        );
        emit log_named_address(
            "Deployed Consideration at",
            address(consideration)
        );
        emit log_named_address("Deployed conduit at", conduit);
    }

    ///@dev deploy reference consideration contracts from pre-compiled source (solc-0.8.7, IR pipeline disabled)
    function _deployAndConfigurePrecompiledConsideration(string memory option)
        public
        returns (
            Consideration _consideration,
            ConduitController _conduitController,
            address _conduit
        )
    {
        emit log(
            string.concat(
                option,
                "-out/ReferenceConduitController.sol/ReferenceConduitController.json"
            )
        );
        // deploy reference conduit
        bytes memory bytecode = vm.getCode(
            string.concat(
                option,
                "-out/ReferenceConduitController.sol/ReferenceConduitController.json"
            )
        );
        assembly {
            _conduitController := create(
                0,
                add(bytecode, 0x20),
                mload(bytecode)
            )

            // sstore(
            //     conduitController.slot,
            //     create(0, add(bytecode, 0x20), mload(bytecode))
            // )
        }

        emit log_named_address(
            string.concat(option, ": Deployed ConduitController at"),
            address(_conduitController)
        );

        // deploy reference consideration
        bytecode = abi.encodePacked(
            vm.getCode(
                string.concat(
                    option,
                    "-out/ReferenceConsideration.sol/ReferenceConsideration.json"
                )
            ),
            abi.encode(address(_conduitController))
        );
        assembly {
            _consideration := create(0, add(bytecode, 0x20), mload(bytecode))
            // sstore(
            //     consideration.slot,
            //     create(0, add(bytecode, 0x20), mload(bytecode))
            // )
        }

        //create conduit, update channel
        _conduit = _conduitController.createConduit(
            conduitKeyOne,
            address(this)
        );
        _conduitController.updateChannel(
            _conduit,
            address(_consideration),
            true
        );

        vm.label(
            address(_conduitController),
            string.concat(option, "ConduitController")
        );
        vm.label(
            address(_consideration),
            string.concat(option, "Consideration")
        );
        vm.label(_conduit, string.concat(option, "Conduit"));

        emit log_named_address(
            string.concat(option, ": Deployed Consideration at"),
            address(_consideration)
        );
        emit log_named_address(
            string.concat(option, ": Deployed conduit at"),
            address(_conduit)
        );
    }

    ///@dev deploy optimized consideration contracts from pre-compiled source (solc-0.8.7, IR pipeline disabled)
    function _deployAndConfigureOptimizedConsideration() public {
        // deploy optimized conduit
        bytes memory bytecode = vm.getCode(
            "optimized-out/ConduitController.sol/ConduitController.json"
        );
        assembly {
            sstore(
                conduitController.slot,
                create(0, add(bytecode, 0x20), mload(bytecode))
            )
        }

        emit log_named_address(
            "Deployed ConduitController at",
            address(conduitController)
        );

        // deploy optimized consideration
        bytecode = abi.encodePacked(
            vm.getCode("optimized-out/Consideration.sol/Consideration.json"),
            abi.encode(address(conduitController))
        );
        assembly {
            sstore(
                consideration.slot,
                create(0, add(bytecode, 0x20), mload(bytecode))
            )
        }

        //create conduit, update channel
        conduit = conduitController.createConduit(conduitKeyOne, address(this));
        conduitController.updateChannel(conduit, address(consideration), true);

        vm.label(address(conduitController), "conduitController");
        vm.label(address(consideration), "optimized");
        vm.label(conduit, "conduit");

        emit log_named_address(
            "Deployed Optimized Consideration at",
            address(consideration)
        );
        emit log_named_address(
            "Deployed optimized conduit at",
            address(conduit)
        );
    }

    ///@dev deploy reference consideration contracts from pre-compiled source (solc-0.8.7, IR pipeline disabled)
    function _deployAndConfigureReferenceConsideration() public {
        // deploy reference conduit
        bytes memory bytecode = vm.getCode(
            "reference-out/ReferenceConduitController.sol/ReferenceConduitController.json"
        );
        assembly {
            sstore(
                referenceConduitController.slot,
                create(0, add(bytecode, 0x20), mload(bytecode))
            )
        }

        emit log_named_address(
            "Deployed ReferenceConduitController at",
            address(referenceConduitController)
        );

        // deploy reference consideration
        bytecode = abi.encodePacked(
            vm.getCode(
                "reference-out/ReferenceConsideration.sol/ReferenceConsideration.json"
            ),
            abi.encode(address(referenceConduitController))
        );
        assembly {
            sstore(
                referenceConsideration.slot,
                create(0, add(bytecode, 0x20), mload(bytecode))
            )
        }

        //create conduit, update channel
        referenceConduit = referenceConduitController.createConduit(
            conduitKeyOne,
            address(this)
        );
        referenceConduitController.updateChannel(
            referenceConduit,
            address(referenceConsideration),
            true
        );

        vm.label(
            address(referenceConduitController),
            "referenceConduitController"
        );
        vm.label(address(referenceConsideration), "reference");
        vm.label(referenceConduit, "referenceConduit");

        emit log_named_address(
            "Deployed Reference Consideration at",
            address(referenceConsideration)
        );
        emit log_named_address(
            "Deployed reference conduit at",
            address(referenceConduit)
        );
    }

    function setUp() public virtual {
        conduitKeyOne = bytes32(uint256(uint160(address(this))));
        vm.label(address(this), "testContract");
        _deployAndConfigureOptimizedConsideration();
        _deployAndConfigureReferenceConsideration();
        // (
        //     referenceConsideration,
        //     referenceConduitController,
        //     referenceConduit
        // ) = _deployAndConfigurePrecompiledConsideration("reference");
        // (
        //     consideration,
        //     conduitController,
        //     conduit
        // ) = _deployAndConfigurePrecompiledConsideration("optimized");
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
