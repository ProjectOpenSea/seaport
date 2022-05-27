# @version 0.3.3

interface EIP1271Interface:
    def isValidSignature(
        digest: bytes32, signature: Bytes[100]) -> bytes4: view

IS_VALID_SIGNATURE_SELECTOR: constant(bytes4) = 0x1626ba7e
EIP2098_allButHighestBitMask: constant(
    bytes32) = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff

@internal
@view
def _assertValidEIP1271Signature(signer: address, digest: bytes32, signature: Bytes[100]):
    """
    @dev Internal view function to verify the signature of an order using
         ERC-1271 (i.e. contract signatures via `isValidSignature`). Note
         that, in contrast to standard ECDSA signatures, 1271 signatures may
         be valid in certain contexts and invalid in others, or vice versa;
         orders that validate signatures ahead of time must explicitly cancel
         those orders to invalidate them.

    @param signer    The signer for the order.
    @param digest    The signature digest, derived from the domain separator
                     and the order hash.
    @param signature A signature (or other data) used to validate the digest.

    """
    if EIP1271Interface(signer).isValidSignature(digest, signature) != IS_VALID_SIGNATURE_SELECTOR:
        raise "Invalid Signer"


@internal
@view
def _assertValidSignature(signer: address, digest: bytes32, signature: Bytes[100]):
    """
    @dev Internal view function to verify the signature of an order. An
         ERC-1271 fallback will be attempted if either the signature length
         is not 32 or 33 bytes or if the recovered signer does not match the
         supplied signer. Note that in cases where a 32 or 33 byte signature
         is supplied, only standard ECDSA signatures that recover to a
         non-zero address are supported.

    @param signer    The signer for the order.
    @param digest    The digest to verify the signature against.
    @param signature A signature from the signer indicating that the order
                     has been approved.
    """
    # Declare r, s, and v signature parameters.
    r: uint256 = 0
    s: uint256 = 0
    v: uint256 = 0

    # If signature contains 64 bytes, parse as EIP-2098 signature. (r+s&v)
    if len(signature) == 64:
        r = convert(slice(signature, 0, 32), uint256)

        # Declare temporary vs that will be decomposed into s and v.
        vs: uint256 = convert(slice(signature, 32, 32), uint256)

        s = bitwise_and(vs, convert(EIP2098_allButHighestBitMask, uint256))
        v = shift(s, -255) + 27

    elif len(signature) == 65:
        r = convert(slice(signature, 0, 32), uint256)
        s = convert(slice(signature, 32, 32), uint256)
        v = convert(slice(signature, 64, 1), uint256)

        # Ensure v value is properly formatted.
        if v != 27 and v != 28:
            raise "Bad Signature"
    else:
        # For all other signature lengths, try verification via EIP-1271.
        # Attempt EIP-1271 static call to signer in case it's a contract.
        self._assertValidEIP1271Signature(signer, digest, signature)

        # Return early if the ERC-1271 signature check succeeded.
        return

    # Attempt to recover signer using the digest and signature parameters.
    recovered_signer: address = ecrecover(digest, v, r, s)

    # Disallow invalid signers.
    if recovered_signer == ZERO_ADDRESS:
        raise "Invalid Signature"
        # Should a signer be recovered, but it doesn't match the signer...
    elif recovered_signer != signer:
        # Attempt EIP-1271 static call to signer in case it's a contract.
        self._assertValidEIP1271Signature(signer, digest, signature)
