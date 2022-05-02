const utils = require("./utils").module;
const consideration = require("./consideration").module;

const eth = utils.eth;
const wallets = utils.wallets;

const deployments = {
  TestERC20: require("../deployments/localhost/TestERC20.json"),
  TestERC721: require("../deployments/localhost/TestERC721.json"),
  TestERC1155: require("../deployments/localhost/TestERC1155.json"),
  Consideration: require("../deployments/localhost/Consideration.json"),
  AuthenticatedProxy: require("../deployments/localhost/AuthenticatedProxy.json"),
  TokenTransferProxy: require("../deployments/localhost/TokenTransferProxy.json"),
  WyvernProxyRegistry: require("../deployments/localhost/WyvernProxyRegistry.json"),
};

// Add stuff that we want easy access to the global object
for (const key of Object.keys(utils || {})) {
  global[key] = utils[key];
}

// Add consideration helper fns to the global scope
for (const method of Object.keys(consideration || {})) {
  global[method] = consideration[method];
}

// Add all ethers utils & constants to the global scope for easy access
Object.keys(eth.utils || {}).forEach((key) => {
  global[key] = eth.utils[key];
});
Object.keys(eth.constants || {}).forEach((key) => {
  global[key] = eth.constants[key];
});

// Save deployments to global scope
for (const key of Object.keys(deployments || {})) {
  console.log(`Loading deployed ${key} contract`);
  const deployment = deployments[key];
  global[key] = new eth.Contract(
    deployment.address,
    deployment.abi,
    wallets[0]
  );
}
