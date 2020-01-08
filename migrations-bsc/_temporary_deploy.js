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
const TBTCEST_POLICY = artifacts.require("tBTCESTPolicy");
const Bridge = artifacts.require("BscMayaBridge");
const TBTCChef = artifacts.require("tBTCChef");
module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    // let bridge = await deployProxy(Bridge,[],{deployer:deployer,initializer:"initialize",from:owner});
    // console.log("BscBridge address:"+bridge.address);
    // console.log("network",network);
    // const policy = await TBTCEST_POLICY.deployed();

    // const upgraded = await upgradeProxy(policy.address,TBTCEST_POLICY,{deployer:deployer,
    //     initializer:"initialize",from:owner});
    // console.log("upgraded!");
    // console.log(upgraded.address);

    const chef = await TBTCChef.deployed();

    const upgraded = await upgradeProxy(chef.address,TBTCChef,{deployer:deployer,
        initializer:"initialize",from:owner,unsafeAllowCustomTypes:true});
    await chef.setAirdropSupply(924*10**9);

    console.log("upgraded!");
    console.log(upgraded.address);
    
    throw("foce stopped");
};
