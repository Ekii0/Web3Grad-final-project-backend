const { run } = require("hardhat");

const verify = async (contractAddress, args) => {
  try {
    console.log("Verifying contract...");
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
  } catch (err) {
    console.log(err);
  }
};

module.exports = { verify };
