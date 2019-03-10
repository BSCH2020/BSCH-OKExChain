const { assert } = require("chai");
const {BigNumber} = require("@ethersproject/bignumber");

const SToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
const BSCH = artifacts.require("BSCH");
// const Farm = artifacts.require("FarmWithApi");
const Farm = artifacts.require("FarmBTC");
const MockERC20 = artifacts.require("MockERC20");

//a function to delay s seconds
const delay = s => new Promise(res => setTimeout(res, s*1000));

contract("Mining-inpool reward balance", async accounts=>{
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
    it("Mining BTC: testTotalRewardBalanceInPool",async ()=>{
        await init();
        let btcunit = 10;
        let A=7,B=8;
        let timekey = getTimeKey();
        let t1 = timekey;
        await mintWith(A,100);
        await mintWith(B,200);
        await stakeToMining(A,100);
        await stakeToMining(B,200);
        
        await depositRewardFrom(btcunit*0.5,timekey);        
        let slot = await farm.viewRoundSlot(t1);
        console.log(t1+" day1 slot t1:");
        console.log(slot);
        //before was day1
        await delayWithNewBlock(timeUnit*3);
        let t2 = getTimeKey();
        let bal = await farm.getTotalRewardBalanceInPool(accounts[A]);
        assert.equal(bal.toNumber(),0);
        bal = await farm.getTotalRewardBalanceInPool(accounts[B]);
        assert.equal(bal.toNumber(),0);

        await depositRewardFrom(btcunit*0.6,t2);
        // slot = await farm.viewRoundSlot(t1);
        // console.log(t2+" day2 slot t1:");
        // console.log(slot);
        slot = await farm.viewRoundSlot(t2);
        console.log(t2+" day2 slot t2:");
        console.log(slot);
        await depositRewardFrom(btcunit*0.5,t1);
        // slot = await farm.viewRoundSlot(t1);
        // console.log(t2+" day2 slot t1:");
        // console.log(slot);
        slot = await farm.viewRoundSlot(t2);
        console.log(t2+" day2 slot t2:");
        console.log(slot);
        
        //before was day2
        await delayWithNewBlock(timeUnit*3);

        let t3 = getTimeKey();
        await depositRewardFrom(btcunit*0.8,t3);
        await depositRewardFrom(btcunit*0.5,t1);
        await depositRewardFrom(btcunit*0.6,t2);
        
        await printUserInfo(B);
        await unStake(B,100);
        await printUserInfo(B);

        await stakeToMining(B,100);

        slot = await farm.viewRoundSlot(t3);
        console.log(t3+" day3 slot t3:");
        console.log(slot);
        slot = await farm.viewRoundSlot(t2);
        console.log(t3+" day3 slot t2:");
        console.log(slot);
        // slot = await farm.viewRoundSlot(t1);
        // console.log(t3+" day3 slot t1:");
        // console.log(slot);
        
        await delayWithNewBlock(1);
        bal = await farm.getTotalRewardBalanceInPool(accounts[A]);
        assert.equal(bal.toNumber(),0.4*btcunit);

        bal = await farm.getTotalRewardBalanceInPool(accounts[B]);
        assert.equal(bal.toNumber(),0.8*btcunit);

        //before was day3
        await delayWithNewBlock(timeUnit*3);
        let t4 = getTimeKey();
        bal = await farm.getTotalRewardBalanceInPool(accounts[A]);
        assert.equal(bal.toNumber(),0.8*btcunit);
        
        slot = await farm.viewRoundSlot(t3);
        console.log(t4+" day4 slot t3:");
        console.log(slot);
        slot = await farm.viewRoundSlot(t2);
        console.log(t4+" day4 slot t2:");
        console.log(slot);
        // slot = await farm.viewRoundSlot(t1);
        // console.log(t4+" day4 slot t1:");
        // console.log(slot);

        await printUserInfo(B);
        bal = await farm.getTotalRewardBalanceInPool(accounts[B]);
        assert.equal(bal.toNumber(),1.2*btcunit);

        await depositRewardFrom(btcunit*0.9,t4);
        slot = await farm.viewRoundSlot(t4);
        console.log(t4+" day4 slot t4:");
        console.log(slot);

        //before was day4
        await delayWithNewBlock(timeUnit*3);
        let t5 = getTimeKey();
        await depositRewardFrom(btcunit*0.6,t5);
        slot = await farm.viewRoundSlot(t4);
        console.log(t5+" day5 slot t4:");
        console.log(slot);


        bal = await farm.getTotalRewardBalanceInPool(accounts[A]);
        assert.equal(bal.toNumber(),1.1*btcunit);

        bal = await farm.getTotalRewardBalanceInPool(accounts[B]);
        assert.equal(bal.toNumber(),1.8*btcunit);

        //before was day5
        await delayWithNewBlock(timeUnit*3);

        bal = await farm.getTotalRewardBalanceInPool(accounts[A]);
        assert.equal(bal.toNumber(),1.3*btcunit);

        bal = await farm.getTotalRewardBalanceInPool(accounts[B]);
        assert.equal(bal.toNumber(),2.2*btcunit);

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
        assert.equal(bal.toNumber(),info.balance);
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
        farm.apiDepositRewardFromForTime(accounts[0],num,time,{from:accounts[0]});
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
