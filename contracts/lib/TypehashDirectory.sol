// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

bytes32 constant twoSubstring = 0x5B325D0000000000000000000000000000000000000000000000000000000000;

uint256 constant MaxTreeHeight = 24;

function getMaxTreeBrackets(uint256 maxHeight) pure returns (bytes memory) {
    bytes memory suffixes = new bytes(3 * maxHeight);
    assembly {
        let ptr := add(suffixes, 0x20)
        let endPtr := add(ptr, mul(maxHeight, 3))
        for {

        } lt(ptr, endPtr) {
            ptr := add(ptr, 3)
        } {
            mstore(ptr, twoSubstring)
        }
    }
    return suffixes;
}

function getTreeSubTypes() pure returns (bytes memory) {
    // Construct the OfferItem type string.
    // prettier-ignore
    bytes memory offerItemTypeString = abi.encodePacked(
            "OfferItem(",
                "uint8 itemType,",
                "address token,",
                "uint256 identifierOrCriteria,",
                "uint256 startAmount,",
                "uint256 endAmount",
            ")"
        );

    // Construct the ConsiderationItem type string.
    // prettier-ignore
    bytes memory considerationItemTypeString = abi.encodePacked(
            "ConsiderationItem(",
                "uint8 itemType,",
                "address token,",
                "uint256 identifierOrCriteria,",
                "uint256 startAmount,",
                "uint256 endAmount,",
                "address recipient",
            ")"
        );

    // Construct the OrderComponents type string, not including the above.
    // prettier-ignore
    bytes memory orderComponentsPartialTypeString = abi.encodePacked(
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
                "uint256 counter",
            ")"
        );
    return
        abi.encodePacked(
            considerationItemTypeString,
            offerItemTypeString,
            orderComponentsPartialTypeString
        );
}

contract TypehashDirectory {
    constructor() {
        bytes32[] memory typeHashes = new bytes32[](MaxTreeHeight);
        bytes memory brackets = getMaxTreeBrackets(MaxTreeHeight);
        bytes memory subTypes = getTreeSubTypes();
        // Cache memory pointer before each loop so memory doesn't expand by the
        // full string size on each loop.
        uint256 freeMemoryPointer;
        assembly {
            freeMemoryPointer := mload(0x40)
        }

        for (uint256 i = 0; i < MaxTreeHeight; ) {
            uint256 height = i + 1;
            // Slice brackets length to size needed for `height`
            assembly {
                mstore(brackets, mul(3, height))
            }

            // Encode the type string for the BulkOrder struct.
            bytes memory bulkOrderTypeString = abi.encodePacked(
                "BulkOrder(OrderComponents",
                brackets,
                " tree)",
                subTypes
            );

            // Derive EIP712 type hash
            bytes32 typeHash = keccak256(bulkOrderTypeString);
            typeHashes[i] = typeHash;

            // Reset free pointer
            assembly {
                mstore(0x40, freeMemoryPointer)
            }

            unchecked {
                ++i;
            }
        }

        assembly {
            // Overwrite length with zero to give the contract a STOP prefix
            // and deploy the type hashes array as a contract.
            mstore(typeHashes, 0)
            return(add(typeHashes, 0x1f), add(mul(MaxTreeHeight, 0x20), 1))
        }
    }
}
