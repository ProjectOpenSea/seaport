// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { SignatureVerification } from "../../contracts/lib/SignatureVerification.sol";
import { ReferenceSignatureVerification } from "../../reference/lib/ReferenceSignatureVerification.sol";
import { GettersAndDerivers } from "../../contracts/lib/GettersAndDerivers.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { OrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";

contract GettersAndDeriversImpl is GettersAndDerivers {
    constructor(address conduitController)
        GettersAndDerivers(conduitController)
    {}

    function deriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) public view returns (bytes32 orderHash) {
        return _deriveOrderHash(orderParameters, counter);
    }

    function domainSeparator() public view returns (bytes32) {
        return _domainSeparator();
    }

    function deriveEIP712Digest(bytes32 _domainSeparator_, bytes32 orderHash)
        public
        pure
        returns (bytes32 value)
    {
        return _deriveEIP712Digest(_domainSeparator_, orderHash);
    }
}

contract SignatureVerificationTest is BaseOrderTest, SignatureVerification {
    GettersAndDeriversImpl gettersAndDeriversImpl;

    function setUp() public override {
        super.setUp();
        gettersAndDeriversImpl = new GettersAndDeriversImpl(
            address(conduitController)
        );
    }

    function testSignatureVerificationDirtyScratchSpace() public {
        addErc721OfferItem(1);
        addEthConsiderationItem(alice, 1);

        // create order where alice is offerer, but signer is *BOB*
        configureOrderParameters(alice);
        _configureOrderComponents(consideration.getCounter(alice));
        bytes32 orderHash = consideration.getOrderHash(baseOrderComponents);
        bytes memory signature = signOrder(consideration, bobPk, orderHash);

        // store bob's address in scratch space
        assembly {
            mstore(0x0, sload(bob.slot))
        }

        bytes32 domainSeparator = gettersAndDeriversImpl.domainSeparator();
        bytes32 digest = gettersAndDeriversImpl.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );
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
