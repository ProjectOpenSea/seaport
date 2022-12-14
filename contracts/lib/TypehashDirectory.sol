// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract TypehashDirectory {
    constructor() {
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

        bytes32 twoSubstring = 0x5B325D0000000000000000000000000000000000000000000000000000000000;

        bytes32[] memory bulkOrderTypehashes = new bytes32[](256);

        for (uint256 i = 0; i < 256; ++i) {
            uint256 totalTwos = i + 1;
            string memory twosSubstring = new string(totalTwos * 3);

            uint256 tail = (totalTwos + 1) * 3;
            for (uint256 j = 1; j < tail; j += 3) {
                assembly {
                    mstore(add(twosSubstring, j), twoSubstring)
                }
            }

            // Encode the type string for the BulkOrder struct.
            bytes memory bulkOrderPartialTypeString = abi.encodePacked(
                "BulkOrder(OrderComponents",
                twosSubstring,
                " tree)"
            );

            // Generate the keccak256 hash of the concatenated type strings for
            // the BulkOrder, considerationItem, offerItem, and orderComponents.
            bulkOrderTypehashes[i] = keccak256(
                abi.encodePacked(
                    bulkOrderPartialTypeString,
                    considerationItemTypeString,
                    offerItemTypeString,
                    orderComponentsPartialTypeString
                )
            );
        }

        assembly {
            return(add(bulkOrderTypehashes, 64), 8192)
        }
    }
}
