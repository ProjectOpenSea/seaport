// erc20 methods
methods {
    name()                                returns (string)  => DISPATCHER(true) UNRESOLVED
    symbol()                              returns (string)  => DISPATCHER(true) UNRESOLVED
    decimals()                            returns (string)  => DISPATCHER(true) UNRESOLVED
    totalSupply()                         returns (uint256) => DISPATCHER(true) UNRESOLVED
    balanceOf(address)                    returns (uint256) => DISPATCHER(true) UNRESOLVED
    allowance(address,address)            returns (uint)    => DISPATCHER(true) UNRESOLVED
    approve(address,uint256)              returns (bool)    => DISPATCHER(true) UNRESOLVED
    transfer(address,uint256)             returns (bool)    => DISPATCHER(true) UNRESOLVED
    transferFrom(address,address,uint256) returns (bool)    => DISPATCHER(true) UNRESOLVED
}
