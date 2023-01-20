const signedOrderType = {
  SignedOrder: [
    { name: "fulfiller", type: "address" },
    { name: "expiration", type: "uint256" },
    { name: "orderHash", type: "bytes32" },
    { name: "context", type: "bytes" },
  ],
};

module.exports = Object.freeze({
  signedOrderType,
});
