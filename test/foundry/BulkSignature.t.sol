// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./utils//BaseOrderTest.sol";

import { EIP712MerkleTree } from "./utils/EIP712MerkleTree.sol";

import {
    ConsiderationInterface
} from "../../contracts/interfaces/ConsiderationInterface.sol";

import {
    OrderComponents,
    OrderParameters,
    ConsiderationItem,
    OfferItem,
    Order,
    OrderType
} from "../../contracts/lib/ConsiderationStructs.sol";

import { ItemType } from "../../contracts/lib/ConsiderationEnums.sol";

contract BulkSignatureTest is BaseOrderTest {
    OrderComponents private _empty;
    SparseArgs private _defaultArgs = SparseArgs({ height: 2, orderIndex: 0 });

    struct Context {
        ConsiderationInterface seaport;
        bool useCompact2098;
        SparseArgs args;
    }

    struct SparseArgs {
        uint8 height;
        uint24 orderIndex;
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testBulkSignature() public {
        test(
            this.execBulkSignature,
            Context({
                seaport: consideration,
                args: _defaultArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignature,
            Context({
                seaport: referenceConsideration,
                args: _defaultArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignature,
            Context({
                seaport: consideration,
                args: _defaultArgs,
                useCompact2098: true
            })
        );
        test(
            this.execBulkSignature,
            Context({
                seaport: referenceConsideration,
                args: _defaultArgs,
                useCompact2098: true
            })
        );
    }

    function execBulkSignature(Context memory context) external stateless {
        string memory offerer = "offerer";
        (address addr, uint256 key) = makeAddrAndKey(offerer);
        addErc721OfferItem(1);
        test721_1.mint(address(addr), 1);
        vm.prank(addr);
        test721_1.setApprovalForAll(address(context.seaport), true);
        addConsiderationItem(
            ConsiderationItem({
                itemType: ItemType.NATIVE,
                token: address(0),
                identifierOrCriteria: 0,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(addr)
            })
        );
        configureOrderParameters(addr);
        configureOrderComponents(context.seaport);
        OrderComponents[] memory orderComponents = new OrderComponents[](3);
        orderComponents[0] = baseOrderComponents;
        // other order components can remain empty

        EIP712MerkleTree merkleTree = new EIP712MerkleTree();
        bytes memory bulkSignature = merkleTree.signBulkOrder(
            context.seaport,
            key,
            orderComponents,
            uint24(0),
            context.useCompact2098
        );
        Order memory order = Order({
            parameters: baseOrderParameters,
            signature: bulkSignature
        });
        context.seaport.fulfillOrder{ value: 1 }(order, bytes32(0));

        // merkleTree.
    }

    function testBulkSignatureSparse() public {
        test(
            this.execBulkSignatureSparse,
            Context({
                seaport: consideration,
                args: _defaultArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignatureSparse,
            Context({
                seaport: referenceConsideration,
                args: _defaultArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignatureSparse,
            Context({
                seaport: consideration,
                args: _defaultArgs,
                useCompact2098: true
            })
        );
        test(
            this.execBulkSignatureSparse,
            Context({
                seaport: referenceConsideration,
                args: _defaultArgs,
                useCompact2098: true
            })
        );
    }

    function execBulkSignatureSparse(
        Context memory context
    ) external stateless {
        string memory offerer = "offerer";
        (address addr, uint256 key) = makeAddrAndKey(offerer);
        addErc721OfferItem(1);
        test721_1.mint(address(addr), 1);
        vm.prank(addr);
        test721_1.setApprovalForAll(address(context.seaport), true);
        addConsiderationItem(
            ConsiderationItem({
                itemType: ItemType.NATIVE,
                token: address(0),
                identifierOrCriteria: 0,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(addr)
            })
        );
        configureOrderParameters(addr);
        configureOrderComponents(context.seaport);
        OrderComponents[] memory orderComponents = new OrderComponents[](3);
        orderComponents[0] = baseOrderComponents;
        // other order components can remain empty

        EIP712MerkleTree merkleTree = new EIP712MerkleTree();
        bytes memory bulkSignature = merkleTree.signSparseBulkOrder(
            context.seaport,
            key,
            baseOrderComponents,
            context.args.height,
            context.args.orderIndex,
            context.useCompact2098
        );
        Order memory order = Order({
            parameters: baseOrderParameters,
            signature: bulkSignature
        });
        context.seaport.fulfillOrder{ value: 1 }(order, bytes32(0));
    }

    function testSparseBulkSignatureFuzz(SparseArgs memory sparseArgs) public {
        sparseArgs.height = uint8(bound(sparseArgs.height, 1, 24));
        sparseArgs.orderIndex = uint24(
            bound(sparseArgs.orderIndex, 0, 2 ** uint256(sparseArgs.height) - 1)
        );

        test(
            this.execBulkSignatureSparse,
            Context({
                seaport: consideration,
                args: sparseArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignatureSparse,
            Context({
                seaport: referenceConsideration,
                args: sparseArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignatureSparse,
            Context({
                seaport: consideration,
                args: sparseArgs,
                useCompact2098: true
            })
        );
        test(
            this.execBulkSignatureSparse,
            Context({
                seaport: referenceConsideration,
                args: sparseArgs,
                useCompact2098: true
            })
        );
    }

    function execBulkSignatureIndexOutOfBounds(
        Context memory context
    ) external stateless {
        string memory offerer = "offerer";
        (address addr, uint256 key) = makeAddrAndKey(offerer);
        addErc721OfferItem(1);
        test721_1.mint(address(addr), 1);
        test721_1.mint(address(addr), 2);
        vm.prank(addr);
        test721_1.setApprovalForAll(address(context.seaport), true);
        addConsiderationItem(
            ConsiderationItem({
                itemType: ItemType.NATIVE,
                token: address(0),
                identifierOrCriteria: 0,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(addr)
            })
        );
        configureOrderParameters(addr);
        configureOrderComponents(context.seaport);
        OrderComponents[] memory orderComponents = new OrderComponents[](3);
        orderComponents[0] = baseOrderComponents;

        (
            OrderParameters memory secondOrderParameters,
            OrderComponents memory secondOrderComponents
        ) = setUpSecondOrder(context, addr);

        orderComponents[1] = secondOrderComponents;

        EIP712MerkleTree merkleTree = new EIP712MerkleTree();

        // Get the signature for the second order.
        bytes memory bulkSignature = merkleTree.signBulkOrder(
            context.seaport,
            key,
            orderComponents,
            1,
            context.useCompact2098
        );

        Order memory order = Order({
            parameters: secondOrderParameters,
            signature: bulkSignature
        });

        // Fulfill the second order.
        context.seaport.fulfillOrder{ value: 1 }(order, bytes32(0));
        assertEq(test721_1.ownerOf(2), address(this));

        // Get the signature for the first order.
        bulkSignature = merkleTree.signBulkOrder(
            context.seaport,
            key,
            orderComponents,
            0,
            context.useCompact2098
        );

        uint256 signatureLength = context.useCompact2098 ? 64 : 65;

        // Swap in a fake index.  Here, we use 4 instead of 0.
        assembly {
            // mload(bulkSignature) := signatureLength
            let indexAndProofDataPointer := add(
                signatureLength,
                add(bulkSignature, 0x20)
            )
            let indexAndProofData := mload(indexAndProofDataPointer)
            let maskedProofData := and(
                indexAndProofData,
                0x000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            )
            let fakeIndexAndProofData := or(
                maskedProofData,
                0x0000040000000000000000000000000000000000000000000000000000000000
            )
            mstore(indexAndProofDataPointer, fakeIndexAndProofData)
        }

        order = Order({
            parameters: baseOrderParameters,
            signature: bulkSignature
        });

        // Fulfill the first order using th bulk signature with the out of
        // bounds index..
        context.seaport.fulfillOrder{ value: 1 }(order, bytes32(0));

        // Should wrap around and fulfill the first order, which is for token ID
        // 1.
        assertEq(test721_1.ownerOf(1), address(this));
    }

    function setUpSecondOrder(
        Context memory context,
        address addr
    )
        public
        view
        returns (
            OrderParameters memory _secondOrderParameters,
            OrderComponents memory _secondOrderComponents
        )
    {
        OfferItem memory secondOfferItem;
        secondOfferItem = OfferItem(
            ItemType.ERC721,
            address(test721_1),
            2,
            1,
            1
        );

        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = secondOfferItem;

        OrderParameters memory secondOrderParameters = OrderParameters(
            address(addr),
            address(0),
            offerItems,
            considerationItems,
            OrderType.FULL_OPEN,
            block.timestamp,
            block.timestamp + 1,
            bytes32(0),
            0,
            bytes32(0),
            1
        );

        OrderComponents memory secondOrderComponents = getOrderComponents(
            secondOrderParameters,
            context.seaport.getCounter(addr)
        );

        return (secondOrderParameters, secondOrderComponents);
    }

    function testExecBulkSignatureIndexOutOfBounds() public {
        test(
            this.execBulkSignatureIndexOutOfBounds,
            Context({
                seaport: consideration,
                args: _defaultArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignatureIndexOutOfBounds,
            Context({
                seaport: referenceConsideration,
                args: _defaultArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignatureIndexOutOfBounds,
            Context({
                seaport: consideration,
                args: _defaultArgs,
                useCompact2098: true
            })
        );
        test(
            this.execBulkSignatureIndexOutOfBounds,
            Context({
                seaport: referenceConsideration,
                args: _defaultArgs,
                useCompact2098: true
            })
        );
    }
}
