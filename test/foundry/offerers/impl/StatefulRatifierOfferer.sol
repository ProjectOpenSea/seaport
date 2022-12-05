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

    constructor(
        address seaport,
        ERC20Interface _token1,
        ERC721Interface _token2
    ) {
        _token1.approve(seaport, type(uint256).max);
        token1 = _token1;
        token2 = _token2;
        ERC20Mintable(address(_token1)).mint(address(this), 100);
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
        offer = new SpentItem[](1);
        offer[0] = SpentItem({
            itemType: ItemType.ERC20,
            token: address(token1),
            identifier: 0,
            amount: value + 1
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

    function ratifyOrder(
        SpentItem[] calldata minimumReceived, /* offer */
        ReceivedItem[] calldata, /* consideration */
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
        if (minimumReceived[0].amount != value + 1) {
            revert IncorrectValue(minimumReceived[0].amount, value + 1);
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
