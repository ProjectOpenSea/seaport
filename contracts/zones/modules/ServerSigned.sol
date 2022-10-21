// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { BaseZone } from "../BaseZone.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { AdvancedOrder } from "../../lib/ConsiderationStructs.sol";

abstract contract ServerSigned is BaseZone {
    error InvalidSignature();

    bytes32 internal constant _SIGN_ORDER_TYPEHASH =
        keccak256("SignOrder(bytes32 orderHash)");

    event ServerSignerSet(address oldSigner, address newSigner);

    uint256 private immutable _EXTRA_DATA_INDEX = _VARIABLE_EXTRA_DATA_LENGTH++;
    address private _signer;

    function setSigner(address signer) public onlyOwner {
        emit ServerSignerSet(_signer, signer);
        _signer = signer;
    }

    function _validateOrder(
        bytes32 orderHash,
        address,
        bytes[] memory,
        bytes[] memory extraData
    ) internal view virtual override {
        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                _domainSeparator(),
                keccak256(abi.encode(_SIGN_ORDER_TYPEHASH, orderHash))
            )
        );

        address signer = ECDSA.recover(digest, extraData[_EXTRA_DATA_INDEX]);
        if (!(signer != address(0) && signer == _signer)) {
            revert InvalidSignature();
        }
    }

    function _validateOrder(bytes32, address) internal view virtual override {
        // Can't check signature without extra data
        revert ExtraDataRequired();
    }
}
