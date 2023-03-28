pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";
import { console2 } from "forge-std/console2.sol";
import { LibString } from "solady/src/utils/LibString.sol";

address constant VM_ADDRESS = address(
    uint160(uint256(keccak256("hevm cheat code")))
);
Vm constant vm = Vm(VM_ADDRESS);

address constant LABELER_ADDRESS = address(
    uint160(uint256(keccak256(".labeler")))
);

function setupLabeler() {}

function getLabelView(address account) view returns (string memory _label) {
    bytes32 storedLabel = vm.load(
        LABELER_ADDRESS,
        bytes32(uint256(uint160(account)))
    );
    if (storedLabel != bytes32(0)) {
        return LibString.unpackOne(storedLabel);
    }
}

function getLabel(address account) pure returns (string memory) {
    return pureGetLabel()(account);
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

function withLabel(
    address[] memory accounts
) pure returns (string[] memory out) {
    uint256 length = accounts.length;
    out = new string[](length);
    for (uint256 i; i < length; i++) {
        out[i] = withLabel(accounts[i]);
    }
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

function setLabel(address account, string memory _label) {
    vm.store(
        LABELER_ADDRESS,
        bytes32(uint256(uint160(account))),
        LibString.packOne(_label)
    );
    /* if (labeler.hasLabel(account)) return;
    labeler.label(account, _label);
    vm.label(account, _label); */
}

/* contract Labeler {
    mapping(address => string) public _getLabel;

    function hasLabel(address account) external view returns (bool have) {
        string memory s = _getLabel[account];
        assembly {
            have := iszero(iszero(mload(s)))
        }
    }

    function label(
        address account,
        string memory _label
    ) external returns (bool) {
        _getLabel[account] = _label;
        return true;
    }
}
 */
