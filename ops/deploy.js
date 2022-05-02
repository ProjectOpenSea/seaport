// Used via etheno to generate additional contracts to deploy via echidna

const eth = require("ethers");
const registryArtifacts = require("../artifacts/contracts/test/wyvern/WyvernProxyRegistry.sol/WyvernProxyRegistry.json");
const proxyImplementationArtifacts = require("../artifacts/contracts/test/wyvern/AuthenticatedProxy.sol/AuthenticatedProxy.json");
const transferProxyArtifacts = require("../artifacts/contracts/test/wyvern/TokenTransferProxy.sol/TokenTransferProxy.json");

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

  // Deploy a proxyImplementation implementation
  const proxyImplementationArgs = [];
  const proxyImplementationFactory = new eth.ContractFactory(
    proxyImplementationArtifacts.abi,
    proxyImplementationArtifacts.bytecode,
    wallet
  );
  const proxyImplementation = await proxyImplementationFactory.deploy(
    ...proxyImplementationArgs,
    {}
  );
  console.log(
    `Sent transaction to deploy proxyImplementation, txHash: ${proxyImplementation.deployTransaction.hash}`
  );
  await proxyImplementation.deployTransaction.wait();
  console.log(
    `Successfully deployed proxyImplementation to address: ${proxyImplementation.address}`
  );

  // Deploy a token transfer transferProxy
  const transferProxyArgs = [];
  const transferProxyFactory = new eth.ContractFactory(
    transferProxyArtifacts.abi,
    transferProxyArtifacts.bytecode,
    wallet
  );
  const transferProxy = await transferProxyFactory.deploy(
    ...transferProxyArgs,
    {}
  );
  console.log(
    `Sent transaction to deploy transferProxy, txHash: ${transferProxy.deployTransaction.hash}`
  );
  await transferProxy.deployTransaction.wait();
  console.log(
    `Successfully deployed transferProxy to address: ${transferProxy.address}`
  );
})();
