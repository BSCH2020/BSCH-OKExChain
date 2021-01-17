const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");

const Migrations = artifacts.require("Migrations");
const BSCHTron = artifacts.require("BSCHTron");

module.exports = async function (deployer,network, accounts) {
    let bschTron = await deployer.deploy(BSCHTron,
        {overwrite: false}
        );
        
    console.log("migration address:"+bschTron.address);
    console.log("network",network);
};
