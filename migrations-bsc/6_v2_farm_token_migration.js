const { deployProxy, upgradeProxy,prepareUpgrade} = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");
var dateFormat = require("dateformat");

const STToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
const Migrations = artifacts.require("Migrations");
const BSCH = artifacts.require("BSCH");
const Farm = artifacts.require("FarmWithApi");
const MockERC20 = artifacts.require("MockERC20");
const BSCHV2 = artifacts.require("BSCHV2");
const FarmBTC = artifacts.require("FarmBTC");
const ONLINE_FARM_STARTED_TIME = "2020-12-18 20:00 GMT+0800";//2020-12-18 20:00 GMT+0800;1608292800
const STAKE_PERIOD = 86400;
let farmbtc = {};
const BSC_BTCB_ADDRESS = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
const BSC_BSCH_ADDRESS = "0x78650B139471520656b9E7aA7A5e9276814a38e9";
module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let rToken = {};
    let sToken = {};
    let bsch = {};
    let farm ={};
    let farm_desc= "Bitcoin Standard Circulation Hashrate Token mining farm for BTC";
    if (network=="bsc"|| network=="ethmain" 
        || network=="testbsc"
        ){
        owner = accounts[2]; 
        rToken = {"address":BSC_BTCB_ADDRESS};
        sToken = {"address":BSC_BSCH_ADDRESS};
    }else{
        rToken = await MockERC20.deployed();
        sToken = await BSCHV2.deployed();
    }
    
    await deployFarmBTC();

    async function deployFarmBTC(){        
        farmbtc = await deployProxy(FarmBTC,[],{deployer:deployer,initializer:"initialize",from:owner});
        console.log("FarmBTC deployed at:",farmbtc.address);
        let date = new Date(ONLINE_FARM_STARTED_TIME);
        let time = date.getTime()/1000;
        
        await farmbtc.changeBaseTime(time);
        await farmbtc.changeDesc(farm_desc);
        
        await farmbtc.changeMiniStakePeriodInSeconds(STAKE_PERIOD);
        if (network == "dev"){
            await farmbtc.changeMiniStakePeriodInSeconds(300);
        }
        
        await farmbtc.changeRewardToken(rToken.address);
        await farmbtc.changeSToken(sToken.address);
        await farmbtc.upgradeSetTimeKey(0);

    }



};





