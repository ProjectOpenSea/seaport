//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ERC20Interface,
    ERC721Interface,
    ERC1155Interface
} from "../interfaces/AbridgedTokenInterfaces.sol";

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
    error InvalidNativeTokenBalance(
        uint256 expectedBalance,
        uint256 actualBalance,
        address checkedAddress
    );
    error InvalidERC20Balance(
        uint256 expectedBalance,
        uint256 actualBalance,
        address checkedAddress,
        address checkedToken
    );
    error InvalidERC1155Balance(
        uint256 expectedBalance,
        uint256 actualBalance,
        address checkedAddress,
        address checkedToken
    );
    // 0x38fb386a
    error InvalidOwner(
        address expectedOwner,
        address actualOwner,
        address checkedToken,
        uint256 checkedTokenId
    );
    error IncorrectSeaportBalance(
        uint256 expectedBalance,
        uint256 actualBalance
    );
    error InvalidDataHash(bytes32 expectedDataHash, bytes32 actualDataHash);
    error InvalidEthBalance(uint256 expectedBalance, uint256 actualBalance);
    error NativeTokenTransferFailed();

    event GenerateOrderDataHash(bytes32 orderHash, bytes32 dataHash);
    event RatifyOrderDataHash(bytes32 orderHash, bytes32 dataHash);

    address private immutable _SEAPORT;
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
        {
            (bool success, ) = payable(_SEAPORT).call{
                value: address(this).balance
            }("");

            if (!success) {
                revert NativeTokenTransferFailed();
            }

            // Get the length of msg.data
            uint256 dataLength = msg.data.length;

            // Create a variable to store msg.data in memory
            bytes memory data;

            // Copy msg.data to memory
            assembly {
                let ptr := mload(0x40)
                calldatacopy(add(ptr, 0x20), 0, dataLength)
                mstore(ptr, dataLength)
                data := ptr
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
        return (a, _convertSpentToReceived(b));
    }

    /**
     * @dev Ratifies that the parties have received the correct items.
     *
     * @param minimumReceived The minimum items that the caller was willing to
     *                        receive.
     * @param maximumSpent    The maximum items that the caller was willing to
     *                        spend.
     * @param context         The context of the order.
     * @ param orderHashes     The order hashes, unused here.
     * @ param contractNonce   The contract nonce, unused here.
     *
     * @return ratifyOrderMagicValue The magic value to indicate things are OK.
     */
    function ratifyOrder(
        SpentItem[] calldata minimumReceived /* offer */,
        ReceivedItem[] calldata maximumSpent /* consideration */,
        bytes calldata context /* context */,
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external override returns (bytes4 /* ratifyOrderMagicValue */) {
        // Ratify the order.
        {
            // Get the length of msg.data
            uint256 dataLength = msg.data.length;

            // Create a variable to store msg.data in memory
            bytes memory data;

            // Copy msg.data to memory
            assembly {
                let ptr := mload(0x40)
                calldatacopy(add(ptr, 0x20), 0, dataLength)
                mstore(ptr, dataLength)
                data := ptr
            }

            bytes32 calldataHash = keccak256(data);

            uint256 contractOffererNonce = ConsiderationInterface(_SEAPORT)
                .getContractOffererNonce(address(this));

            bytes32 orderHash = bytes32(
                contractOffererNonce ^ (uint256(uint160(address(this))) << 96)
            );

            // Store the hash of msg.data
            orderHashToRatifyOrderDataHash[orderHash] = calldataHash;

            emit RatifyOrderDataHash(orderHash, calldataHash);
        }

        return this.ratifyOrder.selector;
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

    function setExpectedOfferRecipient(address expectedOfferRecipient) public {
        _expectedOfferRecipient = expectedOfferRecipient;
    }
}
