const { accounts, contract } = require('@openzeppelin/test-environment');
const [ owner ] = accounts;
const { expect } = require('chai');

const SToken = contract.fromArtifact("Bitcoin Standard Circulation Hashrate TokenToken");
const BSCH = contract.fromArtifact("BSCH");
const Farm = contract.fromArtifact("FarmWithApi");
const MockERC20 = contract.fromArtifact("MockERC20");

//a function to delay s seconds
const delay = s => new Promise(res => setTimeout(res, s*1000));

describe('Mining', function () {
    let sToken = null;
    let farm = null;
    let rToken = null;
    it("let's staking for BTC",async ()=>{
        //return;
        await init();
        
    });
    async function init(){
        sToken = await BSCH.new({from:owner});
        rToken = await MockERC20.new("BitcoinMock","BTC",10000,{from:owner});
        expect(await sToken.owner()).to.equal(owner);
        console.log(MockERC20.isDeployed()+"  "+BSCH.isDeployed());
        //farm = await Farm.new(sToken,rToken,"our test farm");    
    }
})
