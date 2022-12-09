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

    /**
    * @dev Generates an order with the specified minimum and maximum spent items,
    * and the optional extra data.
    *
    * @param -               Fulfiller, unused here.
    * @param minimumReceived The minimum items that the caller is willing to
    *                        receive.
    * @param -               maximumSent, unused here.
    * @param -               context, unused here.
    *
    * @return offer         A tuple containing the offer items.
    * @return consideration A tuple containing the consideration items.
    */
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
        // Generate an offer of ERC20 items.
        value = minimumReceived[0].amount;
        offer = new SpentItem[](numToReturn);
        for (uint256 i; i < numToReturn; i++) {
            // Create a new ERC20 item with a unique value.
            offer[i] = SpentItem({
                itemType: ItemType.ERC20,
                token: address(token1),
                identifier: 0,
                amount: value + i
            });
        }

        // Generate a consideration of a single ERC721 item.
        consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: address(token2),
            identifier: 42,
            amount: 1,
            recipient: payable(address(this))
        });

        // Return the offer and consideration.
        return (offer, consideration);
    }

    /**
    * @dev Generates an order in response to a minimum received set of items.
    *
    * @param -               caller, unused here.
    * @param -               fulfiller, unused here.
    * @param minimumReceived The minimum received set.
    * @param -               maximumSpent, unused here.
    * @param -               context, unused here.
    *
    * @return offer         The offer for the order.
    * @return consideration The consideration for the order.
    */
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
        // Set the value of the items to be spent.
        uint256 _value = minimumReceived[0].amount;

        // Create an offer array and populate it with ERC20 items.
        offer = new SpentItem[](numToReturn);
        for (uint256 i; i < numToReturn; i++) {
            offer[i] = SpentItem({
                itemType: ItemType.ERC20,
                token: address(token1),
                identifier: 0,
                amount: _value + i
            });
        }

        // Create a consideration array with a single ERC721 item.
        consideration = new ReceivedItem[](1);
        consideration[0] = ReceivedItem({
            itemType: ItemType.ERC721,
            token: address(token2),
            identifier: 42,
            amount: 1,
            recipient: payable(address(this))
        });

        // Return the offer and consideration.
        return (offer, consideration);
    }


    error IncorrectValue(uint256 actual, uint256 expected);
    error IncorrectToken(address actual, address expected);
    error IncorrectItemType(ItemType actual, ItemType expected);
    error IncorrectContext(bytes context);
    error IncorrectOrderHashesLength(uint256 actual, uint256 expected);

    function ratifyOrder(
        SpentItem[] calldata minimumReceived /* offer */,
        ReceivedItem[] calldata maximumSpent /* consideration */,
        bytes calldata context /* context */,
        bytes32[] calldata orderHashes /* orderHashes */,
        uint256 /* contractNonce */
    ) external override returns (bytes4 /* ratifyOrderMagicValue */) {
        // Check that all minimumReceived items are of type ERC20.
        for (uint256 i = 0; i < minimumReceived.length; i++) {
            if (minimumReceived[i].itemType != ItemType.ERC20) {
                revert IncorrectItemType(
                    minimumReceived[i].itemType,
                    ItemType.ERC20
                );
            }

            // Check that the token address for each minimumReceived item is
            // correct.
            if (minimumReceived[i].token != address(token1)) {
                revert IncorrectToken(
                    minimumReceived[i].token,
                    address(token1)
                );
            }

            // Check that the value of each minimumReceived item is correct.
            if (minimumReceived[i].amount != value + i) {
                revert IncorrectValue(minimumReceived[i].amount, value + i);
            }
        }

        // Check that all maximumSpent items are of type ERC721, that the
        // address is correct, and that the token ID is correct.
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

        // Check that the context is correct.
        if (keccak256(context) != keccak256("context")) {
            revert IncorrectContext(context);
        }

        // Check that the orderHashes length is correct.
        if (orderHashes.length < 1) {
            revert IncorrectOrderHashesLength(orderHashes.length, 1);
        }

        // Set the public called bool to true.
        called = true;

        // Return the ratifyOrderMagicValue.
        return ContractOffererInterface.ratifyOrder.selector;
    }

    /** @dev Returns the metadata for this contract offerer.
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
        return (1337, "TestContractOfferer", "");
    }
}
