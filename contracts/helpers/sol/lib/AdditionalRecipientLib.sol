// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AdditionalRecipient } from "../../../lib/ConsiderationStructs.sol";
import { StructCopier } from "./StructCopier.sol";

library AdditionalRecipientLib {
    bytes32 private constant ADDITIONAL_RECIPIENT_MAP_POSITION =
        keccak256("seaport.AdditionalRecipientDefaults");
    bytes32 private constant ADDITIONAL_RECIPIENTS_MAP_POSITION =
        keccak256("seaport.AdditionalRecipientsDefaults");

    /**
     * @notice clears a default AdditionalRecipient from storage
     * @param defaultName the name of the default to clear
     */
    function clear(string memory defaultName) internal {
        mapping(string => AdditionalRecipient)
            storage additionalRecipientMap = _additionalRecipientMap();
        AdditionalRecipient storage item = additionalRecipientMap[defaultName];
        clear(item);
    }

    function clear(AdditionalRecipient storage item) internal {
        // clear all fields
        item.amount = 0;
        item.recipient = payable(address(0));
    }

    function clear(AdditionalRecipient[] storage item) internal {
        while (item.length > 0) {
            clear(item[item.length - 1]);
            item.pop();
        }
    }

    /**
     * @notice gets a default AdditionalRecipient from storage
     * @param defaultName the name of the default for retrieval
     */
    function fromDefault(
        string memory defaultName
    ) internal view returns (AdditionalRecipient memory item) {
        mapping(string => AdditionalRecipient)
            storage additionalRecipientMap = _additionalRecipientMap();
        item = additionalRecipientMap[defaultName];
    }

    function fromDefaultMany(
        string memory defaultName
    ) internal view returns (AdditionalRecipient[] memory items) {
        mapping(string => AdditionalRecipient[])
            storage additionalRecipientsMap = _additionalRecipientsMap();
        items = additionalRecipientsMap[defaultName];
    }

    /**
     * @notice saves an AdditionalRecipient as a named default
     * @param additionalRecipient the AdditionalRecipient to save as a default
     * @param defaultName the name of the default for retrieval
     */
    function saveDefault(
        AdditionalRecipient memory additionalRecipient,
        string memory defaultName
    ) internal returns (AdditionalRecipient memory _additionalRecipient) {
        mapping(string => AdditionalRecipient)
            storage additionalRecipientMap = _additionalRecipientMap();
        additionalRecipientMap[defaultName] = additionalRecipient;
        return additionalRecipient;
    }

    function saveDefaultMany(
        AdditionalRecipient[] memory additionalRecipients,
        string memory defaultName
    ) internal returns (AdditionalRecipient[] memory _additionalRecipients) {
        mapping(string => AdditionalRecipient[])
            storage additionalRecipientsMap = _additionalRecipientsMap();
        StructCopier.setAdditionalRecipients(
            additionalRecipientsMap[defaultName],
            additionalRecipients
        );
        return additionalRecipients;
    }

    /**
     * @notice makes a copy of an AdditionalRecipient in-memory
     * @param item the AdditionalRecipient to make a copy of in-memory
     */
    function copy(
        AdditionalRecipient memory item
    ) internal pure returns (AdditionalRecipient memory) {
        return
            AdditionalRecipient({
                amount: item.amount,
                recipient: item.recipient
            });
    }

    function copy(
        AdditionalRecipient[] memory items
    ) internal pure returns (AdditionalRecipient[] memory) {
        AdditionalRecipient[] memory copiedItems = new AdditionalRecipient[](
            items.length
        );
        for (uint256 i = 0; i < items.length; i++) {
            copiedItems[i] = copy(items[i]);
        }
        return copiedItems;
    }

    function empty() internal pure returns (AdditionalRecipient memory) {
        return
            AdditionalRecipient({ amount: 0, recipient: payable(address(0)) });
    }

    /**
     * @notice gets the storage position of the default AdditionalRecipient map
     */
    function _additionalRecipientMap()
        private
        pure
        returns (
            mapping(string => AdditionalRecipient)
                storage additionalRecipientMap
        )
    {
        bytes32 position = ADDITIONAL_RECIPIENT_MAP_POSITION;
        assembly {
            additionalRecipientMap.slot := position
        }
    }

    function _additionalRecipientsMap()
        private
        pure
        returns (
            mapping(string => AdditionalRecipient[])
                storage additionalRecipientsMap
        )
    {
        bytes32 position = ADDITIONAL_RECIPIENTS_MAP_POSITION;
        assembly {
            additionalRecipientsMap.slot := position
        }
    }

    // methods for configuring a single of each of an AdditionalRecipient's fields, which modifies the
    // AdditionalRecipient in-place and
    // returns it

    function withAmount(
        AdditionalRecipient memory item,
        uint256 amount
    ) internal pure returns (AdditionalRecipient memory) {
        item.amount = amount;
        return item;
    }

    function withRecipient(
        AdditionalRecipient memory item,
        address recipient
    ) internal pure returns (AdditionalRecipient memory) {
        item.recipient = payable(recipient);
        return item;
    }
}
