# @version 0.3.3

struct ConduitBatch1155Transfer:
    token: address
    _from: address
    to: address
    ids: DynArray[uint256, 10] 
    amounts: DynArray[uint256, 10] 

TRANSFERFROM_MID: constant(Bytes[4]) = method_id("transferFrom(address,address,uint256)")
TRANSFERFROM1155_MID: constant(Bytes[4]) = method_id("transferFrom(address,address,uint256,uint256)")
SAFEBATCHTRANSFERFROM_MID: constant(Bytes[4]) = method_id("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)")

@internal
def _performERC20Transfer(token: address, _from: address, to: address, amount: uint256):
    _response: Bytes[32] = raw_call(
    token,
    _abi_encode(
        TRANSFERFROM_MID,
        _from,
        to,
        amount
        ),
        max_outsize=32
    )  
    if len(_response) > 0:
        assert convert(_response, bool), "TransferFrom failed"  

@internal
def _performERC721Transfer(token: address, _from: address, to: address, identifier: uint256):
    _response: Bytes[32] = raw_call(
    token,
    _abi_encode(
        TRANSFERFROM_MID,
        _from,
        to,
        identifier
        ),
        max_outsize=32
    ) 
    if len(_response) > 0:
        assert convert(_response, bool), "TransferFrom failed"  

@internal
def _performERC1155Transfer(token: address, _from: address, to: address, identifier: uint256, amount: uint256):
    _response: Bytes[32] = raw_call(
    token,
    _abi_encode(
        TRANSFERFROM1155_MID,
        _from,
        to,
        identifier,
        amount
        ),
        max_outsize=32
    )  
    if len(_response) > 0:
        assert convert(_response, bool), "TransferFrom failed"  

@internal
def _performERC1155BatchTransfers(batchTransfers: DynArray[ConduitBatch1155Transfer, 10]):
    for transfer in batchTransfers:
        _response: Bytes[32] = raw_call(
        transfer.token,
        _abi_encode(
            SAFEBATCHTRANSFERFROM_MID,
            transfer._from,
            transfer.to,
            transfer.ids,
            transfer.amounts
            ),
            max_outsize=32
        ) 
        if len(_response) > 0:
            assert convert(_response, bool), "SafeBatchTransferFrom failed"  