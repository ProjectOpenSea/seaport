// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ERC20Interface,
    ERC721Interface
} from "../../../../contracts/interfaces/AbridgedTokenInterfaces.sol";

import {
    ContractOffererInterface
} from "../../../../contracts/interfaces/ContractOffererInterface.sol";

import { ItemType } from "../../../../contracts/lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem
} from "../../../../contracts/lib/ConsiderationStructs.sol";

interface ERC20Mintable {
    function mint(address to, uint256 amount) external;
}

contract BadOfferer is ContractOffererInterface {
    error IntentionalRevert();

    ERC20Interface token1;
    ERC721Interface token2;

    enum Path {
        RETURN_GARBAGE,
        NORMAL,
        RETURN_NOTHING,
        REVERT
    }

    constructor(
        address seaport,
        ERC20Interface _token1,
        ERC721Interface _token2
    ) {
        _token1.approve(seaport, type(uint256).max);
        token1 = _token1;
        token2 = _token2;
        ERC20Mintable(address(_token1)).mint(address(this), 100000);
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items.
     */
    function generateOrder(
        address a,
        SpentItem[] calldata b,
        SpentItem[] calldata c,
        bytes calldata d
    )
        external
        virtual
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        return previewOrder(a, a, b, c, d);
    }

    /**
     * @dev View function to preview an order generated in response to a minimum
     *      set of received items, maximum set of spent items, and context
     *      (supplied as extraData).
     */
    function previewOrder(
        address,
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata maximumSpent,
        bytes calldata
    )
        public
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        Path path = Path(
            maximumSpent[0].identifier > 3 ? 0 : maximumSpent[0].identifier
        );
        if (path == Path.NORMAL) {
            offer = minimumReceived;
            consideration = new ReceivedItem[](1);
            consideration[0] = ReceivedItem({
                itemType: ItemType.ERC721,
                token: address(token2),
                identifier: 1,
                amount: 1,
                recipient: payable(address(this))
            });
            return (offer, consideration);
        } else if (path == Path.RETURN_NOTHING) {
            // return nothing
            assembly {
                return(0, 0)
            }
        } else if (path == Path.REVERT) {
            revert IntentionalRevert();
        } else {
            // return garbage
            bytes32 h1 = keccak256(abi.encode(minimumReceived));
            bytes32 h2 = keccak256(abi.encode(maximumSpent));
            assembly {
                mstore(0x00, h1)
                mstore(0x20, h2)
                return(0, 0x100)
            }
        }
    }

    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */,
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external pure override returns (bytes4 /* ratifyOrderMagicValue */) {
        return BadOfferer.ratifyOrder.selector;
    }

    /**
     * @dev Returns the metadata for this contract offerer.
     */
    function getSeaportMetadata()
        external
        pure
        override
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        )
    {
        schemas = new Schema[](1);
        schemas[0].id = 1337;
        schemas[0].metadata = new bytes(0);

        return ("BadOfferer", schemas);
    }
}
