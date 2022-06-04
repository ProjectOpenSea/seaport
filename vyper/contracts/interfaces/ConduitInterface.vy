# @version 0.3.3

MAX_DYN_ARRAY_LENGTH: constant(uint8) = 100

struct ConduitTransfer:
    itemType: uint8
    token: address
    _from: address
    to: address
    identifier: uint256
    amount: uint256

struct ConduitBatch1155Transfer:
    token: address
    _from: address
    to: address
    ids: DynArray[uint256, MAX_DYN_ARRAY_LENGTH]
    amounts: DynArray[uint256, MAX_DYN_ARRAY_LENGTH]

# @dev Emit an event whenever a channel is opened or closed.
#
# @param channel The channel that has been updated.
# @param open    A boolean indicating whether the conduit is open or not.
event ChannelUpdated:
    channel: address
    open: bool

@external
def execute(
    transfers: DynArray[ConduitTransfer, MAX_DYN_ARRAY_LENGTH]
) -> (bytes4):
    """
    @notice Execute a sequence of ERC20/721/1155 transfers. Only a caller
            with an open channel can call this function.
        
    @param transfers The ERC20/721/1155 transfers to perform.
        
    @return magicValue A magic value indicating that the transfers were
                       performed successfully.
    """
    pass

@external
def executeBatch1155(
    batch1155Transfers: DynArray[ConduitBatch1155Transfer, MAX_DYN_ARRAY_LENGTH]
) -> (bytes4):
    """
    @notice Execute a sequence of batch 1155 transfers. Only a caller with an
            open channel can call this function.
        
    @param batch1155Transfers The 1155 batch transfers to perform.
        
    @return magicValue A magic value indicating that the transfers were
                       performed successfully.
    """
    pass

@external
def executeWithBatch1155(
    standardTransfers: DynArray[ConduitTransfer, MAX_DYN_ARRAY_LENGTH],
    batch1155Transfers: DynArray[ConduitBatch1155Transfer, MAX_DYN_ARRAY_LENGTH]
) -> (bytes4):
    """
    @notice Execute a sequence of transfers, both single and batch 1155. Only
            a caller with an open channel can call this function.
        
    @param standardTransfers  The ERC20/721/1155 transfers to perform.
    @param batch1155Transfers The 1155 batch transfers to perform.
        
    @return magicValue A magic value indicating that the transfers were
                       performed successfully.
    """
    pass

@external
def updateChannel(channel: address, isOpen: bool):
    """
    @notice Open or close a given channel. Only callable by the controller.
        
    @param channel The channel to open or close.
    @param isOpen  The status of the channel (either open or closed).
    """
    pass