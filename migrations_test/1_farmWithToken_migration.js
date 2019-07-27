const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const {BigNumber} = require("@ethersproject/bignumber");
var dateFormat = require("dateformat");

const STToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
const Migrations = artifacts.require("Migrations");
const BSCH = artifacts.require("BSCHV2");
const Farm = artifacts.require("FarmWithApi");
const MockERC20 = artifacts.require("MockERC20");
const ONLINE_FARM_STARTED_TIME = "2020-12-18 20:00 GMT+0800";//2020-12-18 20:00 GMT+0800;1608292800

const BSC_BTCB_ADDRESS = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c";
const BSC_BSCH_ADDRESS = "0x78650B139471520656b9E7aA7A5e9276814a38e9";

module.exports = async function (deployer,network, accounts) {
  let owner = deployer.networks[network].from;
  let rewardToken = {};
  let bsch = {};
  let farm ={};
  let farm_desc= "Our mining farm for BTC";
  if (network=="bsc"|| network=="ethmain" 
        || network=="testbsc"
      ){
    rewardToken = {"address":BSC_BTCB_ADDRESS};
  }
  console.log("using owner:"+owner);

  await deployRToken();
  await deploySToken();
  // await deployFarm(bsch.address,rewardToken.address,farm_desc)
  // await changeSTokenToFarm();
  // await bsch.mint(owner,BigNumber.from("1000000").mul(BigNumber.from(1e18+"")));

  console.log("rewardToken deployed at:"+rewardToken.address);
  if (bsch.address){
    console.log('bsch deployed at:', bsch.address); 
    console.log("bsch owner:"+await bsch.getOwner());
  }
  if(farm.address){
    console.log("basetime:"+ (await farm._farmStartedTime()));
    console.log("_miniStakePeriodInSeconds"+(await farm._miniStakePeriodInSeconds()));
    console.log("farm owner:"+await farm.owner());
  }

  
  console.log("migration4 finished");

  async function deployRToken(){
    if (network =="bsc" || network=="ethmain" 
        // || network=="testbsc"
    ){
      //btcb token address
      rewardToken = {"address":BSC_BTCB_ADDRESS};
    }else{
      rewardToken = await deployer.deploy(MockERC20,"Bitcoin Mock","MBTC",BigNumber.from("10000").mul(BigNumber.from(1e18+"")));
      rewardToken = await MockERC20.deployed();
    }
    console.log("mock rewardToken deployed at:",rewardToken.address);
  }
  
  async function deploySToken(){
    BSCH.class_defaults = {from:owner,
      gas:deployer.networks[network].gas,
      gasPrice:deployer.networks[network].gasPrice};
    console.log(BSCH.class_defaults);
  
    bsch = await deployProxy(BSCH,[],
      {deployer:deployer,initializer:"initialize",from:owner});
  
    let contract = await BSCH.at(bsch.address);
    let res = await contract.initialized();
    console.log("bsch initialized:"+res);
    console.log('bsch deployed at:', bsch.address);
  }
  
  async function deployFarm(stokenAddr,rtokenAddr,desc,changeTime=false){
    // farm = await deployer.deploy(Farm,bsch.address,rewardToken.address,farm_desc,{from:owner});
    farm = await deployer.deploy(Farm,stokenAddr,rtokenAddr,desc);
    farm = await Farm.deployed();
    if(changeTime){
      if (network =="bsc" || network=="ethmain" 
        // || network=="testbsc"
      ){
        let date = new Date(ONLINE_FARM_STARTED_TIME);
        let time = date.getTime()/1000;
        await farm.changeBaseTime(time);
      }else{
        let initPeriod = 300;
        await farm.changeMiniStakePeriodInSeconds(initPeriod);
        let now = Date.now()/1000;
        now = now-now%100;
        await farm.changeBaseTime(now-initPeriod*2);
      }  
    }
    
    console.log("farm deployed at:"+farm.address);
    
  }
    
  async function changeSTokenToFarm(){
    await bsch.changeFarmContract(farm.address);
    let farmContract = await bsch._farmContract();
    console.log("farmContract address in bsch changed to:"+farmContract);
  }

};



