// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../../../../contracts/interfaces/AbridgedTokenInterfaces.sol";

import {
    ContractOffererInterface
} from "../../../../contracts/interfaces/ContractOffererInterface.sol";

import {
    ItemType,
    Side
} from "../../../../contracts/lib/ConsiderationEnums.sol";

import {
    SpentItem,
    ReceivedItem
} from "../../../../contracts/lib/ConsiderationStructs.sol";

contract PassthroughOfferer is ContractOffererInterface {
    constructor(
        address[] memory seaports,
        ERC20Interface _token1,
        ERC721Interface _token2
    ) {
        for (uint256 i = 0; i < seaports.length; ++i) {
            address seaport = seaports[i];
            _token1.approve(seaport, type(uint256).max);
            _token2.setApprovalForAll(seaport, true);
        }
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent items,
     */
    function generateOrder(
        address,
        SpentItem[] calldata a,
        SpentItem[] calldata b,
        bytes calldata c
    )
        external
        virtual
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        return previewOrder(address(this), address(this), a, b, c);
    }

    /**
     * @dev Generates an order in response to a minimum received set of items.
     */
    function previewOrder(
        address,
        address,
        SpentItem[] calldata a,
        SpentItem[] calldata b,
        bytes calldata
    )
        public
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        return (a, _convertSpentToReceived(b));
    }

    function _convertSpentToReceived(
        SpentItem[] calldata spentItems
    ) internal view returns (ReceivedItem[] memory) {
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            spentItems.length
        );
        for (uint256 i = 0; i < spentItems.length; ++i) {
            receivedItems[i] = _convertSpentToReceived(spentItems[i]);
        }
        return receivedItems;
    }

    function _convertSpentToReceived(
        SpentItem calldata spentItem
    ) internal view returns (ReceivedItem memory) {
        return
            ReceivedItem({
                itemType: spentItem.itemType,
                token: spentItem.token,
                identifier: spentItem.identifier,
                amount: spentItem.amount,
                recipient: payable(address(this))
            });
    }

    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */,
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external pure override returns (bytes4 /* ratifyOrderMagicValue */) {
        return PassthroughOfferer.ratifyOrder.selector;
    }

    /**
     * @dev Returns the metadata for this contract offerer.
     */
    function getMetadata()
        external
        pure
        override
        returns (
            uint256 schemaID, // maps to a Seaport standard's ID
            string memory name,
            bytes memory metadata // decoded based on the schemaID
        )
    {
        return (1337, "PassthroughOffererfb", "");
    }
}
