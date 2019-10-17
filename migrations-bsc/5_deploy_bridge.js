const { deployProxy, upgradeProxy,prepareUpgrade} = require('@openzeppelin/truffle-upgrades');
const Migrations = artifacts.require("Migrations");

const BscBridge = artifacts.require("BscMayaBridge");
module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let bridge = await deployProxy(BscBridge,[],{deployer:deployer,initializer:"initialize",from:owner});
    console.log("BscBridge address:"+bridge.address);
    console.log("network",network);

    // let bridge = await BscBridge.deployed();
    // const upgraded = await upgradeProxy(bridge.address,BscBridge,{deployer:deployer,
    //     initializer:"initialize",from:owner});

    // console.log("upgraded!");
    // console.log(upgraded.address);
};
