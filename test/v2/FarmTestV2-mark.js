const { assert } = require("chai");
const {BigNumber} = require("@ethersproject/bignumber");

const SToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
const BSCH = artifacts.require("BSCH");
// const Farm = artifacts.require("FarmWithApi");
const Farm = artifacts.require("FarmBTC");
const MockERC20 = artifacts.require("MockERC20");

//a function to delay s seconds
const delay = s => new Promise(res => setTimeout(res, s*1000));

contract("Mining lowest water mark", async accounts=>{
    const [owner] = accounts;
    let gtotal = 0,gtimeLocked=0;
    let sToken = null;
    let farm = null;
    let rToken = null;
    let instance = null;
    let gAccountsInfo = [];
    let timeUnit = 4;//10 seconds per unit to short test time
    let rounds = 4;//4 rounds
    let lockTime = 4*3;//12*4 = 48 seconds
    let stakePeriod = 12;//seconds
    let stokenInFarm = 0;
    let stokenLockedInFarm=0;
    let baseTime = 0;
    let adminRToken =BigNumber.from("10000000000000000000000");
    let farmRToken = 0;
    it("Mining BTC: testLowestWaterMark",async ()=>{
        //return;
        await init(); 
        let stakeNum = 100;
        await mintWith(0,stakeNum);
        await mintWith(2,stakeNum);
        await mintWith(3,stakeNum*2);
        await stakeToMining(2,stakeNum);
        await stakeToMining(3,stakeNum*2);
        console.log(getTimeKey()+" tkey");
        await delayWithNewBlock(2);
        console.log(baseTime+"basetime");
        let timekey = getTimeKey();
        console.log(timekey+" tkey-------");
        let slot = await farm.viewRoundSlot(timekey);
        console.log(slot);
        assert.equal(slot.stakedLowestWaterMark,0,"stakedLowestWaterMark should be 0");
        assert.equal(slot.totalStaked,stakeNum*3,"total stake num error",slot.totalStaked,stakeNum*3);
        assert.equal(slot.totalStakedInSlot,stakeNum*3,"totalStakedInSlot error");

        let user = await farm.viewUserInfo(accounts[2]);
        assert.equal(user.amount,stakeNum,"user.amount error");
        user = await farm.viewUserInfo(accounts[3]);
        assert.equal(user.amount,stakeNum*2,"user.amount error");

        await unStake(2,stakeNum/2);
        await unStake(3,stakeNum);
        user = await farm.viewUserInfo(accounts[2]);
        console.log(user);
        assert.equal(user.stakeInfo[0].withdrawed,stakeNum/2,"withdrawed error");
        user = await farm.viewUserInfo(accounts[3]);
        assert.equal(user.stakeInfo[0].withdrawed,stakeNum,"withdrawed error");
        await delayWithNewBlock(stakePeriod);

        await stakeToMining(0,100);
        timekey = getTimeKey();
        console.log(timekey+" tkey-------");
        slot = await farm.viewRoundSlot(timekey);
        assert.equal(slot.stakedLowestWaterMark,stakeNum*1.5,"stakedLowestWaterMark should be 150");

        await stakeToMining(2,1);
        await stakeToMining(3,2);
        slot = await farm.viewRoundSlot(timekey);
        assert.equal(slot.stakedLowestWaterMark,stakeNum*1.5,"stakedLowestWaterMark should be 150");

        timekey = getTimeKey();
        console.log(timekey+" tkey-------");

        await unStake(2,11);
        await unStake(3,12);
        slot = await farm.viewRoundSlot(timekey);
        assert.equal(slot.stakedLowestWaterMark,130,"stakedLowestWaterMark should be 130");

        await unStake(0,100);

    });

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
    /**
     * delay and generate new block that affects blockchain system's now parameter
     * @param {*} time 
     */
    async function delayWithNewBlock(time){
        if (time <=0)
            return;
        await delay(time);
        await mintWith(5,1000);
        console.log("--- delay time:"+time+" " + getTimeKey()+" ---");
    }
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

    }
    async function printUserInfo(account_index){
        let user = await farm.viewUserInfo(accounts[account_index]);
        console.log(account_index+"user info:");
        console.log(user);
    }
    async function stakeToMining(account_index,stakeNum){
        await sToken.approve(farm.address,stakeNum,{from:accounts[account_index]});
        let allow = await sToken.allowance(accounts[account_index],farm.address,{from:accounts[account_index]});
        console.log("allow: "+allow.toNumber());
        await farm.depositToMining(stakeNum,{from:accounts[account_index]});
        stokenInFarm += stakeNum;
        let inFarmStoken = await sToken.balanceOf(farm.address);
        console.log("farm's staked balance:"+inFarmStoken.toNumber());
        assert.equal(inFarmStoken.toNumber(),stokenInFarm);

        let info = getAccountInfo(account_index);
        info.balance -= stakeNum;
        let bal = await sToken.balanceOf(accounts[account_index]);
        assert.equal(bal.toString(),info.balance.toString(),"not equal",bal,info.balance);
    }
    async function stakeLockedToMining(account_index,num){
        let bal = await sToken.linearLockedBalanceOf(accounts[account_index]);
        console.log("locked bal:"+bal.toNumber());
        await sToken.approveLocked(farm.address,num,{from:accounts[account_index]});
        let allow = await sToken.allowanceLocked(accounts[account_index],farm.address,{from:accounts[account_index]});
        console.log("allow locked: "+allow.toNumber());
        await farm.depositLockedToMining(num,{from:accounts[account_index]});
        stokenInFarm += num;
        stokenLockedInFarm += num;
        let inFarmStoken = await sToken.balanceOf(farm.address);
        console.log("farm's staked balance:"+inFarmStoken.toNumber());
        assert.equal(inFarmStoken.toNumber(),stokenInFarm);
        
        inFarmStoken = await sToken.linearLockedBalanceOf(farm.address);
        console.log("farm's staked locked balance:"+inFarmStoken.toNumber());
        assert.equal(inFarmStoken.toNumber(),stokenLockedInFarm);

        let info = getAccountInfo(account_index);
        info.balance -= num;
        info.locked -= num;

        bal = await sToken.balanceOf(accounts[account_index]);
        assert.equal(bal.toNumber(),info.balance);
        
        
        bal = await sToken.linearLockedBalanceOf(accounts[account_index]);
        assert.equal(bal.toNumber(),info.locked,"locked num error");


    }
    async function unStakeLocked(account_index,num){
        await farm.withdrawLatestLockedSToken(num,{from:accounts[account_index]});
        stokenInFarm -= num;
        stokenLockedInFarm -= num;
        let info = getAccountInfo(account_index);
        info.balance+=num;
        info.locked+=num;

        let inFarmStoken = await sToken.balanceOf(farm.address);
        console.log("farm's staked balance:"+inFarmStoken.toNumber());
        assert.equal(inFarmStoken.toNumber(),stokenInFarm);

        inFarmStoken = await sToken.linearLockedBalanceOf(farm.address);
        console.log("farm's staked locked balance:"+inFarmStoken.toNumber());
        assert.equal(inFarmStoken.toNumber(),stokenLockedInFarm);

        let bal = await sToken.balanceOf(accounts[account_index]);
        assert.equal(bal.toNumber(),info.balance);
        
        
        bal = await sToken.linearLockedBalanceOf(accounts[account_index]);
        assert.equal(bal.toNumber(),info.locked,"locked num error");
    }
    async function unStake(account_index,num){
        await farm.apiWithdrawLatestSToken(num,{from:accounts[account_index]});
        stokenInFarm -= num;
        let info = getAccountInfo(account_index);
        info.balance+=num;
        let inFarmStoken = await sToken.balanceOf(farm.address);
        assert.equal(inFarmStoken.toNumber(),stokenInFarm);
        let bal = await sToken.balanceOf(accounts[account_index]);
        assert.equal(bal.toNumber(),info.balance);
    }
    async function depositRewardFrom(num,time){
        await rToken.approve(farm.address,num,{from:accounts[0]});
        // console.log(farm);
        farm.depositRewardFromForTime(accounts[0],num,time,{from:accounts[0]});
        // console.log("xxxxxxxx");
        // console.log(xxx);
        // console.log(xxx.toNumber());
        // xxx = await farm.depositRewardFromForTime(accounts[0],num,time);
        // console.log("xxxxxxxx");
        // console.log(xxx);
        adminRToken =adminRToken.sub(BigNumber.from(num));
        farmRToken+=num;
        let bal = await rToken.balanceOf(farm.address);
        assert.equal(bal.toNumber(),farmRToken);
        bal = await rToken.balanceOf(accounts[0]);
        assert.equal(bal.toString(),adminRToken.toString());
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
    /**
     * basic mint process
     * @param {int} account_index 
     * @param {int} amount 
     */
    async function mintWith(account_index,amount){
        await instance.mint(accounts[account_index],amount);
        gtotal+=amount;
        let info = getAccountInfo(account_index);
        info.balance = info.balance+amount;
    }
    /**
     * basic mint locked with
     * @param {int} account_index 
     * @param {int} amount 
     */
    async function mintLockedWith(account_index,amount){
        await instance.mintWithTimeLock(accounts[account_index],amount);
        gtotal+=amount;
        gtimeLocked+=amount;
        let info = getAccountInfo(account_index);
        info.balance = info.balance+amount;
        info.locked = info.locked+amount;
    }
})
