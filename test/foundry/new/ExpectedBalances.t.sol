// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { stdError, Test } from "forge-std/Test.sol";

import { Execution, ReceivedItem } from "seaport-sol/src/SeaportStructs.sol";

import { ItemType } from "seaport-sol/src/SeaportEnums.sol";

import {
    BalanceErrorMessages,
    ERC721TokenDump,
    ExpectedBalances
} from "./helpers/ExpectedBalances.sol";

import { TestERC20 } from "../../../contracts/test/TestERC20.sol";

import { TestERC721 } from "../../../contracts/test/TestERC721.sol";

import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";

contract ExpectedBalancesTest is Test {
    TestERC20 internal erc20;
    TestERC721 internal erc721;
    TestERC1155 internal erc1155;

    ExpectedBalances internal balances;

    address payable internal alice = payable(address(0xa11ce));
    address payable internal bob = payable(address(0xb0b));

    function setUp() public virtual {
        balances = new ExpectedBalances();
        _deployTestTokenContracts();
    }

    function testAddTransfers() external {
        erc20.mint(alice, 500);
        erc721.mint(bob, 1);
        erc1155.mint(bob, 1, 100);
        vm.deal(alice, 1 ether);
        Execution[] memory executions = new Execution[](4);

        executions[0] = Execution({
            offerer: alice,
            conduitKey: bytes32(0),
            item: ReceivedItem(
                ItemType.NATIVE,
                address(0),
                0,
                0.5 ether,
                payable(bob)
            )
        });
        executions[1] = Execution({
            offerer: alice,
            conduitKey: bytes32(0),
            item: ReceivedItem(
                ItemType.ERC20,
                address(erc20),
                0,
                250,
                payable(bob)
            )
        });
        executions[2] = Execution({
            offerer: bob,
            conduitKey: bytes32(0),
            item: ReceivedItem(
                ItemType.ERC721,
                address(erc721),
                1,
                1,
                payable(alice)
            )
        });
        executions[3] = Execution({
            offerer: bob,
            conduitKey: bytes32(0),
            item: ReceivedItem(
                ItemType.ERC1155,
                address(erc1155),
                1,
                50,
                payable(alice)
            )
        });
        balances.addTransfers(executions);
        vm.prank(alice);
        erc20.transfer(bob, 250);

        vm.prank(bob);
        erc721.transferFrom(bob, alice, 1);

        vm.prank(bob);
        erc1155.safeTransferFrom(bob, alice, 1, 50, "");

        vm.prank(alice);
        bob.transfer(0.5 ether);

        balances.checkBalances();
    }

    function testCheckBalances() external {
        erc20.mint(alice, 500);
        erc721.mint(bob, 1);
        erc1155.mint(bob, 1, 100);
        vm.deal(alice, 1 ether);

        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.NATIVE,
                    address(0),
                    0,
                    0.5 ether,
                    payable(bob)
                )
            })
        );
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC20,
                    address(erc20),
                    0,
                    250,
                    payable(bob)
                )
            })
        );
        balances.addTransfer(
            Execution({
                offerer: bob,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC721,
                    address(erc721),
                    1,
                    1,
                    payable(alice)
                )
            })
        );
        balances.addTransfer(
            Execution({
                offerer: bob,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC1155,
                    address(erc1155),
                    1,
                    50,
                    payable(alice)
                )
            })
        );
        vm.prank(alice);
        erc20.transfer(bob, 250);

        vm.prank(bob);
        erc721.transferFrom(bob, alice, 1);

        vm.prank(bob);
        erc1155.safeTransferFrom(bob, alice, 1, 50, "");

        vm.prank(alice);
        bob.transfer(0.5 ether);

        balances.checkBalances();
    }

    // =====================================================================//
    //                            NATIVE TESTS                              //
    // =====================================================================//

    function testNativeInsufficientBalance() external {
        vm.expectRevert(
            bytes(
                BalanceErrorMessages.insufficientNativeBalance(
                    alice,
                    bob,
                    0,
                    1,
                    false
                )
            )
        );
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.NATIVE,
                    address(0),
                    0,
                    alice.balance + 1,
                    payable(bob)
                )
            })
        );
    }

    function testNativeExtraBalance() external {
        vm.deal(alice, 0.5 ether);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.NATIVE,
                    address(0),
                    0,
                    0.5 ether,
                    payable(bob)
                )
            })
        );
        vm.deal(bob, 0.5 ether);
        vm.expectRevert(
            bytes(
                BalanceErrorMessages.nativeUnexpectedBalance(
                    alice,
                    0,
                    0.5 ether
                )
            )
        );

        balances.checkBalances();
    }

    function testNativeNotTransferred() external {
        vm.deal(alice, 0.5 ether);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.NATIVE,
                    address(0),
                    0,
                    0.5 ether,
                    payable(bob)
                )
            })
        );
        vm.prank(alice);
        payable(address(1000)).transfer(0.5 ether);

        vm.expectRevert(
            bytes(
                BalanceErrorMessages.nativeUnexpectedBalance(bob, 0.5 ether, 0)
            )
        );
        balances.checkBalances();
    }

    // =====================================================================//
    //                             ERC20 TESTS                              //
    // =====================================================================//

    function testERC20InsufficientBalance() external {
        vm.expectRevert(
            bytes(
                BalanceErrorMessages.insufficientERC20Balance(
                    address(erc20),
                    alice,
                    bob,
                    0,
                    200,
                    false
                )
            )
        );
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC20,
                    address(erc20),
                    0,
                    200,
                    payable(bob)
                )
            })
        );
    }

    function testERC20ExtraBalance() external {
        erc20.mint(alice, 10);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC20,
                    address(erc20),
                    0,
                    5,
                    payable(bob)
                )
            })
        );
        vm.prank(alice);
        erc20.transfer(bob, 5);
        erc20.mint(alice, 1);

        vm.expectRevert(
            bytes(
                BalanceErrorMessages.erc20UnexpectedBalance(
                    address(erc20),
                    alice,
                    5,
                    6
                )
            )
        );
        balances.checkBalances();
    }

    function testERC20NotTransferred() external {
        erc20.mint(alice, 10);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC20,
                    address(erc20),
                    0,
                    5,
                    payable(bob)
                )
            })
        );

        vm.expectRevert(
            bytes(
                BalanceErrorMessages.erc20UnexpectedBalance(
                    address(erc20),
                    alice,
                    5,
                    10
                )
            )
        );
        balances.checkBalances();
    }

    function testERC20MultipleSenders() external {
        erc20.mint(alice, 100);
        erc20.mint(bob, 200);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC20,
                    address(erc20),
                    0,
                    50,
                    payable(bob)
                )
            })
        );
        balances.addTransfer(
            Execution({
                offerer: bob,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC20,
                    address(erc20),
                    0,
                    50,
                    payable(alice)
                )
            })
        );
        balances.checkBalances();
    }

    // =====================================================================//
    //                            ERC721 TESTS                              //
    // =====================================================================//

    function xtestERC721InsufficientBalance() external {
        erc721.mint(bob, 1);
        vm.expectRevert(stdError.arithmeticError);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC721,
                    address(erc721),
                    1,
                    1,
                    payable(bob)
                )
            })
        );
    }

    function testERC721ExtraBalance() external {
        erc721.mint(alice, 1);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC721,
                    address(erc721),
                    1,
                    1,
                    payable(bob)
                )
            })
        );
        erc721.mint(alice, 2);

        vm.expectRevert(
            bytes(
                BalanceErrorMessages.erc721UnexpectedBalance(
                    address(erc721),
                    alice,
                    0,
                    2
                )
            )
        );
        balances.checkBalances();
    }

    function testERC721NotTransferred() external {
        erc721.mint(alice, 1);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC721,
                    address(erc721),
                    1,
                    1,
                    payable(bob)
                )
            })
        );
        erc721.mint(bob, 2);
        vm.prank(alice);
        erc721.transferFrom(alice, address(1000), 1);
        vm.expectRevert(
            "ExpectedBalances: account does not own expected token"
        );
        balances.checkBalances();
    }

    function testERC721MultipleIdentifiers() external {
        erc721.mint(alice, 1);
        erc721.mint(alice, 2);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC721,
                    address(erc721),
                    1,
                    1,
                    payable(bob)
                )
            })
        );
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC721,
                    address(erc721),
                    2,
                    1,
                    payable(bob)
                )
            })
        );
        vm.prank(alice);
        erc721.transferFrom(alice, bob, 1);
        vm.prank(alice);
        erc721.transferFrom(alice, bob, 2);
        balances.checkBalances();
    }

    // =====================================================================//
    //                            ERC1155 TESTS                             //
    // =====================================================================//

    function testERC1155InsufficientBalance() external {
        vm.expectRevert(
            bytes(
                BalanceErrorMessages.insufficientERC1155Balance(
                    address(erc1155),
                    0,
                    alice,
                    bob,
                    0,
                    200,
                    false
                )
            )
        );
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC1155,
                    address(erc1155),
                    0,
                    200,
                    payable(bob)
                )
            })
        );
    }

    function testERC1155ExtraBalance() external {
        erc1155.mint(alice, 1, 10);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC1155,
                    address(erc1155),
                    1,
                    5,
                    payable(bob)
                )
            })
        );
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, bob, 1, 5, "");
        erc1155.mint(alice, 1, 1);

        vm.expectRevert(
            bytes(
                BalanceErrorMessages.erc1155UnexpectedBalance(
                    address(erc1155),
                    alice,
                    1,
                    5,
                    6
                )
            )
        );
        balances.checkBalances();
    }

    function testERC1155NotTransferred() external {
        erc1155.mint(alice, 1, 10);
        balances.addTransfer(
            Execution({
                offerer: alice,
                conduitKey: bytes32(0),
                item: ReceivedItem(
                    ItemType.ERC1155,
                    address(erc1155),
                    1,
                    5,
                    payable(bob)
                )
            })
        );
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(1000), 1, 5, "");
        vm.expectRevert(
            bytes(
                BalanceErrorMessages.erc1155UnexpectedBalance(
                    address(erc1155),
                    bob,
                    1,
                    5,
                    0
                )
            )
        );
        balances.checkBalances();
    }

    /**
     * @dev Deploy test token contracts.
     */
    function _deployTestTokenContracts() internal {
        createErc20Token();
        createErc721Token();
        createErc1155Token();
    }

    function createErc20Token() internal {
        TestERC20 token = new TestERC20();
        erc20 = token;
        vm.label(address(token), "ERC20");
    }

    function createErc721Token() internal {
        TestERC721 token = new TestERC721();
        erc721 = token;
        vm.label(address(token), "ERC721");
    }

    function createErc1155Token() internal {
        TestERC1155 token = new TestERC1155();
        erc1155 = token;
        vm.label(address(token), "ERC1155");
    }
}
