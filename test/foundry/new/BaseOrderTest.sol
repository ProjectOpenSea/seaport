// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { LibString } from "solady/src/utils/LibString.sol";

import {
    FulfillAvailableHelper
} from "seaport-sol/src/fulfillments/available/FulfillAvailableHelper.sol";

import {
    MatchFulfillmentHelper
} from "seaport-sol/src/fulfillments/match/MatchFulfillmentHelper.sol";

import {
    AdvancedOrderLib,
    ConsiderationItemLib,
    FulfillmentComponentLib,
    FulfillmentLib,
    OfferItemLib,
    OrderComponentsLib,
    OrderLib,
    OrderParametersLib,
    SeaportArrays
} from "seaport-sol/src/SeaportSol.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters
} from "seaport-sol/src/SeaportStructs.sol";

import { ItemType, OrderType } from "seaport-sol/src/SeaportEnums.sol";

import { SeaportInterface } from "seaport-sol/src/SeaportInterface.sol";

import { setLabel, BaseSeaportTest } from "./helpers/BaseSeaportTest.sol";

import { ArithmeticUtil } from "./helpers/ArithmeticUtil.sol";

import { CriteriaResolverHelper } from "./helpers/CriteriaResolverHelper.sol";

import { ERC1155Recipient } from "./helpers/ERC1155Recipient.sol";

import { ERC721Recipient } from "./helpers/ERC721Recipient.sol";

import { ExpectedBalances } from "./helpers/ExpectedBalances.sol";

import { PreapprovedERC721 } from "./helpers/PreapprovedERC721.sol";

import { AmountDeriver } from "seaport-core/src/lib/AmountDeriver.sol";

import { TestERC20 } from "../../../contracts/test/TestERC20.sol";

import { TestERC721 } from "../../../contracts/test/TestERC721.sol";

import { TestERC1155 } from "../../../contracts/test/TestERC1155.sol";

/**
 * @dev This is a base test class for cases that depend on pre-deployed token
 *      contracts. Note that it is different from the BaseOrderTest in the
 *      legacy test suite.
 */
contract BaseOrderTest is
    BaseSeaportTest,
    AmountDeriver,
    ERC721Recipient,
    ERC1155Recipient
{
    using ArithmeticUtil for *;
    using Strings for uint256;

    using AdvancedOrderLib for AdvancedOrder;
    using AdvancedOrderLib for AdvancedOrder[];
    using ConsiderationItemLib for ConsiderationItem;
    using ConsiderationItemLib for ConsiderationItem[];
    using FulfillmentComponentLib for FulfillmentComponent;
    using FulfillmentComponentLib for FulfillmentComponent[];
    using FulfillmentLib for Fulfillment;
    using FulfillmentLib for Fulfillment[];
    using OfferItemLib for OfferItem;
    using OfferItemLib for OfferItem[];
    using OrderComponentsLib for OrderComponents;
    using OrderLib for Order;
    using OrderLib for Order[];
    using OrderParametersLib for OrderParameters;

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

    FulfillAvailableHelper fulfill;
    MatchFulfillmentHelper matcher;

    Account offerer1;
    Account offerer2;

    Account dillon;
    Account eve;
    Account frank;

    PreapprovedERC721 internal preapproved721;

    TestERC20[] erc20s;
    TestERC721[] erc721s;
    TestERC1155[] erc1155s;

    ExpectedBalances public balanceChecker;
    CriteriaResolverHelper public criteriaResolverHelper;

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

        balanceChecker = new ExpectedBalances();

        // TODO: push to 24 if performance allows
        criteriaResolverHelper = new CriteriaResolverHelper(6);

        preapprovals = [
            address(seaport),
            address(referenceSeaport),
            address(conduit),
            address(referenceConduit)
        ];

        _deployTestTokenContracts();

        offerer1 = makeAndAllocateAccount("alice");
        offerer2 = makeAndAllocateAccount("bob");

        dillon = makeAndAllocateAccount("dillon");
        eve = makeAndAllocateAccount("eve");
        frank = makeAndAllocateAccount("frank");

        // allocate funds and tokens to test addresses
        allocateTokensAndApprovals(address(this), type(uint128).max);

        _configureStructDefaults();

        fulfill = new FulfillAvailableHelper();
        matcher = new MatchFulfillmentHelper();
    }

    /**
     * @dev Creates a set of globally available default structs for use in
     *      tests.
     */
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
     * @dev Wrapper for forge-std's makeAccount that has public visibility
     *      instead of internal visibility, so that we can access it in
     *      libraries.
     */
    function makeAccountWrapper(
        string memory name
    ) public returns (Account memory) {
        return makeAccount(name);
    }

    /**
     * @dev Convenience wrapper for makeAddrAndKey that also allocates tokens,
     *      ether, and approvals.
     */
    function makeAndAllocateAccount(
        string memory name
    ) internal returns (Account memory) {
        Account memory account = makeAccountWrapper(name);
        allocateTokensAndApprovals(account.addr, type(uint128).max);
        return account;
    }

    /**
     * @dev Sets up a new address and sets up token approvals for it.
     */
    function makeAddrWithAllocationsAndApprovals(
        string memory label
    ) internal returns (address) {
        address addr = makeAddr(label);
        allocateTokensAndApprovals(addr, type(uint128).max);
        return addr;
    }

    /**
     * @dev Deploy test token contracts.
     */
    function _deployTestTokenContracts() internal {
        for (uint256 i; i < 3; i++) {
            createErc20Token();
            createErc721Token();
            createErc1155Token();
        }
        preapproved721 = new PreapprovedERC721(preapprovals);
    }

    /**
     * @dev Creates a new ERC20 token contract and stores it in the erc20s
     *      array.
     */
    function createErc20Token() internal returns (uint256 i) {
        i = erc20s.length;
        TestERC20 token = new TestERC20();
        erc20s.push(token);
        setLabel(address(token), string.concat("ERC20", LibString.toString(i)));
    }

    /**
     * @dev Creates a new ERC721 token contract and stores it in the erc721s
     *      array.
     */
    function createErc721Token() internal returns (uint256 i) {
        i = erc721s.length;
        TestERC721 token = new TestERC721();
        erc721s.push(token);
        setLabel(
            address(token),
            string.concat("ERC721", LibString.toString(i))
        );
    }

    /**
     * @dev Creates a new ERC1155 token contract and stores it in the erc1155s
     *      array.
     */
    function createErc1155Token() internal returns (uint256 i) {
        i = erc1155s.length;
        TestERC1155 token = new TestERC1155();
        erc1155s.push(token);
        setLabel(
            address(token),
            string.concat("ERC1155", LibString.toString(i))
        );
    }

    /**
     * @dev Allocate amount of ether and each erc20 token; set approvals for all
     *      tokens.
     */
    function allocateTokensAndApprovals(address _to, uint128 _amount) public {
        vm.deal(_to, _amount);
        for (uint256 i = 0; i < erc20s.length; ++i) {
            erc20s[i].mint(_to, _amount);
        }
        _setApprovals(_to);
    }

    /**
     * @dev Set approvals for all tokens.
     *
     * @param _owner The address to set approvals for.
     */
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

    receive() external payable virtual {}
}
