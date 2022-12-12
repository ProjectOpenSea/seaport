// SignedOrder is for use with SignedZone
const signedOrderType = {
  SignedOrder: [
    { name: "fulfiller", type: "address" },
    { name: "expiration", type: "uint256" },
    { name: "orderHash", type: "bytes32" },
  ],
};

module.exports = Object.freeze({
  signedOrderType,
});
