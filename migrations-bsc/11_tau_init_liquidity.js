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
module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let pancakeFactory = {};
    let pancakeFact_Addr;
    let btcb_addr;
    let lpAddress={};
    let pancakeRouter;
    if (network=="bsc_testnet"){
        pancakeFact_Addr = PANCAKE_FACTORY_BSC_TESTNET;
        btcb_addr = BTCB_ADDR_TESTNET;
        pancakeRouter = ROUTER_TESTNET;
    }else if (network=="bsc"){
        pancakeFact_Addr = "";
        btcb_addr = BTCB_ADDR_BSC;
        pancakeRouter = "";
    }else if (network=="dev_bsc"){
        pancakeFact_Addr = "0x35beF3a11EB2169D46F04eE147167ADcbbBeeE1C";
        pancakeRouter = "0x593cdaa5747075555b1db29a7E4Fab06A66EC970";
        let mockedBtcb = await MockERC20.deployed();
        btcb_addr = mockedBtcb.address;
    }

    await createSwapPair();

    let oracle = await TBTCORACLE.deployed();

    await oracle.setTTokenIntermediaAddress(lpAddress+"");

    async function createSwapPair(){
        let tBTC = await TBTC.deployed();
        pancakeFactory = await IPancakeFactory.at(pancakeFact_Addr);
        lpAddress = await pancakeFactory.getPair(btcb_addr,tBTC.address);
        if (lpAddress == '0x0000000000000000000000000000000000000000'){
            lpAddress = await pancakeFactory.getPair(tBTC.address,btcb_addr);
        }
        if (lpAddress == '0x0000000000000000000000000000000000000000'){
            lpAddress = await pancakeFactory.createPair(btcb_addr,tBTC.address);
            console.log("pancakeFactory createPair:"+btcb_addr+","+tBTC.address);
            lpAddress = await pancakeFactory.getPair(btcb_addr,tBTC.address);
            if (lpAddress == '0x0000000000000000000000000000000000000000'){
                lpAddress = await pancakeFactory.getPair(tBTC.address,btcb_addr);
            }
        }

        
        console.log("pancakeFactory tbtc-btcb-lp address:",lpAddress);
        
        let router = await IPancakeRouter.at(pancakeRouter);

        let btcb = await IBEP20.at(btcb_addr);
        let amountADesire = await btcb.balanceOf(owner);
        //90% of my balance will be used to provide liquidity
        console.log("amountADesire",amountADesire+"");
        if (network=="dev_bsc"){
            //5
            amountADesire = BigNumber.from(5).mul(BigNumber.from(1e18+""));
        }else{
            //1
            amountADesire = BigNumber.from(1).mul(BigNumber.from(1e18+""));
        }
        const BTCB_DECIMAL = 18;
        const TBTC_DECIMAL = 9;
        await btcb.approve(router.address,amountADesire);
        
        let now = Math.round(Date.now()/1000);
        let amountBDesire = amountADesire.div(10**(BTCB_DECIMAL-TBTC_DECIMAL));

        await tBTC.approve(router.address,amountBDesire);
        console.log(btcb_addr+","+tBTC.address+" pancake swap router add liquidity with amout:",amountADesire+"",amountBDesire+"");

        let result = await router.addLiquidity(btcb_addr,tBTC.address,
            amountADesire,amountBDesire,0,0,owner,(now+100));

        console.log("liqudity add result:",result);
        
    }
    
};





