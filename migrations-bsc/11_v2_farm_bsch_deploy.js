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
const FarmBSCH = artifacts.require("FarmBSCH");
const ONLINE_FARM_STARTED_TIME = "2020-12-18 20:00 GMT+0800";//2020-12-18 20:00 GMT+0800;1608292800
const ONLINE_TBTC_REBASE_STARTED_TIME = "2021-03-22 20:00 GMT+0800";//2020-12-18 20:00 GMT+0800;1608292800
const STAKE_PERIOD = 86400;
const BSC_BTCB_ADDRESS = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
const BSC_BSCH_ADDRESS = "0x78650B139471520656b9E7aA7A5e9276814a38e9";
const TBTC = artifacts.require("tBTC");
const TBTCEST_POLICY = artifacts.require("tBTCESTPolicy");
const Orchestrator = artifacts.require("Orchestrator");

const EST_DECIMAL = 9;
const DEFAULT_TBTC_MINT = 840;
module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let farmBSCH = {};
    let rToken = {};
    let sToken = {};
    // rToken = await MockERC20.deployed();
    sToken = await BSCHV2.deployed();
    console.log("bsch address:,",sToken.address);
    
    await deployFarmBSCH();
    async function deployFarmBSCH(){
        farmBSCH = await deployProxy(FarmBSCH,[],{deployer:deployer,initializer:"initialize",from:owner});
        let initPeriod = 86400;
        if (network.indexOf("dev")!=-1){
            initPeriod = 300;
        }
        await farmBSCH.changeMiniStakePeriodInSeconds(initPeriod);
        let now = Date.now()/1000;
        now = now-now%100;

        let date = new Date(ONLINE_FARM_STARTED_TIME);
        let time = date.getTime()/1000;

        await farmBSCH.changeBaseTime(time);
        await farmBSCH.changeDesc("Bitcoin Standard Circulation Hashrate Token mining farm for BSCH");
        await farmBSCH.changeRewardToken(sToken.address);
        await farmBSCH.changeSToken(sToken.address);
        console.log("farmBSCH was setup at:",farmBSCH.address);
    }

    
};





