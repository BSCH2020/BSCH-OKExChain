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
    // let chef = await TBTCChef.deployed();
    // console.log("start upgrade",chef.address);
    // > transaction hash:    0x0efb4d607f6776107326787e78b418d48361ea8cf4ffb2015938ac27de68be7e
    // > Blocks: 8            Seconds: 25
    // > contract address:    0x8b6E39a08EEC988b3561c1d55f5C6dfd05786B44
    // await prepareUpgrade(chef.address,TBTCChef,{deployer:deployer,initializer:"initialize",from:owner,unsafeAllowCustomTypes: true})
    // const upgraded = await upgradeProxy(chef.address,TBTCChef,{deployer:deployer,initializer:"initialize",from:owner,unsafeAllowCustomTypes: true});
    
    
    // console.log("chef upgraded!");

    // const adminFac = getProxyAdminFactory(TBTCChef);
    // console.log(adminFac);
    // const admin = new adminFac("0xaa4C10aa3DE2E4dA6b0c0C9d177F1fa77314c9d8");
    // await admin.upgrade("0xeA17a97705BB74b2c6270830943b7663890D7ceB","0x8b6E39a08EEC988b3561c1d55f5C6dfd05786B44");

    // let opt = await FarmOperatorv2.deployed();
    // const upgraded = await upgradeProxy(opt.address,FarmOperatorv2,{deployer:deployer,
    //         initializer:"initialize",from:owner});
    // console.log("upgraded!");
    // console.log(upgraded.address);
    console.log("start");
    // console.log("accounts",accounts);
    // await wait(5000);
    // let up = await TBTCORACLE.deployed();
    // let upgraded = await upgradeProxy(up.address,TBTCORACLE,{deployer:deployer,
    //     initializer:"initialize",from:owner});
    // console.log("upgraded!");
    // console.log(upgraded.address);

    // up = await TBTCEST_POLICY.deployed();
    // upgraded = await upgradeProxy(up.address,TBTCEST_POLICY,{deployer:deployer,
    //     initializer:"initialize",from:owner});
    // console.log("upgraded!");
    // console.log(upgraded.address);

    // let up = await TBTC.deployed();
    // let upgraded = await upgradeProxy(up.address,TBTC,{deployer:deployer,
    //     initializer:"initialize",from:owner});
    // console.log("upgraded!");
    // console.log(upgraded.address);

    let up = await FarmOperatorv2.deployed();
    let upgraded = await upgradeProxy(up.address,FarmOperatorv2,{deployer:deployer,
        initializer:"initialize",from:owner});
    console.log("upgraded!");
    console.log(upgraded.address);
    // await upgraded.adminChangeOrch("0x5E4348da028A8D7734fA2945C76723248fa96e3c");

    // let up = await Orchestrator.deployed();
    // let upgraded = await upgradeProxy(up.address,Orchestrator,{deployer:deployer,
    //     initializer:"initialize",from:owner});
    // console.log("upgraded!");
    // console.log(upgraded.address);

    // let up = await TBTCChef.deployed();
    // let upgraded = await upgradeProxy(up.address,TBTCChef,{deployer:deployer,
    //     initializer:"initialize",from:owner});
    // console.log("upgraded!");
    // console.log(upgraded.address);
}

function sleep(delay) {
    var start = (new Date()).getTime();
    while ((new Date()).getTime() - start < delay) {
        // 使用  continue 实现；
        continue; 
    }
}
function wait(ms) {
    return new Promise(resolve => setTimeout(() =>resolve(), ms));
};
