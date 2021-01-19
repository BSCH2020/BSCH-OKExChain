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
module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let collector = {};
    let btcb = {};
    if (network.indexOf("dev")!=-1){
        
    }else{

    }
    
    await deployMasterCollector();

    async function deployMasterCollector(){
        collector = await deployProxy(MASTER_COLLECTOR,[],{deployer:deployer,initializer:"initialize",from:owner});
        console.log("collector deployed at:",collector.address);
        let tBTCChef = await TBTCChef.deployed();
        let rToken = await tBTCChef.rToken();
        //add BSCH_tbtc_MINING
        await collector.addChef(tBTCChef.address,Chef_TYPE.BLOCK,rToken,0);
        //add BTCB_tbtc_MINING
        await collector.addChef(tBTCChef.address,Chef_TYPE.BLOCK,rToken,1);
        //add TBTC_tbtc_MINING
        await collector.addChef(tBTCChef.address,Chef_TYPE.BLOCK,rToken,2);
        // //add LP_tbtc_MINING
        // await collector.addChef(tBTCChef.address,Chef_TYPE.BLOCK,rToken,3);
        
        let farmBSCH = await FarmBSCH.deployed();
        let bschReward = await farmBSCH._rewardToken();
        //add BSCH_BSCH_MINING
        console.log("adding daily rewardtoken",farmBSCH.address,bschReward);
        await collector.addChef(farmBSCH.address,Chef_TYPE.DAILY,bschReward,0);

        // let collector = await MASTER_COLLECTOR.deployed();
        let farmBTC = await FarmBTC.deployed();
        let btcReward = await farmBTC._rewardToken();
        //add BSCH_BTCB_MINING
        console.log("adding daily rewardtoken",farmBTC.address,btcReward);
        await collector.addChef(farmBTC.address,Chef_TYPE.DAILY,btcReward,0);


    }

    async function deployMockBTC(){
        btcb = await deployProxy(MockBTC,[],{deployer:deployer,initializer:"initialize",from:owner});
        console.log("mocked btcb deployed at:",btcb.address);
    }
}
