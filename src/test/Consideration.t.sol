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

      consider = new Consideration(address(0), address(0));

      //deploy a test 721
      test721 = new NFT("Nifty", "NFT");

      //d6e900755be565cb8eb4dbd2bbb77583c5996f9c254aa80c6270d8756f6efb00
      //d6e900755be565cb8eb4dbd2bbb77583c5996f9c254aa80c6270d8756f6efb01
      //d6e900755be565cb8eb4dbd2bbb77583c5996f9c254aa80c6270d8756f6efb02
      accountA = 0xEbe047B1229E95E6a4F03039eF17140Bd6E2A1F0;
      accountB = 0xb8722FD62E5589241228970b165aB617ed186AeD;
      accountC = 0x81f464ed27111E8c1606546D5DC7fD72fF45EE0e;

      for(uint i; i < 50; i++){
        test721.mintTo(accountA);
      }

      vm.label(accountA, "Account A");

    }

    //basic orders
    function testBasicOrder721toEth() external {
        emit log("Basic Orders, Buy Now");
        address seller = accountA;
        vm.startPrank(seller);
    }

    function testBasicOrder721to20() external {
        address seller = accountA;
        vm.startPrank(seller);
    }

    function testBasicOrder1155toEth() external {
        address seller = accountA;
        vm.startPrank(seller);
    }

    function testBasicOrder1155to20() external {
        address seller = accountA;
        vm.startPrank(seller);
    }

    //match
    function testMatchOrder721toEth() external {
        emit log("Basic Order, Match Order")
        address seller = accountA;
        vm.startPrank(seller);
    }

    function testMatchOrder721to20() external {
        address seller = accountA;
        vm.startPrank(seller);
    }

    function testMatchOrder1155toEth() external {
        address seller = accountA;
        vm.startPrank(seller);
    }

    function testMatchOrder1155to20() external {
        address seller = accountA;
        vm.startPrank(seller);
    }

    //getters
    function testGetters() external{
      emit log("Getter Tests");
      address seller = accountA;
      vm.startPrank(seller);
    }

    function testCanceledOrder() external{
      emit log("Cancel Order");
      address seller = accountA;
      vm.startPrank(seller);
    }

    function TestSequenceOrder(){
      emit log("SequenceOrder");
      address seller = accountA;
      vm.startPrank(seller);
    }

    function testFailNoSequencerder(){
      address seller = accountA;
      vm.startPrank(seller);
    }

    function testFailReenterSell(){
      emit log("Re-entrency tests on ever function that should have it.");
      address seller = accountA;
      vm.startPrank(seller);
    }

    function testFailReenterSell(){
      emit log("Re-entrency tests on ever function that should have it.");
      address seller = accountA;
      address buyer = accountB;

      //make a valid order
      vm.prank(seller);

      //make a valid buy but try to re-enter using a callback.
      //TODO this will need a second helper contract to have a callback since our test tokens do not have it.
    }

    function testFailInsufficientBuys() external{
      emit log("Insufficient amounts and bad items orders.")
    }

    //ascending and descending
    function testCreateDescendingPriceOrders() external {
        emit log("TODO");

        assertTrue(false, "this is false.");
    }

    function testCreateAscendingPriceOrders() external {
        emit log("TODO");

        assertTrue(false, "this is false.");
    }


}
