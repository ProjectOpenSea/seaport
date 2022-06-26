# @version 0.3.4

#pragma once

#include "ConsiderationStructs.vy"
#include "ConsiderationBase.vy"

@view
@internal
def _deriveOrderHash(orderParameters: OrderParameters, counter: uint256) -> bytes32:
    """
    @dev Internal view function to derive the order hash for a given order.
         Note that only the original consideration items are included in the
         order hash, as additional consideration items may be supplied by the
         caller.
        
    @param orderParameters The parameters of the order to hash.
    @param counter           The counter of the order to hash.
        
    @return orderHash The hash.
    """
    # Calculate Offer Hash
    offerHashArr: uint8[32 * MAX_DYN_ARRAY_LENGTH] = empty(uint8[32 * MAX_DYN_ARRAY_LENGTH])

    i: uint256 = 0
    for offerItem in orderParameters.offer:
        tempHash: uint256 = convert(
            keccak256(
                concat(
                    _OFFER_ITEM_TYPEHASH,
                    convert(offerItem.itemType, bytes32),
                    convert(offerItem.token, bytes32),
                    convert(offerItem.identifierOrCriteria, bytes32),
                    convert(offerItem.startAmount, bytes32),
                    convert(offerItem.endAmount, bytes32)
                )
            ), 
            uint256
        )

        for j in range(32):
            offerHashArr[i + j] = shift(tempHash, -31 + j) & 255

        i += 32
    

    offerHash: bytes32 = keccak256(
        convert(
            offerHashArr, 
            Bytes[32 * MAX_DYN_ARRAY_LENGTH]
        )
    )

    # Calculate Consideration Hash
    considerationHashArr: uint8[32 * MAX_DYN_ARRAY_LENGTH] = empty(uint8[32 * MAX_DYN_ARRAY_LENGTH])

    i = 0
    for considerationItem in orderParameters.consideration:
        tempHash: uint256 = convert(
            keccak256(
                    concat(
                    _CONSIDERATION_ITEM_TYPEHASH,
                    convert(considerationItem.itemType, bytes32),
                    convert(considerationItem.token, bytes32),
                    convert(considerationItem.identifierOrCriteria, bytes32),
                    convert(considerationItem.startAmount, bytes32),
                    convert(considerationItem.endAmount, bytes32),
                    convert(considerationItem.recipient, bytes32)
                )
            ), 
            uint256
        )

        for j in range(32):
            considerationHashArr[i + j] = shift(tempHash, -31 + j) & 255

        i += 32

    considerationHash: bytes32 = keccak256(
        convert(
            considerationHashArr, 
            Bytes[32 * MAX_DYN_ARRAY_LENGTH]
        )
    )

    return keccak256(
        concat(
            _ORDER_TYPEHASH,
            convert(orderParameters.offerer, bytes32),
            convert(orderParameters.zone, bytes32),
            offerHash,
            considerationHash,
            convert(orderParameters.orderType, bytes32),
            convert(orderParameters.startTime, bytes32),
            convert(orderParameters.endTime, bytes32),
            orderParameters.zoneHash,
            convert(orderParameters.salt, bytes32),
            orderParameters.conduitKey,
            convert(counter, bytes32)
        )
    )


@view
@internal
def _deriveConduit(conduitKey: bytes32) -> address:
    """
    @dev Internal view function to derive the address of a given conduit
         using a corresponding conduit key.
        
    @param conduitKey A bytes32 value indicating what corresponding conduit,
                      if any, to source token approvals from. This value is
                      the "salt" parameter supplied by the deployer (i.e. the
                      conduit controller) when deploying the given conduit.
        
    @return conduit The address of the conduit associated with the given
                    conduit key.
    """
    return convert(
        keccak256(
            concat(
                0xff, 
                convert(_CONDUIT_CONTROLLER, bytes20), 
                _CONDUIT_CREATION_CODE_HASH
            )
        ), address
    )

@view
@internal
def _domainSeparator() -> bytes32:
    """
    @dev Internal view function to get the EIP-712 domain separator. If the
         chainId matches the chainId set on deployment, the cached domain
         separator will be returned; otherwise, it will be derived from
         scratch.
        
    @return The domain separator.
    """
    if(chain.id == _CHAIN_ID):
        return _DOMAIN_SEPARATOR

    return self._deriveDomainSeparator()

@view
@internal
def _information() -> (String[3], bytes32, address):
    """
    @dev Internal view function to retrieve configuration information for
         this contract.
        
    @return version           The contract version.
    @return domainSeparator   The domain separator for this contract.
    @return conduitController The conduit Controller set for this contract.
    """
    return (
        "1.1",
        self._domainSeparator(),
        _CONDUIT_CONTROLLER
    )

@pure
@internal
def _deriveEIP712Digest(domainSeparator: bytes32, orderHash: bytes32) -> bytes32:
    """
    @dev Internal pure function to efficiently derive an digest to sign for
         an order in accordance with EIP-712.
        
    @param domainSeparator The domain separator.
    @param orderHash       The order hash.
        
    @return value The hash.
    """
    return keccak256(_abi_encode(0x1901, domainSeparator, orderHash))