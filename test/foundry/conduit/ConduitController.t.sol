// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseConsiderationTest } from "../utils/BaseConsiderationTest.sol";

import {
    ConduitControllerInterface
} from "seaport-types/src/interfaces/ConduitControllerInterface.sol";

import {
    ConduitInterface
} from "seaport-types/src/interfaces/ConduitInterface.sol";

/**
 * @dev Covers ConduitController's conduit creation, channel bookkeeping,
 *      two-step ownership transfer and getters, plus Conduit.updateChannel's
 *      access checks. Every case runs against both the optimized
 *      ConduitController and ReferenceConduitController, each starting from
 *      the conduit BaseConsiderationTest creates under conduitKeyOne (owned by
 *      this contract, with its Consideration channel open).
 */
contract ConduitControllerTest is BaseConsiderationTest {
    struct Context {
        string label;
        ConduitControllerInterface controller;
        address conduit;
        address marketplace;
    }

    address buyer;
    address seller;

    function setUp() public override {
        super.setUp();
        buyer = makeAddr("buyer");
        seller = makeAddr("seller");
    }

    function _contexts() internal view returns (Context[] memory contexts) {
        contexts = new Context[](2);
        contexts[0] = Context(
            "optimized",
            conduitController,
            address(conduit),
            address(consideration)
        );
        contexts[1] = Context(
            "reference",
            referenceConduitController,
            address(referenceConduit),
            address(referenceConsideration)
        );
    }

    function _keyWithSalt(uint96 salt) internal view returns (bytes32) {
        return bytes32((uint256(uint160(address(this))) << 96) | salt);
    }

    // createConduit

    function testCreateConduit() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            Context memory c = contexts[i];
            ConduitControllerInterface controller = c.controller;
            bytes32 key = _keyWithSalt(1);

            (address expected, bool existsBefore) = controller.getConduit(key);
            assertFalse(existsBefore, c.label);

            vm.expectRevert(
                ConduitControllerInterface.InvalidInitialOwner.selector
            );
            controller.createConduit(key, address(0));

            vm.expectEmit(address(controller));
            emit ConduitControllerInterface.NewConduit(expected, key);
            vm.expectEmit(address(controller));
            emit ConduitControllerInterface.OwnershipTransferred(
                expected,
                address(0),
                address(this)
            );
            address created = controller.createConduit(key, address(this));

            assertEq(created, expected, c.label);
            (, bool existsAfter) = controller.getConduit(key);
            assertTrue(existsAfter, c.label);
            assertEq(controller.ownerOf(created), address(this), c.label);
            assertEq(controller.getKey(created), key, c.label);
            assertEq(controller.getPotentialOwner(created), address(0), c.label);
            assertEq(controller.getTotalChannels(created), 0, c.label);
        }
    }

    function testCreateConduitRevertsInvalidCreator() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            ConduitControllerInterface controller = contexts[i].controller;

            vm.expectRevert(ConduitControllerInterface.InvalidCreator.selector);
            controller.createConduit(bytes32(0), address(this));

            // A key scoped to this contract can't be used by anyone else.
            vm.prank(buyer);
            vm.expectRevert(ConduitControllerInterface.InvalidCreator.selector);
            controller.createConduit(_keyWithSalt(2), buyer);
        }
    }

    function testCreateConduitRevertsConduitAlreadyExists() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            Context memory c = contexts[i];

            vm.expectRevert(
                abi.encodeWithSelector(
                    ConduitControllerInterface.ConduitAlreadyExists.selector,
                    c.conduit
                )
            );
            c.controller.createConduit(conduitKeyOne, address(this));
        }
    }

    // updateChannel

    function testUpdateChannelRevertsCallerIsNotOwner() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            Context memory c = contexts[i];

            vm.prank(buyer);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ConduitControllerInterface.CallerIsNotOwner.selector,
                    c.conduit
                )
            );
            c.controller.updateChannel(c.conduit, buyer, true);

            vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
            c.controller.updateChannel(buyer, seller, true);
        }
    }

    function testConduitUpdateChannelRevertsInvalidController() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            Context memory c = contexts[i];

            // The conduit owner can't bypass the controller.
            vm.expectRevert(ConduitInterface.InvalidController.selector);
            ConduitInterface(c.conduit).updateChannel(address(0), true);

            vm.prank(buyer);
            vm.expectRevert(ConduitInterface.InvalidController.selector);
            ConduitInterface(c.conduit).updateChannel(buyer, true);
        }
    }

    function testConduitUpdateChannelRevertsChannelStatusAlreadySet() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            Context memory c = contexts[i];

            vm.prank(address(c.controller));
            vm.expectRevert(
                abi.encodeWithSelector(
                    ConduitInterface.ChannelStatusAlreadySet.selector,
                    c.marketplace,
                    true
                )
            );
            ConduitInterface(c.conduit).updateChannel(c.marketplace, true);

            vm.prank(address(c.controller));
            vm.expectRevert(
                abi.encodeWithSelector(
                    ConduitInterface.ChannelStatusAlreadySet.selector,
                    seller,
                    false
                )
            );
            ConduitInterface(c.conduit).updateChannel(seller, false);

            // The controller bubbles the conduit's revert up unchanged.
            vm.expectRevert(
                abi.encodeWithSelector(
                    ConduitInterface.ChannelStatusAlreadySet.selector,
                    seller,
                    false
                )
            );
            c.controller.updateChannel(c.conduit, seller, false);
        }
    }

    function testAddsAndRemovesChannels() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            _testAddsAndRemovesChannels(contexts[i]);
        }
    }

    function _testAddsAndRemovesChannels(Context memory c) internal {
        ConduitControllerInterface controller = c.controller;
        address conduitAddress = c.conduit;
        address marketplace = c.marketplace;

        assertEq(controller.getTotalChannels(conduitAddress), 1, c.label);
        assertTrue(
            controller.getChannelStatus(conduitAddress, marketplace), c.label
        );

        // Opening an open channel is rejected by the conduit.
        vm.expectRevert(
            abi.encodeWithSelector(
                ConduitInterface.ChannelStatusAlreadySet.selector,
                marketplace,
                true
            )
        );
        controller.updateChannel(conduitAddress, marketplace, true);

        assertTrue(
            controller.getChannelStatus(conduitAddress, marketplace), c.label
        );
        assertEq(controller.getTotalChannels(conduitAddress), 1, c.label);

        // Open a second channel: channels = [marketplace, seller].
        vm.expectEmit(conduitAddress);
        emit ConduitInterface.ChannelUpdated(seller, true);
        controller.updateChannel(conduitAddress, seller, true);

        assertTrue(controller.getChannelStatus(conduitAddress, seller), c.label);
        assertEq(controller.getTotalChannels(conduitAddress), 2, c.label);
        assertEq(controller.getChannel(conduitAddress, 1), seller, c.label);

        // Close the first channel. It isn't the last one, so the controller
        // moves seller into its slot before popping: channels = [seller].
        vm.expectEmit(conduitAddress);
        emit ConduitInterface.ChannelUpdated(marketplace, false);
        controller.updateChannel(conduitAddress, marketplace, false);

        assertFalse(
            controller.getChannelStatus(conduitAddress, marketplace), c.label
        );
        assertTrue(controller.getChannelStatus(conduitAddress, seller), c.label);
        assertEq(controller.getTotalChannels(conduitAddress), 1, c.label);
        assertEq(controller.getChannel(conduitAddress, 0), seller, c.label);

        // Reopen marketplace on the conduit directly, so the conduit says open
        // while the controller still tracks it as closed. Closing it through
        // the controller then takes the !isOpen && !channelPreviouslyOpen
        // branch, which leaves the channels array alone.
        vm.prank(address(controller));
        ConduitInterface(conduitAddress).updateChannel(marketplace, true);

        controller.updateChannel(conduitAddress, marketplace, false);

        assertFalse(
            controller.getChannelStatus(conduitAddress, marketplace), c.label
        );
        assertEq(controller.getTotalChannels(conduitAddress), 1, c.label);
        assertEq(controller.getChannel(conduitAddress, 0), seller, c.label);

        // Close seller, now the last channel, so it's popped without a swap.
        // This also relies on the swap above having updated seller's index.
        controller.updateChannel(conduitAddress, seller, false);

        assertFalse(
            controller.getChannelStatus(conduitAddress, seller), c.label
        );
        assertEq(controller.getTotalChannels(conduitAddress), 0, c.label);
        assertEq(controller.getChannels(conduitAddress).length, 0, c.label);

        controller.updateChannel(conduitAddress, marketplace, true);

        assertTrue(
            controller.getChannelStatus(conduitAddress, marketplace), c.label
        );
        assertEq(controller.getTotalChannels(conduitAddress), 1, c.label);
        assertEq(controller.getChannel(conduitAddress, 0), marketplace, c.label);
    }

    // Ownership

    function testTransferOwnershipTwoStep() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            _testTransferOwnershipTwoStep(contexts[i]);
        }
    }

    function _testTransferOwnershipTwoStep(Context memory c) internal {
        ConduitControllerInterface controller = c.controller;
        address conduitAddress = c.conduit;

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ConduitControllerInterface.CallerIsNotOwner.selector,
                conduitAddress
            )
        );
        controller.transferOwnership(conduitAddress, buyer);

        vm.expectRevert(
            abi.encodeWithSelector(
                ConduitControllerInterface.NewPotentialOwnerIsZeroAddress
                .selector,
                conduitAddress
            )
        );
        controller.transferOwnership(conduitAddress, address(0));

        vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
        controller.transferOwnership(seller, buyer);

        assertEq(
            controller.getPotentialOwner(conduitAddress), address(0), c.label
        );

        vm.expectEmit(address(controller));
        emit ConduitControllerInterface.PotentialOwnerUpdated(buyer);
        controller.transferOwnership(conduitAddress, buyer);

        assertEq(controller.getPotentialOwner(conduitAddress), buyer, c.label);

        vm.expectRevert(
            abi.encodeWithSelector(
                ConduitControllerInterface.NewPotentialOwnerAlreadySet.selector,
                conduitAddress,
                buyer
            )
        );
        controller.transferOwnership(conduitAddress, buyer);

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ConduitControllerInterface.CallerIsNotOwner.selector,
                conduitAddress
            )
        );
        controller.cancelOwnershipTransfer(conduitAddress);

        vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
        controller.cancelOwnershipTransfer(seller);

        vm.expectEmit(address(controller));
        emit ConduitControllerInterface.PotentialOwnerUpdated(address(0));
        controller.cancelOwnershipTransfer(conduitAddress);

        assertEq(
            controller.getPotentialOwner(conduitAddress), address(0), c.label
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ConduitControllerInterface.NoPotentialOwnerCurrentlySet
                .selector,
                conduitAddress
            )
        );
        controller.cancelOwnershipTransfer(conduitAddress);

        controller.transferOwnership(conduitAddress, buyer);

        assertEq(controller.getPotentialOwner(conduitAddress), buyer, c.label);

        vm.prank(buyer);
        vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
        controller.acceptOwnership(seller);

        vm.prank(seller);
        vm.expectRevert(
            abi.encodeWithSelector(
                ConduitControllerInterface.CallerIsNotNewPotentialOwner
                .selector,
                conduitAddress
            )
        );
        controller.acceptOwnership(conduitAddress);

        vm.expectEmit(address(controller));
        emit ConduitControllerInterface.PotentialOwnerUpdated(address(0));
        vm.expectEmit(address(controller));
        emit ConduitControllerInterface.OwnershipTransferred(
            conduitAddress,
            address(this),
            buyer
        );
        vm.prank(buyer);
        controller.acceptOwnership(conduitAddress);

        assertEq(
            controller.getPotentialOwner(conduitAddress), address(0), c.label
        );
        assertEq(controller.ownerOf(conduitAddress), buyer, c.label);

        // Owner-only actions now follow the new owner.
        vm.expectRevert(
            abi.encodeWithSelector(
                ConduitControllerInterface.CallerIsNotOwner.selector,
                conduitAddress
            )
        );
        controller.updateChannel(conduitAddress, seller, true);

        vm.prank(buyer);
        controller.updateChannel(conduitAddress, seller, true);
        assertTrue(controller.getChannelStatus(conduitAddress, seller), c.label);
    }

    // Getters

    function testOwnerOf() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            Context memory c = contexts[i];

            assertEq(c.controller.ownerOf(c.conduit), address(this), c.label);

            vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
            c.controller.ownerOf(buyer);
        }
    }

    function testGetKey() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            Context memory c = contexts[i];

            assertEq(c.controller.getKey(c.conduit), conduitKeyOne, c.label);

            vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
            c.controller.getKey(buyer);
        }
    }

    function testGetPotentialOwner() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            Context memory c = contexts[i];

            assertEq(
                c.controller.getPotentialOwner(c.conduit), address(0), c.label
            );

            vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
            c.controller.getPotentialOwner(buyer);
        }
    }

    function testGetChannelStatus() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            Context memory c = contexts[i];

            assertTrue(
                c.controller.getChannelStatus(c.conduit, c.marketplace), c.label
            );
            assertFalse(
                c.controller.getChannelStatus(c.conduit, seller), c.label
            );

            vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
            c.controller.getChannelStatus(buyer, seller);
        }
    }

    function testGetChannels() public {
        Context[] memory contexts = _contexts();
        for (uint256 i; i < contexts.length; ++i) {
            Context memory c = contexts[i];
            ConduitControllerInterface controller = c.controller;

            uint256 totalChannels = controller.getTotalChannels(c.conduit);
            assertEq(totalChannels, 1, c.label);

            vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
            controller.getTotalChannels(buyer);

            assertEq(
                controller.getChannel(c.conduit, 0), c.marketplace, c.label
            );

            vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
            controller.getChannel(buyer, totalChannels - 1);

            vm.expectRevert(
                abi.encodeWithSelector(
                    ConduitControllerInterface.ChannelOutOfRange.selector,
                    c.conduit
                )
            );
            controller.getChannel(c.conduit, 1);

            vm.expectRevert(
                abi.encodeWithSelector(
                    ConduitControllerInterface.ChannelOutOfRange.selector,
                    c.conduit
                )
            );
            controller.getChannel(c.conduit, 2);

            address[] memory channels = controller.getChannels(c.conduit);
            assertEq(channels.length, 1, c.label);
            assertEq(channels[0], c.marketplace, c.label);

            vm.expectRevert(ConduitControllerInterface.NoConduit.selector);
            controller.getChannels(buyer);
        }
    }
}
