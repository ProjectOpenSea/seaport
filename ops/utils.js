const eth = require("ethers");

const env = {
  hardhat: process.env.ETHCONSOLE_HARDHAT || "",
  ethProviderUrl: process.env.ETH_PROVIDER || "http://localhost:8545",
  mnemonic:
    process.env.ETH_MNEMONIC ||
    "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat",
};

// This provider should only be used from the console, in tests use hre.ethers.provider
const provider = new eth.providers.JsonRpcProvider(env.ethProviderUrl);

const log = (msg) => {
  const prefix = `\n`;
  if (typeof msg === "string") {
    console.log(msg);
  } else if (typeof msg === "object") {
    if (msg._isBigNumber) {
      console.log(prefix + eth.utils.formatEther(msg));
    } else {
      console.log(prefix + JSON.stringify(msg, undefined, 2));
    }
  }
};

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

exports.module = {
  BN: eth.BigNumber.from,
  eth: eth,
  log: log,
  provider: provider,
  wallets: wallets,
};
