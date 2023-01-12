// SPDX-Identifier: MIT
pragma solidity ^0.8.13;

import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "./ERC721Recipient.sol";
import { ERC1155Recipient } from "./ERC1155Recipient.sol";
import { ItemType } from "../../../contracts/lib/ConsiderationEnums.sol";
import { BaseConsiderationTest } from "./BaseConsiderationTest.sol";
import { CustomERC721 } from "../token/CustomERC721.sol";

contract PreapprovedERC721 is CustomERC721 {
    mapping(address => bool) public preapprovals;

    constructor(address[] memory preapproved) CustomERC721("", "") {
        for (uint256 i = 0; i < preapproved.length; i++) {
            preapprovals[preapproved[i]] = true;
        }
    }

    function mint(address to, uint256 amount) external returns (bool) {
        _mint(to, amount);
        return true;
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) public view override returns (bool) {
        return preapprovals[operator] || super.isApprovedForAll(owner, operator);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }
}

contract TestTokenMinter is
    BaseConsiderationTest,
    ERC721Recipient,
    ERC1155Recipient
{
    uint256 constant MAX_INT = ~uint256(0);

    uint256 internal alicePk = 0xa11ce;
    uint256 internal bobPk = 0xb0b;
    uint256 internal calPk = 0xca1;
    address payable internal alice = payable(vm.addr(alicePk));
    address payable internal bob = payable(vm.addr(bobPk));
    address payable internal cal = payable(vm.addr(calPk));

    TestERC20 internal token1;
    TestERC20 internal token2;
    TestERC20 internal token3;

    TestERC721 internal test721_1;
    TestERC721 internal test721_2;
    TestERC721 internal test721_3;
    PreapprovedERC721 internal preapproved721;

    TestERC1155 internal test1155_1;
    TestERC1155 internal test1155_2;
    TestERC1155 internal test1155_3;

    TestERC20[] erc20s;
    TestERC721[] erc721s;
    TestERC1155[] erc1155s;

    address[] preapprovals;

    modifier only1155Receiver(address recipient) {
        vm.assume(
            recipient != address(0)
                && recipient != 0x4c8D290a1B368ac4728d83a9e8321fC3af2b39b1
                && recipient != 0x4e59b44847b379578588920cA78FbF26c0B4956C
        );

        if (recipient.code.length > 0) {
            (bool success, bytes memory returnData) = recipient.call(
                abi.encodeWithSelector(
                    ERC1155Recipient.onERC1155Received.selector,
                    address(1),
                    address(1),
                    1,
                    1,
                    ""
                )
            );
            vm.assume(success);
            try this.decodeBytes4(returnData) returns (bytes4 response) {
                vm.assume(response == onERC1155Received.selector);
            } catch (bytes memory reason) {
                vm.assume(false);
            }
        }
        _;
    }

    function decodeBytes4(bytes memory data) external pure returns (bytes4) {
        return abi.decode(data, (bytes4));
    }

    function setUp() public virtual override {
        super.setUp();

        preapprovals = [
            address(consideration),
            address(referenceConsideration),
            address(conduit),
            address(referenceConduit)
        ];

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(cal, "cal");

        _deployTestTokenContracts();
        erc20s = [token1, token2, token3];
        erc721s = [test721_1, test721_2, test721_3];
        erc1155s = [test1155_1, test1155_2, test1155_3];

        // allocate funds and tokens to test addresses
        allocateTokensAndApprovals(address(this), uint128(MAX_INT));
        allocateTokensAndApprovals(alice, uint128(MAX_INT));
        allocateTokensAndApprovals(bob, uint128(MAX_INT));
        allocateTokensAndApprovals(cal, uint128(MAX_INT));
    }

    function makeAddrWithAllocationsAndApprovals(string memory label)
        internal
        returns (address)
    {
        address addr = makeAddr(label);
        allocateTokensAndApprovals(addr, uint128(MAX_INT));
        return addr;
    }

    function mintErc721TokenTo(address to, uint256 id) internal {
        mintErc721TokenTo(to, test721_1, id);
    }

    function mintErc721TokenTo(
        address to,
        TestERC721 token,
        uint256 id
    ) internal {
        token.mint(to, id);
    }

    function mintTokensTo(
        address to,
        ItemType itemType,
        uint256 amount
    ) internal {
        mintTokensTo(to, itemType, 1, amount);
    }

    function mintTokensTo(
        address to,
        ItemType itemType,
        uint256 id,
        uint256 amount
    ) internal {
        if (itemType == ItemType.NATIVE) {
            vm.deal(to, amount);
        } else if (itemType == ItemType.ERC20) {
            mintErc20TokensTo(to, amount);
        } else if (itemType == ItemType.ERC1155) {
            mintErc1155TokensTo(to, id, amount);
        } else {
            mintErc721TokenTo(to, id);
        }
    }

    function mintTokensTo(
        address to,
        ItemType itemType,
        address token,
        uint256 id,
        uint256 amount
    ) internal {
        if (itemType == ItemType.NATIVE) {
            vm.deal(to, amount);
        } else if (itemType == ItemType.ERC20) {
            mintErc20TokensTo(to, TestERC20(token), amount);
        } else if (itemType == ItemType.ERC1155) {
            mintErc1155TokensTo(to, TestERC1155(token), id, amount);
        } else {
            mintErc721TokenTo(to, TestERC721(token), id);
        }
    }

    function mintErc1155TokensTo(
        address to,
        uint256 id,
        uint256 amount
    ) internal {
        mintErc1155TokensTo(to, test1155_1, id, amount);
    }

    function mintErc1155TokensTo(
        address to,
        TestERC1155 token,
        uint256 id,
        uint256 amount
    ) internal {
        token.mint(to, id, amount);
    }

    function mintErc20TokensTo(address to, uint256 amount) internal {
        mintErc20TokensTo(to, token1, amount);
    }

    function mintErc20TokensTo(
        address to,
        TestERC20 token,
        uint256 amount
    ) internal {
        token.mint(to, amount);
    }

    /**
     * @dev deploy test token contracts
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
        preapproved721 = new PreapprovedERC721(preapprovals);

        vm.label(address(token1), "token1");
        vm.label(address(test721_1), "test721_1");
        vm.label(address(test1155_1), "test1155_1");
        vm.label(address(preapproved721), "preapproved721");
    }

    /**
     * @dev allocate amount of each token, 1 of each 721, and 1, 5, and 10 of
     * respective 1155s
     */
    function allocateTokensAndApprovals(
        address _to,
        uint128 _amount
    ) internal {
        vm.deal(_to, _amount);
        for (uint256 i = 0; i < erc20s.length; ++i) {
            erc20s[i].mint(_to, _amount);
        }
        _setApprovals(_to);
    }

    function _setApprovals(address _owner) internal virtual {
        vm.startPrank(_owner);
        for (uint256 i = 0; i < erc20s.length; ++i) {
            erc20s[i].approve(address(consideration), MAX_INT);
            erc20s[i].approve(address(referenceConsideration), MAX_INT);
            erc20s[i].approve(address(conduit), MAX_INT);
            erc20s[i].approve(address(referenceConduit), MAX_INT);
        }
        for (uint256 i = 0; i < erc721s.length; ++i) {
            erc721s[i].setApprovalForAll(address(consideration), true);
            erc721s[i].setApprovalForAll(address(referenceConsideration), true);
            erc721s[i].setApprovalForAll(address(conduit), true);
            erc721s[i].setApprovalForAll(address(referenceConduit), true);
        }
        for (uint256 i = 0; i < erc1155s.length; ++i) {
            erc1155s[i].setApprovalForAll(address(consideration), true);
            erc1155s[i].setApprovalForAll(address(referenceConsideration), true);
            erc1155s[i].setApprovalForAll(address(conduit), true);
            erc1155s[i].setApprovalForAll(address(referenceConduit), true);
        }

        vm.stopPrank();
    }
}
