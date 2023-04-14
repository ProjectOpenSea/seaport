// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { vm } from "./VmUtils.sol";
import { LibString } from "solady/src/utils/LibString.sol";

address constant LABELER_ADDRESS = address(
    uint160(uint256(keccak256(".labeler")))
);

function setLabel(address account, string memory _label) {
    vm.store(
        LABELER_ADDRESS,
        bytes32(uint256(uint160(account))),
        LibString.packOne(_label)
    );
}

function withLabel(address account) pure returns (string memory out) {
    out = LibString.toHexString(account);
    string memory label = pureGetLabel()(account);
    uint256 length;
    assembly {
        length := mload(label)
    }
    if (length > 0) {
        out = string.concat(out, " (", label, ")");
    }
}

function getLabel(address account) pure returns (string memory) {
    return pureGetLabel()(account);
}

function getLabelView(address account) view returns (string memory _label) {
    bytes32 storedLabel = vm.load(
        LABELER_ADDRESS,
        bytes32(uint256(uint160(account)))
    );
    if (storedLabel != bytes32(0)) {
        return LibString.unpackOne(storedLabel);
    }
}

function withLabel(address[] memory accounts) pure returns (string[] memory) {
    uint256 length = accounts.length;
    string[] memory out = new string[](length);
    for (uint256 i; i < length; i++) {
        out[i] = withLabel(accounts[i]);
    }
    return out;
}

function pureGetLabel()
    pure
    returns (function(address) internal pure returns (string memory) pureFn)
{
    function(address)
        internal
        view
        returns (string memory) viewFn = getLabelView;
    assembly {
        pureFn := viewFn
    }
}
