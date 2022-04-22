// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./Consideration.sol";
import "./test/TestERC20.sol";
import "./test/TestERC721.sol";
import "./test/TestERC1155.sol";

enum HowToCall {
    Call,
    DelegateCall
}

interface AuthenticatedProxy {
    function user() external returns (address);
    function registry() external returns (address);
    function revoked() external returns (bool);
    function initialize(address, address) external;
    function setRevoke(bool) external;
    function proxy(address, HowToCall, bytes calldata) external returns (bool);
    function proxyAssert(address, HowToCall, bytes calldata) external;
}

interface ProxyRegistry {
    function delegateProxyImplementation() external returns(address);
    function proxies(address) external returns(address);
    function pending(address) external returns(uint);
    function contracts(address) external returns(bool);
    function DELAY_PERIOD() external returns(uint);
    function startGrantAuthentication(address) external;
    function endGrantAuthentication(address) external;
    function revokeAuthentication(address) external;
    function registerProxy() external returns (address);
    function grantInitialAuthentication(address) external;
}

interface TokenTransferProxy {
    function transferFrom(
        address,
        address,
        address,
        uint256
    ) external returns (bool);
}

interface FuzzyTests {
    function test() external;
}

contract Echidna is FuzzyTests {

    AuthenticatedProxy private _proxyImplementation = AuthenticatedProxy(
        0x1D7022f5B17d2F8B695918FB48fa1089C9f85401
    );
    ProxyRegistry private _registry = ProxyRegistry(
        0x1dC4c1cEFEF38a777b15aA20260a54E584b16C48
    );
    TokenTransferProxy private _transferProxy = TokenTransferProxy(
        0x871DD7C2B4b25E1Aa18728e9D5f2Af4C4e431f5c
    );
    Consideration private _opensea;
    TestERC20 private _erc20;
    TestERC721 private _erc721;
    TestERC1155 private _erc1155;

    constructor() {
        _opensea = new Consideration(
            address(_registry),
            address(_proxyImplementation),
            address(_transferProxy)
        );
        _erc20 = new TestERC20();
        _erc721 = new TestERC721();
        _erc1155 = new TestERC1155();
    }

    function test() public view override {
        uint nonce = _opensea.getNonce(address(0));
        assert(nonce == 0);
    }

}
