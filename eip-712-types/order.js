const orderType = {
  OrderComponents: [
    {
      name: "offerer",
      type: "address",
    },
    { name: "zone", type: "address" },
    { name: "offer", type: "OfferedItem[]" },
    { name: "consideration", type: "ReceivedItem[]" },
    { name: "orderType", type: "uint8" },
    { name: "startTime", type: "uint256" },
    { name: "endTime", type: "uint256" },
    { name: "salt", type: "uint256" },
    { name: "nonce", type: "uint256" },
  ],
  OfferedItem: [
    { name: "itemType", type: "uint8" },
    { name: "token", type: "address" },
    { name: "identifierOrCriteria", type: "uint256" },
    { name: "startAmount", type: "uint256" },
    { name: "endAmount", type: "uint256" },
  ],
  ReceivedItem: [
    { name: "itemType", type: "uint8" },
    { name: "token", type: "address" },
    { name: "identifierOrCriteria", type: "uint256" },
    { name: "startAmount", type: "uint256" },
    { name: "endAmount", type: "uint256" },
    { name: "recipient", type: "address" },
  ],
};

module.exports = Object.freeze({
    orderType,
});