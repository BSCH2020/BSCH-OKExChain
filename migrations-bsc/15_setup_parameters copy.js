const { deployProxy, upgradeProxy,prepareUpgrade} = require('@openzeppelin/truffle-upgrades');
// const {getProxyAdminFactory} = require('@openzeppelin/truffle-upgrades/factories');
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
const MASTER_COLLECTOR = artifacts.require("MasterCollector");

const ONLINE_FARM_STARTED_TIME = "2020-12-18 20:00 GMT+0800";//2020-12-18 20:00 GMT+0800;1608292800
const ONLINE_TBTC_REBASE_STARTED_TIME = "2021-03-22 20:00 GMT+0800";//2020-12-18 20:00 GMT+0800;1608292800
const STAKE_PERIOD = 86400;
const BSC_BTCB_ADDRESS = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
const BSC_BSCH_ADDRESS = "0x78650B139471520656b9E7aA7A5e9276814a38e9";
const TBTC = artifacts.require("tBTC");
const MockBTC = artifacts.require("MockBTC");
const TBTCEST_POLICY = artifacts.require("tBTCESTPolicy");
const Orchestrator = artifacts.require("Orchestrator");
const TBTCChef = artifacts.require("tBTCChef");
const MANAGED_MARKET_ORACLE = artifacts.require("ManagedOracle");
const TBTCORACLE = artifacts.require("tBTCOracle");
const EST_DECIMAL = 9;
const DEFAULT_TBTC_MINT = 840;
const DEFAULT_TEAM_SPLIT = BigNumber.from(40).mul(1e12).div(100);
const DEFAUL_BSC_START_BLOCK_APPROX_MARCH_22 = 5853851;
const Chef_TYPE = {BLOCK:0,DAILY:1};
const FarmOperatorv2 = artifacts.require("FarmOperatorv2");
module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let collector = {};
    let btcb = {};
    let farmbtc = await FarmBTC.deployed();
    let farmbsch = await FarmBSCH.deployed();
    if (network.indexOf("dev")!=-1){
        //every hour
        farmbtc.changeMiniStakePeriodInSeconds(3600);
        farmbsch.changeMiniStakePeriodInSeconds(3600);
        let bsch = await BSCHV2.deployed();
        await bsch.adminUpgradeDecimal(17);
        console.log("decimal upgrade to 17");
    }else{

    }
    
    let paused = await farmbtc.paused();
    if (paused){
        farmbtc.unpause();
    }
    paused = await farmbsch.paused();
    if (paused){
        farmbsch.unpause();
    }
    
}
