//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../interfaces/AbridgedTokenInterfaces.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem,
    ZoneParameters
} from "../lib/ConsiderationStructs.sol";

import { ItemType } from "../lib/ConsiderationEnums.sol";

import {
    ConsiderationInterface
} from "../interfaces/ConsiderationInterface.sol";

import {
    ContractOffererInterface
} from "../interfaces/ContractOffererInterface.sol";

contract HashCalldataContractOfferer is ContractOffererInterface {
    error NativeTokenTransferFailed();

    event GenerateOrderDataHash(bytes32 orderHash, bytes32 dataHash);
    event RatifyOrderDataHash(bytes32 orderHash, bytes32 dataHash);

    address private _SEAPORT;
    address internal _expectedOfferRecipient;

    mapping(bytes32 => bytes32) public orderHashToGenerateOrderDataHash;
    mapping(bytes32 => bytes32) public orderHashToRatifyOrderDataHash;

    receive() external payable {}

    constructor(address seaport) {
        _SEAPORT = seaport;
    }

    /**
     * @dev Generates an order with the specified minimum and maximum spent
     *      items. Validates data hash set in activate.
     */
    function generateOrder(
        address fulfiller,
        SpentItem[] calldata a,
        SpentItem[] calldata b,
        bytes calldata c
    )
        external
        virtual
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        {
            (bool success, ) = payable(_SEAPORT).call{
                value: _getOfferedNativeTokens(a)
            }("");

            if (!success) {
                revert NativeTokenTransferFailed();
            }

            // Create a variable to store msg.data in memory
            bytes memory data = new bytes(msg.data.length);

            // Copy msg.data to memory
            assembly {
                calldatacopy(add(data, 0x20), 0, calldatasize())
            }

            bytes32 calldataHash = keccak256(data);

            uint256 contractOffererNonce = ConsiderationInterface(_SEAPORT)
                .getContractOffererNonce(address(this));

            bytes32 orderHash = bytes32(
                contractOffererNonce ^ (uint256(uint160(address(this))) << 96)
            );

            // Store the hash of msg.data
            orderHashToGenerateOrderDataHash[orderHash] = calldataHash;

            emit GenerateOrderDataHash(orderHash, calldataHash);
        }

        return previewOrder(msg.sender, fulfiller, a, b, c);
    }

    /**
     * @dev View function to preview an order generated in response to a minimum
     *      set of received items, maximum set of spent items, and context
     *      (supplied as extraData).
     */
    function previewOrder(
        address caller,
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
        require(
            caller == _SEAPORT,
            "HashCalldataContractOfferer: caller not seaport"
        );
        return (a, _convertSpentToReceived(b));
    }

    /**
     * @dev Ratifies that the parties have received the correct items.
     */
    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */,
        bytes32[] calldata /* orderHashes */,
        uint256 contractNonce
    ) external override returns (bytes4 /* ratifyOrderMagicValue */) {
        require(
            msg.sender == _SEAPORT,
            "HashCalldataContractOfferer: ratify caller not seaport"
        );

        // Ratify the order.
        {
            // Create a variable to store msg.data in memory
            bytes memory data = new bytes(msg.data.length);

            // Copy msg.data to memory
            assembly {
                calldatacopy(add(data, 0x20), 0, calldatasize())
            }

            bytes32 calldataHash = keccak256(data);

            bytes32 orderHash = bytes32(
                contractNonce ^ (uint256(uint160(address(this))) << 96)
            );

            // Store the hash of msg.data
            orderHashToRatifyOrderDataHash[orderHash] = calldataHash;

            emit RatifyOrderDataHash(orderHash, calldataHash);
        }

        return this.ratifyOrder.selector;
    }

    /**
     * @dev Allows us to set Seaport address following deployment.
     *
     * @param seaportAddress The Seaport address.
     */
    function setSeaportAddress(address seaportAddress) external {
        _SEAPORT = seaportAddress;
    }

    function getSeaportMetadata()
        external
        pure
        override(ContractOffererInterface)
        returns (string memory name, Schema[] memory schemas)
    {
        // Return the metadata.
        name = "TestCalldataHashContractOfferer";
        schemas = new Schema[](1);
        schemas[0].id = 1337;
        schemas[0].metadata = new bytes(0);
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

    function _getOfferedNativeTokens(
        SpentItem[] calldata offer
    ) internal view returns (uint256 amount) {
        for (uint256 i = 0; i < offer.length; ++i) {
            SpentItem memory item = offer[i];
            if (item.itemType == ItemType.NATIVE) {
                amount += item.amount;
            }
        }
    }

    /**
     * @dev Enable accepting ERC1155 tokens via safeTransfer.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        assembly {
            mstore(0, 0xf23a6e61)
            return(0x1c, 0x04)
        }
    }

    function setExpectedOfferRecipient(address expectedOfferRecipient) public {
        _expectedOfferRecipient = expectedOfferRecipient;
    }
}
