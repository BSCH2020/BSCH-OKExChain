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
const TBTCChef = artifacts.require("tBTCChef");
const MANAGED_MARKET_ORACLE = artifacts.require("ManagedOracle");
const TBTCORACLE = artifacts.require("tBTCOracle");
const EST_DECIMAL = 9;
const DEFAULT_TBTC_MINT = 210;// /10
const DEFAULT_TEAM_SPLIT = BigNumber.from(40).mul(1e12).div(100);
const DEFAUL_BSC_START_BLOCK_APPROX_MARCH_22 = 5853851;
const FarmBSCH = artifacts.require("FarmBSCH");
module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    let orchestrator = await Orchestrator.deployed();
    let tBTC = {};
    let tBTCESTPolicy = {};
    let chefTBTC = {};
    let tBtcOracle = await TBTCORACLE.deployed();
    
    // await deployTBTC();
    // await tmp();

    tBTC = await TBTC.deployed();

    // await deployTBTCESTPolicy();
    
    await deployTBTCChef();

    async function tmp(){
        console.log("tmp exec change start time");
        let farmbsch = await FarmBSCH.deployed();
        let date = new Date(ONLINE_FARM_STARTED_TIME);
        let time = date.getTime()/1000;

        await farmbsch.changeBaseTime(time);
    }

    async function deployTBTC(){        
        tBTC = await deployProxy(TBTC,[],{deployer:deployer,initializer:"initialize",from:owner});
        console.log("tBTC deployed at:",tBTC.address);
        let date = new Date(ONLINE_TBTC_REBASE_STARTED_TIME);
        let time = date.getTime()/1000;
        if (network=="dev"){
            time = (new Date()).getTime()/1000;
        }
        //rebase started
        await tBTC.startWithInitialSupply(BigNumber.from(10**(EST_DECIMAL-1)).mul(DEFAULT_TBTC_MINT),time);
        console.log("deployTBTC done");
        let totalSupply = await tBTC.totalSupply();
        console.log("totalSupply:"+totalSupply);

        let bal = await tBTC.balanceOf(owner);
        console.log("owner:"+owner+" balance:"+bal);
    }
    async function deployTBTCESTPolicy(){
        tBTCESTPolicy = await deployProxy(TBTCEST_POLICY,[tBTC.address],{deployer:deployer,initializer:"initialize",from:owner});
        console.log("tBTCESTPolicy deployed at:",tBTCESTPolicy.address);

        await tBTCESTPolicy.setMarketOracle(tBtcOracle.address);
        await tBTCESTPolicy.setOrchestrator(orchestrator.address);
        await tBTC.setMonetaryPolicy(tBTCESTPolicy.address);
        if (network.indexOf("dev")!=-1){
            //for development rebase every hour,rebase only during **:05 to **:50
            await tBTCESTPolicy.setRebaseTimingParameters(3600,5*60,45*60);
        }
        // TODO: check production rebase timing params
        await orchestrator.addPolicy(tBTCESTPolicy.address);

        let oracleControllerRole = await tBtcOracle.ORACLE_CONTROLLER_ROLE();
        tBtcOracle.grantRole(oracleControllerRole,tBTCESTPolicy.address);
        console.log("deployTBTCESTPolicy done");
    }
    
    async function deployTBTCChef(){
        tBTCESTPolicy = await TBTCEST_POLICY.deployed();
        chefTBTC = await deployProxy(TBTCChef,[],{deployer:deployer,initializer:"initialize",from:owner});
        console.log("TBTCChef deployed at:",chefTBTC.address);
        await chefTBTC.setRebasePolicy(tBTCESTPolicy.address);
        await chefTBTC.setTeamRebaseSplit(DEFAULT_TEAM_SPLIT);
        if(network=="bsc"){
            // await chefTBTC.setStartBlock(DEFAUL_BSC_START_BLOCK_APPROX_MARCH_22);
        }else if (network=="bsc_testnet"){
            // await chefTBTC.setStartBlock(7000648+86400*2/3);
            //total 15 hour*8 = 120 /24 5days to distribute all,every 15hours halfing
            await chefTBTC.setTimeParams(3,4*60*60,8);
            //mining supply 840,total supply 2100
            // await chefTBTC.setSupplyTargets(840*10**EST_DECIMAL,2100*10**EST_DECIMAL);
        }else{
            // await chefTBTC.setStartBlock(2);
            //20s/block,6hours a cycle, 8 cycles
            await chefTBTC.setTimeParams(20,6*60*60,8);
        }
        await chefTBTC.setAirdropSupply(924*10**9);
        let MINTER_ROLE = await tBTC.MINTER_ROLE();
        await tBTC.grantRole(MINTER_ROLE+"",chefTBTC.address);
        console.log("tBTC grantRole MINTER_ROLE to chefTBTC done");

        await tBTCESTPolicy.setChefAddress(chefTBTC.address);
        
        await chefTBTC.setRToken(tBTC.address);
        await chefTBTC.setAirDropToken(tBTC.address);
        
        console.log("tBTCESTPolicy setChefAddress done");
        console.log("deploy TBTCChef done");
    }
};





