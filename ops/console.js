const utils = require("./utils").module;

const eth = utils.eth;
const provider = utils.provider;

const deployments = {
  TestERC20: require("../deployments/localhost/TestERC20.json"),
  TestERC721: require("../deployments/localhost/TestERC721.json"),
  TestERC1155: require("../deployments/localhost/TestERC1155.json"),
  Consideration: require("../deployments/localhost/Consideration.json"),
  AuthenticatedProxy: require("../deployments/localhost/AuthenticatedProxy.json"),
  TokenTransferProxy: require("../deployments/localhost/TokenTransferProxy.json"),
  WyvernProxyRegistry: require("../deployments/localhost/WyvernProxyRegistry.json"),
};

// Add stuff that we want access to via the console to the global object
for (const key of Object.keys(utils || {})) {
  global[key] = utils[key];
}
// deployments
for (const key of Object.keys(deployments || {})) {
  console.log(`Loading deployed ${key} contract`);
  const deployment = deployments[key];
  global[key] = new eth.Contract(deployment.address, deployment.abi, provider);
}
