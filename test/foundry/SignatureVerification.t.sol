// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    SignatureVerification
} from "../../contracts/lib/SignatureVerification.sol";
import {
    ReferenceSignatureVerification
} from "../../reference/lib/ReferenceSignatureVerification.sol";
import { GettersAndDerivers } from "../../contracts/lib/GettersAndDerivers.sol";
import {
    ReferenceGettersAndDerivers
} from "../../reference/lib/ReferenceGettersAndDerivers.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";
import { OrderParameters } from "../../contracts/lib/ConsiderationStructs.sol";
import {
    ConsiderationInterface
} from "../../contracts/interfaces/ConsiderationInterface.sol";

interface GetterAndDeriver {
    function deriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) external returns (bytes32 orderHash);

    function domainSeparator() external returns (bytes32);

    function deriveEIP712Digest(
        bytes32 _domainSeparator_,
        bytes32 orderHash
    ) external returns (bytes32 value);
}

contract GettersAndDeriversImpl is GetterAndDeriver, GettersAndDerivers {
    constructor(
        address conduitController
    ) GettersAndDerivers(conduitController) {}

    function deriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) public view returns (bytes32 orderHash) {
        return _deriveOrderHash(orderParameters, counter);
    }

    function domainSeparator() public view returns (bytes32) {
        return _domainSeparator();
    }

    function deriveEIP712Digest(
        bytes32 _domainSeparator_,
        bytes32 orderHash
    ) public pure returns (bytes32 value) {
        return _deriveEIP712Digest(_domainSeparator_, orderHash);
    }
}

contract ReferenceGettersAndDeriversImpl is
    GetterAndDeriver,
    ReferenceGettersAndDerivers
{
    constructor(
        address conduitController
    ) ReferenceGettersAndDerivers(conduitController) {}

    function deriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) public view returns (bytes32 orderHash) {
        return _deriveOrderHash(orderParameters, counter);
    }

    function domainSeparator() public view returns (bytes32) {
        return _domainSeparator();
    }

    function deriveEIP712Digest(
        bytes32 _domainSeparator_,
        bytes32 orderHash
    ) public pure returns (bytes32 value) {
        return _deriveEIP712Digest(_domainSeparator_, orderHash);
    }
}

contract SignatureVerifierLogic is BaseOrderTest, SignatureVerification {
    GetterAndDeriver getterAndDeriver;

    constructor(
        address _conduitController,
        ConsiderationInterface _consideration
    ) {
        getterAndDeriver = GetterAndDeriver(
            new GettersAndDeriversImpl(address(_conduitController))
        );

        vm.label(address(getterAndDeriver), "getterAndDeriver");
        consideration = _consideration;
    }

    function signatureVerificationDirtyScratchSpace() external {
        addErc721OfferItem(1);
        addEthConsiderationItem(alice, 1);

        // create order where alice is offerer, but signer is *BOB*
        configureOrderParameters(alice);
        _configureOrderComponents(consideration.getCounter(alice));
        bytes32 orderHash = consideration.getOrderHash(baseOrderComponents);
        bytes memory signature = signOrder(consideration, bobPk, orderHash);

        bytes32 domainSeparator = getterAndDeriver.domainSeparator();
        bytes32 digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        // store bob's address in scratch space
        assembly {
            mstore(0x0, sload(bob.slot))
        }

        _assertValidSignature(
            alice,
            digest,
            digest,
            signature.length,
            signature
        );
    }
}

contract ReferenceSignatureVerifierLogic is
    BaseOrderTest,
    ReferenceSignatureVerification
{
    GetterAndDeriver getterAndDeriver;

    constructor(
        address _conduitController,
        ConsiderationInterface _consideration
    ) {
        getterAndDeriver = GetterAndDeriver(
            new ReferenceGettersAndDeriversImpl(address(_conduitController))
        );
        vm.label(address(getterAndDeriver), "referenceGetterAndDeriver");
        consideration = _consideration;
    }

    function referenceSignatureVerificationDirtyScratchSpace() external {
        addErc721OfferItem(1);
        addEthConsiderationItem(alice, 1);

        // create order where alice is offerer, but signer is *BOB*
        configureOrderParameters(alice);
        _configureOrderComponents(consideration.getCounter(alice));
        bytes32 orderHash = consideration.getOrderHash(baseOrderComponents);
        bytes memory signature = signOrder(consideration, bobPk, orderHash);

        bytes32 domainSeparator = getterAndDeriver.domainSeparator();
        bytes32 digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        // store bob's address in scratch space
        assembly {
            mstore(0x0, sload(bob.slot))
        }

        _assertValidSignature(alice, digest, digest, signature, signature);
    }
}

contract SignatureVerificationTest is BaseOrderTest {
    function test(function() external fn) internal {
        try fn() {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testSignatureVerification() public {
        SignatureVerifierLogic logic = new SignatureVerifierLogic(
            address(conduitController),
            consideration
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        logic.signatureVerificationDirtyScratchSpace();
        ReferenceSignatureVerifierLogic referenceLogic = new ReferenceSignatureVerifierLogic(
                address(referenceConduitController),
                referenceConsideration
            );
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        referenceLogic.referenceSignatureVerificationDirtyScratchSpace();
    }
}
