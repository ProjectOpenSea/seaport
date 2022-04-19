// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./Consideration.sol";

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

contract Echidna {

    AuthenticatedProxy public proxy = AuthenticatedProxy(0x1D7022f5B17d2F8B695918FB48fa1089C9f85401);
    ProxyRegistry public registry = ProxyRegistry(0x1dC4c1cEFEF38a777b15aA20260a54E584b16C48);
    Consideration public opensea;

    constructor() {
        opensea = new Consideration(address(registry), address(proxy));
    }

    function test() public {
        uint nonce = opensea.getNonce(address(0));
        assert(nonce == 0);
    }

}
