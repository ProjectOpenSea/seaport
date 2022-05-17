import "@rari-capital/solmate/src/tokens/ERC721.sol";

///@notice this token is purposefully modified to allow unapproved transfers
contract NoApprovalERC721 is ERC721("Test721", "TST721") {
    event TransferERC721(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event MintERC721(uint256 amount);

    function mint(address to, uint256 tokenId) public returns (bool) {
        _mint(to, tokenId);
        emit MintERC721(tokenId);
        return true;
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "tokenURI";
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        require(from == ownerOf[id], "WRONG_FROM");
        require(to != address(0), "INVALID_RECIPIENT");
        unchecked {
            balanceOf[from]--;
            balanceOf[to]++;
        }
        ownerOf[id] = to;
        emit TransferERC721(from, to, id);
    }
}
