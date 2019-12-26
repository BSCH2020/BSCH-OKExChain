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
const TBTC = artifacts.require("tBTC");
const Bridge = artifacts.require("BscMayaBridge");
const ONLINE_TBTC_REBASE_STARTED_TIME = "2021-04-01 20:00 GMT+0800";//2020-12-18 20:00 GMT+0800;1608292800
const EST_DECIMAL = 9;
const DEFAULT_TBTC_MINT = 210;// /10

module.exports = async function (deployer,network, accounts) {
    let owner = deployer.networks[network].from;
    console.log("owner:"+owner);
    
    await deployTBTC();

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
};
