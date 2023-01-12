// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC20Interface } from
    "../../../../contracts/interfaces/AbridgedTokenInterfaces.sol";

import { ContractOffererInterface } from
    "../../../../contracts/interfaces/ContractOffererInterface.sol";

import {
    ItemType, Side
} from "../../../../contracts/lib/ConsiderationEnums.sol";

import {
    SpentItem,
    ReceivedItem
} from "../../../../contracts/lib/ConsiderationStructs.sol";

contract AdjustedAmountOfferer is ContractOffererInterface {
    int256 immutable offerAmountAdjust;
    int256 immutable considerationAmountAdjust;

    constructor(
        address[] memory seaports,
        ERC20Interface _token1,
        ERC20Interface _token2,
        int256 _offerAmountAdjust,
        int256 _considerationAmountAdjust
    ) {
        for (uint256 i = 0; i < seaports.length; ++i) {
            address seaport = seaports[i];
            _token1.approve(seaport, type(uint256).max);
            _token2.approve(seaport, type(uint256).max);
        }
        offerAmountAdjust = _offerAmountAdjust;
        considerationAmountAdjust = _considerationAmountAdjust;
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     * items,
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
        return (
            adjustAmounts(a, offerAmountAdjust),
            _convertSpentToReceived(adjustAmounts(b, considerationAmountAdjust))
        );
    }

    function adjustAmounts(
        SpentItem[] memory items,
        int256 amount
    ) internal pure returns (SpentItem[] memory) {
        SpentItem[] memory adjustedItems = new SpentItem[](items.length);
        for (uint256 i = 0; i < items.length; ++i) {
            adjustedItems[i] = items[i];
            adjustedItems[i].amount = uint256(int256(items[i].amount) + amount);
        }
        return adjustedItems;
    }

    function _convertSpentToReceived(SpentItem[] memory spentItems)
        internal
        view
        returns (ReceivedItem[] memory)
    {
        ReceivedItem[] memory receivedItems = new ReceivedItem[](
            spentItems.length
        );
        for (uint256 i = 0; i < spentItems.length; ++i) {
            receivedItems[i] = _convertSpentToReceived(spentItems[i]);
        }
        return receivedItems;
    }

    function _convertSpentToReceived(SpentItem memory spentItem)
        internal
        view
        returns (ReceivedItem memory)
    {
        return ReceivedItem({
            itemType: spentItem.itemType,
            token: spentItem.token,
            identifier: spentItem.identifier,
            amount: spentItem.amount,
            recipient: payable(address(this))
        });
    }

    function ratifyOrder(
        SpentItem[] calldata, /* offer */
        ReceivedItem[] calldata, /* consideration */
        bytes calldata, /* context */
        bytes32[] calldata, /* orderHashes */
        uint256 /* contractNonce */
    ) external pure override returns (bytes4 /* ratifyOrderMagicValue */ ) {
        return AdjustedAmountOfferer.ratifyOrder.selector;
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
