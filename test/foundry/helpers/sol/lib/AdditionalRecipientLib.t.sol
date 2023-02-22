// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    AdditionalRecipientLib
} from "../../../../../contracts/helpers/sol/lib/AdditionalRecipientLib.sol";
import {
    AdditionalRecipient
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../../../../contracts/lib/ConsiderationEnums.sol";

contract AdditionalRecipientLibTest is BaseTest {
    using AdditionalRecipientLib for AdditionalRecipient;

    function testRetrieveDefault(
        uint256 amount,
        address payable recipient
    ) public {
        AdditionalRecipient memory additionalRecipient = AdditionalRecipient({
            amount: amount,
            recipient: recipient
        });
        AdditionalRecipientLib.saveDefault(additionalRecipient, "default");
        AdditionalRecipient
            memory defaultAdditionalRecipient = AdditionalRecipientLib
                .fromDefault("default");
        assertEq(additionalRecipient, defaultAdditionalRecipient);
    }

    function testComposeEmpty(
        uint256 amount,
        address payable recipient
    ) public {
        AdditionalRecipient memory additionalRecipient = AdditionalRecipientLib
            .empty()
            .withAmount(amount)
            .withRecipient(recipient);
        assertEq(
            additionalRecipient,
            AdditionalRecipient({ amount: amount, recipient: recipient })
        );
    }

    function testCopy() public {
        AdditionalRecipient memory additionalRecipient = AdditionalRecipient({
            amount: 1,
            recipient: payable(address(1))
        });
        AdditionalRecipient memory copy = additionalRecipient.copy();
        assertEq(additionalRecipient, copy);
        additionalRecipient.amount = 2;
        assertEq(copy.amount, 1);
    }

    function testRetrieveDefaultMany(
        uint256[3] memory amount,
        address payable[3] memory recipient
    ) public {
        AdditionalRecipient[]
            memory additionalRecipients = new AdditionalRecipient[](3);
        for (uint256 i = 0; i < 3; i++) {
            additionalRecipients[i] = AdditionalRecipient({
                amount: amount[i],
                recipient: recipient[i]
            });
        }
        AdditionalRecipientLib.saveDefaultMany(additionalRecipients, "default");
        AdditionalRecipient[]
            memory defaultAdditionalRecipients = AdditionalRecipientLib
                .fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(additionalRecipients[i], defaultAdditionalRecipients[i]);
        }
    }
}
