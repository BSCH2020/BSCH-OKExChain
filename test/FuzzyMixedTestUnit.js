const { assert } = require("chai");
const {BigNumber,FixedNumber} = require("@ethersproject/bignumber");

const SToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
const BSCH = artifacts.require("BSCH");
const Farm = artifacts.require("FarmWithApi");
const MockERC20 = artifacts.require("MockERC20");
const fs = require("fs");
const { argv, exit } = require("process");
//a function to delay s seconds
const delay = s => new Promise(res => setTimeout(res, s*1000));
if (argv.length<5){
    console.log("please use following command");
    console.log("truffle test FuzzyTestUnit.js data.json");
    exit(1);
}
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
let timeUnit = 4;//10 seconds per unit to short test time
let rounds = 4;//4 rounds
let lockTime = 4*3;//12*4 = 48 seconds
let stakePeriod = 12;//seconds
let slotTimeKey = [];
let gAccountsInfo = [];
const EventType = {SLOT:1,ASSERT:2,DEPOSIT:3,STAKE:4,UNSTAKE:5,STAKE_LOCKED:6,UNSTAKE_LOCKED:7};
let data = fs.readFileSync(unitDataPath);
let json = JSON.parse(data);
// console.log(json);
// console.log(EventType);
let previousActCost = 0;
contract("FuzzyTest", async accounts=>{
    const [owner] = accounts;
    it("Fuzzy processing",async()=>{
        await init();
        for (let ii=0;ii<json.length;ii++){
            let element = json[ii];
            let start = Date.now();
            switch (EventType[element.eventType]) {
                case EventType.SLOT:
                    await actSLOT(element.data,ii);
                    break;
                case EventType.ASSERT:
                    await actASSERT(element.data,ii);
                    previousActCost += (Date.now()-start);
                    break;
                case EventType.DEPOSIT:
                    await actDEPOSIT(element.data,ii);
                    previousActCost += (Date.now()-start);
                    break;
                case EventType.STAKE:
                    await actSTAKE(element.data,ii);
                    previousActCost += (Date.now()-start);
                    break;
                case EventType.UNSTAKE:
                    await actUNSTAKE(element.data,ii);
                    previousActCost += (Date.now()-start);
                    break;             
                case EventType.STAKE_LOCKED:
                    // await actSTAKE_LOCKED(element.data,ii);
                    await actSTAKE(element.data,ii);
                    previousActCost += (Date.now()-start);
                    break;  
                case EventType.UNSTAKE_LOCKED:
                    // await actUNSTAKE_LOCKED(element.data,ii);
                    await actUNSTAKE(element.data,ii);
                    previousActCost += (Date.now()-start);
                    break;            
                default:
                    assert.fail(EventType.SLOT.toString()+" unknown eventType: "+element.eventType.toString());
                    break;                   
            }
        }
        // await json.forEach(element => {
            
        // });
    })

    async function init(){
        sToken = await BSCH.deployed();
        instance = sToken;
        rToken = await MockERC20.deployed();
        farm = await Farm.deployed();
        let paused = await farm.paused();
        if (paused){
            await farm.unpause();
        }
        await farm.changeMiniStakePeriodInSeconds(stakePeriod);
        assert.equal((await farm._miniStakePeriodInSeconds()).toNumber(),stakePeriod,"stake period change error");
        baseTime=(await farm._farmStartedTime()).toNumber();

        await instance.changeLockTimeUnitPerSeconds(timeUnit);
        let tu = await instance._lockTimeUnitPerSeconds();
        assert.equal(tu.toNumber(),timeUnit,"change time unit test");
        await instance.changeLockRounds(rounds);
        tu = await instance._lockRounds();
        assert.equal(tu.toNumber(),rounds,"change lock rounds unit test");

        await instance.changeLockTime(lockTime);
        tu = await instance._lockTime();
        assert.equal(tu.toNumber(),lockTime,"change lockTime unit test");

        //init mint
        let initAmount = 999999;
        for (let ii=0;ii<10;ii++){
            await mintLockedWith(ii,initAmount);
        }
        for (let ii=0;ii<10;ii++){
            await mintWith(ii,initAmount);
        }
    }

    async function delayWithNewBlock(time){
        if (time <=0)
            return;
        await delay(time);
        await mintWith(5,1000);
        
        let key = getTimeKey();
        if (slotTimeKey && slotTimeKey.length>0){
            let last = slotTimeKey[slotTimeKey.length-1];
            if (key>last){
                slotTimeKey.push(key);
            }
        }else{
            slotTimeKey = [];
            slotTimeKey.push(key);
        }
        console.log("--- delay time:"+time+" " + getTimeKey()+" ---");
    }
    async function actSLOT(data,ii){
        let time = stakePeriod - previousActCost/1000;
        await delayWithNewBlock(time);
        previousActCost = 0;
    }
    async function actASSERT(data,tt){
        if (data && data.length>0){
            for (let ii = 0;ii<data.length;ii++){
                let bal = await farm.getTotalRewardBalanceInPool(accounts[data[ii].user]);
                let no = Math.floor(data[ii].amount);
                if (BigNumber.from(bal.toString()) == BigNumber.from(no)){
                    //check passed
                    return;
                }
                if (no ==0){
                    assert.equal(bal.toNumber(),0,ii+" round "+tt+" assert error");
                    return;
                }
                //else check with precision
                let res = (FixedNumber.from(bal.toString()).divUnsafe(FixedNumber.from(no)))
                    .subUnsafe(FixedNumber.from(1.0));
                if (res<FixedNumber.from(0)){
                    res = FixedNumber.from(0).subUnsafe(res);
                }
                assert.equal((res<FixedNumber.from("0.0001")),true,
                    ii+" round "+tt+" assert error"+"actual:"+bal.toString()+" expected:"+no);
            }
            return;
        }
        assert.fail("undefined actASSERT with:"+data);
    }
    async function actDEPOSIT(data,ii){
        if (data.slot!=undefined && data.amount!=undefined){
            let timekey = slotTimeKey[data.slot];
            await depositRewardFrom(data.amount,timekey);
            return;
        }
        assert.fail("undefined actDEPOSIT with:"+data);
    }
    async function actSTAKE_LOCKED(data,ii){
        if (data.user!=undefined && data.amount!=undefined){
            await stakeLockedToMining(data.user,data.amount);
            return;
        }
        assert.fail("undefined actSTAKE with:"+data);
    }
    async function actUNSTAKE_LOCKED(data,ii){
        if (data.user!=undefined && data.amount!=undefined){
            await unStakeLocked(data.user,data.amount);
            return;
        }
        assert.fail("undefined actUNSTAKE with:"+data);
    }
    async function actSTAKE(data,ii){
        if (data.user!=undefined && data.amount!=undefined){
            await stakeToMining(data.user,data.amount);
            return;
        }
        assert.fail("undefined actSTAKE with:"+data);
    }
    async function actUNSTAKE(data,ii){
        if (data.user!=undefined && data.amount!=undefined){
            await unStake(data.user,data.amount);
            return;
        }
        assert.fail("undefined actUNSTAKE with:"+data);
    }
    function getTimeKey(){
        let time = Date.now()/1000;
        let passed = Math.round(Date.now()/1000-baseTime);
        let round = Math.round(passed/stakePeriod);
        let end = baseTime+round*stakePeriod;
        if (end<time){
            return end+stakePeriod;
        }
        return end;
    }
    async function mintWith(account_index,amount){
        await instance.mint(accounts[account_index],amount);
        gtotal+=amount;
        let info = getAccountInfo(account_index);
        info.balance = info.balance+amount;
    }
    function getAccountInfo(account_index){
        let info = gAccountsInfo[account_index];
        if (info ==null){
            gAccountsInfo[account_index] = {
                index:account_index,
                balance:0,
                locked:0
            };
        }
        return gAccountsInfo[account_index];
    }
    async function depositRewardFrom(num,time){
        await rToken.approve(farm.address,num,{from:accounts[0]});
        farm.depositRewardFromForTime(accounts[0],num,time,{from:accounts[0]});
        adminRToken =adminRToken.sub(BigNumber.from(num));
        farmRToken+=num;
        let bal = await rToken.balanceOf(farm.address);
        assert.equal(bal.toNumber(),farmRToken);
        bal = await rToken.balanceOf(accounts[0]);
        assert.equal(bal.toString(),adminRToken.toString());
    }
    async function stakeToMining(account_index,stakeNum){
        await sToken.approve(farm.address,stakeNum,{from:accounts[account_index]});
        let allow = await sToken.allowance(accounts[account_index],farm.address,{from:accounts[account_index]});
        // console.log("allow: "+allow.toNumber());
        await farm.depositToMining(stakeNum,{from:accounts[account_index]});
        stokenInFarm += stakeNum;
        let inFarmStoken = await sToken.balanceOf(farm.address);
        // console.log("farm's staked balance:"+inFarmStoken.toNumber());
        assert.equal(inFarmStoken.toNumber(),stokenInFarm);

        let info = getAccountInfo(account_index);
        info.balance -= stakeNum;
        let bal = await sToken.balanceOf(accounts[account_index]);
        assert.equal(bal.toNumber(),info.balance);
    }
    async function unStake(account_index,num){
        await farm.withdrawLatestSToken(num,{from:accounts[account_index]});
        stokenInFarm -= num;
        let info = getAccountInfo(account_index);
        info.balance+=num;
        let inFarmStoken = await sToken.balanceOf(farm.address);
        assert.equal(inFarmStoken.toNumber(),stokenInFarm);
        let bal = await sToken.balanceOf(accounts[account_index]);
        assert.equal(bal.toNumber(),info.balance);
    }
    async function mintWith(account_index,amount){
        await instance.mint(accounts[account_index],amount);
        gtotal+=amount;
        let info = getAccountInfo(account_index);
        info.balance = info.balance+amount;
    }
    async function mintLockedWith(account_index,amount){
        await instance.mintWithTimeLock(accounts[account_index],amount);
        gtotal+=amount;
        gtimeLocked+=amount;
        let info = getAccountInfo(account_index);
        info.balance = info.balance+amount;
        info.locked = info.locked+amount;
    }

    async function stakeLockedToMining(account_index,num){
        let bal = await sToken.linearLockedBalanceOf(accounts[account_index]);
        // console.log("locked bal:"+bal.toNumber());
        await sToken.approveLocked(farm.address,num,{from:accounts[account_index]});
        let allow = await sToken.allowanceLocked(accounts[account_index],farm.address,{from:accounts[account_index]});
        // console.log("allow locked: "+allow.toNumber());
        await farm.depositLockedToMining(num,{from:accounts[account_index]});
        stokenInFarm += num;
        stokenLockedInFarm += num;
        let inFarmStoken = await sToken.balanceOf(farm.address);
        // console.log("farm's staked balance:"+inFarmStoken.toNumber());
        assert.equal(inFarmStoken.toNumber(),stokenInFarm);
        
        // inFarmStoken = await sToken.linearLockedBalanceOf(farm.address);
        // console.log("farm's staked locked balance:"+inFarmStoken.toNumber());
        // assert.equal(inFarmStoken.toNumber(),stokenLockedInFarm);

        let info = getAccountInfo(account_index);
        info.balance -= num;
        info.locked -= num;

        bal = await sToken.balanceOf(accounts[account_index]);
        assert.equal(bal.toString(),info.balance.toString());
        
        // bal = await sToken.linearLockedBalanceOf(accounts[account_index]);
        // assert.equal(bal.toNumber(),info.locked,"locked num error"+info);
    }
    async function unStakeLocked(account_index,num){
        await farm.withdrawLatestLockedSToken(num,{from:accounts[account_index]});
        stokenInFarm -= num;
        stokenLockedInFarm -= num;
        let info = getAccountInfo(account_index);
        info.balance+=num;
        info.locked+=num;

        let inFarmStoken = await sToken.balanceOf(farm.address);
        // console.log("farm's staked balance:"+inFarmStoken.toNumber());
        assert.equal(inFarmStoken.toNumber(),stokenInFarm);

        // inFarmStoken = await sToken.linearLockedBalanceOf(farm.address);
        // console.log("farm's staked locked balance:"+inFarmStoken.toNumber());
        // assert.equal(inFarmStoken.toNumber(),stokenLockedInFarm);

        let bal = await sToken.balanceOf(accounts[account_index]);
        assert.equal(bal.toNumber(),info.balance);
        
        
        // bal = await sToken.linearLockedBalanceOf(accounts[account_index]);
        // assert.equal(bal.toNumber(),info.locked,"locked num error");
    }
});
