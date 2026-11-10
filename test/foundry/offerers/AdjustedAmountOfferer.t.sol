// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import { AdjustedAmountOfferer } from "./impl/AdjustedAmountOfferer.sol";

import { AlteredItemOfferer } from "./impl/AlteredItemOfferer.sol";

import {
    ERC20Interface
} from "seaport-types/src/interfaces/AbridgedTokenInterfaces.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    OrderType,
    ItemType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    ConsiderationItem,
    AdvancedOrder,
    CriteriaResolver
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ConsiderationEventsAndErrors
} from "seaport-types/src/interfaces/ConsiderationEventsAndErrors.sol";

import {
    ZoneInteractionErrors
} from "seaport-types/src/interfaces/ZoneInteractionErrors.sol";

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

    function setUpOfferer(int256 offerAdjust, int256 considerationAdjust)
        internal
    {
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

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
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

        test(this.execLessMinimumReceived, Context({ seaport: consideration }));
        test(
            this.execLessMinimumReceived,
            Context({ seaport: referenceConsideration })
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

        test(this.execMoreMinimumReceived, Context({ seaport: consideration }));
        test(
            this.execMoreMinimumReceived,
            Context({ seaport: referenceConsideration })
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

    // do the same as above but now for consideration items, specifying -1 and 1 as the second arguments to setUpOfferer

    function testLessMaximumSpent() public {
        setUpLessMaximumSpent();

        test(this.execLessMaximumSpent, Context({ seaport: consideration }));
        test(
            this.execLessMaximumSpent,
            Context({ seaport: referenceConsideration })
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

        test(this.execMoreMaximumSpent, Context({ seaport: consideration }));
        test(
            this.execMoreMaximumSpent,
            Context({ seaport: referenceConsideration })
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

    // The original testAlterOfferItem and testAlterConsiderationItem changed
    // amounts, which generateOrder now sees after amount derivation, so they
    // no longer applied. What advanced.spec.ts checked instead is that a
    // contract offerer can't swap the item type, token or identifier of an
    // item it was asked for, on either side.

    function testAlterOfferItemType() public {
        _testAlteredItem(false, AlteredItemOfferer.Field.ITEM_TYPE);
    }

    function testAlterOfferToken() public {
        _testAlteredItem(false, AlteredItemOfferer.Field.TOKEN);
    }

    function testAlterOfferIdentifier() public {
        _testAlteredItem(false, AlteredItemOfferer.Field.IDENTIFIER);
    }

    function testAlterConsiderationItemType() public {
        _testAlteredItem(true, AlteredItemOfferer.Field.ITEM_TYPE);
    }

    function testAlterConsiderationToken() public {
        _testAlteredItem(true, AlteredItemOfferer.Field.TOKEN);
    }

    function testAlterConsiderationIdentifier() public {
        _testAlteredItem(true, AlteredItemOfferer.Field.IDENTIFIER);
    }

    function _testAlteredItem(
        bool alterConsideration,
        AlteredItemOfferer.Field field
    ) internal {
        address[] memory seaports = new address[](2);
        seaports[0] = address(consideration);
        seaports[1] = address(referenceConsideration);
        AlteredItemOfferer altered = new AlteredItemOfferer(
            seaports,
            ERC20Interface(address(token1)),
            ERC20Interface(address(token2)),
            address(token3)
        );
        offerer = altered;
        token1.mint(address(altered), 100000);
        setUpNormalOrder(address(altered));

        ConsiderationInterface[2] memory seaportsToTest =
            [consideration, referenceConsideration];
        for (uint256 i; i < 2; ++i) {
            Context memory context = Context({ seaport: seaportsToTest[i] });

            altered.setAlteration(alterConsideration, field);
            vm.expectRevert(
                abi.encodeWithSelector(
                    InvalidContractOrder.selector,
                    (uint256(uint160(address(altered))) << 96)
                        + context.seaport
                        .getContractOffererNonce(address(altered))
                )
            );
            fulfillAdvanced(context, configureAdvancedOrder());

            // Unaltered, the same order fills.
            altered.setAlteration(false, AlteredItemOfferer.Field.NONE);
            uint256 token1Balance = token1.balanceOf(address(this));
            uint256 token2Balance = token2.balanceOf(address(this));
            fulfillAdvanced(context, configureAdvancedOrder());
            assertEq(token1.balanceOf(address(this)), token1Balance + 1000);
            assertEq(token2.balanceOf(address(this)), token2Balance - 1000);
        }
    }

    function configureAdvancedOrder() internal returns (AdvancedOrder memory) {
        return configureAdvancedOrder(1, 1);
    }

    function configureAdvancedOrder(uint120 numer, uint120 denom)
        internal
        returns (AdvancedOrder memory)
    {
        return AdvancedOrder({
            parameters: getOrderParameters(
                address(offerer), OrderType.CONTRACT
            ),
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
        context.seaport
            .fulfillAdvancedOrder({
                advancedOrder: advancedOrder,
                fulfillerConduitKey: bytes32(0),
                criteriaResolvers: criteriaResolvers,
                recipient: address(0)
            });
    }
}
