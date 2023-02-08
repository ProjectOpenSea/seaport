// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ERC20Interface
} from "../../../../contracts/interfaces/AbridgedTokenInterfaces.sol";

import {
    ContractOffererInterface
} from "../../../../contracts/interfaces/ContractOffererInterface.sol";

import { ERC165 } from "../../../../contracts/interfaces/ERC165.sol";

import {
    SpentItem,
    ReceivedItem,
    Schema
} from "../../../../contracts/lib/ConsiderationStructs.sol";

contract AdjustedAmountOfferer is ContractOffererInterface, ERC165 {
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
     * @dev View function to preview an order generated in response to a minimum
     *      set of received items, maximum set of spent items, and context
     *      (supplied as extraData).
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

    function _convertSpentToReceived(
        SpentItem[] memory spentItems
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
        SpentItem memory spentItem
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
        return AdjustedAmountOfferer.ratifyOrder.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC165, ContractOffererInterface)
        returns (bool)
    {
        return
            interfaceId == type(ContractOffererInterface).interfaceId ||
            super.supportsInterface(interfaceId);
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

        return ("AdjustedAmountOfferer", schemas);
    }
}
