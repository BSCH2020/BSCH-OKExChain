const { deployProxy, upgradeProxy,prepareUpgrade} = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");
var dateFormat = require("dateformat");

const STToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
const Migrations = artifacts.require("Migrations");
const BSCH = artifacts.require("BSCH");
const BSCHV2 = artifacts.require("BSCHV2");
const Farm = artifacts.require("FarmWithApi");
const MockERC20 = artifacts.require("MockERC20");
const FarmBTC = artifacts.require("FarmBTC");
const OPERATOR = artifacts.require("FarmOperatorv2");

const Bridge = artifacts.require("BscMayaBridge");

module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let bridge = await deployProxy(Bridge,[],{deployer:deployer,initializer:"initialize",from:owner});
    console.log("BscBridge address:"+bridge.address);
    console.log("network",network);
};
