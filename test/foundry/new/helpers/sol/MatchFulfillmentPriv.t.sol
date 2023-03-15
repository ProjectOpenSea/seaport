// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import "seaport-sol/SeaportSol.sol";
import {
    MatchFulfillmentLib,
    ProcessComponentParams
} from "seaport-sol/fulfillments/match/MatchFulfillmentLib.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {
    MatchComponent,
    MatchComponentType
} from "seaport-sol/lib/types/MatchComponentType.sol";
import { LibSort } from "solady/src/utils/LibSort.sol";

contract MatchFulfillmentLibTest is Test {
    using Strings for uint256;
    using OrderParametersLib for OrderParameters;
    using OfferItemLib for OfferItem;
    using ConsiderationItemLib for ConsiderationItem;

    address A;
    address B;
    address C;
    address D;
    address E;
    address F;
    address G;

    function setUp() public virtual {
        A = makeAddr("A");
        B = makeAddr("B");
        C = makeAddr("C");
        D = makeAddr("D");
        E = makeAddr("E");
        F = makeAddr("F");
        G = makeAddr("G");
    }

    function testExtend() public {
        Fulfillment[] memory fulfillments = new Fulfillment[](0);
        Fulfillment memory fulfillment = Fulfillment({
            offerComponents: new FulfillmentComponent[](0),
            considerationComponents: new FulfillmentComponent[](0)
        });
        fulfillments = MatchFulfillmentLib.extend(fulfillments, fulfillment);
        assertEq(fulfillments.length, 1, "extend length");
        assertEq(fulfillments[0], fulfillment, "extend fulfillment");

        fulfillment = Fulfillment({
            offerComponents: SeaportArrays.FulfillmentComponents(
                FulfillmentComponent({ orderIndex: 1, itemIndex: 1 })
                ),
            considerationComponents: SeaportArrays.FulfillmentComponents(
                FulfillmentComponent({ orderIndex: 1, itemIndex: 1 })
                )
        });
        fulfillments = MatchFulfillmentLib.extend(fulfillments, fulfillment);
        assertEq(fulfillments.length, 2, "extend length");
        assertEq(fulfillments[1], fulfillment, "extend fulfillment");
    }

    function testTruncateArray(
        FulfillmentComponent[10] memory components,
        uint8 endLength
    ) public {
        endLength = uint8(bound(endLength, 0, 10));
        FulfillmentComponent[] memory copied = new FulfillmentComponent[](
            endLength
        );
        for (uint256 i = 0; i < endLength; i++) {
            copied[i] = components[i];
        }
        FulfillmentComponent[] memory truncated =
            MatchFulfillmentLib.truncateArray(copied, endLength);
        assertEq(truncated.length, endLength, "truncateArray length");
        for (uint256 i = 0; i < endLength; i++) {
            assertEq(truncated[i], components[i], "truncateArray component");
        }
    }

    MatchComponent[] _components;

    // function testPopIndex(MatchComponent[10] memory components, uint256 index)
    //     public
    // {
    //     index = bound(index, 0, 9);
    //     for (uint256 i = 0; i < 10; i++) {
    //         _components.push(components[i]);
    //     }
    //     MatchFulfillmentLib.popIndex(_components, index);
    //     assertEq(_components.length, 9, "popIndex length");
    //     for (uint256 i = 0; i < 9; i++) {
    //         if (i == index) {
    //             assertEq(_components[i], components[9]);
    //         } else {
    //             assertEq(_components[i], components[i]);
    //         }
    //     }
    // }

    using MatchComponentType for MatchComponent[];

    function testCleanUpZeroedComponents(uint240[10] memory amounts) public {
        // copy to dynamic array
        MatchComponent[] memory toBeSorted = new MatchComponent[](10);
        for (uint256 i = 0; i < 10; i++) {
            MatchComponent temp =
                MatchComponentType.createMatchComponent(amounts[i], 0, 0);
            toBeSorted[i] = temp;
        }
        // sort dynamic array in-place
        LibSort.sort(toBeSorted.toUints());
        // copy to storage
        for (uint256 i = 0; i < 10; i++) {
            _components.push(toBeSorted[i]);
        }
        // call function
        MatchFulfillmentLib.cleanUpZeroedComponents(_components);
        for (uint256 i; i < _components.length; ++i) {
            assertGt(_components[i].getAmount(), 0, "cleanUpZeroedComponents");
        }
    }

    MatchComponent[] offer;
    MatchComponent[] consideration;

    function testProcessOfferComponent() public {
        FulfillmentComponent[] memory offerFulfillmentComponents =
            MatchFulfillmentLib.allocateAndShrink(2);

        offer.push(MatchComponentType.createMatchComponent(1, 0, 0));
        consideration.push(MatchComponentType.createMatchComponent(1, 0, 0));
        ProcessComponentParams memory params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: new FulfillmentComponent[](0),
            offerItemIndex: 0,
            considerationItemIndex: 0
        });
        MatchFulfillmentLib.processOfferComponent(offer, consideration, params);
        assertEq(
            params.offerItemIndex, 1, "processOfferComponent offerItemIndex"
        );
        assertEq(
            offer[0].getAmount(),
            0,
            "processOfferComponent offer[0].getAmount()"
        );
        assertEq(
            consideration[0].getAmount(),
            0,
            "processOfferComponent consideration[0].getAmount()"
        );
        assertEq(
            params.offerFulfillmentComponents.length,
            1,
            "offerFulfillmentComponents length"
        );

        offerFulfillmentComponents = MatchFulfillmentLib.allocateAndShrink(2);
        consideration[0] = MatchComponentType.createMatchComponent(2, 0, 0);
        offer[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: new FulfillmentComponent[](0),
            offerItemIndex: 0,
            considerationItemIndex: 0
        });
        MatchFulfillmentLib.processOfferComponent(offer, consideration, params);
        assertEq(
            params.offerItemIndex, 1, "processOfferComponent offerItemIndex"
        );
        assertEq(
            offer[0].getAmount(),
            0,
            "processOfferComponent offer[0].getAmount()"
        );
        assertEq(
            consideration[0].getAmount(),
            1,
            "processOfferComponent consideration[0].getAmount()"
        );
        assertEq(
            params.offerFulfillmentComponents.length,
            1,
            "offerFulfillmentComponents length"
        );

        offerFulfillmentComponents = MatchFulfillmentLib.allocateAndShrink(2);
        consideration[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        offer[0] = MatchComponentType.createMatchComponent(2, 0, 0);
        params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: new FulfillmentComponent[](0),
            offerItemIndex: 0,
            considerationItemIndex: 0
        });
        MatchFulfillmentLib.processOfferComponent(offer, consideration, params);
        assertEq(
            params.offerItemIndex, 0, "processOfferComponent offerItemIndex"
        );
        assertEq(
            params.offerFulfillmentComponents.length,
            1,
            "offerFulfillmentComponents length"
        );
        assertEq(
            offer[0].getAmount(),
            1,
            "processOfferComponent offer[0].getAmount()"
        );
        assertEq(
            consideration[0].getAmount(),
            0,
            "processOfferComponent consideration[0].getAmount()"
        );
        assertEq(params.offerFulfillmentComponents.length, 1);

        offerFulfillmentComponents = MatchFulfillmentLib.allocateAndShrink(2);

        consideration[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        offer[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: new FulfillmentComponent[](0),
            offerItemIndex: 0,
            considerationItemIndex: 0
        });
        MatchFulfillmentLib.processOfferComponent(offer, consideration, params);
        assertEq(
            consideration[0].getAmount(), 0, "consideration[0].getAmount()"
        );
        assertEq(offer[0].getAmount(), 0, "offer[0].getAmount()");
        assertEq(
            params.offerItemIndex, 1, "processOfferComponent offerItemIndex"
        );
        assertEq(params.offerFulfillmentComponents.length, 1);
    }

    function testProcessConsiderationComponents() public {
        FulfillmentComponent[] memory offerFulfillmentComponents =
            MatchFulfillmentLib.allocateAndShrink(2);
        FulfillmentComponent[] memory considerationFulfillmentComponents =
            MatchFulfillmentLib.allocateAndShrink(2);
        offer.push(MatchComponentType.createMatchComponent(1, 0, 0));
        consideration.push(MatchComponentType.createMatchComponent(1, 0, 0));
        ProcessComponentParams memory params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: considerationFulfillmentComponents,
            offerItemIndex: 0,
            considerationItemIndex: 0
        });
        MatchFulfillmentLib.processConsiderationComponent(
            offer, consideration, params
        );
        assertEq(
            params.offerItemIndex,
            1,
            "processConsiderationComponent offerItemIndex"
        );

        assertEq(
            offer[0].getAmount(),
            0,
            "processConsiderationComponent offer[0].getAmount()"
        );
        assertEq(
            consideration[0].getAmount(),
            0,
            "processConsiderationComponent consideration[0].getAmount()"
        );

        consideration[0] = MatchComponentType.createMatchComponent(2, 0, 0);
        offer[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: considerationFulfillmentComponents,
            offerItemIndex: 0,
            considerationItemIndex: 0
        });
        MatchFulfillmentLib.processConsiderationComponent(
            offer, consideration, params
        );
        assertEq(
            params.offerItemIndex,
            1,
            "processConsiderationComponent offerItemIndex"
        );

        assertEq(
            offer[0].getAmount(),
            0,
            "processConsiderationComponent offer[0].getAmount()"
        );
        assertEq(
            consideration[0].getAmount(),
            1,
            "processConsiderationComponent consideration[0].getAmount()"
        );

        consideration[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        offer[0] = MatchComponentType.createMatchComponent(2, 0, 0);
        params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: considerationFulfillmentComponents,
            offerItemIndex: 0,
            considerationItemIndex: 0
        });
        MatchFulfillmentLib.processConsiderationComponent(
            offer, consideration, params
        );
        assertEq(
            params.offerItemIndex,
            0,
            "processConsiderationComponent offerItemIndex"
        );

        assertEq(
            offer[0].getAmount(),
            1,
            "processConsiderationComponent offer[0].getAmount()"
        );
        assertEq(
            consideration[0].getAmount(),
            0,
            "processConsiderationComponent consideration[0].getAmount()"
        );

        consideration[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        offer[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: considerationFulfillmentComponents,
            offerItemIndex: 0,
            considerationItemIndex: 0
        });
        // offerFulfillmentIndex: 1,
        // considerationFulfillmentIndex: 0

        MatchFulfillmentLib.processConsiderationComponent(
            offer, consideration, params
        );
        assertEq(
            params.offerItemIndex,
            1,
            "processConsiderationComponent offerItemIndex"
        );
    }

    function clear(MatchComponent[] storage components) internal {
        while (components.length > 0) {
            components.pop();
        }
    }

    function assertEq(MatchComponent left, MatchComponent right) internal {
        FulfillmentComponent memory leftComponent =
            left.toFulfillmentComponent();
        FulfillmentComponent memory rightComponent =
            right.toFulfillmentComponent();
        assertEq(leftComponent, rightComponent, "component");

        assertEq(left.getAmount(), right.getAmount(), "componentType");
    }

    event LogFulfillmentComponent(FulfillmentComponent);
    event LogFulfillment(Fulfillment);

    function assertEq(
        Fulfillment memory left,
        Fulfillment memory right,
        string memory message
    ) internal {
        emit LogFulfillment(left);
        emit LogFulfillment(right);
        emit Spacer();
        assertEq(
            left.offerComponents,
            right.offerComponents,
            string.concat(message, " offerComponents")
        );
        assertEq(
            left.considerationComponents,
            right.considerationComponents,
            string.concat(message, " considerationComponents")
        );
    }

    function assertEq(
        FulfillmentComponent[] memory left,
        FulfillmentComponent[] memory right,
        string memory message
    ) internal {
        assertEq(left.length, right.length, string.concat(message, " length"));

        for (uint256 i = 0; i < left.length; i++) {
            assertEq(
                left[i],
                right[i],
                string.concat(message, " index ", i.toString())
            );
        }
    }

    event Spacer();

    function assertEq(
        FulfillmentComponent memory left,
        FulfillmentComponent memory right,
        string memory message
    ) internal {
        emit LogFulfillmentComponent(left);
        emit LogFulfillmentComponent(right);
        emit Spacer();
        assertEq(
            left.orderIndex,
            right.orderIndex,
            string.concat(message, " orderIndex")
        );
        assertEq(
            left.itemIndex,
            right.itemIndex,
            string.concat(message, " itemIndex")
        );
    }
}
