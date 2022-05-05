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
import { ProxyRegistry } from "../interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "../interfaces/OwnableDelegateProxy.sol";

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

    TestERC721 internal test721_1;
    TestERC721 internal test721_2;
    TestERC721 internal test721_3;

    TestERC1155 internal test1155_1;
    TestERC1155 internal test1155_2;
    TestERC1155 internal test1155_3;

    uint256 internal globalTokenId;

    modifier onlyPayable(address _addr) {
        {
            bool success;
            assembly {
                // Transfer the ETH and store if it succeeded or not.
                success := call(gas(), _addr, 1, 0, 0, 0, 0)
            }
            vm.assume(success);
        }
        _;
    }

    /**
    @dev top up eth of this contract to uint128(MAX_INT) to avoid fuzz failures
     */
    modifier topUp() {
        vm.deal(address(this), uint128(MAX_INT));
        _;
    }

    function setUp() public virtual override {
        super.setUp();

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(cal, "cal");

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
        test721_2 = new TestERC721();
        test721_3 = new TestERC721();
        test1155_1 = new TestERC1155();
        test1155_2 = new TestERC1155();
        test1155_3 = new TestERC1155();
        vm.label(address(token1), "token1");
        vm.label(address(test721_1), "test721_1");
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
        // test721_1.mint(_to, globalTokenId++);
        // test721_2.mint(_to, globalTokenId++);
        // test721_3.mint(_to, globalTokenId++);
        // test1155_1.mint(_to, globalTokenId++, 1);
        // test1155_2.mint(_to, globalTokenId++, 5);
        // test1155_3.mint(_to, globalTokenId++, 10);
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

        token1.approve(address(referenceConsideration), MAX_INT);
        token2.approve(address(referenceConsideration), MAX_INT);
        token3.approve(address(referenceConsideration), MAX_INT);
        test721_1.setApprovalForAll(address(referenceConsideration), true);
        test721_2.setApprovalForAll(address(referenceConsideration), true);
        test721_3.setApprovalForAll(address(referenceConsideration), true);
        test1155_1.setApprovalForAll(address(referenceConsideration), true);
        test1155_2.setApprovalForAll(address(referenceConsideration), true);
        test1155_3.setApprovalForAll(address(referenceConsideration), true);

        token1.approve(address(conduit), MAX_INT);
        token2.approve(address(conduit), MAX_INT);
        token3.approve(address(conduit), MAX_INT);
        test721_1.setApprovalForAll(address(conduit), true);
        test721_2.setApprovalForAll(address(conduit), true);
        test721_3.setApprovalForAll(address(conduit), true);
        test1155_1.setApprovalForAll(address(conduit), true);
        test1155_2.setApprovalForAll(address(conduit), true);
        test1155_3.setApprovalForAll(address(conduit), true);

        vm.stopPrank();
        emit log_named_address(
            "Owner proxy approved for all tokens from",
            _owner
        );
        emit log_named_address(
            "Consideration approved for all tokens from",
            _owner
        );
        emit log_named_address(
            "referenceConsideration approved for all tokens from",
            _owner
        );
    }

    function _reset721Mint(
        TestERC721 token,
        uint256 tokenId,
        address finalOwner
    ) internal {
        address token721 = address(token);
        // ownerOf(uint256)
        stdstore
            .target(token721)
            .sig("ownerOf(uint256)")
            .with_key(tokenId)
            .checked_write(address(0));
        // balanceOf(address)
        stdstore
            .target(token721)
            .sig("balanceOf(address)")
            .with_key(finalOwner)
            .checked_write(uint256(0));
    }

    /**
     * @dev reset written token storage slots to 0 and reinitialize uint128(MAX_INT) erc20 balances for 3 test accounts and this
     */
    function _resetTokensAndEthForTestAccounts() internal {
        _resetTokensStorage();
        _restoreERC20Balances();
        _restoreEthBalances();
    }

    function _restoreEthBalances() internal {
        vm.deal(address(this), uint128(MAX_INT));
        vm.deal(alice, uint128(MAX_INT));
        vm.deal(bob, uint128(MAX_INT));
        vm.deal(cal, uint128(MAX_INT));
    }

    function _resetTokensStorage() internal {
        _resetStorage(address(token1));
        _resetStorage(address(token2));
        _resetStorage(address(token3));
        _resetStorage(address(test721_1));
        _resetStorage(address(test721_2));
        _resetStorage(address(test721_3));
        _resetStorage(address(test1155_1));
        _resetStorage(address(test1155_2));
        _resetStorage(address(test1155_3));
    }

    /**
     * @dev restore erc20 balances for all accounts
     */
    function _restoreERC20Balances() internal {
        _restoreERC20BalancesForAddress(alice);
        _restoreERC20BalancesForAddress(bob);
        _restoreERC20BalancesForAddress(cal);
        _restoreERC20BalancesForAddress(address(this));
    }

    /**
     * @dev restore all erc20 balances for a given address
     */
    function _restoreERC20BalancesForAddress(address _who) internal {
        _restoreERC20Balance(address(token1), _who);
        _restoreERC20Balance(address(token2), _who);
        _restoreERC20Balance(address(token3), _who);
    }

    /**
     * @dev reset all storage written at an address thus far to 0; will overwrite totalSupply()for ERC20s but that should be fine
     *      with the goal of resetting the balances and owners of tokens - but note: should be careful about approvals, etc
     *
     *      note: must be called in conjunction with vm.record()
     */
    function _resetStorage(address _addr) internal {
        (, bytes32[] memory writeSlots) = vm.accesses(_addr);
        for (uint256 i = 0; i < writeSlots.length; i++) {
            bytes32 slot = writeSlots[i];
            vm.store(_addr, slot, bytes32(0));
        }
    }

    /**
     * @dev reset token balance for an address to uint128(MAX_INT)
     */
    function _restoreERC20Balance(address _token, address _who) internal {
        stdstore
            .target(_token)
            .sig("balanceOf(address)")
            .with_key(_who)
            .checked_write(uint128(MAX_INT));
    }
}
