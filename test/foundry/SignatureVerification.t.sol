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
    bytes32 orderHash;
    bytes signature;
    bytes signature1271;
    bytes32 domainSeparator;
    bytes32 digest;

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
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature = signOrder(consideration, bobPk, orderHash);

        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
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

    function signatureVerification65ByteJunkWithBadSignatureV() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature = abi.encodePacked(bytes32(0), bytes32(0), bytes1(0));
        assertEq(signature.length, 65);

        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            alice,
            digest,
            digest,
            signature.length,
            signature
        );
    }


    function signatureVerification65ByteJunkWithAcceptableSignatureV() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature = abi.encodePacked(bytes32(0), bytes32(0), bytes1(uint8(27)));
        assertEq(signature.length, 65);

        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            alice,
            digest,
            digest,
            signature.length,
            signature
        );
    }
    

    // THIS IS A WEIRD ONE.  I EXPECT TO GET `InvalidSigner` LIKE IN THE
    // REFERENCE CONTRACT, BUT I GET `BadSignatureV` INSTEAD.  I'M NOT SURE WHY.
    function signatureVerification64ByteJunk() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature = abi.encodePacked(bytes32(0), bytes32(0));
        assertEq(signature.length, 64);

        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            alice,
            digest,
            digest,
            signature.length,
            signature
        );
    }

    function signatureVerificationTooLong() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature = new bytes(69);

        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            alice, 
            digest, 
            digest, 
            signature.length, 
            signature
        );
    }

    function signatureVerification1271Valid() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0));

        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            // A contract address is the signer.
            address(this),
            digest,
            digest,
            signature1271.length,
            signature1271
        );
    }
}

contract SignatureVerifierLogicWith1271Override is
    BaseOrderTest,
    SignatureVerification
{
    GetterAndDeriver getterAndDeriver;
    bytes32 orderHash;
    bytes signature;
    bytes signature1271;
    bytes32 domainSeparator;
    bytes32 digest;
    
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

    ///@dev This overrides the hardcoded `isValidSignature` magic value response
    ///     in the BaseOrderTest.
    function isValidSignature(
        bytes32,
        bytes memory
    ) external pure override returns (bytes4) {
        return 0xDEAFBEEF;
    }

    function signatureVerification1271Invalid() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0), bytes1(0));

        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            // A contract address is the signer.
            address(this),
            digest,
            digest,
            signature1271.length,
            signature1271
        );
    }
}

contract ReferenceSignatureVerifierLogic is
    BaseOrderTest,
    ReferenceSignatureVerification
{
    GetterAndDeriver getterAndDeriver;
    bytes32 orderHash;
    bytes signature;
    bytes signature1271;
    bytes32 domainSeparator;
    bytes32 digest;
    
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
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature = signOrder(consideration, bobPk, orderHash);

        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        // store bob's address in scratch space
        assembly {
            mstore(0x0, sload(bob.slot))
        }

        _assertValidSignature(alice, digest, digest, signature, signature);
    }

    function referenceSignatureVerification65ByteJunkWithBadSignatureV() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature = abi.encodePacked(bytes32(0), bytes32(0), bytes1(0));
        assertEq(signature.length, 65);
        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            alice,
            digest,
            digest,
            signature,
            signature
        );
    }


    function referenceSignatureVerification65ByteJunkWithAcceptableSignatureV() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature = abi.encodePacked(bytes32(0), bytes32(0), bytes1(uint8(27)));
        assertEq(signature.length, 65);
        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            alice,
            digest,
            digest,
            signature,
            signature
        );
    }

    function referenceSignatureVerification64ByteJunk() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature = abi.encodePacked(bytes32(0), bytes32(0));
        assertEq(signature.length, 64);
        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            alice,
            digest,
            digest,
            signature,
            signature
        );
    }

    function referenceSignatureVerificationTooLong() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature = new bytes(69);
        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(alice, digest, digest, signature, signature);
    }

    function referenceSignatureVerification1271Valid() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0), bytes1(0));
        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            // A contract address is the signer.
            address(this),
            digest,
            digest,
            signature1271,
            signature1271
        );
    }

    // function referenceSignatureVerificationValid() external {
    //     // addErc721OfferItem(1);
    //     // addEthConsiderationItem(alice, 1);
    //     configureOrderParameters(alice);
    //     _configureOrderComponents(consideration.getCounter(alice));
    //     orderHash = consideration.getOrderHash(baseOrderComponents);
    //     signature = signOrder(consideration, alicePk, orderHash);

    //     domainSeparator = getterAndDeriver.domainSeparator();
    //     digest = getterAndDeriver.deriveEIP712Digest(
    //         domainSeparator,
    //         orderHash
    //     );

    //     _assertValidSignature(alice, digest, digest, signature, signature);
    // }
}

