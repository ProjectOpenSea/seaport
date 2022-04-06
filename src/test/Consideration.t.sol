// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity 0.8.12;

import "ds-test/test.sol";
import "../../contracts/Consideration.sol";
import "src/test/NFT.sol";

contract ConsiderationTest is DSTest {
    Consideration consider;

    NFT test721;
    function setUp() public {

      //deploy a test 721
      test721 = new NFT("Nifty", "NFT");

      //send some to addresses
      //test721.mintTo();

      //setup cheat codes
      //cheats = Cheats(HEVM_ADDRESS);
    }

    function testCreateOrders() public {
        assertTrue(true, "this is false.");
    }

    function testFullfilOrders() public {
        assertTrue(true, "this is false.");
    }

    function testCreateDescendingPriceOrders() public {
        emit log("this will fail...");

        assertTrue(false, "this is false.");
    }

    function testCreateAscendingPriceOrders() public {
        emit log("this will fail...");
        uint num = 0;
        for(uint i; i < 5000; i++){
          num += i;
          num = num * 7777;
          num % 5555;
        }

        assertTrue(false, "this is false.");
    }

    function testFillOrders() public {
      uint num = 0;
      for(uint i; i < 5000; i++){
        num += i;
        num = num * 7777;
        num % 5555;
      }

      assertTrue(true, "this is true");
    }
}
