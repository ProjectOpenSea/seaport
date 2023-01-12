// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";
import { AdjustedAmountOfferer } from "./impl/AdjustedAmountOfferer.sol";
import { Merkle } from "murky/Merkle.sol";
import {
    ERC20Interface,
    ERC721Interface
} from "../../../contracts/interfaces/AbridgedTokenInterfaces.sol";
import { ConsiderationInterface } from
    "../../../contracts/interfaces/ConsiderationInterface.sol";
import {
    OrderType,
    ItemType,
    Side
} from "../../../contracts/lib/ConsiderationEnums.sol";
import {
    Order,
    SpentItem,
    OrderParameters,
    ConsiderationItem,
    OfferItem,
    AdvancedOrder,
    CriteriaResolver
} from "../../../contracts/lib/ConsiderationStructs.sol";

import { ConsiderationEventsAndErrors } from
    "../../../contracts/interfaces/ConsiderationEventsAndErrors.sol";
import { ZoneInteractionErrors } from
    "../../../contracts/interfaces/ZoneInteractionErrors.sol";

contract AdjustedAmountOffererTest is
    BaseOrderTest,
    ConsiderationEventsAndErrors,
    ZoneInteractionErrors
{
    AdjustedAmountOfferer offerer;
    CriteriaResolver[] criteriaResolvers;

    struct Context {
        ConsiderationInterface seaport;
    }

    function setUp() public virtual override {
        super.setUp();
        token1.mint(address(this), 100000);
        token2.mint(address(this), 100000);
    }

    function setUpOfferer(
        int256 offerAdjust,
        int256 considerationAdjust
    ) internal {
        address[] memory seaports = new address[](2);
        seaports[0] = address(consideration);
        seaports[1] = address(referenceConsideration);
        offerer = new AdjustedAmountOfferer(
            seaports,
            ERC20Interface(address(token1)),
            ERC20Interface(address(token2)),
            offerAdjust,
            considerationAdjust
        );
        token1.mint(address(offerer), 100000);
        token2.mint(address(offerer), 100000);
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) { }
        catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function setUpNormalOrder(address recipient) public {
        // add normal offer item identifier 2
        addOfferItem({
            itemType: ItemType.ERC20,
            token: address(token1),
            identifier: 0,
            amount: 1000
        });
        // add consideration item to address(test) for 1000 of token1
        addConsiderationItem(
            ConsiderationItem({
                itemType: ItemType.ERC20,
                token: address(token2),
                identifierOrCriteria: 0,
                startAmount: 1000,
                endAmount: 1000,
                recipient: payable(recipient)
            })
        );
    }

    function testLessMinimumReceived() public {
        setUpLessMinimumReceived();

        test(this.execLessMinimumReceived, Context({seaport: consideration}));
        test(
            this.execLessMinimumReceived,
            Context({seaport: referenceConsideration})
        );
    }

    function setUpLessMinimumReceived() internal {
        setUpOfferer(-1, 0);
        setUpNormalOrder(address(offerer));
    }

    function execLessMinimumReceived(Context memory context)
        external
        stateless
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                uint256(uint160(address(offerer))) << 96
            )
        );
        fulfillAdvanced(context, configureAdvancedOrder());
    }

    // testMoreMinimumReceived: same as above but specify setUpOfferer(1, 0)
    function testMoreMinimumReceived() public {
        setUpMoreMinimumReceived();

        test(this.execMoreMinimumReceived, Context({seaport: consideration}));
        test(
            this.execMoreMinimumReceived,
            Context({seaport: referenceConsideration})
        );
    }

    function setUpMoreMinimumReceived() internal {
        setUpOfferer(1, 0);
        setUpNormalOrder(address(offerer));
    }

    function execMoreMinimumReceived(Context memory context)
        external
        stateless
    {
        uint256 startBalance = token2.balanceOf(address(this));
        fulfillAdvanced(context, configureAdvancedOrder());
        assertEq(token1.balanceOf(address(this)), startBalance + 1001);
    }

    // do the same as above but now for consideration items, specifying -1 and 1
    // as the second arguments to setUpOfferer

    function testLessMaximumSpent() public {
        setUpLessMaximumSpent();

        test(this.execLessMaximumSpent, Context({seaport: consideration}));
        test(
            this.execLessMaximumSpent,
            Context({seaport: referenceConsideration})
        );
    }

    function setUpLessMaximumSpent() internal {
        setUpOfferer(0, -1);
        setUpNormalOrder(address(offerer));
    }

    function execLessMaximumSpent(Context memory context) external stateless {
        uint256 startBalance = token1.balanceOf(address(this));

        fulfillAdvanced(context, configureAdvancedOrder());
        assertEq(token2.balanceOf(address(this)), startBalance - 999);
    }

    function testMoreMaximumSpent() public {
        setUpMoreMaximumSpent();

        test(this.execMoreMaximumSpent, Context({seaport: consideration}));
        test(
            this.execMoreMaximumSpent,
            Context({seaport: referenceConsideration})
        );
    }

    function setUpMoreMaximumSpent() internal {
        setUpOfferer(0, 1);
        setUpNormalOrder(address(offerer));
    }

    function execMoreMaximumSpent(Context memory context) external stateless {
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                uint256(uint160(address(offerer))) << 96
            )
        );
        fulfillAdvanced(context, configureAdvancedOrder());
    }

    // make sure altering offer item start/end amount results in falure

    function testAlterOfferItem() public {
        setUpOfferer(0, 0);
        setUpNormalOrder(address(offerer));
        offerItems[0].endAmount += 1;

        test(this.execAlterOfferItem, Context({seaport: consideration}));
        test(
            this.execAlterOfferItem, Context({seaport: referenceConsideration})
        );
    }

    function execAlterOfferItem(Context memory context) external stateless {
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                uint256(uint160(address(offerer))) << 96
            )
        );
        fulfillAdvanced(context, configureAdvancedOrder());
    }

    // make sure altering consideration item start/end amount results in falure
    function testAlterConsiderationItem() public {
        setUpOfferer(0, 0);
        setUpNormalOrder(address(offerer));
        considerationItems[0].endAmount += 1;

        test(this.execAlterConsiderationItem, Context({seaport: consideration}));
        test(
            this.execAlterConsiderationItem,
            Context({seaport: referenceConsideration})
        );
    }

    function execAlterConsiderationItem(Context memory context)
        external
        stateless
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                uint256(uint160(address(offerer))) << 96
            )
        );
        fulfillAdvanced(context, configureAdvancedOrder());
    }

    function configureAdvancedOrder() internal returns (AdvancedOrder memory) {
        return configureAdvancedOrder(1, 1);
    }

    function configureAdvancedOrder(
        uint120 numer,
        uint120 denom
    ) internal returns (AdvancedOrder memory) {
        return AdvancedOrder({
            parameters: getOrderParameters(address(offerer), OrderType.CONTRACT),
            numerator: numer,
            denominator: denom,
            signature: "",
            extraData: ""
        });
    }

    function fulfillAdvanced(
        Context memory context,
        AdvancedOrder memory advancedOrder
    ) internal {
        context.seaport.fulfillAdvancedOrder({
            advancedOrder: advancedOrder,
            fulfillerConduitKey: bytes32(0),
            criteriaResolvers: criteriaResolvers,
            recipient: address(0)
        });
    }
}
