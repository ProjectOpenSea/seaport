// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "solmate/tokens/ERC721.sol";


contract NFT is ERC721 {
   uint256 public currentTokenId;

   constructor(
       string memory _name,
       string memory _symbol
   ) ERC721(_name, _symbol) {
   }

   function mintTo(address recipient) public payable returns (uint256) {
       uint256 newItemId = ++currentTokenId;
       _safeMint(recipient, newItemId);
       return newItemId;
   }

   function tokenURI(uint256 id) public view virtual override returns (string memory) {
       return _toString(id);
   }

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     *      Inlined from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
