// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseOrderTest } from "./utils//BaseOrderTest.sol";
import { EIP712MerkleTree } from "./utils/EIP712Merkletree.sol";
import {
    ConsiderationInterface
} from "../../contracts/interfaces/ConsiderationInterface.sol";
import {
    OrderComponents,
    ConsiderationItem,
    Order
} from "../../contracts/lib/ConsiderationStructs.sol";
import { ItemType } from "../../contracts/lib/ConsiderationEnums.sol";

contract BulkSignatureTest is BaseOrderTest {
    OrderComponents private _empty;

    struct Context {
        ConsiderationInterface seaport;
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
        test(this.execBulkSignature, Context({ seaport: consideration }));
        test(
            this.execBulkSignature,
            Context({ seaport: referenceConsideration })
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
        // orderComponents[1] = _empty;

        EIP712MerkleTree merkleTree = new EIP712MerkleTree();
        bytes memory bulkSignature = merkleTree.signBulkOrder(
            context.seaport,
            key,
            orderComponents,
            uint24(0)
        );
        bytes32 orderHash = context.seaport.getOrderHash(baseOrderComponents);
        bytes memory regularSignature = signOrder(
            context.seaport,
            key,
            orderHash
        );
        Order memory order = Order({
            parameters: baseOrderParameters,
            signature: bulkSignature
        });
        context.seaport.fulfillOrder{ value: 1 }(order, bytes32(0));

        // merkleTree.
    }
}
