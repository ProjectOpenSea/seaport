module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;
  const [args, from, log] = [[], deployer, true];

  // Deploy test tokens
  await deploy("TestERC20", { from, args, log });
  await deploy("TestERC721", { from, args, log });
  await deploy("TestERC1155", { from, args, log });

  // Deploy proxy-related helpers
  const registry = await deploy("WyvernProxyRegistry", { from, args, log });
  const transferProxy = await deploy("TokenTransferProxy", { from, args, log });
  const proxy = await deploy("AuthenticatedProxy", { from, args, log });

  // Deploy main OpenSea contract
  await deploy("Consideration", {
    from,
    log,
    args: [registry.address, transferProxy.address, proxy.address],
  });
};
module.exports.tags = ["Consideration"];
