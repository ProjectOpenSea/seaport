// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { BaseConsiderationTest } from "./BaseConsiderationTest.sol";
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "./ERC721Recipient.sol";
import { ERC1155Recipient } from "./ERC1155Recipient.sol";

/// @dev base test class for cases that depend on pre-deployed token contracts
contract BaseOrderTest is
    BaseConsiderationTest,
    ERC721Recipient,
    ERC1155Recipient
{
    using stdStorage for StdStorage;

    uint256 constant MAX_INT = ~uint256(0);

    uint256 internal alicePk = 0xa11ce;
    uint256 internal bobPk = 0xb0b;
    uint256 internal calPk = 0xca1;
    address internal alice = vm.addr(alicePk);
    address internal bob = vm.addr(bobPk);
    address internal cal = vm.addr(calPk);

    TestERC20 internal token1;
    TestERC20 internal token2;
    TestERC20 internal token3;

    address internal test721Address;
    TestERC721 internal test721;
    TestERC721 internal test721_1;
    TestERC721 internal test721_2;
    TestERC721 internal test721_3;

    TestERC1155 internal test1155_1;
    TestERC1155 internal test1155_2;
    TestERC1155 internal test1155_3;

    uint256 internal globalTokenId;

    function setUp() public virtual override {
        super.setUp();
        _deployTestTokenContracts();

        // allocate funds and tokens to test addresses
        globalTokenId = 1;
        allocateTokensAndApprovals(address(this), uint128(MAX_INT));
        allocateTokensAndApprovals(alice, uint128(MAX_INT));
        allocateTokensAndApprovals(bob, uint128(MAX_INT));
        allocateTokensAndApprovals(cal, uint128(MAX_INT));
    }

    /**
    @dev deploy test token contracts
     */
    function _deployTestTokenContracts() internal {
        token1 = new TestERC20();
        token2 = new TestERC20();
        token3 = new TestERC20();
        test721_1 = new TestERC721();
        //deploy a test 721
        test721Address = address(new TestERC721());
        test721 = TestERC721(test721Address);
        test721_2 = new TestERC721();
        test721_3 = new TestERC721();
        test1155_1 = new TestERC1155();
        test1155_2 = new TestERC1155();
        test1155_3 = new TestERC1155();
        emit log("Deployed test token contracts");
    }

    /**
    @dev allocate amount of each token, 1 of each 721, and 1, 5, and 10 of respective 1155s
    */
    function allocateTokensAndApprovals(address _to, uint128 _amount) internal {
        vm.deal(_to, _amount);
        token1.mint(_to, _amount);
        token2.mint(_to, _amount);
        token3.mint(_to, _amount);
        test721_1.mint(_to, globalTokenId++);
        test721_2.mint(_to, globalTokenId++);
        test721_3.mint(_to, globalTokenId++);
        test1155_1.mint(_to, globalTokenId++, 1);
        test1155_2.mint(_to, globalTokenId++, 5);
        test1155_3.mint(_to, globalTokenId++, 10);
        emit log_named_address("Allocated tokens to", _to);
        _setApprovals(_to);
    }

    function _setApprovals(address _owner) internal {
        vm.startPrank(_owner);
        token1.approve(address(consideration), MAX_INT);
        token2.approve(address(consideration), MAX_INT);
        token3.approve(address(consideration), MAX_INT);
        test721_1.setApprovalForAll(address(consideration), true);
        test721_2.setApprovalForAll(address(consideration), true);
        test721_3.setApprovalForAll(address(consideration), true);
        test1155_1.setApprovalForAll(address(consideration), true);
        test1155_2.setApprovalForAll(address(consideration), true);
        test1155_3.setApprovalForAll(address(consideration), true);
        vm.stopPrank();

        emit log_named_address(
            "Consideration approved for all tokens from",
            _owner
        );
    }
}
