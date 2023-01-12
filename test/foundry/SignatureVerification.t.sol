// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { SignatureVerification } from
    "../../contracts/lib/SignatureVerification.sol";
import { ReferenceSignatureVerification } from
    "../../reference/lib/ReferenceSignatureVerification.sol";
import { BaseOrderTest } from "./utils/BaseOrderTest.sol";

contract SignatureVerifierLogic is BaseOrderTest, SignatureVerification {
    bytes signature;
    bytes signature1271;
    bytes32 digest;

    function signatureVerificationDirtyScratchSpace() external {
        digest = bytes32(uint256(69420));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        signature = abi.encodePacked(r, s, v);

        // store bob's address in scratch space
        assembly {
            mstore(0x0, sload(bob.slot))
        }

        _assertValidSignature(
            alice, digest, digest, signature.length, signature
        );
    }

    function signatureVerification65ByteWithBadSignatureV() external {
        digest = bytes32(uint256(69420));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        v = 0;
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);

        _assertValidSignature(
            alice, digest, digest, signature.length, signature
        );
    }

    function signatureVerification65ByteJunkWithAcceptableSignatureV()
        external
    {
        digest = bytes32(uint256(69420));
        // Note that Bob is signing but we're passing in Alice's address below.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, digest);
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);

        _assertValidSignature(
            alice, digest, digest, signature.length, signature
        );
    }

    function signatureVerification64ByteJunk() external {
        digest = bytes32(uint256(69420));
        // Note that Bob is signing but we're passing in Alice's address below.
        (, bytes32 r, bytes32 s) = vm.sign(bobPk, digest);
        signature = abi.encodePacked(r, s);
        assertEq(signature.length, 64);

        _assertValidSignature(
            alice, digest, digest, signature.length, signature
        );
    }

    function signatureVerificationTooLong() external {
        digest = bytes32(uint256(69420));
        signature = new bytes(69);

        _assertValidSignature(
            alice, digest, digest, signature.length, signature
        );
    }

    function signatureVerificationValid() external {
        digest = bytes32(uint256(69420));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        signature = abi.encodePacked(r, s, v);

        _assertValidSignature(
            alice, digest, digest, signature.length, signature
        );
    }

    function signatureVerification1271Valid() external {
        digest = bytes32(uint256(69420));
        // This is valid because we hardcoded the `isValidSignature` magic value
        // response in the BaseOrderTest.
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0));

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
    bytes signature1271;
    bytes32 digest;

    ///@dev This overrides the hardcoded `isValidSignature` magic value response
    ///     in the BaseOrderTest.
    function isValidSignature(
        bytes32,
        bytes memory
    ) external pure override returns (bytes4) {
        return 0xDEAFBEEF;
    }

    function signatureVerification1271Invalid() external {
        digest = bytes32(uint256(69420));
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0));

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

contract SignatureVerifierLogicWith1271Fail is
    BaseOrderTest,
    SignatureVerification
{
    bytes signature1271;
    bytes32 digest;

    ///@dev This overrides the hardcoded `isValidSignature` magic value response
    ///     in the BaseOrderTest.
    function isValidSignature(
        bytes32,
        bytes memory
    ) external pure override returns (bytes4) {
        revert();
    }

    function signatureVerification1271Fail() external {
        digest = bytes32(uint256(69420));
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0));

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
    bytes signature;
    bytes signature1271;
    bytes32 digest;

    function referenceSignatureVerificationDirtyScratchSpace() external {
        digest = bytes32(uint256(69420));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        signature = abi.encodePacked(r, s, v);

        // store bob's address in scratch space
        assembly {
            mstore(0x0, sload(bob.slot))
        }

        _assertValidSignature(alice, digest, digest, signature, signature);
    }

    function referenceSignatureVerification65ByteWithBadSignatureV() external {
        digest = bytes32(uint256(69420));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        v = 0;
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);

        _assertValidSignature(alice, digest, digest, signature, signature);
    }

    function referenceSignatureVerification65ByteJunkWithAcceptableSignatureV()
        external
    {
        digest = bytes32(uint256(69420));
        // Note that Bob is signing but we're passing in Alice's address below.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, digest);
        signature = abi.encodePacked(r, s, v);
        assertEq(signature.length, 65);

        _assertValidSignature(alice, digest, digest, signature, signature);
    }

    function referenceSignatureVerification64ByteJunk() external {
        digest = bytes32(uint256(69420));
        // Note that Bob is signing but we're passing in Alice's address below.
        (, bytes32 r, bytes32 s) = vm.sign(bobPk, digest);
        signature = abi.encodePacked(r, s);
        assertEq(signature.length, 64);

        _assertValidSignature(alice, digest, digest, signature, signature);
    }

    function referenceSignatureVerificationTooLong() external {
        digest = bytes32(uint256(69420));
        signature = new bytes(69);

        _assertValidSignature(alice, digest, digest, signature, signature);
    }

    function referenceSignatureVerificationValid() external {
        digest = bytes32(uint256(69420));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        signature = abi.encodePacked(r, s, v);

        _assertValidSignature(alice, digest, digest, signature, signature);
    }

    function referenceSignatureVerification1271Valid() external {
        digest = bytes32(uint256(69420));
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0));

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

