// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Vm } from "forge-std/Vm.sol";

import { NonReentrantTest } from "./NonReentrant.t.sol";

import { Consideration } from "seaport-core/src/lib/Consideration.sol";

import {
    ConsiderationEventsAndErrors
} from "seaport-types/src/interfaces/ConsiderationEventsAndErrors.sol";

import {
    ReentrancyErrors
} from "seaport-types/src/interfaces/ReentrancyErrors.sol";

import {
    BasicOrderType,
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    AdvancedOrder,
    BasicOrderParameters,
    ConsiderationItem,
    CriteriaResolver,
    OfferItem,
    Order,
    OrderParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    _ENTERED_SSTORE,
    _NOT_ENTERED_SSTORE,
    _REENTRANCY_GUARD_SLOT,
    _TSTORE_ENABLED_SSTORE
} from "seaport-types/src/lib/ConsiderationConstants.sol";

interface TstoreActivation {
    function __activateTstore() external;
}

/**
 * @dev Native token recipient that, while Seaport is paying it, reads
 *      Seaport's guard slot and tries to activate TSTORE.
 */
contract ActivateTstoreOnReceive {
    Vm private constant VM =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private immutable seaport;

    uint256 public observedGuard;
    bytes public activationRevert;

    constructor(address _seaport) {
        seaport = _seaport;
    }

    receive() external payable {
        observedGuard =
            uint256(VM.load(seaport, bytes32(_REENTRANCY_GUARD_SLOT)));
        try TstoreActivation(seaport).__activateTstore() {
            activationRevert = "activated";
        } catch (bytes memory reason) {
            activationRevert = reason;
        }
    }
}

/**
 * @dev Seaport 1.6 probes for TLOAD in its constructor and, on chains that
 *      lacked TSTORE when it was deployed, keeps its reentrancy guard in
 *      storage until someone calls __activateTstore after the chain upgrades.
 *      Every other suite deploys on Cancun and never runs that path.
 *
 *      setUp switches the EVM to Shanghai before deploying, so the probe fails
 *      and Seaport starts in SSTORE mode. The EVM stays on Shanghai for each
 *      test unless the test switches it, so the deployed bytecode runs the
 *      way it does on a pre-Cancun chain. This works because neither Seaport
 *      nor the test helpers these tests reach emit Cancun-only opcodes other
 *      than Seaport's guarded TLOAD/TSTORE; a helper that starts using MCOPY
 *      would fail here with NotActivated.
 *
 *      The reference build always uses a storage guard, so the inherited
 *      testNonReentrant matrix runs it unchanged alongside the optimized one.
 */
