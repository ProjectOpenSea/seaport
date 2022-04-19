const eth = require("ethers");
const registryArtifacts = require("../artifacts/contracts/test/wyvern/WyvernProxyRegistry.sol/WyvernProxyRegistry.json");
const proxyArtifacts = require("../artifacts/contracts/test/wyvern/AuthenticatedProxy.sol/AuthenticatedProxy.json");
console.log(`Deps loaded, time to deploy!`);

const pk = "0xf2f48ee19680706196e2e339e5da3491186e0c4c5030670656b0e0164837257d";
const provider = new eth.providers.JsonRpcProvider("http://localhost:8545");
const wallet = new eth.Wallet(pk).connect(provider);
console.log(`Got wallet with address: ${wallet.address}`);

(async () => {
  // Deploy a proxy registry
  const registryArgs = [];
  const registryFactory = new eth.ContractFactory(
    registryArtifacts.abi,
    registryArtifacts.bytecode,
    wallet
  );
  const registry = await registryFactory.deploy(...registryArgs, {});
  console.log(
    `Sent transaction to deploy registry, txHash: ${registry.deployTransaction.hash}`
  );
  await registry.deployTransaction.wait();
  console.log(`Successfully deployed registry to address: ${registry.address}`);

  // Deploy a proxy
  const proxyArgs = [];
  const proxyFactory = new eth.ContractFactory(
    proxyArtifacts.abi,
    proxyArtifacts.bytecode,
    wallet
  );
  const proxy = await proxyFactory.deploy(...proxyArgs, {});
  console.log(
    `Sent transaction to deploy proxy, txHash: ${proxy.deployTransaction.hash}`
  );
  await proxy.deployTransaction.wait();
  console.log(`Successfully deployed proxy to address: ${proxy.address}`);
})();
