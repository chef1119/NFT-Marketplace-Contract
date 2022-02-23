const MarketPlace = artifacts.require("CoinracerMarketPlace");

module.exports = async function (deployer) {

  await deployer.deploy(MarketPlace, "0xfbb4f2f342c6daab63ab85b0226716c4d1e26f36", "0x3A7951Ff955d4e0b6CBBe54De8593606e5e0FA08");

  const saleInstance = await MarketPlace.deployed();

  console.log("MarketPlace deployed at:", saleInstance.address);
};

