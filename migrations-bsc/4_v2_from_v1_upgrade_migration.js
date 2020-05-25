const { deployProxy, upgradeProxy,prepareUpgrade} = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");
var dateFormat = require("dateformat");

const { promisify } = require('util');
const crypto = require('crypto');

// const STToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
// const Migrations = artifacts.require("Migrations");
const BSCH = artifacts.require("BSCH");
const BSCHV2 = artifacts.require("BSCHV2");
// const Farm = artifacts.require("FarmWithApi");
// const MockERC20 = artifacts.require("MockERC20");
// const FarmBTC = artifacts.require("FarmBTC");
let farmbtc = {};
const BSC_BTCB_ADDRESS = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
const BSC_BSCH_ADDRESS = "0x78650B139471520656b9E7aA7A5e9276814a38e9";
const BSC_DEPLOYER = "0xAd3784cD071602d6c9c2980d8e0933466C3F0a0a";

module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let rToken = {};
    let bsch = {};
    let network_id = deployer.networks[network].network_id;
    if (network=="bsc"|| network=="dev_bsc_fork" ){
        owner = BSC_DEPLOYER;
        rToken = {"address":BSC_BTCB_ADDRESS};
        bsch = {"address":BSC_BSCH_ADDRESS};
    }else{
        bsch = await BSCH.deployed();
    }
    console.log("using owner:"+owner);
    console.log("id:"+network_id);
    try{
        await upgradeSToken();
    }catch(error){
        console.log("error",error);
    }
    
    async function upgradeSToken(){ 
        // BSCH.class_defaults = {from:owner,
        //   gas:deployer.networks[network].gas,
        //   gasPrice:deployer.networks[network].gasPrice};
        
        // console.log(deployer);
        
        console.log("start upgrade");
        const upgraded = await upgradeProxy(bsch.address,BSCHV2,{deployer:deployer,
                    initializer:"initialize",from:owner,unsafeAllowCustomTypes: true});
        
        // bsch = await deployProxy(BSCH,[],
        //     {deployer:deployer,initializer:"initialize",from:owner});
        
        console.log("upgraded!");
        console.log(upgraded.address);
    }
    
    
};
