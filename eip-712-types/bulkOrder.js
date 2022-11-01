const bulkOrderType = {
  BulkOrder: [
    { name: "a", type: "LevelOne" },
    { name: "b", type: "LevelOne" },
  ],
  LevelOne: [
    { name: "a", type: "LevelTwo" },
    { name: "b", type: "LevelTwo" },
  ],
  LevelTwo: [
    { name: "a", type: "LevelThree" },
    { name: "b", type: "LevelThree" },
  ],
  LevelThree: [
    { name: "a", type: "LevelFour" },
    { name: "b", type: "LevelFour" },
  ],
  LevelFour: [
    { name: "a", type: "LevelFive" },
    { name: "b", type: "LevelFive" },
  ],
  LevelFive: [
    { name: "a", type: "LevelSix" },
    { name: "b", type: "LevelSix" },
  ],
  LevelSix: [
    { name: "a", type: "OrderComponents" },
    { name: "b", type: "OrderComponents" },
  ],
  OrderComponents: [
    { name: "offerer", type: "address" },
    { name: "zone", type: "address" },
    { name: "offer", type: "OfferItem[]" },
    { name: "consideration", type: "ConsiderationItem[]" },
    { name: "orderType", type: "uint8" },
    { name: "startTime", type: "uint256" },
    { name: "endTime", type: "uint256" },
    { name: "zoneHash", type: "bytes32" },
    { name: "salt", type: "uint256" },
    { name: "conduitKey", type: "bytes32" },
    { name: "counter", type: "uint256" },
  ],
  OfferItem: [
    { name: "itemType", type: "uint8" },
    { name: "token", type: "address" },
    { name: "identifierOrCriteria", type: "uint256" },
    { name: "startAmount", type: "uint256" },
    { name: "endAmount", type: "uint256" },
  ],
  ConsiderationItem: [
    { name: "itemType", type: "uint8" },
    { name: "token", type: "address" },
    { name: "identifierOrCriteria", type: "uint256" },
    { name: "startAmount", type: "uint256" },
    { name: "endAmount", type: "uint256" },
    { name: "recipient", type: "address" },
  ],
};

module.exports = Object.freeze({
  bulkOrderType,
});
