# @version 0.3.4

#pragma once
#include "GettersAndDrivers.vy"

# TODO: include the top (grand)children

@external
def __init__(conduitController: address):
    # self.consideration_base__init__(conduitController)

    # The following has been hoisted up from ConsiderationBase.vy, Since
    # Vyper only allows 1 __init__ function per contract and cannot delegate
    # assignment for immutable variables to other internal functions. This also
    # stems from lack of inheritance structure for Vyper. Our current strategy of
    # simulating inheritance is by preprocessing/concatenating parent contracts to
    # the children.
    _CHAIN_ID = chain.id
    _DOMAIN_SEPARATOR = self._deriveDomainSeparator()


    _CONDUIT_CONTROLLER = conduitController