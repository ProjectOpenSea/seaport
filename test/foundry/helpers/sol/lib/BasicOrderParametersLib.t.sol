// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseTest } from "../BaseTest.sol";
import {
    BasicOrderParametersLib
} from "../../../../../contracts/helpers/sol/lib/BasicOrderParametersLib.sol";
import {
    AdditionalRecipientLib
} from "../../../../../contracts/helpers/sol/lib/AdditionalRecipientLib.sol";
import {
    BasicOrderParameters,
    OrderParameters,
    AdditionalRecipient
} from "../../../../../contracts/lib/ConsiderationStructs.sol";
import {
    ItemType,
    BasicOrderType
} from "../../../../../contracts/lib/ConsiderationEnums.sol";
import {
    OrderParametersLib
} from "../../../../../contracts/helpers/sol/lib/OrderParametersLib.sol";
import {
    SeaportArrays
} from "../../../../../contracts/helpers/sol/lib/SeaportArrays.sol";

contract BasicOrderParametersLibTest is BaseTest {
    using BasicOrderParametersLib for BasicOrderParameters;
    using OrderParametersLib for OrderParameters;

    struct Blob {
        address considerationToken; // 0x24
        uint256 considerationIdentifier; // 0x44
        uint256 considerationAmount; // 0x64
        address payable offerer; // 0x84
        address zone; // 0xa4
        address offerToken; // 0xc4
        uint256 offerIdentifier; // 0xe4
        uint256 offerAmount; // 0x104
        uint8 basicOrderType;
        uint256 startTime; // 0x144
        uint256 endTime; // 0x164
        bytes32 zoneHash; // 0x184
        uint256 salt; // 0x1a4
        bytes32 offererConduitKey; // 0x1c4
        bytes32 fulfillerConduitKey; // 0x1e4
        uint256 totalOriginalAdditionalRecipients; // 0x204
        AdditionalRecipient[] additionalRecipients; // 0x224
        bytes signature;
    }

    function testRetrieveDefault(Blob memory blob) public {
        // assign everything from blob
        BasicOrderParameters
            memory basicOrderParameters = BasicOrderParametersLib.empty();
        basicOrderParameters = basicOrderParameters.withConsiderationToken(
            blob.considerationToken
        );
        basicOrderParameters = basicOrderParameters.withConsiderationIdentifier(
            blob.considerationIdentifier
        );
        basicOrderParameters = basicOrderParameters.withConsiderationAmount(
            blob.considerationAmount
        );
        basicOrderParameters = basicOrderParameters.withOfferer(blob.offerer);
        basicOrderParameters = basicOrderParameters.withZone(blob.zone);
        basicOrderParameters = basicOrderParameters.withOfferToken(
            blob.offerToken
        );
        basicOrderParameters = basicOrderParameters.withOfferIdentifier(
            blob.offerIdentifier
        );
        basicOrderParameters = basicOrderParameters.withOfferAmount(
            blob.offerAmount
        );
        basicOrderParameters = basicOrderParameters.withBasicOrderType(
            BasicOrderType(bound(blob.basicOrderType, 0, 23))
        );
        basicOrderParameters = basicOrderParameters.withStartTime(
            blob.startTime
        );
        basicOrderParameters = basicOrderParameters.withEndTime(blob.endTime);
        basicOrderParameters = basicOrderParameters.withZoneHash(blob.zoneHash);
        basicOrderParameters = basicOrderParameters.withSalt(blob.salt);
        basicOrderParameters = basicOrderParameters.withOffererConduitKey(
            blob.offererConduitKey
        );
        basicOrderParameters = basicOrderParameters.withFulfillerConduitKey(
            blob.fulfillerConduitKey
        );
        basicOrderParameters = basicOrderParameters
            .withTotalOriginalAdditionalRecipients(
                blob.totalOriginalAdditionalRecipients
            );
        basicOrderParameters = basicOrderParameters.withAdditionalRecipients(
            blob.additionalRecipients
        );
        basicOrderParameters = basicOrderParameters.withSignature(
            blob.signature
        );

        BasicOrderParametersLib.saveDefault(basicOrderParameters, "default");
        BasicOrderParameters
            memory defaultBasicOrderParameters = BasicOrderParametersLib
                .fromDefault("default");
        assertEq(basicOrderParameters, defaultBasicOrderParameters);
    }

    function testCopy() public {
        AdditionalRecipient[] memory additionalRecipients = SeaportArrays
            .AdditionalRecipients(
                AdditionalRecipient({
                    amount: 1,
                    recipient: payable(address(1234))
                })
            );
        BasicOrderParameters
            memory basicOrderParameters = BasicOrderParametersLib
                .empty()
                .withConsiderationToken(address(1))
                .withConsiderationIdentifier(2)
                .withConsiderationAmount(3)
                .withOfferer(address(4))
                .withZone(address(5))
                .withOfferToken(address(6))
                .withOfferIdentifier(7)
                .withOfferAmount(8)
                .withBasicOrderType(BasicOrderType(9))
                .withStartTime(10)
                .withEndTime(11)
                .withZoneHash(bytes32(uint256(12)))
                .withSalt(13)
                .withOffererConduitKey(bytes32(uint256(14)))
                .withFulfillerConduitKey(bytes32(uint256(15)))
                .withTotalOriginalAdditionalRecipients(16)
                .withAdditionalRecipients(additionalRecipients)
                .withSignature(new bytes(0));
        BasicOrderParameters memory copy = basicOrderParameters.copy();
        assertEq(basicOrderParameters, copy);
        basicOrderParameters.considerationIdentifier = 123;
        assertEq(copy.considerationIdentifier, 2, "copy changed");

        additionalRecipients[0].recipient = payable(address(456));

        assertEq(
            copy.additionalRecipients[0].recipient,
            address(1234),
            "copy recipient changed"
        );
    }

    function testRetrieveDefaultMany(
        uint256[3] memory considerationidentifier,
        uint256[3] memory considerationAmount,
        address payable[3] memory recipient
    ) public {
        BasicOrderParameters[]
            memory basicOrderParameterss = new BasicOrderParameters[](3);
        for (uint256 i = 0; i < 3; i++) {
            AdditionalRecipient[] memory additionalRecipients = SeaportArrays
                .AdditionalRecipients(
                    AdditionalRecipient({
                        amount: 1,
                        recipient: payable(address(recipient[i]))
                    })
                );

            basicOrderParameterss[i] = BasicOrderParametersLib
                .empty()
                .withConsiderationIdentifier(considerationidentifier[i])
                .withConsiderationAmount(considerationAmount[i])
                .withAdditionalRecipients(additionalRecipients);
        }
        BasicOrderParametersLib.saveDefaultMany(
            basicOrderParameterss,
            "default"
        );
        BasicOrderParameters[]
            memory defaultBasicOrderParameterss = BasicOrderParametersLib
                .fromDefaultMany("default");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(basicOrderParameterss[i], defaultBasicOrderParameterss[i]);
        }
    }

    function assertEq(
        BasicOrderParameters memory a,
        BasicOrderParameters memory b
    ) internal {
        /**
         * do all these
         *  // calldata offset
         * address considerationToken; // 0x24
         * uint256 considerationIdentifier; // 0x44
         * uint256 considerationAmount; // 0x64
         * address payable offerer; // 0x84
         * address zone; // 0xa4
         * address offerToken; // 0xc4
         * uint256 offerIdentifier; // 0xe4
         * uint256 offerAmount; // 0x104
         * BasicOrderType basicOrderType; // 0x124
         * uint256 startTime; // 0x144
         * uint256 endTime; // 0x164
         * bytes32 zoneHash; // 0x184
         * uint256 salt; // 0x1a4
         * bytes32 offererConduitKey; // 0x1c4
         * bytes32 fulfillerConduitKey; // 0x1e4
         * uint256 totalOriginalAdditionalRecipients; // 0x204
         * AdditionalRecipient[] additionalRecipients; // 0x224
         * bytes signature; // 0x244
         */
        assertEq(
            a.considerationToken,
            b.considerationToken,
            "considerationToken"
        );
        assertEq(
            a.considerationIdentifier,
            b.considerationIdentifier,
            "considerationIdentifier"
        );
        assertEq(
            a.considerationAmount,
            b.considerationAmount,
            "considerationAmount"
        );
        assertEq(a.offerer, b.offerer, "offerer");
        assertEq(a.zone, b.zone, "zone");
        assertEq(a.offerToken, b.offerToken, "offerToken");
        assertEq(a.offerIdentifier, b.offerIdentifier, "offerIdentifier");
        assertEq(a.offerAmount, b.offerAmount, "offerAmount");
        assertEq(
            uint8(a.basicOrderType),
            uint8(b.basicOrderType),
            "basicOrderType"
        );
        assertEq(a.startTime, b.startTime, "startTime");
        assertEq(a.endTime, b.endTime, "endTime");
        assertEq(a.zoneHash, b.zoneHash, "zoneHash");
        assertEq(a.salt, b.salt, "salt");
        assertEq(a.offererConduitKey, b.offererConduitKey, "offererConduitKey");
        assertEq(
            a.fulfillerConduitKey,
            b.fulfillerConduitKey,
            "fulfillerConduitKey"
        );
        assertEq(
            a.totalOriginalAdditionalRecipients,
            b.totalOriginalAdditionalRecipients,
            "totalOriginalAdditionalRecipients"
        );
        assertEq(a.additionalRecipients, b.additionalRecipients);
        assertEq(a.signature, b.signature, "signature");
    }
}
