# @version 0.3.3

#  @title NonceManager
#  @author 0age
#  @notice NonceManager contains a storage mapping and related functionality
#          for retrieving and incrementing a per-offerer nonce.

# @dev Emit an event whenever a nonce for a given offerer is incremented.
# 
# @param newNonce The new nonce for the offerer.
# @param offerer  The offerer in question.
event NonceIncremented:
    newNonce: uint256
    offerer: indexed(address)

# Only orders signed using an offerer's current nonce are fulfillable.
_nonces: HashMap[address, uint256]

@internal
@nonreentrant("nonce-lock")
def _incrementNonce() -> uint256:
    """
    @dev Internal function to cancel all orders from a given offerer with a
         given zone in bulk by incrementing a nonce. Note that only the
         offerer may increment the nonce.
    @return newNonce The new nonce.
    """

    # Increment current nonce for the supplied offerer.
    new_nonce: uint256 = self._nonces[msg.sender] + 1
    self._nonces[msg.sender] = new_nonce

    log NonceIncremented(new_nonce, msg.sender)

    return new_nonce

@view
@internal
def _gerNonce(offerer: address) -> uint256:
    """
    @dev Internal view function to retrieve the current nonce for a given
         offerer.
        
    @param offerer The offerer in question.
    
    @return currentNonce The current nonce.
    """

    return self._nonces[offerer]







