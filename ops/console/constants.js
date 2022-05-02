const eth = require("ethers");

// Contains stuff that are constant at run-time (not between different runtime instances)

const env = {
  hardhat: process.env.ETHCONSOLE_HARDHAT || "",
  ethProviderUrl: process.env.ETH_PROVIDER || "http://localhost:8545",
  mnemonic:
    "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat",
};

// This provider should only be used from the console, in tests use hre.ethers.provider
const provider = new eth.providers.JsonRpcProvider(env.ethProviderUrl);

const hdNode = eth.utils.HDNode.fromMnemonic(env.mnemonic).derivePath(
  "m/44'/60'/0'/0"
);
const wallets = Array(10)
  .fill(0)
  .map((_, idx) => {
    const wallet = new eth.Wallet(
      hdNode.derivePath(idx.toString()).privateKey,
      provider
    );
    return wallet;
  });

const deployments = {
  TestERC20: require("../../deployments/localhost/TestERC20.json"),
  TestERC721: require("../../deployments/localhost/TestERC721.json"),
  TestERC1155: require("../../deployments/localhost/TestERC1155.json"),
  Consideration: require("../../deployments/localhost/Consideration.json"),
  AuthenticatedProxy: require("../../deployments/localhost/AuthenticatedProxy.json"),
  TokenTransferProxy: require("../../deployments/localhost/TokenTransferProxy.json"),
  WyvernProxyRegistry: require("../../deployments/localhost/WyvernProxyRegistry.json"),
};

const contracts = Object.entries(deployments).reduce((acc, cur) => {
  const name = cur[0];
  const deployment = cur[1];
  acc[name] = new eth.Contract(deployment.address, deployment.abi, wallets[0]);
  return acc;
}, {});

module.exports = {
  deployments: deployments,
  contracts: contracts,
  provider: provider,
  wallets: wallets,
};
