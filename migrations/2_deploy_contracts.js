const OneRingNFT = artifacts.require("OneRingNFT");
const NFTMarketplace = artifacts.require("OneRingNFTMarketplace");

module.exports = async function (deployer) {
  await deployer.deploy(OneRingNFT);

  const deployedNFT =  await OneRingNFT.deployed();
  const NFTAddress = deployedNFT.address;
  await deployer.deploy(NFTMarketplace, NFTAddress);
};