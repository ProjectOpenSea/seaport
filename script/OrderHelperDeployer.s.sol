// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {
    RequestValidator
} from "../contracts/helpers/order-helper/lib/RequestValidator.sol";
import {
    CriteriaHelper
} from "../contracts/helpers/order-helper/lib/CriteriaHelper.sol";
import {
    ValidatorHelper
} from "../contracts/helpers/order-helper/lib/ValidatorHelper.sol";
import {
    OrderDetailsHelper
} from "../contracts/helpers/order-helper/lib/OrderDetailsHelper.sol";
import {
    FulfillmentsHelper
} from "../contracts/helpers/order-helper/lib/FulfillmentsHelper.sol";
import {
    ExecutionsHelper
} from "../contracts/helpers/order-helper/lib/ExecutionsHelper.sol";
import {
    SeaportOrderHelper
} from "../contracts/helpers/order-helper/SeaportOrderHelper.sol";

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

contract OrderHelperDeployer is Script {
    ImmutableCreate2Factory private constant IMMUTABLE_CREATE2_FACTORY =
        ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);
    address private constant SEAPORT_ADDRESS =
        0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
    address private constant SEAPORT_VALIDATOR_ADDRESS =
        0x000000000DD1F1B245b936b2771408555CF8B8af;
    bytes32 private constant SALT = bytes32(uint256(0x1));

    function deploy(
        string memory name,
        bytes memory initCode
    ) internal returns (address) {
        address deploymentAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(IMMUTABLE_CREATE2_FACTORY),
                            SALT,
                            keccak256(initCode)
                        )
                    )
                )
            )
        );
        bool deployed;
        if (!IMMUTABLE_CREATE2_FACTORY.hasBeenDeployed(deploymentAddress)) {
            deploymentAddress = IMMUTABLE_CREATE2_FACTORY.safeCreate2(
                SALT,
                initCode
            );
            deployed = true;
        }
        console.log(deployed ? "deploying" : "found", name, deploymentAddress);
        return deploymentAddress;
    }

    function run() public {
        vm.startBroadcast();

        address requestValidator = deploy(
            "requestValidator",
            type(RequestValidator).creationCode
        );
        address criteriaHelper = deploy(
            "criteriaHelper",
            type(CriteriaHelper).creationCode
        );
        address validatorHelper = deploy(
            "validatorHelper",
            type(ValidatorHelper).creationCode
        );
        address orderDetailsHelper = deploy(
            "orderDetailsHelper",
            type(OrderDetailsHelper).creationCode
        );
        address fulfillmentsHelper = deploy(
            "fulfillmentsHelper",
            type(FulfillmentsHelper).creationCode
        );
        address executionsHelper = deploy(
            "executionsHelper",
            type(ExecutionsHelper).creationCode
        );

        deploy(
            "orderHelper",
            bytes.concat(
                type(SeaportOrderHelper).creationCode,
                abi.encode(
                    SEAPORT_ADDRESS,
                    SEAPORT_VALIDATOR_ADDRESS,
                    requestValidator,
                    criteriaHelper,
                    validatorHelper,
                    orderDetailsHelper,
                    fulfillmentsHelper,
                    executionsHelper
                )
            )
        );
    }
}
