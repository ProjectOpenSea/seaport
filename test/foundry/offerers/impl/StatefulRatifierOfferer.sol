// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../../../../contracts/interfaces/AbridgedTokenInterfaces.sol";

import {
    ContractOffererInterface
} from "../../../../contracts/interfaces/ContractOffererInterface.sol";

import { ItemType } from "../../../../contracts/lib/ConsiderationEnums.sol";

import {
    SpentItem,
    ReceivedItem
} from "../../../../contracts/lib/ConsiderationStructs.sol";

interface ERC20Mintable {
    function mint(address to, uint256 amount) external;
}

contract StatefulRatifierOfferer is ContractOffererInterface {
    ERC20Interface token1;
    ERC721Interface token2;
    uint256 value;
    bool public called;
    uint256 numToReturn;

    constructor(
        address seaport,
        ERC20Interface _token1,
        ERC721Interface _token2,
        uint256 _numToReturn
    ) {
        numToReturn = _numToReturn;
        _token1.approve(seaport, type(uint256).max);
        token1 = _token1;
        token2 = _token2;
        ERC20Mintable(address(_token1)).mint(address(this), 100000);
    }

    function generateOrder(
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata,
        bytes calldata
    )
        external
        virtual
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        value = minimumReceived[0].amount;
        offer = new SpentItem[](numToReturn);
        for (uint256 i; i < numToReturn; i++) {
            offer[i] = SpentItem({
                itemType: ItemType.ERC20,
                token: address(token1),
                identifier: 0,
                amount: value + i
            });
        }

        consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: address(token2),
            identifier: 42,
            amount: 1,
            recipient: payable(address(this))
        });
        return (offer, consideration);
    }

    function previewOrder(
        address,
        address,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata,
        bytes calldata
    )
        external
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        offer = new SpentItem[](1);
        offer[0] = SpentItem({
            itemType: ItemType.ERC20,
            token: address(token1),
            identifier: 0,
            amount: minimumReceived[0].amount + 1
        });
        consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: address(token2),
            identifier: 42,
            amount: 1,
            recipient: payable(address(this))
        });
        return (offer, consideration);
    }

    error IncorrectValue(uint256 actual, uint256 expected);
    error IncorrectToken(address actual, address expected);
    error IncorrectItemType(ItemType actual, ItemType expected);

    function ratifyOrder(
        SpentItem[] calldata minimumReceived, /* offer */
        ReceivedItem[] calldata maximumSpent, /* consideration */
        bytes calldata, /* context */
        bytes32[] calldata, /* orderHashes */
        uint256 /* contractNonce */
    )
        external
        override
        returns (
            bytes4 /* ratifyOrderMagicValue */
        )
    {
        for (uint256 i = 0; i < minimumReceived.length; i++) {
            if (minimumReceived[i].itemType != ItemType.ERC20) {
                revert IncorrectItemType(
                    minimumReceived[i].itemType,
                    ItemType.ERC20
                );
            }
            if (minimumReceived[i].token != address(token1)) {
                revert IncorrectToken(
                    minimumReceived[i].token,
                    address(token1)
                );
            }

            if (minimumReceived[i].amount != value + i) {
                revert IncorrectValue(minimumReceived[i].amount, value + i);
            }
        }
        for (uint256 i; i < maximumSpent.length; i++) {
            if (maximumSpent[i].itemType != ItemType.ERC721) {
                revert IncorrectItemType(
                    maximumSpent[i].itemType,
                    ItemType.ERC721
                );
            }
            if (maximumSpent[i].token != address(token2)) {
                revert IncorrectToken(maximumSpent[i].token, address(token2));
            }
            if (maximumSpent[i].identifier != 42) {
                revert IncorrectValue(maximumSpent[i].identifier, 42);
            }
        }
        called = true;
        return ContractOffererInterface.ratifyOrder.selector;
    }

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
        return (1337, "TestContractOfferer", "");
    }
}
