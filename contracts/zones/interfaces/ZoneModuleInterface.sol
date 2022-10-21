// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import { ZoneInterface } from "../../interfaces/ZoneInterface.sol";
import { AdvancedOrder } from "../../lib/ConsiderationStructs.sol";

abstract contract ZoneModuleInterface is ZoneInterface {
    error ExtraDataRequired();

    function _validateOrder(
        bytes32 orderHash,
        address caller,
        bytes[] memory fixedExtraDatas,
        bytes[] memory variableExtraDatas
    ) internal view virtual;

    function _validateOrder(bytes32 orderHash, address caller)
        internal
        view
        virtual;
}
