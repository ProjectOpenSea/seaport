# @version 0.3.4

MAX_DYN_ARRAY_LENGTH: constant(uint8) = 100

# @dev Track the conduit key, current owner, new potential owner, and open
#      channels for each deployed conduit.
struct ConduitProperties:
    key: bytes32
    owner: address
    potentialOwner: address
    channels: DynArray[address, MAX_DYN_ARRAY_LENGTH]

# @dev Emit an event whenever a new conduit is created.
#
# @param conduit    The newly created conduit.
# @param conduitKey The conduit key used to create the new conduit.
event NewConduit:
    conduit: address
    conduitKey: bytes32

# @dev Emit an event whenever conduit ownership is transferred.
#
# @param conduit       The conduit for which ownership has been
#                      transferred.
# @param previousOwner The previous owner of the conduit.
# @param newOwner      The new owner of the conduit.
event OwnershipTransferred:
    conduit: indexed(address)
    previousOwner: indexed(address)
    newOwner: indexed(address)

event PotentialOwnerUpdated:
    conduit: indexed(address)
    newPotentialOwner: indexed(address)

@external
def createConduit(conduitKey: bytes32, initialOwner: address) -> (address):
    """
    @notice Deploy a new conduit using a supplied conduit key and assigning
            an initial owner for the deployed conduit. Note that the last
            twenty bytes of the supplied conduit key must match the caller
            and that a new conduit cannot be created if one has already been
            deployed using the same conduit key.
        
    @param conduitKey   The conduit key used to deploy the conduit. Note that
                        the last twenty bytes of the conduit key must match
                        the caller of this contract.
    @param initialOwner The initial owner to set for the new conduit.
        
    @return conduit The address of the newly deployed conduit.
    """
    pass

@external
def updateChannel(conduit: address, channel: address, isOpen: bool):
    """
    @notice Open or close a channel on a given conduit, thereby allowing the
            specified account to execute transfers against that conduit.
            Extreme care must be taken when updating channels, as malicious
            or vulnerable channels can transfer any ERC20, ERC721 and ERC1155
            tokens where the token holder has granted the conduit approval.
            Only the owner of the conduit in question may call this function.
        
    @param conduit The conduit for which to open or close the channel.
    @param channel The channel to open or close on the conduit.
    @param isOpen  A boolean indicating whether to open or close the channel.
    """
    pass

@external
def transferOwnership(conduit: address, newPotentialOwner: address):
    """
    @notice Initiate conduit ownership transfer by assigning a new potential
            owner for the given conduit. Once set, the new potential owner
            may call `acceptOwnership` to claim ownership of the conduit.
            Only the owner of the conduit in question may call this function.
        
    @param conduit The conduit for which to initiate ownership transfer.
    """
    pass

@external
def cancelOwnershipTransfer(conduit: address):
    """
    @notice Clear the currently set potential owner, if any, from a conduit.
            Only the owner of the conduit in question may call this function.
        
    @param conduit The conduit for which to cancel ownership transfer.
    """
    pass

@external
def acceptOwnership(conduit: address):
    """
    @notice Accept ownership of a supplied conduit. Only accounts that the
            current owner has set as the new potential owner may call this
            function.
        
    @param conduit The conduit for which to accept ownership.
    """
    pass

@view
@external
def ownerOf(conduit: address) -> (address):
    """
    @notice Retrieve the current owner of a deployed conduit.
        
    @param conduit The conduit for which to retrieve the associated owner.
    
    @return owner The owner of the supplied conduit.
    """
    pass

@view
@external
def getKey(conduit: address) -> (bytes32):
    """
    @notice Retrieve the conduit key for a deployed conduit via reverse
            lookup.
        
    @param conduit The conduit for which to retrieve the associated conduit
                   key.
        
    @return conduitKey The conduit key used to deploy the supplied conduit.
    """
    pass

@view
@external
def getConduit(conduitKey: bytes32) -> (address, bool):
    """
    @notice Derive the conduit associated with a given conduit key and
            determine whether that conduit exists (i.e. whether it has been
            deployed).
        
    @param conduitKey The conduit key used to derive the conduit.
       
    @return conduit The derived address of the conduit.
    @return exists  A boolean indicating whether the derived conduit has been
                    deployed or not.
    """
    pass

@view
@external
def getPotentialOwner(conduit: address) -> (address):
    """
    @notice Retrieve the potential owner, if any, for a given conduit. The
            current owner may set a new potential owner via
            `transferOwnership` and that owner may then accept ownership of
            the conduit in question via `acceptOwnership`.
        
    @param conduit The conduit for which to retrieve the potential owner.
    
    @return potentialOwner The potential owner, if any, for the conduit.
    """
    pass

@view
@external
def getChannelStatus(conduit: address, channel: address) -> (bool):
    """
    @notice Retrieve the status (either open or closed) of a given channel on
            a conduit.
        
    @param conduit The conduit for which to retrieve the channel status.
    @param channel The channel for which to retrieve the status.
        
    @return isOpen The status of the channel on the given conduit.
    """
    pass

@view
@external
def getTotalChannels(conduit: address) -> (uint256):
    """
    @notice Retrieve the total number of open channels for a given conduit.
        
    @param conduit The conduit for which to retrieve the total channel count.
        
    @return totalChannels The total number of open channels for the conduit.
    """
    pass

@view
@external
def getChannel(conduit: address, channelIndex: uint256) -> (address):
    """
    @notice Retrieve an open channel at a specific index for a given conduit.
            Note that the index of a channel can change as a result of other
            channels being closed on the conduit.
        
    @param conduit      The conduit for which to retrieve the open channel.
    @param channelIndex The index of the channel in question.
        
    @return channel The open channel, if any, at the specified channel index.
    """
    pass

@view
@external
def getChannels(conduit: address) -> (DynArray[address, MAX_DYN_ARRAY_LENGTH]):
    """
    @notice Retrieve all open channels for a given conduit. Note that calling
            this function for a conduit with many channels will revert with
            an out-of-gas error.
        
    @param conduit The conduit for which to retrieve open channels.
        
    @return channels An array of open channels on the given conduit.
    """
    pass

@view
@external
def getConduitCodeHashes() -> (bytes32, bytes32):
    """
    @dev Retrieve the conduit creation code and runtime code hashes.
    """
    pass