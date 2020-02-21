const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");

const Migrations = artifacts.require("Migrations");
const BSCH = artifacts.require("BSCH");

module.exports = async function (deployer,network, accounts) {
    let migrate = await deployer.deploy(Migrations,
        {overwrite: true}
        );
    migrate = await Migrations.deployed();
    console.log("migration address:"+migrate.address);
    console.log("network",network);
};
