// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import '../base/ElasticSupplyToken.sol';
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

interface IRewardVault{
    function noticeUnderWaterSell(uint256 inputReward,uint256 logIndex) external;
    function noticeUnderWaterBuy(uint256 index,address buyer,uint256 amount)external;
}

contract ElasticTokenWithStrategy is ElasticSupplyToken{
    using SafeMathInt for int256;
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bool public usingStrategy;
    EnumerableSetUpgradeable.AddressSet private whitelist;
    EnumerableSetUpgradeable.AddressSet private swapPairs;
    uint256 public totalBurned;

    struct BurnLog{
        uint256 epoch;
        uint256 time;
        uint256 initTotal;
        int256  supplyDelta;
        uint256 absDelta;
        uint256 burned;
        uint256 rewards;   
    }

    BurnLog[] public logs;
    uint256 public factor;
    uint256 public burnSplit;
    address public rewardVault;
    uint256 public constant FACTOR_BASE = 1e18;
    function viewList()public view returns(address[] memory,address[] memory){
        uint256 len = whitelist.length();
        address[] memory list = new address[](len);
        for (uint256 x=0;x<len;x++){
            list[x] = whitelist.at(x);
        }
        len = swapPairs.length();
        address[] memory list1 = new address[](len);
        for (uint256 x=0;x<len;x++){
            list[x] = swapPairs.at(x);
        }
        return (list,list1);
    }
    function viewLogsLen()public view returns(uint256){
        return logs.length;
    }

    function isAboveWater() public view returns(bool){
        if (logs.length>0){
            uint256 index = logs.length-1;
            BurnLog memory lastLog = logs[index];
            if (lastLog.supplyDelta<0){
                return false;
            }
        }
        return true;
    }
    function isUnderWater() public view returns(bool){
        if (logs.length>0){
            uint256 index = logs.length-1;
            BurnLog memory lastLog = logs[index];
            if (lastLog.supplyDelta<0){
                return true;
            }
        }
        return false;
    }
    function adminChangeStrategyFactors(bool _st,uint256 factor_,uint256 split_,address vault_) public onlyOwner{
        require(burnSplit<=FACTOR_BASE,"check uppass");
        usingStrategy = _st;
        factor = factor_;
        burnSplit = split_;
        rewardVault = vault_;
    }

    function adminAddWhiteList(address white)public onlyOwner{
        if (!whitelist.contains(white)){
            whitelist.add(white);
        }
    }
    function adminRemoveWhiteList(address white)public onlyOwner{
        if (whitelist.contains(white)){
            whitelist.remove(white);
        }
    }
    function adminAddSwapPair(address pair)public onlyOwner{
        if (!swapPairs.contains(pair)){
            swapPairs.add(pair);
        }
    }
    function adminRemoveSwapPair(address pair)public onlyOwner{
        if (swapPairs.contains(pair)){
            swapPairs.remove(pair);
        }
    }
    

    function strategicRebase(uint256 epoch,int256 supplyDelta) external
        onlyMonetaryPolicy onlyAfterRebaseStart nonReentrant returns(uint256){
        uint256 totalSupply = totalSupply();
        if (supplyDelta ==0 ){
            emit LogRebase(epoch, totalSupply);
            return totalSupply;
        }
        if (supplyDelta<0){
            logs.push(
                BurnLog({
                    epoch:epoch,
                    time:block.timestamp,
                    initTotal:totalSupply,
                    supplyDelta:supplyDelta,
                    absDelta:uint256(supplyDelta.abs()),
                    burned:0,
                    rewards:0
                })
            );
        }

    }

    function viewTryTransfer(address account,address to,uint256 amount) public view returns(bool,uint256){
        if (account == to) return (true,0);
        if (!usingStrategy) return(true,0);
        if (_inWhiteList(account) || _inWhiteList(to)){
            return (true,0);
        }
        if (logs.length>0){
            uint256 index = logs.length-1;
            BurnLog memory lastLog = logs[index];
            if (lastLog.supplyDelta<0){
                if (_inSwapPair(account)){
                    //transfer from swap,means remove liquidity or buy from swap
                    return (true,0);
                }else{
                    //others burn
                    uint256 rebased = lastLog.burned.add(lastLog.rewards);
                    if (rebased<lastLog.absDelta && factor>0){
                        uint256 toBeLocked = amount.mul(lastLog.absDelta).mul(factor).div(lastLog.initTotal).div(FACTOR_BASE);
                        uint256 balance = balanceOf(account);
                        bool pass = true;
                        if (balance < toBeLocked.add(amount)){
                            pass = false;
                        }
                        return (pass,toBeLocked);
                    }
                }
            }
            
        }
        return (true,0);
    }

    function _beforeTokenTransfer(address account, address to, uint256 amount) internal override virtual {
        super._beforeTokenTransfer(account, to, amount);
        if (account == to) return;
        if (!usingStrategy) return;
        if (_inWhiteList(account) || _inWhiteList(to)){
            return;
        }
        if (logs.length>0){
            uint256 index = logs.length-1;
            BurnLog memory lastLog = logs[index];
            if (lastLog.supplyDelta<0){
                if (_inSwapPair(account)){
                    //transfer from swap,means remove liquidity or buy from swap
                    if (rewardVault!=address(0)){
                        IRewardVault(rewardVault).noticeUnderWaterBuy(index,tx.origin,amount);
                    }
                }else{
                    //others burn
                    uint256 rebased = lastLog.burned.add(lastLog.rewards);
                    if (rebased<lastLog.absDelta && factor>0){
                        uint256 toBeLocked = amount.mul(lastLog.absDelta).mul(factor).div(lastLog.initTotal).div(FACTOR_BASE);
                        if (rewardVault==address(0)){
                            burn(toBeLocked);
                            return;
                        }
                        uint256 toBeBurned = toBeLocked.mul(burnSplit).div(FACTOR_BASE);
                        uint256 tobeRewarded = toBeLocked.sub(toBeBurned);
                        burn(toBeBurned);
                        transfer(rewardVault,tobeRewarded);
                        IRewardVault(rewardVault).noticeUnderWaterSell(tobeRewarded, index);
                    }
                }
            }
            
        }
    }

    function _inWhiteList(address account)public view returns(bool){
        return (whitelist.contains(account)|| account == rewardVault);
    }
    function _inSwapPair(address account)public view  returns(bool){
        return swapPairs.contains(account);
    }
}
