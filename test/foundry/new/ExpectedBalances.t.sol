// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../../contracts/lib/ConsiderationStructs.sol";
import {
    ExpectedBalances,
    ERC721TokenDump
} from "./helpers/ExpectedBalances.sol";
// import "./ExpectedBalanceSerializer.sol";
import "forge-std/Test.sol";
// import "forge-std/StdError.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";

import { TestERC721 } from "../../../contracts/test/TestERC721.sol";

import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";

contract ExpectedBalancesTest is Test {
    TestERC20 internal erc20;
    TestERC721 internal erc721;
    TestERC1155 internal erc1155;

    ExpectedBalances internal balances;

    function setUp() public virtual {
        balances = new ExpectedBalances();
        _deployTestTokenContracts();
    }

    function testERC20InsufficientBalance(address alice, address bob) external {
        vm.expectRevert(stdError.arithmeticError);
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

    function testERC1155InsufficientBalance(
        address alice,
        address bob
    ) external {
        vm.expectRevert(stdError.arithmeticError);
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

    function test1(address alice, address bob) external {
        if (alice == address(0)) {
            alice = address(1);
        }
        if (bob == address(0)) {
            bob = address(2);
        }
        erc20.mint(alice, 500);
        erc721.mint(bob, 1);
        erc1155.mint(bob, 1, 100);
        vm.prank(alice);
        erc20.transfer(bob, 250);

        vm.prank(bob);
        erc721.transferFrom(bob, alice, 1);

        vm.prank(bob);
        erc1155.safeTransferFrom(bob, alice, 1, 50, "");

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
        balances.checkBalances();

        // balances.addTransfer(
        //     Execution({
        //         offerer: bob,
        //         conduitKey: bytes32(0),
        //         item: ReceivedItem(
        //             ItemType.ERC721,
        //             address(erc721s[0]),
        //             99,
        //             1,
        //             payable(bob)
        //         )
        //     })
        // );
        {
            // ERC20TokenDump[] memory dump = balances.dumpERC20Balances();
            // require(dump.length == 1);
            // require(dump[0].token == address(erc20s[0]));
            // require(dump[0].accounts.length == 2);
            // require(dump[0].accounts[0].account == alice);
            // require(dump[0].accounts[0].balance == 300);
            // require(dump[0].accounts[1].account == bob);
            // require(dump[0].accounts[1].balance == 200);
            // string memory finalJson = tojsonDynArrayERC20TokenDump("root", "erc20", dump);
            // string memory finalJson = tojsonExpectedBalancesDump(
            // "root",
            // "data",
            // dump
            // );
            // vm.writeJson(finalJson, "./fuzz_debug.json");
        }
        {
            // require(dump.length == 1);
            // require(dump[0].token == address(erc721s[0]));
            // require(dump[0].accounts.length == 2);
            // require(dump[0].accounts[0].account == bob);
            // require(dump[0].accounts[0].identifiers.length == 0);
            // require(dump[0].accounts[1].account == alice);
            // require(dump[0].accounts[1].identifiers.length == 1);
            // require(dump[0].accounts[1].identifiers[0] == 99);
        }
    }

    /**
     * @dev deploy test token contracts
     */
    function _deployTestTokenContracts() internal {
        createErc20Token();
        createErc721Token();
        createErc1155Token();
    }

    function createErc20Token() internal {
        TestERC20 token = new TestERC20();
        erc20 = token;
        vm.label(address(token), string(abi.encodePacked("ERC20")));
    }

    function createErc721Token() internal {
        TestERC721 token = new TestERC721();
        erc721 = token;
        vm.label(address(token), string(abi.encodePacked("ERC721")));
    }

    function createErc1155Token() internal {
        TestERC1155 token = new TestERC1155();
        erc1155 = token;
        vm.label(address(token), string(abi.encodePacked("ERC1155")));
    }
}
