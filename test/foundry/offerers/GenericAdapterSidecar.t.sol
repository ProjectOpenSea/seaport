// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    Call,
    GenericAdapterSidecarInterface
} from "../../../contracts/contractOfferers/GenericAdapterSidecarInterface.sol";

import {
    GenericAdapterSidecar
} from "../../../contracts/contractOfferers/GenericAdapterSidecar.sol";

import {
    ReferenceGenericAdapterSidecar
} from "../../../reference/contractOfferers/ReferenceGenericAdapterSidecar.sol";

import { TestERC721 } from "../../../contracts/test/TestERC721.sol";

import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";

import { BaseOrderTest } from "../utils/BaseOrderTest.sol";

import {
    ConsiderationInterface
} from "../../../contracts/interfaces/ConsiderationInterface.sol";

import "lib/forge-std/src/console.sol";

contract GenericAdapterSidecarTest is BaseOrderTest {
    struct Context {
        ConsiderationInterface consideration;
        GenericAdapterSidecarInterface sidecar;
        bool isReference;
    }

    GenericAdapterSidecarInterface testSidecar;
    GenericAdapterSidecarInterface testSidecarReference;
    TestERC721 testERC721;
    TestERC1155 testERC1155;
    bool rejectReceive;

    function setUp() public override {
        super.setUp();
        testSidecar = GenericAdapterSidecarInterface(
            deployCode(
                "optimized-out/GenericAdapterSidecar.sol/GenericAdapterSidecar.json"
            )
        );
        testSidecarReference = GenericAdapterSidecarInterface(
            deployCode(
                "reference-out/ReferenceGenericAdapterSidecar.sol/ReferenceGenericAdapterSidecar.json"
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
                sidecar: testSidecar,
                isReference: false
            })
        );
        test(
            this.execReceive,
            Context({
                consideration: referenceConsideration,
                sidecar: testSidecarReference,
                isReference: true
            })
        );
    }

    function execReceive(Context memory context) external stateless {
        (bool success, ) = address(context.sidecar).call{ value: 1 ether }("");
        require(success);
        assertEq(address(context.sidecar).balance, 1 ether);

        testERC1155.mint(address(context.sidecar), 1, 1);
        testERC721.mint(address(this), 1);
        testERC721.safeTransferFrom(address(this), address(context.sidecar), 1);
    }

    function testExecuteReturnsNativeBalance() public {
        test(
            this.execExecuteReturnsNativeBalance,
            Context({
                consideration: consideration,
                sidecar: testSidecar,
                isReference: false
            })
        );
        test(
            this.execExecuteReturnsNativeBalance,
            Context({
                consideration: referenceConsideration,
                sidecar: testSidecarReference,
                isReference: true
            })
        );
    }

    function execExecuteReturnsNativeBalance(
        Context memory context
    ) external stateless {
        Call[] memory calls;
        context.sidecar.execute(calls);

        (bool success, ) = address(context.sidecar).call{ value: 1 ether }("");
        require(success);
        assertEq(address(context.sidecar).balance, 1 ether);

        context.sidecar.execute(calls);
        assertEq(address(context.sidecar).balance, 0);

        rejectReceive = true;
        (success, ) = address(context.sidecar).call{ value: 1 ether }("");

        if (context.isReference) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ReferenceGenericAdapterSidecar
                        .NativeTokenTransferGenericFailure
                        .selector
                )
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    GenericAdapterSidecar
                        .ExcessNativeTokenReturnFailed
                        .selector,
                    1 ether
                )
            );
        }

        context.sidecar.execute(calls);
    }

    function testExecuteNotDesignatedCaller() public {
        // test(
        //     this.execExecuteNotDesignatedCaller,
        //     Context({
        //         consideration: consideration,
        //         sidecar: testSidecar,
        //         isReference: false
        //     })
        // );
        test(
            this.execExecuteNotDesignatedCaller,
            Context({
                consideration: referenceConsideration,
                sidecar: testSidecarReference,
                isReference: true
            })
        );
    }

    function execExecuteNotDesignatedCaller(
        Context memory context
    ) external stateless {
        vm.prank(makeAddr("not designated caller"));
        vm.expectRevert(GenericAdapterSidecar.InvalidEncodingOrCaller.selector);
        Call[] memory calls;
        context.sidecar.execute(calls);
    }

    function testExecuteInvalidEncoding() public {
        // Only relevant to the optimized version.
        address sidecarAddress = address(testSidecar);

        bool testCallSuccess;
        assembly {
            mstore(sub(0x80, 0x1c), 0xb252b6e5)
            // Put the 0x20 pointer where the sidecar expects it to be.
            mstore(sub(0xa0, 0x1c), 0x20)
            // I think I need this region to be empty but "existing" or
            // something.
            mstore(0xc0, 0)

            // This should pass the sender check and the encoding check.
            testCallSuccess := call(
                gas(),
                sidecarAddress, // Target address.
                0, // No value.
                0x80, // Call data starts at 0x80.
                0x60, // Call data is 0x60 bytes long.
                0, // Store return data at 0.
                0x20 // Output is 0x20 bytes long.
            )
        }

        assertTrue(testCallSuccess);

        // 0x8f183575 == InvalidEncodingOrCaller()
        vm.expectRevert(abi.encodeWithSignature("InvalidEncodingOrCaller()"));
        assembly {
            // Seems like expectRevert stores the selector at 0xa0 and a size
            // or something at 0xc0, and so on all the way to 0xe0.  So
            // everything in this call needs to be back by five? words. Could
            // also probably get in underneath, but things seem to get pushed
            // back sometimes.

            // Write the execute(Calls[]) selector.
            mstore(sub(0x120, 0x1c), 0xb252b6e5)

            // Put a non-0x20 value where the 0x20 pointer should go.
            // VALUES GREATER THAN 0x20 WORK HERE (expected).  0x20 FAILS BC IT
            // DOESN'T REVERT (expected).  VALUES BETWEEN 0x19 and 0x01 DON'T
            // WORK. THEY GIVE A "Call reverted as expected, but without data".
            // 0 WORKS.
            mstore(sub(0x140, 0x1c), 0x21)

            // When the call fails...
            if iszero(
                call(
                    gas(),
                    sidecarAddress, // Target address.
                    0, // No value.
                    0x120, // Call data starts at 0x120.
                    0x60, // Call data is 0x60 bytes long
                    0, // Where to store the data of the subcontext.
                    0x20 // Output is 0x20 bytes long.
                )
            ) {
                // ... copy the return data into memory and revert with it.
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function testExecuteFailurePermittedToggle() public {
        // test(
        //     this.execExecuteFailurePermittedToggle,
        //     Context({
        //         consideration: consideration,
        //         sidecar: testSidecar,
        //         isReference: false
        //     })
        // );
        test(
            this.execExecuteFailurePermittedToggle,
            Context({
                consideration: referenceConsideration,
                sidecar: testSidecarReference,
                isReference: true
            })
        );
    }

    function execExecuteFailurePermittedToggle(
        Context memory context
    ) external stateless {
        Call[] memory calls = new Call[](1);

        // struct Call {
        //     address target;
        //     bool allowFailure;
        //     uint256 value;
        //     bytes callData;
        // }

        address someTarget = makeAddr("some target");

        Call memory call = Call({
            target: address(testERC721),
            allowFailure: true,
            value: 0,
            callData: abi.encodeWithSelector(
                TestERC721.mint.selector,
                someTarget,
                42069
            )
        });

        console.log("call.callData");
        console.logBytes(call.callData);

        calls[0] = call;

        context.sidecar.execute(calls);

        // address someOtherTarget = makeAddr("some other target");

        // call = Call({
        //     target: someOtherTarget,
        //     allowFailure: true,
        //     value: 0,
        //     callData: abi.encodeWithSelector(
        //         TestERC721.mint.selector,
        //         someTarget, 42
        //     )
        // });

        // calls[0] = call;

        // // // Test that the call doesn't fail when failure is permitted.
        // context.sidecar.execute(calls);

        // calls = new Call[](2);

        // calls[0] = call;

        // call = Call({
        //     target: someTarget,
        //     allowFailure: false,
        //     value: 0,
        //     callData: abi.encodeWithSelector(
        //         TestERC721.mint.selector,
        //         someOtherTarget, 42
        //     )
        // });

        // calls[1] = call;

        // // Test that the call reverts when failure is not permitted.
        // context.sidecar.execute(calls);

        // (bool success, ) = address(context.sidecar).call{ value: 1 ether }("");
        // require(success);
        // assertEq(address(context.sidecar).balance, 1 ether);

        // context.sidecar.execute(calls);
        // assertEq(address(context.sidecar).balance, 0);

        // rejectReceive = true;
        // (success, ) = address(context.sidecar).call{ value: 1 ether }("");

        // if (context.isReference) {
        //     vm.expectRevert(
        //         abi.encodeWithSelector(
        //             ReferenceGenericAdapterSidecar
        //                 .NativeTokenTransferGenericFailure
        //                 .selector
        //         )
        //     );
        // } else {
        //     vm.expectRevert(
        //         abi.encodeWithSelector(
        //             GenericAdapterSidecar
        //                 .ExcessNativeTokenReturnFailed
        //                 .selector,
        //             1 ether
        //         )
        //     );
        // }

        // context.sidecar.execute(calls);
    }

    receive() external payable override {
        if (rejectReceive) {
            revert("rejectReceive");
        }
    }
}
