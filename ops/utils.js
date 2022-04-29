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
  if (msg === null || msg === undefined) {
    console.log(msg);
  } else if (typeof msg === "string") {
    console.log(msg);
  } else if (typeof msg === "object") {
    if (msg._isBigNumber) {
      console.log(prefix + eth.utils.formatEther(msg));
    } else {
      console.log(prefix + JSON.stringify(msg, undefined, 2));
    }
  }
};

const logEvents = (hash, abi) => {
  provider.getTransactionReceipt(hash).then((receipt) => {
    if (!receipt) log(`No receipt is available for ${hash}`);
    const iface = new eth.utils.Interface(abi);
    log(``);
    log(`Events Emitted:`);
    receipt.logs.forEach((txLog) => {
      const evt = iface.parseLog(txLog);
      log(``);
      log(`${evt.signature}`);
      evt.args.forEach((arg, i) => {
        log(
          ` - ${evt.eventFragment.inputs[i].name} [${evt.eventFragment.inputs[i].type}]: ${arg}`
        );
      });
    });
    log(``);
  });
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
      const indexedRes = {
        ...res,
        structLogs: res.structLogs.map((structLog, index) => ({
          index,
          ...structLog,
        })),
      };
      fs.writeFileSync(filename, JSON.stringify(indexedRes, null, 2));
    } else {
      log(res);
    }
  });
};

exports.module = {
  toBN: eth.BigNumber.from,
  eth: eth,
  log: log,
  logEvents: logEvents,
  provider: provider,
  wallets: wallets,
  traceStorage: traceStorage,
  traceTx: traceTx,
};
