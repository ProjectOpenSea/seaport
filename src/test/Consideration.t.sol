// SPDX-License-Identifier: MIT
//Author: CupOJoseph

pragma solidity 0.8.12;

import "ds-test/test.sol";
import "../../contracts/Consideration.sol";
import "src/test/NFT721.sol";
import "src/test/CheatCodes.sol";

//use solmate tokens
import "solmate/tokens/ERC20.sol";
import "solmate/tokens/ERC1155.sol";
import "solmate/tokens/ERC721.sol";

contract ConsiderationTest is DSTest {
    Consideration consider;
    address considerAddress;

    CheatCodes internal vm;

    address accountA;
    address accountB;
    address accountC;

    NFT test721;

    function setUp() public {
        vm = CheatCodes(HEVM_ADDRESS);

        considerAddress = address(new Consideration(address(0), address(0)));
        consider = Consideration(consider);

        //deploy a test 721
        test721 = new NFT("Nifty", "NFT");

        //d6e900755be565cb8eb4dbd2bbb77583c5996f9c254aa80c6270d8756f6efb00
        //d6e900755be565cb8eb4dbd2bbb77583c5996f9c254aa80c6270d8756f6efb01
        //d6e900755be565cb8eb4dbd2bbb77583c5996f9c254aa80c6270d8756f6efb02
        accountA = 0xEbe047B1229E95E6a4F03039eF17140Bd6E2A1F0;
        accountB = 0xb8722FD62E5589241228970b165aB617ed186AeD;
        accountC = 0x81f464ed27111E8c1606546D5DC7fD72fF45EE0e;

        for (uint256 i; i < 10; i++) {
            test721.mintTo(accountA);
        }
        emit log("Account A airdropped 10 NFTs.");

        vm.prank(accountA);
        test721.setApprovalForAll(considerAddress, true);
        vm.prank(accountB);
        test721.setApprovalForAll(considerAddress, true);
        vm.prank(accountC);
        test721.setApprovalForAll(considerAddress, true);
        emit log("Accounts A B C have approved consideration.");

        vm.label(accountA, "Account A");
    }

    //basic Order

    //eth to 721
    //eth to 1155
    //20 to 721
    //20 to 1155
    //721 to 20
    // 1155 to 20


    //match
    function testMatchOrder721toEth() external {
        emit log("Basic Order, Match Order");
        address seller = accountA;
        vm.startPrank(seller);
    }

}
