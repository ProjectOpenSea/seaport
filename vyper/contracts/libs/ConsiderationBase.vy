# @version 0.3.4

# pragma once

CONSIDERATION_LENGTH: constant(uint8) = 13

# Precompute hashes, original chainId, and domain separator on deployment.
_NAME_HASH: constant(bytes32) = keccak256("Consideration")
_VERSION_HASH: constant(bytes32) = keccak256("1.1")

_EIP_712_DOMAIN_TYPEHASH: constant(bytes32) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
_OFFER_ITEM_TYPEHASH: constant(bytes32) = keccak256("OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)")
_CONSIDERATION_ITEM_TYPEHASH: constant(bytes32) = keccak256("ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)")
_ORDER_TYPEHASH: constant(bytes32) = keccak256("OrderComponents(address offerer,address zone,OfferItem[] offer,ConsiderationItem[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,bytes32 zoneHash,uint256 salt,bytes32 conduitKey,uint256 counter)ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)")

_CHAIN_ID: immutable(uint256)
_DOMAIN_SEPARATOR: immutable(bytes32)

# Allow for interaction with the conduit controller.
_CONDUIT_CONTROLLER: immutable(address)

# Cache the conduit creation code hash used by the conduit controller.
# TODO: calculate
_CONDUIT_CREATION_CODE_HASH: constant(bytes32) = 0x0000000000000000000000000000000000000000000000000000000000000000

@pure
@internal
def _name() -> (String[CONSIDERATION_LENGTH]):
    """
    @dev Internal pure function to retrieve the default name of this
         contract and return.
    
    @return The name of this contract.
    """
    return "Consideration"

@pure
@internal
def _nameString() -> (String[CONSIDERATION_LENGTH]):
    """
    @dev Internal pure function to retrieve the default name of this contract
         as a string that can be used internally.
        
    @return The name of this contract.
    """
    return "Consideration"

@view
@internal
def _deriveDomainSeparator() -> (bytes32):
    """
    @dev Internal view function to derive the EIP-712 domain separator.
        
    @return The derived domain separator.
    """

    return keccak256(
        _abi_encode(
            _EIP_712_DOMAIN_TYPEHASH,
            _NAME_HASH,
            _VERSION_HASH,
            chain.id,
            self
        )
    )

@internal
def consideration_base__init__(conduitController: address):
    """
    @dev Derive and set hashes, reference chainId, and associated domain
         separator during deployment.
        
    @param conduitController A contract that deploys conduits, or proxies
                             that may optionally be used to transfer approved
                             ERC20/721/1155 tokens.
    """

    # Store the current chainId and derive the current domain separator.
    # The following assignments are delegated to the __init__ for Consideration.vy
    # _CHAIN_ID = chain.id
    # _DOMAIN_SEPARATOR = self._deriveDomainSeparator()

    # # Set the supplied conduit controller.
    # _CONDUIT_CONTROLLER = conduitController