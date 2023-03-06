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
        GenericAdapterInterface adapter;
        bool isReference;
    }

    GenericAdapterInterface testAdapter;
    GenericAdapterInterface testAdapterReference;
    FlashloanOffererInterface testFlashloanOfferer;
    FlashloanOffererInterface testFlashloanOffererReference;
    TestERC721 testERC721;
    TestERC1155 testERC1155;
    bool rejectReceive;

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

        testAdapter = GenericAdapterInterface(
            deployCode(
                "optimized-out/GenericAdapter.sol/GenericAdapter.json",
                abi.encode(address(consideration), address(testFlashloanOfferer))
            )
        );
        testAdapterReference = GenericAdapterInterface(
            deployCode(
                "reference-out/ReferenceGenericAdapter.sol/ReferenceGenericAdapter.json",
                abi.encode(address(referenceConsideration), address(testFlashloanOffererReference))
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
                adapter: testAdapter,
                isReference: false
            })
        );
        test(
            this.execReceive,
            Context({
                consideration: referenceConsideration,
                adapter: testAdapterReference,
                isReference: true
            })
        );
    }

    function execReceive(Context memory context) external stateless {
        (bool success, ) = address(context.adapter).call{ value: 1 ether }("");
        require(success);
        assertEq(address(context.adapter).balance, 1 ether);

        testERC1155.mint(address(context.adapter), 1, 1);
        testERC721.mint(address(this), 1);
        testERC721.safeTransferFrom(address(this), address(context.adapter), 1);
    }
}
