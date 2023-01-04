// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";
import { PassthroughOfferer } from "./impl/PassthroughOfferer.sol";
import { Merkle } from "murky/Merkle.sol";
import {
    ERC20Interface,
    ERC721Interface
} from "../../../contracts/interfaces/AbridgedTokenInterfaces.sol";
import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";
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

contract OffererCriteriaAdvancedTest is BaseOrderTest {
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
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testCriteriaMinimumReceived() public {
        setUpCriteriaMinimumReceived();

        test(
            this.execCriteriaMinimumReceived,
            Context({ seaport: consideration })
        );
        test(
            this.execCriteriaMinimumReceived,
            Context({ seaport: referenceConsideration })
        );
    }

    function setUpCriteriaMinimumReceived() internal {
        (bytes32 root, bytes32[] memory proof) = getRootAndProof(2);
        // addOfferItem type ERC721_WITH_CRITERIA, criteria equal to root of merkle tree
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
        configureAdvancedOrder();
    }

    function execCriteriaMinimumReceived(
        Context memory context
    ) external stateless {
        fulfillAdvanced(context, configureAdvancedOrder());
        assertEq(test721_1.ownerOf(2), address(this));
    }

    function testCriteriaMaximumSpent() public {
        setUpCriteriaMaximumSpent();

        test(
            this.execCriteriaMaximumSpent,
            Context({ seaport: consideration })
        );
        test(
            this.execCriteriaMaximumSpent,
            Context({ seaport: referenceConsideration })
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
        // addConsiderationItem type ERC721_WITH_CRITERIA, criteria equal to root of merkle tree, recipient offerer
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

        // add criteria resolver for side consideration, orderIndex 0, index 0, identifier 2, proof
        criteriaResolvers.push(
            CriteriaResolver({
                orderIndex: 0,
                side: Side.CONSIDERATION,
                index: 0,
                identifier: 1,
                criteriaProof: proof
            })
        );
        configureAdvancedOrder();
    }

    function execCriteriaMaximumSpent(
        Context memory context
    ) external stateless {
        fulfillAdvanced(context, configureAdvancedOrder());
        // assertEq(test721_1.ownerOf(1), address(offerer));
    }

    function configureAdvancedOrder() internal returns (AdvancedOrder memory) {
        return
            AdvancedOrder({
                parameters: getOrderParameters(
                    address(offerer),
                    OrderType.CONTRACT
                ),
                numerator: 1,
                denominator: 1,
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

    function getRootAndProof(
        uint256 identifier
    ) internal returns (bytes32 root, bytes32[] memory proof) {
        Merkle tree = new Merkle();
        bytes32[] memory leaves = generateLeaves();
        root = tree.getRoot(leaves);
        proof = tree.getProof(leaves, identifier);
        return (root, proof);
    }

    /**
     * @dev Generate hashed leaves for identifiers [0,50) for insertion into a Merkle tree.
     */
    function generateLeaves() internal pure returns (bytes32[] memory) {
        uint256[] memory leaves = new uint256[](50);
        for (uint256 i = 0; i < leaves.length; ++i) {
            leaves[i] = i;
        }
        return toHashedLeaves(leaves);
    }
}
