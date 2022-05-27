# @version 0.3.3

_NOT_ENTERED: constant(uint256) = 1
_ENTERED: constant(uint256) = 2

# Prevent reentrant calls on protected functions.
_reentrancyGuard: uint256

@external
def __init__():
    """
    @dev Initialize the reentrancy guard during deployment.
    """

    # Initialize the reentrancy guard in a cleared state.
    self._reentrancyGuard = _NOT_ENTERED

@view
@internal
def _assertNonReentrant():
    """
    @dev Internal view function to ensure that the sentinel value for the
         reentrancy guard is not currently set.
    """
    # Ensure that the reentrancy guard is not currently set.
    if self._reentrancyGuard != _NOT_ENTERED:
        raise "No Reenterant Calls"

@internal
def _setReentrancyGuard():
    """
    @dev Internal function to ensure that the sentinel value for the
         reentrancy guard is not currently set and, if not, to set the
         sentinel value for the reentrancy guard.
    """
    # Ensure that the reentrancy guard is not already set.
    self._assertNonReentrant()

    # Set the reentrancy guard.
    self._reentrancyGuard = _ENTERED

@internal
def _clearReentrancyGuard() :
    """
    @dev Internal function to unset the reentrancy guard sentinel value.
    """

    # Clear the reentrancy guard.
    self._reentrancyGuard = _NOT_ENTERED
