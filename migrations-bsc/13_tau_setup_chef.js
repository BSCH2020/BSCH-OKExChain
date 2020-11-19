const { deployProxy, upgradeProxy,prepareUpgrade} = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");
var dateFormat = require("dateformat");

const STToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
const Migrations = artifacts.require("Migrations");
const BSCH = artifacts.require("BSCH");
const Farm = artifacts.require("FarmWithApi");
const MockERC20 = artifacts.require("MockERC20");
const IBEP20 = artifacts.require("IBEP20");
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
const IPancakeFactory = artifacts.require("IPancakeFactory");
const TBTCChef = artifacts.require("tBTCChef");
const MANAGED_MARKET_ORACLE = artifacts.require("ManagedOracle");
const TBTCORACLE = artifacts.require("tBTCOracle");
const IPancakeRouter = artifacts.require("IPancakeRouter02");
const EST_DECIMAL = 9;
const DEFAULT_TBTC_MINT = 840;
const DEFAULT_TEAM_SPLIT = BigNumber.from(40).mul(1e12).div(100);
const DEFAUL_BSC_START_BLOCK_APPROX_MARCH_22 = 5853851;
const PANCAKE_FACTORY_BSC_TESTNET = "0x6725F303b657a9451d8BA641348b6761A6CC7a17";
const BTCB_ADDR_TESTNET = "0x6ce8da28e2f864420840cf74474eff5fd80e65b8";
const BTCB_ADDR_BSC= "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c";
const ROUTER_TESTNET ="0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
const BSCH_MINING_YEILD = 1050;
const BTCB_MINING_YEILD = 21;
const TBTC_MINING_YEILD = 84;
const BTCB_TBTC_MINING_YEILD = 0;
const TOTAL_YEILD = BSCH_MINING_YEILD+BTCB_MINING_YEILD+TBTC_MINING_YEILD+BTCB_TBTC_MINING_YEILD;

module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let pancakeFactory = {};
    let pancakeFact_Addr;
    let btcb_addr;
    let lpAddress;
    let pancakeRouter;
    let oracle = await TBTCORACLE.deployed();
    if (network=="bsc_testnet"){
        pancakeFact_Addr = PANCAKE_FACTORY_BSC_TESTNET;
        btcb_addr = BTCB_ADDR_TESTNET;
        pancakeRouter = ROUTER_TESTNET;
    }else if (network=="bsc"){
        pancakeFact_Addr = "";
        btcb_addr = BTCB_ADDR_BSC;
        pancakeRouter = "";
        lpAddress = "0x2D4E52c48fD18eE06D3959E82AB0f773c41B9277";

    }else if (network=="dev_bsc"){
        pancakeFact_Addr = "0x35beF3a11EB2169D46F04eE147167ADcbbBeeE1C";
        pancakeRouter = "0x593cdaa5747075555b1db29a7E4Fab06A66EC970";
        let mockedBtcb = await MockERC20.deployed();
        btcb_addr = mockedBtcb.address;
        lpAddress = await oracle._tToken_Intermedia();
    }
    console.log("start upgrade,",oracle.address);

    // const upgraded = await upgradeProxy(oracle.address,TBTCORACLE,{deployer:deployer,initializer:"initialize",from:owner});
    // console.log("oracle upgraded!",upgraded.address);
    // oracle = await TBTCORACLE.deployed();

    await oracle.setTTokenIntermediaAddress(lpAddress);
    console.log("oracle.setTTokenIntermediaAddress:",lpAddress);

    let tBtcChef = await TBTCChef.deployed();
    let bsch = await BSCHV2.deployed();
    let tBtc = await TBTC.deployed();
    //adding bsch staking to mine tBTC
    await tBtcChef.add(BSCH_MINING_YEILD,bsch.address,false);

    //adding btcb staking to mine tBTC
    await tBtcChef.add(BTCB_MINING_YEILD,btcb_addr,false);

    //adding tBTC staking to mine tBTC
    await tBtcChef.add(TBTC_MINING_YEILD,tBtc.address,false);

    
    

    //adding tBTC-BTCB-LP staking to mine tBTC
    // await tBtcChef.add(BTCB_TBTC_MINING_YEILD,lpAddress,false);

    let totalAlloc = await tBtcChef.totalAllocPoint();

    console.log("tBtcChef setup ok,totalAllocPoint:",totalAlloc+"");
    
};





