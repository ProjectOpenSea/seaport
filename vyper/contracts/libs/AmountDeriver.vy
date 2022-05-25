# @version 0.3.3

"""
@dev  A struct containing the data used to apply a
      fraction to an order.
"""
struct FractionData:
    numerator: uint256  # The portion of the order that should be filled.
    denominator: uint256  # The total size of the order
    offererConduitKey: bytes32  # The offerer's conduit key.
    fulfillerConduitKey: bytes32  # The fulfiller's conduit key.
    duration: uint256  # The total duration of the order.
    elapsed: uint256  # The time elapsed since the order's start time.
    remaining: uint256  # The time left until the order's end time.

@internal
@pure
def _locateCurrentAmount(
    startAmount: uint256,
    endAmount: uint256,
    elapsed: uint256,
    remaining: uint256,
    duration: uint256,
    roundUp: bool
) -> uint256:
    """
    @dev Internal pure function to derive the current amount of a given item
        based on the current price, the starting price, and the ending
        price. If the start and end prices differ, the current price will be
        extrapolated on a linear basis.

    @param startAmount The starting amount of the item.
    @param endAmount   The ending amount of the item.
    @param elapsed     The time elapsed since the order's start time.
    @param remaining   The time left until the order's end time.
    @param duration    The total duration of the order.
    @param roundUp     A boolean indicating whether the resultant amount
                       should be rounded up or down.

    @return The current amount.
    """
    # Only modify end amount if it doesn't already equal start amount.
    if startAmount != endAmount:
        # Leave extra amount to add for rounding at zero (i.e. round down).
        extraCeiling: uint256 = 0

        # If rounding up, set rounding factor to one less than denominator.
        if roundUp:
            extraCeiling = duration - 1

        # Aggregate new amounts weighted by time with rounding factor.
        totalBeforeDivision: uint256 = ((startAmount * remaining) +
            (endAmount * elapsed) +
            extraCeiling)

        # Division is performed without zero check as it cannot be zero.
        newAmount: uint256 = totalBeforeDivision / duration

        # Return the current amount (expressed as endAmount internally).
        return newAmount

    # Return the original amount (now expressed as endAmount internally).
    return endAmount

@internal
@pure
def _getFraction(
    numerator: uint256,
    denominator: uint256,
    val: uint256
) -> uint256:
    """
    @dev Internal pure function to return a fraction of a given value and to
         ensure the resultant value does not have any fractional component.

    @param numerator   A value indicating the portion of the order that
                       should be filled.
    @param denominator A value indicating the total size of the order.
    @param val       The value for which to compute the fraction.

    @return newValue The value after applying the fraction.
    """
    # Return value early in cases where the fraction resolves to 1.
    if numerator == denominator:
        return val

    # Multiply the numerator by the value and ensure no overflow occurs.
    valueTimesNumerator: uint256 = val * numerator

    # Divide that value by the denominator to get the new value.
    newValue: uint256 = valueTimesNumerator / denominator

    # Ensure that division gave a final result with no remainder.
    assert ((newValue * denominator) / numerator) == val, "inexact fraction"

    return newValue

@internal
@view # Change to @pure once https://github.com/vyperlang/vyper/issues/2870 is fixed.
def _applyFraction(
    startAmount: uint256,
    endAmount: uint256,
    fractionData: FractionData,
    roundUp: bool
)  -> uint256: # amount
    """
    @dev Internal pure function to apply a fraction to a consideration
    or offer item.

    @param startAmount     The starting amount of the item.
    @param endAmount       The ending amount of the item.
    @param fractionData    A struct containing the data used to apply a
                           fraction to an order.
    @return amount The received item to transfer with the final amount.
    """
    amount: uint256 = 0

    # If start amount equals end amount, apply fraction to end amount.
    if startAmount == endAmount:
        amount = self._getFraction(
            fractionData.numerator,
            fractionData.denominator,
            endAmount
        )
    else:
        # Otherwise, apply fraction to both to extrapolate final amount.
        amount = self._locateCurrentAmount(
            self._getFraction(
                fractionData.numerator,
                fractionData.denominator,
                startAmount
            ),
            self._getFraction(
                fractionData.numerator,
                fractionData.denominator,
                endAmount
            ),
            fractionData.elapsed,
            fractionData.remaining,
            fractionData.duration,
            roundUp
        )

    return amount