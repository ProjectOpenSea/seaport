// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";
import { PassthroughOfferer } from "./impl/PassthroughOfferer.sol";
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

contract OffererCriteriaAdvancedTest is
    BaseOrderTest,
    ConsiderationEventsAndErrors,
    ZoneInteractionErrors
{
    PassthroughOfferer offerer;
    CriteriaResolver[] criteriaResolvers;

    struct Context {
        ConsiderationInterface seaport;
    }

    function setUp() public virtual override {
        super.setUp();
        token1.mint(address(this), 100000);
        test721_1.mint(address(this), 1);
        address[] memory seaports = new address[](2);
        seaports[0] = address(consideration);
        seaports[1] = address(referenceConsideration);
        offerer = new PassthroughOfferer(
            seaports,
            ERC20Interface(address(token1)),
            ERC721Interface(address(test721_1))
        );
        token1.mint(address(offerer), 100000);
        test721_1.mint(address(offerer), 2);
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

    function testOnlyWholeFractional1() public {
        setUpOnlyWholeFractional();

        test(this.execOnlyWholeFractional1, Context({seaport: consideration}));
        test(
            this.execOnlyWholeFractional1,
            Context({seaport: referenceConsideration})
        );
    }

    function setUpOnlyWholeFractional() public {
        setUpNormalOrder(address(offerer));
    }

    function setUpNormalOrder(address recipient) public {
        // add normal offer item identifier 2
        addOfferItem({
            itemType: ItemType.ERC721,
            token: address(test721_1),
            identifier: 2,
            amount: 1
        });
        // add consideration item to address(test) for 1000 of token1
        addConsiderationItem(
            ConsiderationItem({
                itemType: ItemType.ERC20,
                token: address(token1),
                identifierOrCriteria: 0,
                startAmount: 1000,
                endAmount: 1000,
                recipient: payable(recipient)
            })
        );
    }

    function execOnlyWholeFractional1(Context memory context)
        external
        stateless
    {
        fulfillAdvanced(context, configureAdvancedOrder());
        assertEq(test721_1.ownerOf(2), address(this));
    }

    // same as above but test a 0/n fraction
    function testOnlyWholeFractional0() public {
        setUpOnlyWholeFractional();

        test(this.execOnlyWholeFractional0, Context({seaport: consideration}));
        test(
            this.execOnlyWholeFractional0,
            Context({seaport: referenceConsideration})
        );
    }

    function execOnlyWholeFractional0(Context memory context)
        external
        stateless
    {
        vm.expectRevert(BadFraction.selector);
        fulfillAdvanced(context, configureAdvancedOrder(0, 1));
    }

    // same as above but test a n/n fraction (2/2)
    function testOnlyWholeFractional2() public {
        setUpOnlyWholeFractional();

        test(this.execOnlyWholeFractional2, Context({seaport: consideration}));
        test(
            this.execOnlyWholeFractional2,
            Context({seaport: referenceConsideration})
        );
    }

    function execOnlyWholeFractional2(Context memory context)
        external
        stateless
    {
        vm.expectRevert(BadFraction.selector);
        fulfillAdvanced(context, configureAdvancedOrder(2, 2));
    }

    function setUpOnlyWholeFractional0() public {
        // add normal offer item identifier 2
        addOfferItem({
            itemType: ItemType.ERC721,
            token: address(test721_1),
            identifier: 2,
            amount: 1
        });
        // add consideration item to address(test) for 1000 of token1
        addConsiderationItem(
            ConsiderationItem({
                itemType: ItemType.ERC20,
                token: address(token1),
                identifierOrCriteria: 0,
                startAmount: 0,
                endAmount: 0,
                recipient: payable(address(offerer))
            })
        );
    }

    function testZeroReceiverWildcard() public {
        setUpNormalOrder(address(0));

        test(this.execZeroReceiverWildcard, Context({seaport: consideration}));
        test(
            this.execZeroReceiverWildcard,
            Context({seaport: referenceConsideration})
        );
    }

    function execZeroReceiverWildcard(Context memory context)
        external
        stateless
    {
        fulfillAdvanced(context, configureAdvancedOrder(1, 1));
        assertEq(test721_1.ownerOf(2), address(this));
    }

    function testMismatchedReceiver() public {
        setUpNormalOrder(makeAddr("not offerer"));

        test(this.execMismatchedReceiver, Context({seaport: consideration}));
        test(
            this.execMismatchedReceiver,
            Context({seaport: referenceConsideration})
        );
    }

    function execMismatchedReceiver(Context memory context)
        external
        stateless
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(offerer)))) << 96
            )
        );
        fulfillAdvanced(context, configureAdvancedOrder(1, 1));
    }

    function testCriteriaMinimumReceived() public {
        setUpCriteriaMinimumReceived();

        test(
            this.execCriteriaMinimumReceived, Context({seaport: consideration})
        );
        test(
            this.execCriteriaMinimumReceived,
            Context({seaport: referenceConsideration})
        );
    }

    function setUpCriteriaMinimumReceived() internal {
        (bytes32 root, bytes32[] memory proof) = getRootAndProof(2);
        // addOfferItem type ERC721_WITH_CRITERIA, criteria equal to root of
        // merkle tree
        addOfferItem({
            itemType: ItemType.ERC721_WITH_CRITERIA,
            token: address(test721_1),
            identifier: uint256(root),
            amount: 1
        });
        // add consideration item to address(test) for 1000 of token1
        addConsiderationItem(
            ConsiderationItem({
                itemType: ItemType.ERC20,
                token: address(token1),
                identifierOrCriteria: 0,
                startAmount: 1000,
                endAmount: 1000,
                recipient: payable(address(offerer))
            })
        );

        criteriaResolvers.push(
            CriteriaResolver({
                orderIndex: 0,
                side: Side.OFFER,
                index: 0,
                identifier: 2,
                criteriaProof: proof
            })
        );
    }

    function execCriteriaMinimumReceived(Context memory context)
        external
        stateless
    {
        fulfillAdvanced(context, configureAdvancedOrder());
        assertEq(test721_1.ownerOf(2), address(this));
    }

    function testCriteriaMaximumSpent() public {
        setUpCriteriaMaximumSpent();

        test(this.execCriteriaMaximumSpent, Context({seaport: consideration}));
        test(
            this.execCriteriaMaximumSpent,
            Context({seaport: referenceConsideration})
        );
    }

    function setUpCriteriaMaximumSpent() internal {
        (bytes32 root, bytes32[] memory proof) = getRootAndProof(1);
        // addOfferItem type ERC20, amount 1000
        addOfferItem(
            OfferItem({
                itemType: ItemType.ERC20,
                token: address(token1),
                identifierOrCriteria: 0,
                startAmount: 1000,
                endAmount: 1000
            })
        );
        // addConsiderationItem type ERC721_WITH_CRITERIA, criteria equal to
        // root of merkle tree, recipient offerer
        addConsiderationItem(
            ConsiderationItem({
                itemType: ItemType.ERC721_WITH_CRITERIA,
                token: address(test721_1),
                identifierOrCriteria: uint256(root),
                startAmount: 1,
                endAmount: 1,
                recipient: payable(address(offerer))
            })
        );

        // add criteria resolver for side consideration, orderIndex 0, index 0,
        // identifier 2, proof
        criteriaResolvers.push(
            CriteriaResolver({
                orderIndex: 0,
                side: Side.CONSIDERATION,
                index: 0,
                identifier: 1,
                criteriaProof: proof
            })
        );
    }

    function execCriteriaMaximumSpent(Context memory context)
        external
        stateless
    {
        fulfillAdvanced(context, configureAdvancedOrder());
        assertEq(test721_1.ownerOf(1), address(offerer));
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

    function getRootAndProof(uint256 identifier)
        internal
        returns (bytes32 root, bytes32[] memory proof)
    {
        Merkle tree = new Merkle();
        bytes32[] memory leaves = generateLeaves();
        root = tree.getRoot(leaves);
        proof = tree.getProof(leaves, identifier);
        return (root, proof);
    }

    /**
     * @dev Generate hashed leaves for identifiers [0,50) for insertion into a
     * Merkle tree.
     */
    function generateLeaves() internal pure returns (bytes32[] memory) {
        uint256[] memory leaves = new uint256[](50);
        for (uint256 i = 0; i < leaves.length; ++i) {
            leaves[i] = i;
        }
        return toHashedLeaves(leaves);
    }
}
