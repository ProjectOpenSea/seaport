// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { BaseZone } from "../BaseZone.sol";
import { ZoneModuleInterface } from "../interfaces/ZoneModuleInterface.sol";
import { AdvancedOrder } from "../../lib/ConsiderationStructs.sol";

abstract contract Pausable is BaseZone {
    error Paused();
    error SetToCurrentPauseValue();

    bool private _paused;

    event PausedSet(bool pauseValue);

    function isPaused() public view returns (bool) {
        return _paused;
    }

    function setPaused(bool paused) public onlyOwner {
        if (paused == _paused) {
            revert SetToCurrentPauseValue();
        }

        emit PausedSet(paused);

        _paused = paused;
    }

    function _validateOrder(bytes32, address) internal view virtual override {
        if (_paused) {
            revert Paused();
        }
    }

    function _validateOrder(
        bytes32,
        address,
        bytes[] memory,
        bytes[] memory
    ) internal view virtual override {
        if (_paused) {
            revert Paused();
        }
    }
}
