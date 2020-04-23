const SToken = artifacts.require("Bitcoin Standard Circulation Hashrate TokenToken");
const BSCH = artifacts.require("BSCH");
//a function to delay s seconds
const delay = s => new Promise(res => setTimeout(res, s*1000));

contract("BSCH", async accounts=>{
    it("basic token parameter test",async ()=>{
        let instance = await BSCH.deployed();
        let owner = await instance.owner();
        console.log("owner:"+owner.valueOf());
        assert.equal(owner.valueOf(),accounts[0],"owner should be the contract creator");

        let defaultRound = await instance._lockRounds();
        assert.equal(defaultRound.valueOf(),25,"default rounds==25");

        let defaultLockTime = await instance._lockTime();
        assert.equal(defaultLockTime.valueOf(),25*7,"defaultLockTime==25");

        let defaultTimeUnit = await instance._lockTimeUnitPerSeconds();
        assert.equal(defaultTimeUnit.valueOf(),24*60*60,"defaultTimeUnit==24*60*60");

        let decimal = await instance.decimals();
        assert.equal(decimal.valueOf(),18,"decimals==18");

        let devaddr = await instance.devaddr();
        assert.equal(devaddr.valueOf(),accounts[0],"devaddr == accounts[0]");

        let inited = await instance.initialized();
        assert.equal(inited,true,"inited == true");

        let paused = await instance.paused();
        assert.equal(paused,false,"paused == false");

        let total = await instance.totalSupply();
        assert.equal(total,0,"totalSupply == 0");
    });
    it("basic token access control test",async ()=>{
        let instance = await BSCH.deployed();
        let role = await instance.DEFAULT_ADMIN_ROLE();
        let hasRole = await instance.hasRole(role.valueOf(),accounts[0]);
        assert.equal(hasRole,true,"contract creator should have DEFAULT_ADMIN_ROLE");
        role = await instance.MINTER_ROLE();
        hasRole = await instance.hasRole(role.valueOf(),accounts[0]);
        assert.equal(hasRole,true,"contract creator should have MINTER_ROLE");
        role = await instance.PAUSER_ROLE();
        hasRole = await instance.hasRole(role.valueOf(),accounts[0]);
        assert.equal(hasRole,true,"contract creator should have PAUSER_ROLE");
    });
    it("basic erc20 token transfer function test",async ()=>{
        let instance = await BSCH.deployed();
        let balance = await instance.balanceOf.call(accounts[0]);
        console.log("banalance of account[0]:"+balance.valueOf());
        // console.log(instance);
        // console.log(Date.now());
        // await delay(5);
        // console.log(Date.now());

        //let's mint some coin to the owner
        let amount = 10000;
        await instance.mint(accounts[0],amount);
        balance = await instance.balanceOf.call(accounts[0]);
        assert.equal(amount,balance.valueOf(),"initial amount check");

        await instance.mint(accounts[1],amount);
        let balance2 = await instance.balanceOf.call(accounts[1]);
        assert.equal(amount,balance2.valueOf(),"initial amount check");
        let sent = 200;
        await instance.transfer(accounts[0],sent,{from:accounts[1]});
        balance = await instance.balanceOf.call(accounts[0]);
        balance2 = await instance.balanceOf.call(accounts[1]);

        assert.equal(balance.toNumber(),amount+sent,"check account0's coins");
        assert.equal(balance2.toNumber(),amount-sent,"check account1's coins");

        // await instance.mint(accounts[1],500,{from:accounts[1]});

    });
    
});
