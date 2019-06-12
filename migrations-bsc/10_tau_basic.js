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
const ONLINE_TBTC_REBASE_STARTED_TIME = "2021-03-22 20:00 GMT+0800";//2020-12-18 20:00 GMT+0800;1608292800
const STAKE_PERIOD = 86400;
const BSC_BTCB_ADDRESS = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
const BSC_BSCH_ADDRESS = "0x78650B139471520656b9E7aA7A5e9276814a38e9";
const TBTC = artifacts.require("tBTC");
const TBTCEST_POLICY = artifacts.require("tBTCESTPolicy");
const Orchestrator = artifacts.require("Orchestrator");
const MANAGED_MARKET_ORACLE = artifacts.require("ManagedOracle");
const TBTCORACLE = artifacts.require("tBTCOracle");
const EST_DECIMAL = 9;
const DEFAULT_TBTC_MINT = 840;
const DEFAULT_TEAM_SPLIT = BigNumber.from(40).mul(1e12).div(100);
const DEFAUL_BSC_START_BLOCK_APPROX_MARCH_22 = 5853851;
module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let orchestrator = {};
    let tBTC = {};
    let tBTCESTPolicy = {};
    let chefTBTC = {};
    let tBtcOracle = {};

    await deployOrchestrator();
    
    await deploytBTCOracle();
    

    async function deployOrchestrator(){
        orchestrator = await deployProxy(Orchestrator,[],{deployer:deployer,initializer:"initialize",from:owner});
        console.log("orchestrator deployed at:",orchestrator.address);
    }
    async function deploytBTCOracle(){
        tBtcOracle = await deployProxy(TBTCORACLE,[],{deployer:deployer,initializer:"initialize",from:owner});
        console.log("tBtcOracle deployed at:",tBtcOracle.address);
    }
};