contract ReferenceSignatureVerifierLogicWith1271Override is
    BaseOrderTest,
    ReferenceSignatureVerification
{
    bytes signature1271;
    bytes32 digest;

    ///@dev This overrides the hardcoded `isValidSignature` magic value response
    ///     in the BaseOrderTest.
    function isValidSignature(
        bytes32,
        bytes memory
    ) external pure override returns (bytes4) {
        return 0xDEAFBEEF;
    }

    function referenceSignatureVerification1271Invalid() external {
        digest = bytes32(uint256(69420));
        signature1271 = abi.encodePacked(bytes32(0), bytes32(0));

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
        try fn() { }
        catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testSignatureVerification() public {
        SignatureVerifierLogic logic = new SignatureVerifierLogic();
        logic.signatureVerificationDirtyScratchSpace();
        vm.expectRevert(abi.encodeWithSignature("BadSignatureV(uint8)", 0));
        logic.signatureVerification65ByteWithBadSignatureV();
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        logic.signatureVerification65ByteJunkWithAcceptableSignatureV();
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        logic.signatureVerification64ByteJunk();
        vm.expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        logic.signatureVerificationTooLong();
        logic.signatureVerificationValid();
        logic.signatureVerification1271Valid();

        SignatureVerifierLogicWith1271Override logicWith1271Override =
            new SignatureVerifierLogicWith1271Override();
        vm.expectRevert(abi.encodeWithSignature("BadContractSignature()"));
        logicWith1271Override.signatureVerification1271Invalid();

        SignatureVerifierLogicWith1271Fail logicWith1271Fail =
            new SignatureVerifierLogicWith1271Fail();
        vm.expectRevert(abi.encodeWithSignature("BadContractSignature()"));
        logicWith1271Fail.signatureVerification1271Fail();

        ReferenceSignatureVerifierLogic referenceLogic =
            new ReferenceSignatureVerifierLogic();
        referenceLogic.referenceSignatureVerificationDirtyScratchSpace();
        vm.expectRevert(abi.encodeWithSignature("BadSignatureV(uint8)", 0));
        referenceLogic.referenceSignatureVerification65ByteWithBadSignatureV();
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        referenceLogic
            .referenceSignatureVerification65ByteJunkWithAcceptableSignatureV();
        vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
        referenceLogic.referenceSignatureVerification64ByteJunk();
        vm.expectRevert(abi.encodeWithSignature("InvalidSignature()"));
        referenceLogic.referenceSignatureVerificationTooLong();
        referenceLogic.referenceSignatureVerificationValid();
        referenceLogic.referenceSignatureVerification1271Valid();

        ReferenceSignatureVerifierLogicWith1271Override
            referenceLogicWith1271Override =
                new ReferenceSignatureVerifierLogicWith1271Override();
        vm.expectRevert(abi.encodeWithSignature("BadContractSignature()"));
        referenceLogicWith1271Override.referenceSignatureVerification1271Invalid(
        );
    }
}
