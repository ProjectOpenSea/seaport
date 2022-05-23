# @version 0.3.3

interface ERC20ApprovalInterface:
    def approve(user: address, amount: uint256) -> bool: nonpayable

interface NFTApprovalInterface:
    def setApprovalForAll(user: address, approved: bool): nonpayable


_EIP_1271_MAGIC_VALUE: constant(bytes4) = 0x1626ba7e

owner: public(address)  # immutable
showRevertMessage: public(bool)
digestApproved: public(HashMap[bytes32, bool])
isValid: public(bool)

@external
def __init__(owner: address):
    self.owner = owner
    self.showRevertMessage = True
    self.isValid = True


@external
def setValid(valid: bool):
    self.isValid = valid


@external
def revertWithMessage(showMessage: bool):
    self.showRevertMessage = showMessage


@external
def registerDigest(digest: bytes32, approved: bool):
    self.digestApproved[digest] = approved


@external
def approveERC20(token: ERC20ApprovalInterface, operator: address, amount: uint256):
    assert msg.sender == self.owner, "Only owner"
    token.approve(operator, amount)


@external
def approveNFT(token: NFTApprovalInterface, operator: address):
    assert msg.sender == self.owner, "Only owner"
    token.setApprovalForAll(operator, True)


@external
def isValidSignature(digest: bytes32, signature: Bytes[65]) -> bytes4:
    if self.digestApproved[digest]:
        return _EIP_1271_MAGIC_VALUE
    
    assert len(signature) == 65

    r: uint256 = convert(slice(signature, 0, 32), uint256)
    s: uint256 = convert(slice(signature, 32, 32), uint256)
    v: uint256 = convert(slice(signature, 64, 1), uint256)

    assert s <= convert(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, uint256)

    assert v in [27, 28]

    signer: address = ecrecover(digest, v, r, s)

    assert signer != ZERO_ADDRESS

    if signer != self.owner:
        if self.showRevertMessage:
            raise "BAD SIGNER"
        raise

    if self.isValid:
        return _EIP_1271_MAGIC_VALUE
    
    return 0xffffffff
