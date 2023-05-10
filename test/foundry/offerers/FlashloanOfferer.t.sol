// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    GenericAdapterInterface
} from "../../../contracts/contractOfferers/GenericAdapterInterface.sol";

import {
    FlashloanOffererInterface
} from "../../../contracts/contractOfferers/FlashloanOffererInterface.sol";

import {
    GenericAdapter
} from "../../../contracts/contractOfferers/GenericAdapter.sol";

import {
    ReferenceGenericAdapter
} from "../../../reference/contractOfferers/ReferenceGenericAdapter.sol";

import { TestERC721 } from "../../../contracts/test/TestERC721.sol";

import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";

contract GenericAdapterTest is BaseOrderTest {
    struct Context {
        ConsiderationInterface consideration;
        FlashloanOffererInterface flashloanOfferer;
        bool isReference;
    }

    FlashloanOffererInterface testFlashloanOfferer;
    FlashloanOffererInterface testFlashloanOffererReference;
    TestERC721 testERC721;
    TestERC1155 testERC1155;
    bool rejectReceive;

    /**
     * @dev Enable accepting ERC721 tokens via safeTransfer.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        assembly {
            mstore(0, 0x150b7a02)
            return(0x1c, 0x04)
        }
    }

    /**
     * @dev Enable accepting ERC1155 tokens via safeTransfer.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        assembly {
            mstore(0, 0xf23a6e61)
            return(0x1c, 0x04)
        }
    }

    receive() external payable override {
        if (rejectReceive) {
            revert("rejectReceive");
        }
    }

    function setUp() public override {
        super.setUp();

        testFlashloanOfferer = FlashloanOffererInterface(
            deployCode(
                "optimized-out/FlashloanOfferer.sol/FlashloanOfferer.json",
                abi.encode(address(consideration))
            )
        );

        testFlashloanOffererReference = FlashloanOffererInterface(
            deployCode(
                "reference-out/ReferenceFlashloanOfferer.sol/ReferenceFlashloanOfferer.json",
                abi.encode(address(referenceConsideration))
            )
        );

        testERC721 = new TestERC721();
        testERC1155 = new TestERC1155();
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {
            fail(
                "Stateless test function should have reverted with assertion failure status."
            );
        } catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function testReceive() public {
        test(
            this.execReceive,
            Context({
                consideration: consideration,
                flashloanOfferer: testFlashloanOfferer,
                isReference: false
            })
        );
        test(
            this.execReceive,
            Context({
                consideration: referenceConsideration,
                flashloanOfferer: testFlashloanOffererReference,
                isReference: true
            })
        );
    }

    function execReceive(Context memory context) external stateless {
        (bool success, ) = address(context.flashloanOfferer).call{
            value: 1 ether
        }("");
        require(success);
        assertEq(address(context.flashloanOfferer).balance, 1 ether);

        // testERC1155.mint(address(context.flashloanOfferer), 1, 1);
        testERC721.mint(address(this), 2);
        testERC721.safeTransferFrom(
            address(this),
            address(context.flashloanOfferer),
            2
        );
    }
}
