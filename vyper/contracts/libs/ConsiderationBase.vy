# @version 0.3.3

from ..interfaces import ConduitControllerInterface

MAX_BYTE_LENGTH: constant(uint8) = 100

# Precompute hashes, original chainId, and domain separator on deployment.
_NAME_HASH: immutable(bytes32)
_VERSION_HASH: immutable(bytes32)
_EIP_712_DOMAIN_TYPEHASH: immutable(bytes32)
_OFFER_ITEM_TYPEHASH: immutable(bytes32)
_CONSIDERATION_ITEM_TYPEHASH: immutable(bytes32)
_ORDER_TYPEHASH:immutable(bytes32) 
_CHAIN_ID: immutable(uint256)
_DOMAIN_SEPARATOR: immutable(bytes32)

# Allow for interaction with the conduit controller.
_CONDUIT_CONTROLLER: immutable(ConduitControllerInterface)

# Cache the conduit creation code hash used by the conduit controller.
_CONDUIT_CREATION_CODE_HASH: immutable(bytes32)

@pure
@internal
def _name() -> (String[MAX_BYTE_LENGTH]):
    """
    @dev Internal pure function to retrieve the default name of this
         contract and return.
    
    @return The name of this contract.
    """
    raise "Not Implemented"

@pure
@internal
def _nameString() -> (String[MAX_BYTE_LENGTH]):
    """
    @dev Internal pure function to retrieve the default name of this contract
         as a string that can be used internally.
        
    @return The name of this contract.
    """
    # Return the name of the contract.
    return "Consideration"

@view
@internal
def _deriveTypehashes() -> (bytes32,bytes32,bytes32,bytes32,bytes32,bytes32):
    """
    @dev Internal pure function to derive required EIP-712 typehashes and
         other hashes during contract creation.
        
    @return nameHash                  The hash of the name of the contract.
    @return versionHash               The hash of the version string of the
                                      contract.
    @return eip712DomainTypehash      The primary EIP-712 domain typehash.
    @return offerItemTypehash         The EIP-712 typehash for OfferItem
                                      types.
    @return considerationItemTypehash The EIP-712 typehash for
                                      ConsiderationItem types.
    @return orderTypehash             The EIP-712 typehash for Order types.
    """
    # Derive hash of the name of the contract.
    nameHash: bytes32 = keccak256(convert(self._nameString(), Bytes))

    # Derive hash of the version string of the contract.
    versionHash: bytes32 = keccak256(convert("1", Bytes))

    # Construct the OfferItem type string.
    offerItemTypeString: Bytes[MAX_BYTE_LENGTH] = _abi_encode(
        concat(
            "OfferItem(",
                "uint8 itemType,",
                "address token,",
                "uint256 identifierOrCriteria,",
                "uint256 startAmount,",
                "uint256 endAmount",
            ")"
        )
    )

    # Construct the ConsiderationItem type string.
    considerationItemTypeString: Bytes[MAX_BYTE_LENGTH] = _abi_encode(
        concat(
            "ConsiderationItem(",
                "uint8 itemType,",
                "address token,",
                "uint256 identifierOrCriteria,",
                "uint256 startAmount,",
                "uint256 endAmount,",
                "address recipient",
            ")"
        )
    )

    # Construct the OrderComponents type string, not including the above.
    orderComponentsPartialTypeString: Bytes[MAX_BYTE_LENGTH] = _abi_encode(
        concat(
            "OrderComponents(",
                "address offerer,",
                "address zone,",
                "OfferItem[] offer,",
                "ConsiderationItem[] consideration,",
                "uint8 orderType,",
                "uint256 startTime,",
                "uint256 endTime,",
                "bytes32 zoneHash,",
                "uint256 salt,",
                "bytes32 conduitKey,",
                "uint256 nonce",
            ")"
        )
    )

    # Construct the primary EIP-712 domain type string.
    eip712DomainTypehash: bytes32 = keccak256(
        _abi_encode(
            concat(
                "EIP712Domain(",
                    "string name,",
                    "string version,",
                    "uint256 chainId,",
                    "address verifyingContract",
                ")"
            )
        )
    )

    # Derive the OfferItem type hash using the corresponding type string.
    offerItemTypehash: bytes32 = keccak256(offerItemTypeString)

    # Derive ConsiderationItem type hash using corresponding type string.
    considerationItemTypehash: bytes32 = keccak256(considerationItemTypeString)

    # Derive OrderItem type hash via combination of relevant type strings.
    orderTypehash: bytes32 = keccak256(
        concat(
            orderComponentsPartialTypeString,
            considerationItemTypeString,
            offerItemTypeString
        )
    )

    return (
        nameHash,
        versionHash,
        eip712DomainTypehash,
        offerItemTypehash,
        considerationItemTypehash,
        orderTypehash
    )


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
            block.chainid,
            address(this)
        )
    )

@external
def __init__():
    """
    @dev Derive and set hashes, reference chainId, and associated domain
         separator during deployment.
        
    @param conduitController A contract that deploys conduits, or proxies
                             that may optionally be used to transfer approved
                             ERC20/721/1155 tokens.
    """
    # Derive name and version hashes alongside required EIP-712 typehashes.
    (
        _NAME_HASH,
        _VERSION_HASH,
        _EIP_712_DOMAIN_TYPEHASH,
        _OFFER_ITEM_TYPEHASH,
        _CONSIDERATION_ITEM_TYPEHASH,
        _ORDER_TYPEHASH
    ) = self._deriveTypehashes()

    # Store the current chainId and derive the current domain separator.
    _CHAIN_ID = block.chainid
    _DOMAIN_SEPARATOR = self._deriveDomainSeparator()

    # Set the supplied conduit controller.
    _CONDUIT_CONTROLLER = ConduitControllerInterface(conduitController)

    # Retrieve the conduit creation code hash from the supplied controller.
    (_CONDUIT_CREATION_CODE_HASH, ) = (
        _CONDUIT_CONTROLLER.getConduitCodeHashes()
    )