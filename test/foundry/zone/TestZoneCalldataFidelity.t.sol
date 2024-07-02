// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ConsiderationItemLib,
    OfferItemLib,
    OrderParametersLib
} from "seaport-sol/src/SeaportSol.sol";

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { HashCalldataTestZone } from "./impl/HashCalldataTestZone.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    ItemType,
    OfferItem,
    OrderParameters,
    ZoneParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { OrderType } from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

contract PreAndPostFulfillmentCheckTest is BaseOrderTest {
    using ConsiderationItemLib for ConsiderationItem[];
    using OfferItemLib for OfferItem[];
    using OrderParametersLib for OrderParameters;

    HashCalldataTestZone testZone = new HashCalldataTestZone();

    struct Context {
        ConsiderationInterface consideration;
        TestCase testCase;
    }

    struct TestCase {
        uint256 itemType;
        uint256 offerItemStartingIdentifier;
        uint256 considerationItemStartingIdentifier;
        uint256 startAmount;
        uint256 endAmount;
        bytes signature;
        bytes extraData;
        uint256 recipient;
        uint256 offerLength;
        uint256 considerationLength;
        uint256 orderType;
        uint256 startTime;
        uint256 endTime;
        uint256 zoneHash;
        uint256 salt;
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {
            fail();
        } catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function setUp() public override {
        super.setUp();
        conduitController.updateChannel(address(conduit), address(this), true);
        referenceConduitController.updateChannel(
            address(referenceConduit),
            address(this),
            true
        );
        vm.label(address(testZone), "TestZone");
    }

    function testCalldataEquivalence(TestCase memory testCase) public {
        test(
            this.execCalldataEquivalence,
            Context({ consideration: consideration, testCase: testCase })
        );
        test(
            this.execCalldataEquivalence,
            Context({
                consideration: referenceConsideration,
                testCase: testCase
            })
        );
    }

    function execCalldataEquivalence(Context memory context) public stateless {
        // Bound the test case.
        TestCase memory testCase = _boundTestCase(context.testCase);

        // Mint the necessary tokens.
        _mintNecessaryTokens(testCase);

        // Create the params for the advanced order.
        OrderParameters memory orderParameters = OrderParameters({
            offerer: address(this),
            zone: address(testZone),
            offer: new OfferItem[](testCase.offerLength),
            consideration: new ConsiderationItem[](
                testCase.considerationLength
            ),
            orderType: OrderType(testCase.orderType),
            startTime: testCase.startTime,
            endTime: testCase.endTime,
            zoneHash: bytes32(testCase.zoneHash),
            salt: testCase.salt,
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: testCase.considerationLength
        });

        // Populate the offer and consideration.
        for (uint256 i = 0; i < testCase.offerLength; i++) {
            orderParameters.offer[i] = OfferItem({
                itemType: ItemType(testCase.itemType),
                token: address(test721_1),
                identifierOrCriteria: testCase.offerItemStartingIdentifier + i,
                startAmount: testCase.startAmount,
                endAmount: testCase.endAmount
            });
        }

        for (uint256 i = 0; i < testCase.considerationLength; i++) {
            orderParameters.consideration[i] = ConsiderationItem({
                itemType: ItemType(testCase.itemType),
                token: address(test721_1),
                identifierOrCriteria: testCase
                    .considerationItemStartingIdentifier + i,
                startAmount: testCase.startAmount,
                endAmount: testCase.endAmount,
                recipient: payable(address(uint160(testCase.recipient)))
            });
        }

        // Create the advanced order.
        AdvancedOrder memory advancedOrder = AdvancedOrder({
            parameters: orderParameters,
            numerator: 1,
            denominator: 1,
            signature: new bytes(0),
            extraData: abi.encodePacked(bytes32(testCase.extraData))
        });

        // Generate the order hash.
        bytes32 orderHash = context.consideration.getOrderHash(
            advancedOrder.parameters.toOrderComponents(0)
        );

        // Create the expected zone parameters.
        ZoneParameters memory zoneParameters = ZoneParameters({
            orderHash: orderHash,
            fulfiller: address(this),
            offerer: address(this),
            offer: orderParameters.offer.toSpentItemArray(),
            consideration: orderParameters.consideration.toReceivedItemArray(),
            extraData: abi.encodePacked(bytes32(testCase.extraData)),
            orderHashes: new bytes32[](0),
            startTime: testCase.startTime,
            endTime: testCase.endTime,
            zoneHash: bytes32(testCase.zoneHash)
        });

        // Hash the zone parameters.
        bytes32 expectedZoneHash = bytes32(
            keccak256(abi.encode(zoneParameters))
        );

        // Send the expectation for authorize to the test zone.
        testZone.setExpectedAuthorizeCalldataHash(expectedZoneHash);

        // Add the order hash to the zone parameters.
        zoneParameters.orderHashes = new bytes32[](1);
        zoneParameters.orderHashes[0] = orderHash;

        // Hash the updated zone parameters.
        expectedZoneHash = bytes32(keccak256(abi.encode(zoneParameters)));

        // Send the expectation for validate to the test zone.
        testZone.setExpectedValidateCalldataHash(expectedZoneHash);

        // Fulfill the advanced order.
        context.consideration.fulfillAdvancedOrder({
            advancedOrder: advancedOrder,
            criteriaResolvers: new CriteriaResolver[](0),
            fulfillerConduitKey: bytes32(0),
            recipient: payable(address(uint160(testCase.recipient)))
        });
    }

    function _boundTestCase(
        TestCase memory _testCase
    ) internal view returns (TestCase memory) {
        TestCase memory testCase = _testCase;

        testCase.itemType = bound(testCase.itemType, 2, 2);
        testCase.offerItemStartingIdentifier = bound(
            testCase.offerItemStartingIdentifier,
            1,
            type(uint16).max
        );
        testCase.considerationItemStartingIdentifier = bound(
            testCase.considerationItemStartingIdentifier,
            type(uint32).max,
            type(uint64).max
        );
        testCase.startAmount = bound(testCase.startAmount, 1, 1);
        testCase.endAmount = bound(
            testCase.endAmount,
            1,
            testCase.itemType == 2 ? 1 : 1000
        );
        testCase.recipient = bound(testCase.recipient, 10, type(uint160).max);
        testCase.offerLength = bound(testCase.offerLength, 1, 30);
        testCase.considerationLength = bound(
            testCase.considerationLength,
            1,
            30
        );
        testCase.orderType = bound(testCase.orderType, 1, 3); // 0, 4);
        testCase.startTime = bound(testCase.startTime, 0, 1);
        testCase.endTime = bound(
            testCase.endTime,
            block.timestamp + 1,
            type(uint256).max
        );

        return testCase;
    }

    function _mintNecessaryTokens(TestCase memory testCase) internal {
        for (uint256 i = 0; i < testCase.offerLength; i++) {
            test721_1.mint(
                address(this),
                testCase.offerItemStartingIdentifier + i
            );
            test1155_1.mint(
                address(this),
                testCase.offerItemStartingIdentifier + i,
                testCase.endAmount
            );
        }
        for (uint256 i = 0; i < testCase.considerationLength; i++) {
            test721_1.mint(
                address(this),
                testCase.considerationItemStartingIdentifier + i
            );
            test1155_1.mint(
                address(this),
                testCase.considerationItemStartingIdentifier + i,
                testCase.endAmount
            );
        }
    }
}
