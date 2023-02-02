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
        // The other order components can remain empty.

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
        // The other order components can remain empty.

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

    function testBulkSignatureSparseFuzz(SparseArgs memory sparseArgs) public {
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

    // This tests the "targeting" of orders in the out-of-range index case.
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

        // Get the signature for the order at index 0.
        bytes memory bulkSignature = merkleTree.signBulkOrder(
            context.seaport,
            key,
            orderComponents,
            0,
            context.useCompact2098
        );

        Order memory order = Order({
            parameters: baseOrderParameters,
            signature: bulkSignature
        });

        // Fulfill the order at index 0.
        context.seaport.fulfillOrder{ value: 1 }(order, bytes32(0));
        assertEq(test721_1.ownerOf(1), address(this));

        // Get the signature for the order at index 1.
        bulkSignature = merkleTree.signBulkOrder(
            context.seaport,
            key,
            orderComponents,
            1,
            context.useCompact2098
        );

        uint256 signatureLength = context.useCompact2098 ? 64 : 65;

        // Swap in a fake index.  Here, we use 5 instead of 1.
        assembly {
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
                0x0000050000000000000000000000000000000000000000000000000000000000
            )
            mstore(indexAndProofDataPointer, fakeIndexAndProofData)
        }

        order = Order({
            parameters: secondOrderParameters,
            signature: bulkSignature
        });

        // Fulfill the order order at index 1 using the bulk signature with the
        // out of bounds index (5).
        context.seaport.fulfillOrder{ value: 1 }(order, bytes32(0));

        // Should wrap around and fulfill the order at index 1, which is for
        // token ID 2.
        assertEq(test721_1.ownerOf(2), address(this));
    }

    // Pulled out bc of stacc2dank but can be moved or cleaned up in some better
    // way.
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

    // This tests the overflow behavior for trees of different heights.
    function execBulkSignatureSparseIndexOutOfBounds(
        Context memory context
    ) external stateless {
        // Set up the boilerplate for the offerer.
        string memory offerer = "offerer";
        (address addr, uint256 key) = makeAddrAndKey(offerer);
        addErc721OfferItem(1);
        test721_1.mint(address(addr), 1);
        vm.prank(addr);
        test721_1.setApprovalForAll(address(context.seaport), true);
        // Set up the order.
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
        // The other order components can remain empty because
        // `signSparseBulkOrder` will fill them in with empty orders and we only
        // care about one order.

        EIP712MerkleTree merkleTree = new EIP712MerkleTree();

        // Get the real signature.
        bytes memory bulkSignature = merkleTree.signSparseBulkOrder(
            context.seaport,
            key,
            baseOrderComponents,
            context.args.height,
            context.args.orderIndex,
            context.useCompact2098
        );

        // The memory region that needs to be modified depends on the signature
        // length.
        uint256 signatureLength = context.useCompact2098 ? 64 : 65;
        // Set up an index equal to orderIndex + 2 ** tree height.
        uint256 index = context.args.orderIndex + (2 ** context.args.height);
        uint24 convertedIndex = uint24(index);

        // Use assembly to swap in a fake index.
        assembly {
            // Get the pointer to the index and proof data.
            let indexAndProofDataPointer := add(
                signatureLength,
                add(bulkSignature, 0x20)
            )
            // Load the index and proof data into memory.
            let indexAndProofData := mload(indexAndProofDataPointer)
            // Mask for the index.
            let maskedProofData := and(
                indexAndProofData,
                0x000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            )
            // 256 - 24 = 232
            // Create a new value the same as the old value, except that it uses
            // the fake index.
            let fakeIndexAndProofData := or(
                maskedProofData,
                // Shift the fake index left by 232 bits to produce a value to
                // `or` with the `maskedProofData`.  For example:
                // `0x000005000...`
                shl(232, convertedIndex)
            )
            // Store the fake index and proof data at the
            // indexAndProofDataPointer location.
            mstore(indexAndProofDataPointer, fakeIndexAndProofData)
        }

        // Create an order using the `bulkSignature` that was modified in the
        // assembly block above.
        Order memory order = Order({
            parameters: baseOrderParameters,
            signature: bulkSignature
        });

        // This should wrap around and fulfill the order at the index equal to
        // (the fake order index - (height ** 2)).
        context.seaport.fulfillOrder{ value: 1 }(order, bytes32(0));
    }

    function testBulkSignatureSparseIndexOutOfBoundsFuzz(
        SparseArgs memory sparseArgs
    ) public {
        sparseArgs.height = uint8(bound(sparseArgs.height, 1, 24));
        sparseArgs.orderIndex = uint24(
            bound(sparseArgs.orderIndex, 0, 2 ** uint256(sparseArgs.height) - 1)
        );

        test(
            this.execBulkSignatureSparseIndexOutOfBounds,
            Context({
                seaport: consideration,
                args: sparseArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignatureSparseIndexOutOfBounds,
            Context({
                seaport: referenceConsideration,
                args: sparseArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignatureSparseIndexOutOfBounds,
            Context({
                seaport: consideration,
                args: sparseArgs,
                useCompact2098: true
            })
        );
        test(
            this.execBulkSignatureSparseIndexOutOfBounds,
            Context({
                seaport: referenceConsideration,
                args: sparseArgs,
                useCompact2098: true
            })
        );
    }

    // This tests that indexes other than the predicted overflow indexes do not
    // work.
    function execBulkSignatureSparseIndexOutOfBoundsNonHits(
        Context memory context
    ) external stateless {
        // Set up the boilerplate for the offerer.
        string memory offerer = "offerer";
        (address addr, uint256 key) = makeAddrAndKey(offerer);
        addErc721OfferItem(1);
        test721_1.mint(address(addr), 1);
        vm.prank(addr);
        test721_1.setApprovalForAll(address(context.seaport), true);
        // Set up the order.
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
        // The other order components can remain empty because
        // `signSparseBulkOrder` will fill them in with empty orders and we only
        // care about one order.

        EIP712MerkleTree merkleTree = new EIP712MerkleTree();

        uint256 treeHeight = 8;

        // Get the real signature.
        bytes memory bulkSignature = merkleTree.signSparseBulkOrder(
            context.seaport,
            key,
            baseOrderComponents,
            treeHeight,
            uint24(0),
            context.useCompact2098
        );

        // The memory region that needs to be modified depends on the signature
        // length.
        uint256 signatureLength = context.useCompact2098 ? 64 : 65;
        uint256 firstExpectedOverflowIndex = 2 ** treeHeight;
        uint256 secondExpectedOverflowIndex = (2 ** treeHeight) * 2;

        uint24 convertedIndex;
        Order memory order;

        // Iterate over all indexes from the firstExpectedOverflowIndex + 1 to
        // the secondExpectedOverflowIndex, inclusive, and make sure that none
        // of them work except the expected indexes.
        for (
            uint256 i = firstExpectedOverflowIndex + 1;
            i <= secondExpectedOverflowIndex;
            ++i
        ) {
            convertedIndex = uint24(i);

            // Use assembly to swap a fake index into the bulkSignature.
            assembly {
                // Get the pointer to the index and proof data.
                let indexAndProofDataPointer := add(
                    signatureLength,
                    add(bulkSignature, 0x20)
                )
                // Load the index and proof data into memory.
                let indexAndProofData := mload(indexAndProofDataPointer)
                // Mask for the index.
                let maskedProofData := and(
                    indexAndProofData,
                    0x000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )
                // 256 - 24 = 232
                // Create a new value the same as the old value, except that it
                // uses the fake index.
                let fakeIndexAndProofData := or(
                    maskedProofData,
                    // Shift the fake index left by 232 bits to produce a value
                    // to `or` with the `maskedProofData`.  For example:
                    // `0x000005000...`
                    shl(232, convertedIndex)
                )
                // Store the fake index and proof data at the
                // indexAndProofDataPointer location.
                mstore(indexAndProofDataPointer, fakeIndexAndProofData)
            }

            // Create an order using the `bulkSignature` that was modified in
            // the assembly block above.
            order = Order({
                parameters: baseOrderParameters,
                signature: bulkSignature
            });

            // Expect a revert for all indexes except the
            // secondExpectedOverflowIndex. The starting range should revert
            // with `InvalidSigner`, and the secondExpectedOverflowIndex should
            // fulfill the order.
            if (i != secondExpectedOverflowIndex) {
                // Expect InvalidSigner because we're trying to recover the
                // signer using a signature and proof for one of the dummy
                // orders that signSparseBulkOrder filled in.
                vm.expectRevert(abi.encodeWithSignature("InvalidSigner()"));
            }
            context.seaport.fulfillOrder{ value: 1 }(order, bytes32(0));
        }
    }

    function testBulkSignatureSparseIndexOutOfBoundsNonHits() public {
        test(
            this.execBulkSignatureSparseIndexOutOfBoundsNonHits,
            Context({
                seaport: consideration,
                args: _defaultArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignatureSparseIndexOutOfBoundsNonHits,
            Context({
                seaport: referenceConsideration,
                args: _defaultArgs,
                useCompact2098: false
            })
        );
        test(
            this.execBulkSignatureSparseIndexOutOfBoundsNonHits,
            Context({
                seaport: consideration,
                args: _defaultArgs,
                useCompact2098: true
            })
        );
        test(
            this.execBulkSignatureSparseIndexOutOfBoundsNonHits,
            Context({
                seaport: referenceConsideration,
                args: _defaultArgs,
                useCompact2098: true
            })
        );
    }
}
