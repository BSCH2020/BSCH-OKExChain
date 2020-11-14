
const { assert } = require("chai");
const {BigNumber,FixedNumber} = require("@ethersproject/bignumber");

const SToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
const BSCH = artifacts.require("BSCHV2");
// const Farm = artifacts.require("FarmWithApi");
const Farm = artifacts.require("FarmBTC");
const MockERC20 = artifacts.require("MockERC20");
const fs = require("fs");
const { argv, exit } = require("process");
//a function to delay s seconds
const delay = s => new Promise(res => setTimeout(res, s*1000));
let unitDataPath = argv[4];
let gtotal = 0,gtimeLocked=0;
let sToken = null;
let instance = null;
let rToken = null;
let farm = null;
let stokenInFarm = 0;
let stokenLockedInFarm=0;
let baseTime = 0;
let adminRToken =BigNumber.from("10000000000000000000000");
let farmRToken = 0;
// let timeUnit = 4;//10 seconds per unit to short test time
// let rounds = 4;//4 rounds
// let lockTime = 4*3;//12*4 = 48 seconds
// let stakePeriod = 12;//seconds
let timeUnit = 4;//10 seconds per unit to short test time
let rounds = 4;//4 rounds
let lockTime = 12;//12*4 = 48 seconds
let stakePeriod = 20;//seconds

let slotTimeKey = [];
let gAccountsInfo = [];
const EventType = {SLOT:1,ASSERT:2,DEPOSIT:3,STAKE:4,UNSTAKE:5};
let data = fs.readFileSync(unitDataPath);
let json = JSON.parse(data);
// console.log(json);
// console.log(EventType);
let previousActCost = 0;
contract("DebugTest", async (accounts ,debug)=>{
    const [owner] = accounts;
    it("Debug processing",async()=>{
        farm = await FarmBTC.deployed();
        await debug(farm.getTotalRewardBalanceInPool('0xF7a95935232f63e39d52Ab014937c2d5EA06aD3E'));
    })
})
