// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity 0.8.12;

import "ds-test/test.sol";
import "../../contracts/Consideration.sol";
import "src/test/NFT721.sol";

contract ConsiderationTest is DSTest {
    Consideration consider;

    VM internal vm;

    address accountA;
    address accountB;
    address accountC;

    NFT test721;

    function setUp() public {

      vm = VM(HEVM_ADDRESS);

      //deploy a test 721
      test721 = new NFT("Nifty", "NFT");

      //d6e900755be565cb8eb4dbd2bbb77583c5996f9c254aa80c6270d8756f6efb00
      //d6e900755be565cb8eb4dbd2bbb77583c5996f9c254aa80c6270d8756f6efb01
      //d6e900755be565cb8eb4dbd2bbb77583c5996f9c254aa80c6270d8756f6efb02
      accountA = 0xEbe047B1229E95E6a4F03039eF17140Bd6E2A1F0;
      accountB = 0xb8722FD62E5589241228970b165aB617ed186AeD;
      accountC = 0x81f464ed27111E8c1606546D5DC7fD72fF45EE0e;

      vm.label(accountA, "Account A");

    }

    function testCreateBasicOrderA() public {
        address seller = accountA;
        assertTrue(true, "this is true.");

        vm.startPrank(seller);
    }

    function testFullfilOrders() public {
        emit log("this will fail...");

        assertTrue(true, "this is false.");
    }

    function testCreateDescendingPriceOrders() public {
        emit log("this will fail...");

        assertTrue(false, "this is false.");
    }

    function testCreateAscendingPriceOrders() public {
        emit log("this will fail...");

        assertTrue(false, "this is false.");
    }

    function testFillOrders() public {

      assertTrue(true, "this is true");
    }
}
