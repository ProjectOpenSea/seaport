// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { SignatureVerification } from "../../contracts/lib/SignatureVerification.sol";
import { ReferenceSignatureVerification } from "../../reference/lib/ReferenceSignatureVerification.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

contract SignatureVerificationTest is BaseOrderTest, SignatureVerification {
    function testSignatureVerificationDirtyScratchSpace() public {
        addErc721OfferItem(1);
        addEthConsiderationItem(alice, 1);

        // create order where alice is offerer, but signer is *BOB*
        bytes memory signature;

        // store bob's address in scratch space
        assembly {
            mstore(0x0, sload(bob.slot))
        }

        bytes32 digest;
        // figure out digest and pass in here
        // might revert with diff error code?
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        _assertValidSignature(alice, digest, signature);
    }
}

contract ReferenceSignatureVerificationTest is
    BaseOrderTest,
    ReferenceSignatureVerification
{
    function testSignatureVerificationDirtyScratchSpace() public {
        addErc721OfferItem(1);
        addEthConsiderationItem(alice, 1);

        // create order where alice is offerer, but signer is *BOB*
        bytes memory signature;

        // store bob's address in scratch space
        assembly {
            mstore(0x0, sload(bob.slot))
        }

        bytes32 digest;
        // figure out digest and pass in here
        // might revert with diff error code?
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        _assertValidSignature(alice, digest, signature);
    }
}
