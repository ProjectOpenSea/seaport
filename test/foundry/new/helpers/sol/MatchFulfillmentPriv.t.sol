// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Test } from "forge-std/Test.sol";

import { LibSort } from "solady/src/utils/LibSort.sol";

import {
    ConsiderationItemLib,
    OfferItemLib,
    OrderParametersLib
} from "seaport-sol/src/SeaportSol.sol";

import {
    MatchFulfillmentLib,
    ProcessComponentParams
} from "seaport-sol/src/fulfillments/match/MatchFulfillmentLib.sol";

import {
    MatchComponent,
    MatchComponentType
} from "seaport-sol/src/lib/types/MatchComponentType.sol";

import { MatchArrays } from "seaport-sol/src/fulfillments/lib/MatchArrays.sol";

import {
    ConsiderationItem,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    OrderParameters
} from "seaport-sol/src/SeaportStructs.sol";

contract MatchFulfillmentLibTest is Test {
    using ConsiderationItemLib for ConsiderationItem;
    using MatchComponentType for MatchComponent;
    using OfferItemLib for OfferItem;
    using OrderParametersLib for OrderParameters;
    using Strings for uint256;

    MatchComponent[] _components;
    MatchComponent[] consideration;
    MatchComponent[] offer;

    using MatchComponentType for MatchComponent[];

    function testConsolidateComponents(uint240[10] memory amounts) public {
        // copy to dynamic array
        MatchComponent[] memory toBeSorted = new MatchComponent[](10);
        for (uint256 i = 0; i < 10; i++) {
            MatchComponent memory temp = MatchComponentType
                .createMatchComponent(amounts[i], 0, 0);
            toBeSorted[i] = temp;
        }
        // sort dynamic array in-place
        MatchArrays.sortByAmount(toBeSorted);
        // copy to storage
        for (uint256 i = 0; i < 10; i++) {
            _components.push(toBeSorted[i]);
        }
        // call function
        MatchFulfillmentLib.consolidateComponents(
            _components,
            _components.length
        );
        assertLt(_components.length, 2, "consolidateComponents length");
        for (uint256 i; i < _components.length; ++i) {
            assertGt(_components[i].getAmount(), 0, "consolidateComponents");
        }
    }

    function testProcessOfferComponent() public {
        FulfillmentComponent[] memory offerFulfillmentComponents = MatchArrays
            .allocateFulfillmentComponents(2);

        offer.push(MatchComponentType.createMatchComponent(1, 0, 0));
        consideration.push(MatchComponentType.createMatchComponent(1, 0, 0));
        ProcessComponentParams memory params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: new FulfillmentComponent[](0),
            offerItemIndex: 0,
            considerationItemIndex: 0,
            midCredit: false
        });
        MatchFulfillmentLib.processOfferComponent(offer, consideration, params);
        assertEq(
            params.offerItemIndex,
            1,
            "processOfferComponent offerItemIndex"
        );
        assertEq(
            offer[0].getAmount(),
            0,
            "processOfferComponent offer[0].getAmount()"
        );
        assertEq(
            consideration[0].getAmount(),
            0,
            "processOfferComponent consideration[0].getAmount() 1"
        );
        assertEq(
            params.offerFulfillmentComponents.length,
            1,
            "offerFulfillmentComponents length"
        );

        offerFulfillmentComponents = MatchArrays.allocateFulfillmentComponents(
            2
        );
        consideration[0] = MatchComponentType.createMatchComponent(2, 0, 0);
        offer[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: new FulfillmentComponent[](0),
            offerItemIndex: 0,
            considerationItemIndex: 0,
            midCredit: false
        });
        MatchFulfillmentLib.processOfferComponent(offer, consideration, params);
        assertEq(
            params.offerItemIndex,
            1,
            "processOfferComponent offerItemIndex"
        );
        assertEq(
            offer[0].getAmount(),
            0,
            "processOfferComponent offer[0].getAmount()"
        );
        assertEq(
            consideration[0].getAmount(),
            1,
            "processOfferComponent consideration[0].getAmount() 2"
        );
        assertEq(
            params.offerFulfillmentComponents.length,
            1,
            "offerFulfillmentComponents length"
        );

        offerFulfillmentComponents = MatchArrays.allocateFulfillmentComponents(
            2
        );
        consideration[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        offer[0] = MatchComponentType.createMatchComponent(2, 0, 0);
        params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: new FulfillmentComponent[](0),
            offerItemIndex: 0,
            considerationItemIndex: 0,
            midCredit: false
        });
        MatchFulfillmentLib.processOfferComponent(offer, consideration, params);
        assertEq(
            params.offerItemIndex,
            0,
            "processOfferComponent offerItemIndex"
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
            "processOfferComponent consideration[0].getAmount() 3"
        );
        assertEq(params.offerFulfillmentComponents.length, 1);

        offerFulfillmentComponents = MatchArrays.allocateFulfillmentComponents(
            2
        );

        consideration[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        offer[0] = MatchComponentType.createMatchComponent(1, 0, 0);
        params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: new FulfillmentComponent[](0),
            offerItemIndex: 0,
            considerationItemIndex: 0,
            midCredit: false
        });
        MatchFulfillmentLib.processOfferComponent(offer, consideration, params);
        assertEq(
            consideration[0].getAmount(),
            0,
            "consideration[0].getAmount() 4"
        );
        assertEq(offer[0].getAmount(), 0, "offer[0].getAmount()");
        assertEq(
            params.offerItemIndex,
            1,
            "processOfferComponent offerItemIndex"
        );
        assertEq(params.offerFulfillmentComponents.length, 1);
    }

    function testProcessConsiderationComponents() public {
        FulfillmentComponent[] memory offerFulfillmentComponents = MatchArrays
            .allocateFulfillmentComponents(2);
        FulfillmentComponent[]
            memory considerationFulfillmentComponents = MatchArrays
                .allocateFulfillmentComponents(2);
        offer.push(MatchComponentType.createMatchComponent(1, 0, 0));
        consideration.push(MatchComponentType.createMatchComponent(1, 0, 0));
        ProcessComponentParams memory params = ProcessComponentParams({
            offerFulfillmentComponents: offerFulfillmentComponents,
            considerationFulfillmentComponents: considerationFulfillmentComponents,
            offerItemIndex: 0,
            considerationItemIndex: 0,
            midCredit: false
        });
        MatchFulfillmentLib.processConsiderationComponent(
            offer,
            consideration,
            params
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
            considerationItemIndex: 0,
            midCredit: false
        });
        MatchFulfillmentLib.processConsiderationComponent(
            offer,
            consideration,
            params
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
            considerationItemIndex: 0,
            midCredit: false
        });
        MatchFulfillmentLib.processConsiderationComponent(
            offer,
            consideration,
            params
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
            considerationItemIndex: 0,
            midCredit: false
        });
        // offerFulfillmentIndex: 1,
        // considerationFulfillmentIndex: 0

        MatchFulfillmentLib.processConsiderationComponent(
            offer,
            consideration,
            params
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

    function assertEq(
        MatchComponent memory left,
        MatchComponent memory right
    ) internal {
        FulfillmentComponent memory leftComponent = left
            .toFulfillmentComponent();
        FulfillmentComponent memory rightComponent = right
            .toFulfillmentComponent();
        assertEq(leftComponent, rightComponent, "component");
        assertEq(left.getAmount(), right.getAmount(), "amount");
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
