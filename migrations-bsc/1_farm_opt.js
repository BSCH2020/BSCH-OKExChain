const { deployProxy, upgradeProxy,prepareUpgrade} = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");
var dateFormat = require("dateformat");

const BSCH = artifacts.require("BSCH");
const FarmOperatorv2 = artifacts.require("FarmOperatorv2");
const FarmOperator = artifacts.require("FarmOperator");
let farmopt = {};
module.exports = async function (deployer,network, accounts) {
  let owner = deployer.networks[network].from;
  // throw new Error("force stop")
  await deployFarmOpt();


  async function deployFarmOpt(){
    FarmOperator.class_defaults = {from:owner,
          gas:deployer.networks[network].gas,
          gasPrice:deployer.networks[network].gasPrice};
    console.log(FarmOperator.class_defaults);
  
    farmopt = await deployProxy(FarmOperator,[],
      {deployer:deployer,initializer:"initialize",from:owner});
  
    let contract = await FarmOperator.at(farmopt.address);
    let res = await contract.initialized();
    console.log("farmopt initialized:"+res);
    console.log('farmopt deployed at:', farmopt.address);
    console.log("please change farmopt's farm,stoken,rtoken addresses before online");
  }
}

