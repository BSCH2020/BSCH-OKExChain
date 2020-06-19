const { deployProxy, upgradeProxy,prepareUpgrade} = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");
var dateFormat = require("dateformat");

const BSCH = artifacts.require("BSCH");
const FarmOperatorv2 = artifacts.require("FarmOperatorv2");
const FarmOperator = artifacts.require("FarmOperator");
const BSC_OPT_ADDR = "0x8Bd446aD0710D04bF509A176D6373c7d2b76b5C1";

module.exports = async function (deployer,network, accounts) {
  let owner = deployer.networks[network].from;
    let opt = {};
    if (network=="bsc"|| network=="ethmain" 
        || network=="testbsc"
        ){
      opt = {"address":BSC_OPT_ADDR};//bsc
    }else{
      opt = await FarmOperator.deployed();

    }
    console.log("using owner:"+owner);
    await upgradeFarmOpt();
    
    async function upgradeFarmOpt(){
      FarmOperatorv2.class_defaults = {from:owner,
        gas:deployer.networks[network].gas,
        gasPrice:deployer.networks[network].gasPrice};
      const upgraded = await upgradeProxy(opt.address,FarmOperatorv2,{deployer:deployer,
                  initializer:"initialize",from:owner});
      console.log("upgraded!");
      console.log(upgraded.address);
    }

}

