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
let farmbtc = {};

module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let rToken = {};
    let bsch = {};
    let farm ={};
    let op = {}
    let farm_desc= "Our mining farm for BTC";
    op = await OPERATOR.deployed();
    if (network=="bsc"|| network=="ethmain" 
        || network=="testbsc"
        ){
        rToken = {"address":"0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c"};
        op = await OPERATOR.deployed();
    }
    console.log("using owner:",owner);
    await upgradeOperator();
    

    async function upgradeOperator(){
        const upgraded = await upgradeProxy(op.address,OPERATOR,{deployer:deployer,
            initializer:"initialize",from:owner,unsafeAllowCustomTypes:true});
        console.log("upgraded!");
        console.log(upgraded.address);
    }



    async function upgradeFarmBTC(){
        let farmbtc = await FarmBTC.deployed();
        FarmBTC.class_defaults = {from:owner,
          gas:deployer.networks[network].gas,
          gasPrice:deployer.networks[network].gasPrice};
        
        // console.log(deployer);
        
        console.log("start upgrade");
        const upgraded = await upgradeProxy(farmbtc.address,FarmBTC,{deployer:deployer,
                    initializer:"initialize",from:owner});
        
        console.log("upgraded!");
        console.log(upgraded.address);
    }
};





