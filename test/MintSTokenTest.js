const SToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
const BSCH = artifacts.require("BSCH");
//a function to delay s seconds
const delay = s => new Promise(res => setTimeout(res, s*1000));

contract("BSCH", async accounts=>{
    let timeUnit = 10;//10 seconds per unit to short test time
    let rounds = 4;//10 rounds
    let lockTime = 4*2;//8*4 = 32 seconds

    let instance = null;
    let gtotal=0,gtimeLocked=0,gtotalReleased=0;
    let gAccountsInfo = [];
    it("linear mint token function test",async ()=>{
        //return;
        await init();
        await testMintMintLockedWith(10000,2000);
        await testMintMintLockedWith(10300,3200);
        console.log(gAccountsInfo);
        await transferFrom(0,8,getAccountInfo(0).balance);
    });
    it("locked token transfer:testWithdrawLockedAmount",async()=>{
        //return;
        await init();
        await mintLockedWith(2,40);
        await printAccountBal(2);
        await delayWithNewBlock(timeUnit*lockTime/rounds);
        console.log("1 round passed");
        await mintLockedWith(2,40);

        await printAccountBal(2);
        await instance.approveLocked(accounts[3],70,{from:accounts[2]});
        await instance.transferLockedFrom(accounts[2],accounts[3],70,{from:accounts[3]});
        console.log("approve withdrawed 70");
        await printAccountBal(2);
        await printAccountBal(3);
        
        await delayWithNewBlock(timeUnit*lockTime/rounds);
        console.log("1 round passed");
        await printAccountBal(2);
        await printAccountBal(3);
        
        await delayWithNewBlock(timeUnit*lockTime/rounds);
        console.log("1 round passed");
        await printAccountBal(2);
        await printAccountBal(3);
        
        await delayWithNewBlock(timeUnit*lockTime/rounds);
        console.log("1 round passed");
        await printAccountBal(2);
        await printAccountBal(3);

        await delayWithNewBlock(timeUnit*lockTime/rounds);
        console.log("1 round passed");
        await printAccountBal(2);
        await printAccountBal(3);
    });
    it("test getFreeToTransferAmount transfer locked tokens after release time",async ()=>{
        //return;
        await init();
        await mintWith(0,10000);
        await mintWith(1,20000);
        await mintLockedWith(1,5000);
        console.log(Date.now()/1000);
        console.log(gAccountsInfo[1]);
        
        await delayWithNewBlock(lockTime*timeUnit+5);
        console.log(Date.now()/1000);
        await checkAllfreedAccount(1);  
        await transferFrom(0,8,getAccountInfo(0).balance);
        await transferFrom(1,8,getAccountInfo(1).balance);
    });
    it("check linear unlock amount view",async()=>{
        //return;
        await init();
        await mintWith(0,10000);
        let freedMint = 20000;
        await mintWith(1,freedMint);
        let lockedTotal = 5000;
        await mintLockedWith(1,lockedTotal);
        
        for (i=0;i<rounds+1;i++){
            let freeToMove = await instance.getFreeToTransferAmount(accounts[1]);
            console.log("freeToMove:"+freeToMove.toNumber());
            assert.equal(freeToMove.toNumber(),i*lockedTotal/rounds+freedMint,"check free to move in linear time");
            await delayWithNewBlock(lockTime*timeUnit/rounds);
        }
        await mintLockedWith(1,lockedTotal);
        let freed = 0;
        for (i=0;i<rounds+1;i++){
            let freeToMove = await instance.getFreeToTransferAmount(accounts[1]);
            console.log("freeToMove:"+freeToMove.toNumber());
            if (i==1){
                freed+=lockedTotal/rounds;
            }
            if (i>1){
                freed+=lockedTotal*2/rounds;
            }
            assert.equal(freeToMove.toNumber(),freed+freedMint+lockedTotal,"check free to move in linear time");
            await delayWithNewBlock(lockTime*timeUnit/rounds);
            if(i==0){
                await mintLockedWith(1,lockedTotal,getAccountInfo(0).balancel);
            }
        }
        await transferFrom(0,8,getAccountInfo(0).balance);
        await transferFrom(1,8,getAccountInfo(1).balance);
    });
    it("locked token transfer:testSendMoreThanFreedAmount",async()=>{
        //return;
        await init();
        let lockedTotal = 100;
        await mintLockedWith(6,lockedTotal);
        let success = await transferFrom(6,7,lockedTotal);
        assert.equal(success,false,"locked transfer shouldn't be transfered");
        let bal = await getBalanceOf(6);
        console.log("account6 balance:"+bal.toNumber());
        assert.equal(bal.toNumber(),lockedTotal);
        bal = await getBalanceOf(7);
        assert.equal(bal.toNumber(),0);
        console.log("account7 balance:"+bal.toNumber());
        let freeToMove = await instance.getFreeToTransferAmount(accounts[6]);
        assert.equal(freeToMove.toNumber(),0);
    });
    it("locked token transfer:testSendAllFreedAmount",async()=>{
        //return;
        await init();
        let amount = 100;
        await mintWith(1,amount/2);
        await mintLockedWith(1,amount);
        console.log(gAccountsInfo);
        
        await delayWithNewBlock(lockTime*timeUnit/2);
        let freeToMove = await instance.getFreeToTransferAmount(accounts[8]);
        let initFree = freeToMove.toNumber();
        let success = await transferFrom(1,8,amount);
        assert.equal(success,true,"after locked token released, we can send");
        let bal = await getBalanceOf(1);
        assert.equal(bal.toNumber(),getAccountInfo(1).balance);
        
        bal = await instance.linearLockedBalanceOf(accounts[1]);
        console.log("locked balance:"+bal.toNumber());
        bal = await instance.balanceOf(accounts[1]);
        console.log("balance:"+bal.toNumber());
        freeToMove = await instance.getFreeToTransferAmount(accounts[1]);
        assert.equal(freeToMove.toNumber(),0,"sender free to move should be 0");
        
        freeToMove = await instance.getFreeToTransferAmount(accounts[8]);
        assert.equal(freeToMove.toNumber(),initFree+amount,"acc8 free to to move should equal");
        
        await printAccountBal(1);
        success = await transferFrom(1,2,amount/2);
        await printAccountBal(1);
        assert.equal(success,false,"token unlocked should send unsuccess");
       
        await delayWithNewBlock(lockTime*timeUnit/2+1);
        //all token freed
        success = await transferFrom(1,8,amount/2);
        assert.equal(success,true,"free to move");
        bal = await instance.balanceOf(accounts[1]);
        assert.equal(bal.toNumber(),0,"balance should be 0");
        bal = await instance.linearLockedBalanceOf(accounts[1]);
        assert.equal(bal.toNumber(),0,"locked balance should be 0");
        freeToMove = await instance.getFreeToTransferAmount(accounts[1]);
        assert.equal(freeToMove.toNumber(),0,"free to move should be 0");

        bal = await instance.balanceOf(accounts[8]);
        assert.equal(bal.toNumber(),initFree+amount*1.5,"balance should be initFree+amount*1.5");
        bal = await instance.linearLockedBalanceOf(accounts[8]);
        assert.equal(bal.toNumber(),0,"locked balance should be 0");
        freeToMove = await instance.getFreeToTransferAmount(accounts[8]);
        assert.equal(freeToMove.toNumber(),initFree+amount*1.5,"free to move should be initFree+amount*1.5");
    });

    async function printAccountBal(index){
        bal = await instance.balanceOf(accounts[index]);
        console.log("account"+index+" bal:"+bal.toNumber());
        bal = await instance.linearLockedBalanceOf(accounts[index]);
        console.log("account"+index+" locked bal:"+bal.toNumber());
        freeToMove = await instance.getFreeToTransferAmount(accounts[index]);
        console.log("account"+index+" free to move:"+freeToMove.toNumber());
        console.log("---------------");
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
    }
    async function init(){
        instance = await BSCH.deployed();
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

    /**
     * test mint with some coins to account
     * @param {normal mint} amount 
     * @param {mint with locked} xamount 
     */
    async function testMintMintLockedWith(amount,xamount){
        await mintWith(0,amount);
        await mintWith(5,amount);
        await mintLockedWith(5,xamount);
        //init state
        await checkTotal(gtotal,gtimeLocked,gtotalReleased);
        
    }

    async function checkTotal(totalSupply,timeLocked,totalReleased){
        let total = await instance.totalSupply();
        assert.equal(totalSupply,total.toNumber(),"amount totalSupply check");
        let totalTimeLocked = await instance.totalSupplyReleaseByTimeLock();
        assert.equal(timeLocked,totalTimeLocked.toNumber(),"totalTimeLocked check");
        let xtotalReleased = await instance.totalReleasedSupplyReleaseByTimeLock();
        assert.equal(totalReleased,xtotalReleased.toNumber(),"totalTimeLocked check");
    }
    async function checkAllfreedAccount(index){
        let info = getAccountInfo(index);
        console.log("expected:"+info.balance);
        info.locked = 0;
        let balance = await instance.balanceOf(accounts[index]);
        console.log("balanceof:"+balance.toNumber());
        let freeToMove = await instance.getFreeToTransferAmount(accounts[index]);

        assert.equal(freeToMove.toNumber(),info.balance,"all freed account freetomove should equal to account's balance");
    }
    async function transferFrom(from,to,amount){
        let success = false;
        try{
            await instance.transfer(accounts[to],amount,{from:accounts[from]});
            success = true;
            let fromInfo = getAccountInfo(from);
            let toInfo = getAccountInfo(to);
            fromInfo.balance = fromInfo.balance-amount;
            toInfo.balance = toInfo.balance+amount;
        }catch(err){
            console.log("transfer from "+from+" to "+to+" "+amount+" failed");
        }
        return success;
    }

    async function getBalanceOf(index){
        return await instance.balanceOf(accounts[index]);
    }
});
