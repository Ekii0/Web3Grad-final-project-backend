const { verify } = require("../utils/verify");
const {
  VERIFICATION_BLOCK_CONFIRMATIONS,
  DEVELOPMENT_CHAINS,
} = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const baseUri = "https://ekiio.infura-ipfs.io/ipfs/";
  const blockConfirmations = DEVELOPMENT_CHAINS.includes(network.name)
    ? 1
    : VERIFICATION_BLOCK_CONFIRMATIONS;

  const caseManager = await deploy("CaseManager", {
    from: deployer,
    args: [baseUri],
    log: true,
    waitConfirmations: blockConfirmations,
  });

  if (!DEVELOPMENT_CHAINS.includes(network.name)) {
    await verify(caseManager.address, [baseUri]);
  }
};
