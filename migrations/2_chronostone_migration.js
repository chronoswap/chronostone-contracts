const Chronostone = artifacts.require("Chronostone");
const ChronoToken = artifacts.require("ChronoToken");

module.exports = async (deployer) => {
  // Where are we?
  const chainId = await web3.eth.getChainId();
  console.log(chainId.toString());
  // Getting addresses
  const accounts = await web3.eth.getAccounts();
  let native = undefined;
  if ((chainId.toString() === "97") || (chainId.toString() === "56")) {
    native = await ChronoToken.at("0x454b40C8CB72d38F255327EadA7aBa57081178d8");
  } else {
    native = await deployer.deploy(ChronoToken, 'Chronoswap Token', 'CHRO');
  }
  // Deploying
  const chronostone = await deployer.deploy(Chronostone, "http://127.0.0.1:5000/nft/{id}", native.address, {from: accounts[0]});
  //Saving addresses
  var title = "./information/" + chainId.toString() + "chronostone_migration.json";
  const fs = require('file-system');
  let infos = [{
      name: 'Chronostone',
      address: chronostone.address,
    }
  ];
  let data = JSON.stringify(infos, null, 2);
  fs.writeFile(title, data, 'utf-8');
};
