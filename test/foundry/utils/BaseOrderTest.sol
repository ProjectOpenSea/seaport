// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { BaseConsiderationTest } from "./BaseConsiderationTest.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "./ERC721Recipient.sol";
import { ERC1155Recipient } from "./ERC1155Recipient.sol";
import { ProxyRegistry } from "../interfaces/ProxyRegistry.sol";
import { OwnableDelegateProxy } from "../interfaces/OwnableDelegateProxy.sol";
import { ConsiderationItem, OfferItem } from "../../../contracts/lib/ConsiderationStructs.sol";

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

    address[] allTokens;
    TestERC20[] erc20s;
    TestERC721[] erc721s;
    TestERC1155[] erc1155s;
    address[] accounts;

    OfferItem[] offerItems;
    ConsiderationItem[] considerationItems;

    uint256 internal globalTokenId;

    struct RestoreERC20Balance {
        address token;
        address who;
    }

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

    /**
     * @dev hook to record storage writes and reset token balances in between differential runs
     */

    modifier resetTokenBalancesBetweenRuns() {
        vm.record();
        _;
        _resetTokensAndEthForTestAccounts();
    }

    function setUp() public virtual override {
        super.setUp();
        offerItems = new OfferItem[](0);
        considerationItems = new ConsiderationItem[](0);

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(cal, "cal");
        vm.label(address(this), "testContract");

        _deployTestTokenContracts();
        accounts = [alice, bob, cal, address(this)];
        erc20s = [token1, token2, token3];
        erc721s = [test721_1, test721_2, test721_3];
        erc1155s = [test1155_1, test1155_2, test1155_3];
        allTokens = [
            address(token1),
            address(token2),
            address(token3),
            address(test721_1),
            address(test721_2),
            address(test721_3),
            address(test1155_1),
            address(test1155_2),
            address(test1155_3)
        ];

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
        vm.label(address(test1155_1), "test1155_1");

        emit log("Deployed test token contracts");
    }

    /**
    @dev allocate amount of each token, 1 of each 721, and 1, 5, and 10 of respective 1155s 
    */
    function allocateTokensAndApprovals(address _to, uint128 _amount) internal {
        vm.deal(_to, _amount);
        for (uint256 i = 0; i < erc20s.length; i++) {
            erc20s[i].mint(_to, _amount);
        }

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
        for (uint256 i = 0; i < erc20s.length; i++) {
            erc20s[i].approve(address(consideration), MAX_INT);
            erc20s[i].approve(address(referenceConsideration), MAX_INT);
            erc20s[i].approve(address(conduit), MAX_INT);
        }
        for (uint256 i = 0; i < erc721s.length; i++) {
            erc721s[i].setApprovalForAll(address(consideration), true);
            erc721s[i].setApprovalForAll(address(referenceConsideration), true);
            erc721s[i].setApprovalForAll(address(conduit), true);
        }
        for (uint256 i = 0; i < erc1155s.length; i++) {
            erc1155s[i].setApprovalForAll(address(consideration), true);
            erc1155s[i].setApprovalForAll(
                address(referenceConsideration),
                true
            );
            erc1155s[i].setApprovalForAll(address(conduit), true);
        }

        vm.stopPrank();
        emit log_named_address(
            "Owner proxy approved for all tokens from",
            _owner
        );
        emit log_named_address(
            "Consideration approved for all tokens from",
            _owner
        );
    }

    function getMaxConsiderationValue() internal view returns (uint256) {
        uint256 value = 0;
        for (uint256 i = 0; i < considerationItems.length; i++) {
            uint256 amount = considerationItems[i].startAmount >
                considerationItems[i].endAmount
                ? considerationItems[i].startAmount
                : considerationItems[i].endAmount;
            value += amount;
        }
        return value;
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
        for (uint256 i = 0; i < accounts.length; i++) {
            vm.deal(accounts[i], uint128(MAX_INT));
        }
    }

    function _resetTokensStorage() internal {
        for (uint256 i = 0; i < allTokens.length; i++) {
            _resetStorage(allTokens[i]);
        }
        // _resetStorage(address(token1));
        // _resetStorage(address(token2));
        // _resetStorage(address(token3));
        // _resetStorage(address(test721_1));
        // _resetStorage(address(test721_2));
        // _resetStorage(address(test721_3));
        // _resetStorage(address(test1155_1));
        // _resetStorage(address(test1155_2));
        // _resetStorage(address(test1155_3));
    }

    /**
     * @dev restore erc20 balances for all accounts
     */
    function _restoreERC20Balances() internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            _restoreERC20BalancesForAddress(accounts[i]);
        }
        // _restoreERC20BalancesForAddress(alice);
        // _restoreERC20BalancesForAddress(bob);
        // _restoreERC20BalancesForAddress(cal);
        // _restoreERC20BalancesForAddress(address(this));
    }

    /**
     * @dev restore all erc20 balances for a given address
     */
    function _restoreERC20BalancesForAddress(address _who) internal {
        for (uint256 i = 0; i < erc20s.length; i++) {
            _restoreERC20Balance(RestoreERC20Balance(address(erc20s[i]), _who));
        }
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
            vm.store(_addr, writeSlots[i], bytes32(0));
        }
    }

    /**
     * @dev reset token balance for an address to uint128(MAX_INT)
     */
    function _restoreERC20Balance(
        RestoreERC20Balance memory restoreErc20Balance
    ) internal {
        stdstore
            .target(restoreErc20Balance.token)
            .sig("balanceOf(address)")
            .with_key(restoreErc20Balance.who)
            .checked_write(uint128(MAX_INT));
    }
}
