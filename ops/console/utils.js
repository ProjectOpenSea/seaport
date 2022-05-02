const fs = require("fs");
const eth = require("ethers");
const constants = require("./constants").module;

const { provider, wallets } = constants;

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
  return provider.getTransactionReceipt(hash).then((receipt) => {
    if (!receipt) log(`No receipt is available for ${hash}`);
    const iface = new eth.utils.Interface(abi);
    receipt.logs.forEach((txLog) => {
      try {
        const evt = iface.parseLog(txLog);
        log(``);
        log(`Event Emitted: ${evt.signature}`);
        evt.args.forEach((arg, i) => {
          log(
            ` - ${evt.eventFragment.inputs[i].name} [${evt.eventFragment.inputs[i].type}]: ${arg}`
          );
        });
      } catch (e) {
        log(`Unknown Event Emitted: ${txLog.topics[0]}`);
      }
    });
    log(``);
  });
};

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
