const fs = require("fs");
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

const traceStorage = (txHash) => {
  provider.send("debug_traceTransaction", [txHash]).then((res) => {
    log(res.structLogs[res.structLogs.length - 1].storage);
  });
};

const traceTx = (txHash, filename) => {
  provider.send("debug_traceTransaction", [txHash]).then((res) => {
    if (filename) {
      fs.writeFileSync(filename, JSON.stringify(res, null, 2));
    } else {
      log(res);
    }
  });
};

exports.module = {
  BN: eth.BigNumber.from,
  eth: eth,
  log: log,
  provider: provider,
  wallets: wallets,
  traceStorage: traceStorage,
  traceTx: traceTx,
};
