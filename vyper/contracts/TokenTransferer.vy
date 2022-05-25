# @version 0.3.3

from vyper.interfaces import ERC721

interface ERC1155:
    def safeTransferFrom(_from: address, _to: address, _id: uint256, _value: uint256, _data: bytes32): nonpayable
    def safeBatchTransferFrom(_from: address, _to: address, _ids: DynArray[uint256, 10] , _amounts: DynArray[uint256, 10], _data: bytes32): nonpayable

struct ConduitBatch1155Transfer:
    token: address
    _from: address
    to: address
    ids: DynArray[uint256, 10] 
    amounts: DynArray[uint256, 10] 

@internal
def _performERC20Transfer(token: address, _from: address, to: address, amount: uint256):
    _response: Bytes[32] = raw_call(
        token,
        _abi_encode(
            _from,
            to,
            amount,
            method=method_id("transferFrom(address,address,uint256)")
        ),
        max_outsize=32
    )  
    if len(_response) > 0:
        assert convert(_response, bool) 

@internal
def _performERC721Transfer(token: address, _from: address, to: address, identifier: uint256):
    ERC721(token).transferFrom(_from, to, identifier)

@internal
def _performERC1155Transfer(token: address, _from: address, to: address, identifier: uint256, amount: uint256):
    ERC1155(token).safeTransferFrom(_from, to, identifier, amount, EMPTY_BYTES32)

@internal
def _performERC1155BatchTransfers(batchTransfers: DynArray[ConduitBatch1155Transfer, 10]):
    for transfer in batchTransfers:
        ERC1155(transfer.token).safeBatchTransferFrom(transfer._from, transfer.to, transfer.ids, transfer.amounts, EMPTY_BYTES32)