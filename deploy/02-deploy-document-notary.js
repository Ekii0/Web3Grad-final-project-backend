const { ethers } = require("hardhat");
const {
  VERIFICATION_BLOCK_CONFIRMATIONS,
  DEVELOPMENT_CHAINS,
} = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async ({ deployments, getNamedAccounts }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const caseManager = await ethers.getContract("CaseManager");
  const caseManagerAddress = caseManager.address;
  const args = [caseManagerAddress];

  const blockConfirmations = DEVELOPMENT_CHAINS.includes(network.name)
    ? 1
    : VERIFICATION_BLOCK_CONFIRMATIONS;

  const documentNotary = await deploy("DocumentNotary", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: blockConfirmations,
  });

  if (
    !DEVELOPMENT_CHAINS.includes(network.name) &&
    process.env.POLYGONSCAN_API_KEY
  ) {
    await verify(documentNotary.address, args);
  }
};