contract NonReentrantPreCancunTest is NonReentrantTest {
    uint256 internal constant PRICE = 3;

    uint256 internal nextId = 5000;

    function setUp() public override {
        vm.setEvmVersion("shanghai");
        super.setUp();
    }

    function test_guardStartsInStorageWithoutTstore() public view {
        assertEq(_guard(address(consideration)), _NOT_ENTERED_SSTORE);
    }

    function test_basicFillWithStorageGuard() public {
        _basicFill(_NOT_ENTERED_SSTORE);
    }

    function test_advancedFillWithStorageGuard() public {
        _advancedFill(_NOT_ENTERED_SSTORE);
    }

    /// @dev The guard sits in storage while a basic order pays out, and
    ///      __activateTstore refuses to run while it is set.
    function test_activateTstoreRevertsWhileGuardIsSet() public {
        ActivateTstoreOnReceive recipient =
            new ActivateTstoreOnReceive(address(consideration));
        (BasicOrderParameters memory basic, uint256 id) =
            _basicOrder(address(recipient));

        vm.prank(bob);
        consideration.fulfillBasicOrder{ value: PRICE }(basic);

        assertEq(test721_1.ownerOf(id), bob);
        assertEq(recipient.observedGuard(), _ENTERED_SSTORE);
        assertEq(
            recipient.activationRevert(),
            abi.encodeWithSelector(
                ReentrancyErrors.TStoreAlreadyActivated.selector
            )
        );
        assertEq(_guard(address(consideration)), _NOT_ENTERED_SSTORE);
    }

    /// @dev receive() rejects native tokens through the storage-guard branch,
    ///      both outside a fulfillment and during a basic order that names
    ///      Seaport as a recipient.
    function test_receiveRejectsEtherWithStorageGuard() public {
        _assertDirectEtherRejected();

        (BasicOrderParameters memory basic,) =
            _basicOrder(address(consideration));
        vm.expectRevert(
            abi.encodeWithSelector(
                ConsiderationEventsAndErrors.InvalidMsgValue.selector, 1
            )
        );
        vm.prank(bob);
        consideration.fulfillBasicOrder{ value: PRICE }(basic);
    }

    function test_activateTstoreRevertsWhenUnsupported() public {
        vm.expectRevert(ReentrancyErrors.TStoreNotSupported.selector);
        TstoreActivation(address(consideration)).__activateTstore();
        assertEq(_guard(address(consideration)), _NOT_ENTERED_SSTORE);
    }

    /// @dev Once the chain supports TSTORE, anyone can switch the guard over,
    ///      and only once.
    function test_activateTstoreAfterUpgrade() public {
        _upgradeAndActivate();
        assertEq(_guard(address(consideration)), _TSTORE_ENABLED_SSTORE);

        vm.expectRevert(ReentrancyErrors.TStoreAlreadyActivated.selector);
        TstoreActivation(address(consideration)).__activateTstore();
    }

    function test_fillsAfterTstoreActivation() public {
        _upgradeAndActivate();
        _basicFill(_TSTORE_ENABLED_SSTORE);
        _advancedFill(_TSTORE_ENABLED_SSTORE);
        _assertDirectEtherRejected();
    }

    /// @dev The full reentrancy matrix on the post-deployment TSTORE branch.
    function test_nonReentrantAfterTstoreActivation() public {
        _upgradeAndActivate();
        testNonReentrant();
        assertEq(_guard(address(consideration)), _TSTORE_ENABLED_SSTORE);
    }

    /// @dev A Seaport deployed where TSTORE already works never needs (or
    ///      allows) activation.
    function test_activateTstoreRevertsWhenSupportedFromDeployment() public {
        vm.setEvmVersion("cancun");
        address seaport = _deploySeaport();
        assertEq(_guard(seaport), 0);

        vm.expectRevert(ReentrancyErrors.TStoreAlreadyActivated.selector);
        TstoreActivation(seaport).__activateTstore();
    }

    /// @dev The constructor deploys its TLOAD probe with CREATE at nonce 1.
    ///      Occupying that address makes the deployment fail.
    function test_constructorRevertsWhenTloadProbeCannotDeploy() public {
        bytes memory initCode = abi.encodePacked(
            coverage_or_debug
                ? type(Consideration).creationCode
                : vm.getCode(
                    "optimized-out/Consideration.sol/Consideration.json"
                ),
            abi.encode(address(conduitController))
        );

        vm.expectRevert(
            ReentrancyErrors.TloadTestContractDeploymentFailed.selector
        );
        this.createWithOccupiedProbe(initCode);
    }

    /// @dev External so vm.expectRevert can watch it. Predicts the address
    ///      inside this frame, since the call itself bumps this contract's
    ///      nonce, and bubbles the constructor's revert data.
    function createWithOccupiedProbe(bytes memory initCode)
        external
        returns (address deployed)
    {
        address seaport = vm.computeCreateAddress(
            address(this), vm.getNonce(address(this))
        );
        vm.etch(vm.computeCreateAddress(seaport, 1), hex"00");
        assembly {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
            if iszero(deployed) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _guard(address seaport) internal view returns (uint256) {
        return uint256(vm.load(seaport, bytes32(_REENTRANCY_GUARD_SLOT)));
    }

    function _upgradeAndActivate() internal {
        vm.setEvmVersion("cancun");
        TstoreActivation(address(consideration)).__activateTstore();
    }

    function _deploySeaport() internal returns (address) {
        if (coverage_or_debug) {
            return address(new Consideration(address(conduitController)));
        }
        return deployCode(
            "optimized-out/Consideration.sol/Consideration.json",
            abi.encode(address(conduitController))
        );
    }

    function _assertDirectEtherRejected() internal {
        vm.prank(bob);
        (bool ok, bytes memory data) =
            address(consideration).call{ value: 1 }("");
        assertFalse(ok);
        assertEq(
            data,
            abi.encodeWithSelector(
                ConsiderationEventsAndErrors.InvalidMsgValue.selector, 1
            )
        );
    }

    /// @dev Alice sells an ERC721 for 2 wei to herself and 1 wei to
    ///      `secondRecipient`.
    function _basicOrder(address secondRecipient)
        internal
        returns (BasicOrderParameters memory basic, uint256 id)
    {
        id = nextId++;
        test721_1.mint(alice, id);
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC721, address(test721_1), id, 1, 1);
        ConsiderationItem[] memory cons = new ConsiderationItem[](2);
        cons[0] = ConsiderationItem(ItemType.NATIVE, address(0), 0, 2, 2, alice);
        cons[1] = ConsiderationItem(
            ItemType.NATIVE, address(0), 0, 1, 1, payable(secondRecipient)
        );
        basic = toBasicOrderParameters(
            _signedOrder(offer, cons, OrderType.FULL_OPEN),
            BasicOrderType.ETH_TO_ERC721_FULL_OPEN
        );
    }

    function _basicFill(uint256 idleGuard) internal {
        (BasicOrderParameters memory basic, uint256 id) = _basicOrder(cal);
        uint256 aliceBalance = alice.balance;

        vm.prank(bob);
        consideration.fulfillBasicOrder{ value: PRICE }(basic);

        assertEq(test721_1.ownerOf(id), bob);
        assertEq(alice.balance, aliceBalance + 2);
        assertEq(_guard(address(consideration)), idleGuard);
    }

    /// @dev Half of a partial ERC1155 order through fulfillAdvancedOrder.
    function _advancedFill(uint256 idleGuard) internal {
        uint256 id = nextId++;
        test1155_1.mint(alice, id, 10);
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem(ItemType.ERC1155, address(test1155_1), id, 10, 10);
        ConsiderationItem[] memory cons = new ConsiderationItem[](1);
        cons[0] =
            ConsiderationItem(ItemType.NATIVE, address(0), 0, 10, 10, alice);
        Order memory order = _signedOrder(offer, cons, OrderType.PARTIAL_OPEN);
        uint256 aliceBalance = alice.balance;

        vm.prank(bob);
        consideration.fulfillAdvancedOrder{ value: 10 }(
            AdvancedOrder(order.parameters, 1, 2, order.signature, ""),
            new CriteriaResolver[](0),
            bytes32(0),
            address(0)
        );

        assertEq(test1155_1.balanceOf(bob, id), 5);
        assertEq(alice.balance, aliceBalance + 5);
        assertEq(_guard(address(consideration)), idleGuard);
    }

    function _signedOrder(
        OfferItem[] memory offer,
        ConsiderationItem[] memory cons,
        OrderType orderType
    ) internal returns (Order memory) {
        OrderParameters memory params = OrderParameters({
            offerer: alice,
            zone: address(0),
            offer: offer,
            consideration: cons,
            orderType: orderType,
            startTime: block.timestamp,
            endTime: block.timestamp + 100,
            zoneHash: bytes32(0),
            salt: globalSalt++,
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: cons.length
        });
        bytes32 orderHash = consideration.getOrderHash(
            toOrderComponents(params, consideration.getCounter(alice))
        );
        return Order(params, signOrder(consideration, alicePk, orderHash));
    }
}
