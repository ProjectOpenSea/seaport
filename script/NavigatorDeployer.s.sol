// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Script.sol";

import "forge-std/console.sol";

import { LibString } from "solady/src/utils/LibString.sol";

import {
    CriteriaHelper
} from "../contracts/helpers/navigator/lib/CriteriaHelper.sol";

import {
    ExecutionsHelper
} from "../contracts/helpers/navigator/lib/ExecutionsHelper.sol";

import {
    FulfillmentsHelper
} from "../contracts/helpers/navigator/lib/FulfillmentsHelper.sol";

import {
    OrderDetailsHelper
} from "../contracts/helpers/navigator/lib/OrderDetailsHelper.sol";

import {
    ReadOnlyOrderValidator
} from "../contracts/helpers/order-validator/lib/ReadOnlyOrderValidator.sol";

import {
    RequestValidator
} from "../contracts/helpers/navigator/lib/RequestValidator.sol";

import {
    SeaportNavigator
} from "../contracts/helpers/navigator/SeaportNavigator.sol";

import {
    SeaportValidator
} from "../contracts/helpers/order-validator/SeaportValidator.sol";

import {
    SeaportValidatorHelper
} from "../contracts/helpers/order-validator/lib/SeaportValidatorHelper.sol";

import {
    SuggestedActionHelper
} from "../contracts/helpers/navigator/lib/SuggestedActionHelper.sol";

import {
    ValidatorHelper
} from "../contracts/helpers/navigator/lib/ValidatorHelper.sol";

interface ImmutableCreate2Factory {
    function hasBeenDeployed(
        address deploymentAddress
    ) external view returns (bool);

    function findCreate2Address(
        bytes32 salt,
        bytes calldata initializationCode
    ) external view returns (address deploymentAddress);

    function safeCreate2(
        bytes32 salt,
        bytes calldata initializationCode
    ) external payable returns (address deploymentAddress);
}

contract NavigatorDeployer is Script {
    // Set up the immutable create2 factory and conduit controller addresses.
    ImmutableCreate2Factory private constant IMMUTABLE_CREATE2_FACTORY =
        ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);
    address private constant CONDUIT_CONTROLLER =
        0x00000000F9490004C11Cef243f5400493c00Ad63;

    // Set up the default salt and the salt for the seaport validator and
    // navigator.
    bytes32 private constant DEFAULT_SALT = bytes32(uint256(0x1));
    bytes32 private constant SEAPORT_VALIDATOR_SALT =
        bytes32(uint256(0x459b42ee5b5e5000d96491ce));
    bytes32 private constant SEAPORT_NAVIGATOR_SALT =
        bytes32(uint256(0x9237ec96f90d12013e58e484));

    function run() public {
        console.log(
            pad("State", 10),
            pad("Name", 23),
            pad("Address", 43),
            "Initcode hash"
        );

        // Deploy the helpers, seaport validator, and navigator.
        vm.startBroadcast();
        address seaportValidatorHelper = deploy(
            "SeaportValidatorHelper",
            type(SeaportValidatorHelper).creationCode
        );
        address readOnlyOrderValidator = deploy(
            "ReadOnlyOrderValidator",
            type(ReadOnlyOrderValidator).creationCode
        );
        deploy(
            "SeaportValidator",
            SEAPORT_VALIDATOR_SALT,
            bytes.concat(
                type(SeaportValidator).creationCode,
                abi.encode(
                    readOnlyOrderValidator,
                    seaportValidatorHelper,
                    CONDUIT_CONTROLLER
                )
            )
        );

        address requestValidator = deploy(
            "RequestValidator",
            type(RequestValidator).creationCode
        );
        address criteriaHelper = deploy(
            "CriteriaHelper",
            type(CriteriaHelper).creationCode
        );
        address validatorHelper = deploy(
            "ValidatorHelper",
            type(ValidatorHelper).creationCode
        );
        address orderDetailsHelper = deploy(
            "OrderDetailsHelper",
            type(OrderDetailsHelper).creationCode
        );
        address fulfillmentsHelper = deploy(
            "FulfillmentsHelper",
            type(FulfillmentsHelper).creationCode
        );
        address suggestedActionHelper = deploy(
            "SuggestedActionHelper",
            type(SuggestedActionHelper).creationCode
        );
        address executionsHelper = deploy(
            "ExecutionsHelper",
            type(ExecutionsHelper).creationCode
        );

        deploy(
            "SeaportNavigator",
            SEAPORT_NAVIGATOR_SALT,
            bytes.concat(
                type(SeaportNavigator).creationCode,
                abi.encode(
                    requestValidator,
                    criteriaHelper,
                    validatorHelper,
                    orderDetailsHelper,
                    fulfillmentsHelper,
                    suggestedActionHelper,
                    executionsHelper
                )
            )
        );
    }

    function deploy(
        string memory name,
        bytes memory initCode
    ) internal returns (address) {
        return deploy(name, DEFAULT_SALT, initCode);
    }

    function deploy(
        string memory name,
        bytes32 salt,
        bytes memory initCode
    ) internal returns (address) {
        bytes32 initCodeHash = keccak256(initCode);
        address deploymentAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(IMMUTABLE_CREATE2_FACTORY),
                            salt,
                            initCodeHash
                        )
                    )
                )
            )
        );
        bool deploying;
        if (!IMMUTABLE_CREATE2_FACTORY.hasBeenDeployed(deploymentAddress)) {
            deploymentAddress = IMMUTABLE_CREATE2_FACTORY.safeCreate2(
                salt,
                initCode
            );
            deploying = true;
        }
        console.log(
            pad(deploying ? "Deploying" : "Found", 10),
            pad(name, 23),
            pad(LibString.toHexString(deploymentAddress), 43),
            LibString.toHexString(uint256(initCodeHash))
        );
        return deploymentAddress;
    }

    function pad(
        string memory name,
        uint256 n
    ) internal pure returns (string memory) {
        string memory padded = name;
        while (bytes(padded).length < n) {
            padded = string.concat(padded, " ");
        }
        return padded;
    }
}