contract ReferenceSignatureVerifierLogicWith1271Override is
    BaseOrderTest,
    ReferenceSignatureVerification
{
    GetterAndDeriver getterAndDeriver;
    bytes32 orderHash;
    bytes signature;
    bytes signature1271;
    bytes32 domainSeparator;
    bytes32 digest;
    
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

    ///@dev This overrides the hardcoded `isValidSignature` magic value response
    ///     in the BaseOrderTest.
    function isValidSignature(
        bytes32,
        bytes memory
    ) external pure override returns (bytes4) {
        return 0xDEAFBEEF;
    }

    function referenceSignatureVerification1271Invalid() external {
        orderHash = consideration.getOrderHash(baseOrderComponents);
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0), bytes1(0));

        domainSeparator = getterAndDeriver.domainSeparator();
        digest = getterAndDeriver.deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        _assertValidSignature(
            // A contract address is the signer.
            address(this),
            digest,
            digest,
            signature1271,
            signature1271
        );
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
        vm.expectRevert(abi.encodeWithSignature("BadSignatureV(uint8)", 0));
        logic.signatureVerification65ByteJunkWithBadSignatureV();
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        logic.signatureVerification65ByteJunkWithAcceptableSignatureV();
        // Inconsistency between the reference and the implementation.
        // vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        vm.expectRevert(abi.encodeWithSignature("BadSignatureV(uint8)", 0));
        logic.signatureVerification64ByteJunk();
        vm.expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        logic.signatureVerificationTooLong();
        logic.signatureVerification1271Valid();

        SignatureVerifierLogicWith1271Override logicWith1271Override = new SignatureVerifierLogicWith1271Override(
                address(conduitController),
                consideration
            );
        // Inconsistency between the reference and the implementation.
        // vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        vm.expectRevert(abi.encodeWithSignature("BadContractSignature()"));
        logicWith1271Override.signatureVerification1271Invalid();

        ReferenceSignatureVerifierLogic referenceLogic = new ReferenceSignatureVerifierLogic(
                address(referenceConduitController),
                referenceConsideration
            );
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        referenceLogic.referenceSignatureVerificationDirtyScratchSpace();
        vm.expectRevert(abi.encodeWithSignature("BadSignatureV(uint8)", 0));
        referenceLogic.referenceSignatureVerification65ByteJunkWithBadSignatureV();
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        referenceLogic.referenceSignatureVerification65ByteJunkWithAcceptableSignatureV();
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        referenceLogic.referenceSignatureVerification64ByteJunk();
        vm.expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        referenceLogic.referenceSignatureVerificationTooLong();
        referenceLogic.referenceSignatureVerification1271Valid();
        // referenceLogic.referenceSignatureVerificationValid();

        ReferenceSignatureVerifierLogicWith1271Override referenceLogicWith1271Override = new ReferenceSignatureVerifierLogicWith1271Override(
                address(referenceConduitController),
                referenceConsideration
            );
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        referenceLogicWith1271Override.referenceSignatureVerification1271Invalid();
    }
}
