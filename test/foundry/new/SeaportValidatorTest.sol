// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseSeaportTest } from "./helpers/BaseSeaportTest.sol";

import {
    ReadOnlyOrderValidator,
    SeaportValidator,
    SeaportValidatorHelper
} from "../../../contracts/helpers/order-validator/SeaportValidator.sol";

contract SeaportValidatorTest is BaseSeaportTest {
    SeaportValidatorHelper internal seaportValidatorHelper;
    SeaportValidator internal validator;

    function setUp() public virtual override {
        super.setUp();

        // Note: this chainId hack prevents the validator from calling a
        // hardcoded royalty registry.
        uint256 chainId = block.chainid;
        vm.chainId(2);
        seaportValidatorHelper = new SeaportValidatorHelper();
        vm.chainId(chainId);

        // Initialize the validator.
        validator = new SeaportValidator(
            address(new ReadOnlyOrderValidator()),
            address(seaportValidatorHelper),
            address(getConduitController())
        );
    }
}
