// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { BaseSeaportTest } from "./helpers/BaseSeaportTest.sol";
import { AmountDeriver } from "../../../contracts/lib/AmountDeriver.sol";

import { SeaportInterface } from "seaport-sol/SeaportInterface.sol";

import { OrderType } from "../../../contracts/lib/ConsiderationEnums.sol";

import {
    AdditionalRecipient,
    Fulfillment,
    FulfillmentComponent,
    Order,
    OrderComponents,
    OrderParameters
} from "seaport-sol/SeaportStructs.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { ArithmeticUtil } from "./helpers/ArithmeticUtil.sol";

import { PreapprovedERC721 } from "./helpers/PreapprovedERC721.sol";

import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";
import { TestERC20 } from "../../../contracts/test/TestERC20.sol";
import { TestERC721 } from "../../../contracts/test/TestERC721.sol";
import { ERC721Recipient } from "./helpers/ERC721Recipient.sol";
import { ERC1155Recipient } from "./helpers/ERC1155Recipient.sol";
import "seaport-sol/SeaportSol.sol";

/// @dev base test class for cases that depend on pre-deployed token contracts
contract BaseOrderTest is
    BaseSeaportTest,
    AmountDeriver,
    ERC721Recipient,
    ERC1155Recipient
{
    using Strings for uint256;
    using ArithmeticUtil for *;
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using OrderLib for Order;
    using OrderLib for Order[];
    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using OrderParametersLib for OrderParameters;
    using OrderComponentsLib for OrderComponents;
    using FulfillmentLib for Fulfillment;
    using FulfillmentLib for Fulfillment[];
    using FulfillmentComponentLib for FulfillmentComponent;
    using FulfillmentComponentLib for FulfillmentComponent[];

    event Transfer(address indexed from, address indexed to, uint256 value);
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    struct Context {
        SeaportInterface seaport;
    }

    /**
     * @dev used to store address and key outputs from makeAddrAndKey(name)
     */
    struct Account {
        address addr;
        uint256 key;
    }

    modifier onlyPayable(address _addr) {
        {
            bool success;
            assembly {
                // Transfer the native token and store if it succeeded or not.
                success := call(gas(), _addr, 1, 0, 0, 0, 0)
            }
            vm.assume(success);
            vm.deal(address(this), type(uint128).max);
        }
        _;
    }

    modifier only1155Receiver(address recipient) {
        vm.assume(
            recipient != address(0) &&
                recipient != 0x4c8D290a1B368ac4728d83a9e8321fC3af2b39b1 &&
                recipient != 0x4e59b44847b379578588920cA78FbF26c0B4956C
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

    FulfillAvailableHelper fulfill;
    MatchFulfillmentHelper matcher;

    Account offerer1;
    Account offerer2;

    PreapprovedERC721 internal preapproved721;

    TestERC20[] erc20s;
    TestERC721[] erc721s;
    TestERC1155[] erc1155s;

    address[] preapprovals;

    string constant SINGLE_ERC721 = "single erc721";
    string constant STANDARD = "standard";
    string constant STANDARD_CONDUIT = "standard conduit";
    string constant FULL = "full";
    string constant FIRST_FIRST = "first first";
    string constant FIRST_SECOND = "first second";
    string constant SECOND_FIRST = "second first";
    string constant SECOND_SECOND = "second second";
    string constant FF_SF = "ff to sf";
    string constant SF_FF = "sf to ff";

    function setUp() public virtual override {
        super.setUp();

        preapprovals = [
            address(seaport),
            address(referenceSeaport),
            address(conduit),
            address(referenceConduit)
        ];

        _deployTestTokenContracts();

        offerer1 = makeAndAllocateAccount("alice");
        offerer2 = makeAndAllocateAccount("bob");

        // allocate funds and tokens to test addresses
        allocateTokensAndApprovals(address(this), type(uint128).max);

        _configureStructDefaults();

        fulfill = new FulfillAvailableHelper();
        matcher = new MatchFulfillmentHelper();
    }

    function _configureStructDefaults() internal {
        OfferItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withStartAmount(1)
            .withEndAmount(1)
            .saveDefault(SINGLE_ERC721);
        ConsiderationItemLib
            .empty()
            .withItemType(ItemType.ERC721)
            .withStartAmount(1)
            .withEndAmount(1)
            .saveDefault(SINGLE_ERC721);

        OrderComponentsLib
            .empty()
            .withOrderType(OrderType.FULL_OPEN)
            .withStartTime(block.timestamp)
            .withEndTime(block.timestamp + 100)
            .saveDefault(STANDARD);

        OrderComponentsLib
            .fromDefault(STANDARD)
            .withConduitKey(conduitKey)
            .saveDefault(STANDARD_CONDUIT);

        AdvancedOrderLib
            .empty()
            .withNumerator(1)
            .withDenominator(1)
            .saveDefault(FULL);

        FulfillmentComponentLib
            .empty()
            .withOrderIndex(0)
            .withItemIndex(0)
            .saveDefault(FIRST_FIRST);
        FulfillmentComponentLib
            .empty()
            .withOrderIndex(0)
            .withItemIndex(1)
            .saveDefault(FIRST_SECOND);
        FulfillmentComponentLib
            .empty()
            .withOrderIndex(1)
            .withItemIndex(0)
            .saveDefault(SECOND_FIRST);
        FulfillmentComponentLib
            .empty()
            .withOrderIndex(1)
            .withItemIndex(1)
            .saveDefault(SECOND_SECOND);

        SeaportArrays
            .FulfillmentComponents(
                FulfillmentComponentLib.fromDefault(FIRST_FIRST)
            )
            .saveDefaultMany(FIRST_FIRST);
        SeaportArrays
            .FulfillmentComponents(
                FulfillmentComponentLib.fromDefault(FIRST_SECOND)
            )
            .saveDefaultMany(FIRST_SECOND);
        SeaportArrays
            .FulfillmentComponents(
                FulfillmentComponentLib.fromDefault(SECOND_FIRST)
            )
            .saveDefaultMany(SECOND_FIRST);
        SeaportArrays
            .FulfillmentComponents(
                FulfillmentComponentLib.fromDefault(SECOND_SECOND)
            )
            .saveDefaultMany(SECOND_SECOND);

        FulfillmentLib
            .empty()
            .withOfferComponents(
                FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
            )
            .withConsiderationComponents(
                FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
            )
            .saveDefault(SF_FF);
        FulfillmentLib
            .empty()
            .withOfferComponents(
                FulfillmentComponentLib.fromDefaultMany(FIRST_FIRST)
            )
            .withConsiderationComponents(
                FulfillmentComponentLib.fromDefaultMany(SECOND_FIRST)
            )
            .saveDefault(FF_SF);
    }

    function test(
        function(Context memory) external fn,
        Context memory context
    ) internal {
        try fn(context) {
            fail("Differential test should have reverted with failure status");
        } catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    /**
     * @dev convenience wrapper for makeAddrAndKey
     */
    function makeAccount(string memory name) internal returns (Account memory) {
        (address addr, uint256 key) = makeAddrAndKey(name);
        return Account(addr, key);
    }

    /**
     * @dev convenience wrapper for makeAddrAndKey that also allocates tokens,
     *      ether, and approvals
     */
    function makeAndAllocateAccount(
        string memory name
    ) internal returns (Account memory) {
        Account memory account = makeAccount(name);
        allocateTokensAndApprovals(account.addr, type(uint128).max);
        return account;
    }

    function makeAddrWithAllocationsAndApprovals(
        string memory label
    ) internal returns (address) {
        address addr = makeAddr(label);
        allocateTokensAndApprovals(addr, type(uint128).max);
        return addr;
    }

    /**
     * @dev deploy test token contracts
     */
    function _deployTestTokenContracts() internal {
        for (uint256 i; i < 3; i++) {
            createErc20Token();
            createErc721Token();
            createErc1155Token();
        }
        preapproved721 = new PreapprovedERC721(preapprovals);
    }

    function createErc20Token() internal returns (uint256 i) {
        i = erc20s.length;
        TestERC20 token = new TestERC20();
        erc20s.push(token);
        vm.label(
            address(token),
            string(abi.encodePacked("erc20_", erc20s.length))
        );
    }

    function createErc721Token() internal returns (uint256 i) {
        i = erc721s.length;
        TestERC721 token = new TestERC721();
        erc721s.push(token);
        vm.label(
            address(token),
            string(abi.encodePacked("erc721_", erc721s.length))
        );
    }

    function createErc1155Token() internal returns (uint256 i) {
        i = erc1155s.length;
        TestERC1155 token = new TestERC1155();
        erc1155s.push(token);
        vm.label(
            address(token),
            string(abi.encodePacked("erc1155_", erc1155s.length))
        );
    }

    /**
     * @dev allocate amount of ether and each erc20 token; set approvals for all tokens
     */
    function allocateTokensAndApprovals(address _to, uint128 _amount) internal {
        vm.deal(_to, _amount);
        for (uint256 i = 0; i < erc20s.length; ++i) {
            erc20s[i].mint(_to, _amount);
        }
        _setApprovals(_to);
    }

    function _setApprovals(address _owner) internal virtual {
        vm.startPrank(_owner);
        for (uint256 i = 0; i < erc20s.length; ++i) {
            erc20s[i].approve(address(seaport), type(uint256).max);
            erc20s[i].approve(address(referenceSeaport), type(uint256).max);
            erc20s[i].approve(address(conduit), type(uint256).max);
            erc20s[i].approve(address(referenceConduit), type(uint256).max);
        }
        for (uint256 i = 0; i < erc721s.length; ++i) {
            erc721s[i].setApprovalForAll(address(seaport), true);
            erc721s[i].setApprovalForAll(address(referenceSeaport), true);
            erc721s[i].setApprovalForAll(address(conduit), true);
            erc721s[i].setApprovalForAll(address(referenceConduit), true);
        }
        for (uint256 i = 0; i < erc1155s.length; ++i) {
            erc1155s[i].setApprovalForAll(address(seaport), true);
            erc1155s[i].setApprovalForAll(address(referenceSeaport), true);
            erc1155s[i].setApprovalForAll(address(conduit), true);
            erc1155s[i].setApprovalForAll(address(referenceConduit), true);
        }

        vm.stopPrank();
    }

    /**
     * @dev allow signing for this contract since it needs to be recipient of
     *       basic order to reenter on receive
     */
    function isValidSignature(
        bytes32,
        bytes memory
    ) external pure virtual returns (bytes4) {
        return 0x1626ba7e;
    }

    function toHashedLeaves(
        uint256[] memory identifiers
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashedLeaves = new bytes32[](identifiers.length);
        for (uint256 i; i < identifiers.length; ++i) {
            hashedLeaves[i] = keccak256(abi.encode(identifiers[i]));
        }
        return hashedLeaves;
    }

    function decodeBytes4(bytes memory data) external pure returns (bytes4) {
        return abi.decode(data, (bytes4));
    }

    receive() external payable virtual {}
}
