// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../libraries/TokenUtility.sol";

import "../interfaces/IFarm.sol";
import "../interfaces/IMiningFarmCoreDataVcs.sol";
import "./FarmSCoreUpgradeable.sol";

abstract contract V2FarmUpgradeableWithVcs is IMiningFarmCoreDataVcs{
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using TokenUtility for uint;
    
    //user's Last Combined Stake record
    mapping (address => IFarmCore.StakeRecord) public _userLastCSR;

    //1.mining method
    function __depositToMiningFrom(address account,uint256 amount)override internal  whenNotPaused{
        require(amount>0,"deposit number should greater than 0");
        //first try to transfer amount from sender to this contract
        IERC20Upgradeable(_stoken).safeTransferFrom(account,address(this),amount);
        
        //if successed let's update the status
        _addMingAccount(account);
        uint currentKey = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        IFarmCore.V2UserInfo storage user = _userInfo[account];
        IFarmCore.StakeRecord storage record = user.stakeInfo[currentKey];
        //update user's record
        record.amount = record.amount.add(amount);
        //update staked amount of this user
        user.amount = user.amount.add(amount);
        record.timeKey = currentKey;

        IFarmCore.RoundSlotInfo storage currentSlot = _roundSlots[currentKey];
        currentSlot.totalStakedInSlot = currentSlot.totalStakedInSlot.add(amount);
        
        _updateIndexAfterDeposit(account,user,currentKey, amount);
        _initOrUpdateLowestWaterMarkAndTotalStaked(currentKey,amount,false);

        IFarmCore.StakeRecord storage lastCSR = _userLastCSR[account];
        ___reduceToLastCombinedStakingRecord(currentKey,lastCSR,user);

        emit DepositToMining(account,amount);

    }
    //2.exit mining method
    function __withdrawLatestSTokenFrom(address account,uint256 amount)override internal{
        IFarmCore.V2UserInfo storage user = _userInfo[account];
        require(amount > 0,"you can't withdraw 0 amount");
        require(user.amount>=amount,"you can't withdraw amount larger than you have deposit");
        uint256 ii = user.stakedTimeIndex.length;
        require(ii>0,"no deposit record found");
        uint currentKey = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        IFarmCore.StakeRecord storage lastCSR = _userLastCSR[account];
        ___reduceToLastCombinedStakingRecord(currentKey,lastCSR,user);
        IFarmCore.RoundSlotInfo storage currentSlot = _roundSlots[currentKey];

        _initOrUpdateLowestWaterMarkAndTotalStaked(currentKey,amount,true);

        uint maxUserRecordTimeKey = user.stakedTimeIndex[ii-1];
        uint256 needCost = amount;
        
        
        if (maxUserRecordTimeKey>lastCSR.timeKey){
            //first withdraw current record's amount
            IFarmCore.StakeRecord storage record = user.stakeInfo[maxUserRecordTimeKey];
            needCost = ___withdrawAmountFromRecord(needCost,record);
            uint256 consumed = amount.sub(needCost);
            if (consumed>0){
                if (consumed <= currentSlot.totalStakedInSlot){
                    currentSlot.totalStakedInSlot = currentSlot.totalStakedInSlot.sub(consumed,"consumed>totalStakedInSlot");
                }else{
                    currentSlot.totalStakedInSlot = 0;
                }
            }
        }

        if (needCost>0){
            //after we withdrawed user's current slot, stakedLowestWaterMark will be affected
            if (needCost<=currentSlot.stakedLowestWaterMark){
                //maker it safer for withdraw SToken
                currentSlot.stakedLowestWaterMark = currentSlot.stakedLowestWaterMark.sub(needCost,"needCost>stakedLowestWaterMark");
            }else{
                currentSlot.stakedLowestWaterMark = 0;
            }
            needCost = ___withdrawAmountFromRecord(needCost, lastCSR);
        }
        require(needCost==0,"needCost should be 0 at here");
        

        _safeTokenTransfer(account,amount,IERC20Upgradeable(_stoken));
        user.amount = user.amount.sub(amount,"amount>user.amount");
        emit Withdraw(account,amount); 
    }
    //3.claim mining reward method
    function __claimAmountOfReward(address account,uint256 amount,bool reCalculate)override internal{
        __claimAmountOfRewardForToken(_rewardToken,account,amount,reCalculate);
    }
    //3.1.claim mining reward for token
    function __claimAmountOfRewardForToken(address token,address account,uint256 amount,bool reCalculate) internal{
        if (account!=_msgSender()){
            reCalculate = true;
        }
        IFarmCore.V2UserInfo storage user = _userInfo[account];
        if (reCalculate){
            uint currentKey = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
            IFarmCore.StakeRecord storage lastCSR = _userLastCSR[account];
            ___reduceToLastCombinedStakingRecord(currentKey,lastCSR,user);
        }
        require(user.tokens_rewardBalanceInpool[token]>=amount,"claim amount should not greater than total mined");
        
        user.tokens_rewardBalanceInpool[token] = user.tokens_rewardBalanceInpool[token].sub(amount,"amount>rewardBalanceInpool");
        _safeTokenTransfer(account,amount,IERC20Upgradeable(token));
        user.tokens_allTimeRewardClaimed[token] = user.tokens_allTimeRewardClaimed[token].add(amount);
        _totalRewardInPoolTokens[token] = _totalRewardInPoolTokens[token].sub(amount,"amount>_totalRewardInPoolTokens");
        
        emit ClaimToken(token,account,amount);
    }
    //4.deposit mining reward token
    function __depositRewardFromForTime(address account,uint256 amount,uint time)override internal {
        __depositRewardFromForTokenForTime(_rewardToken, account, amount, time);
    }

    function __depositRewardFromForTokenForTime(address token,address account,uint256 amount,uint time) internal {
        require(amount>0,"deposit number should greater than 0");
        IERC20Upgradeable(token).safeTransferFrom(account,address(this),amount);
        uint timeKey= time.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        _initOrUpdateLowestWaterMarkAndTotalStaked(timeKey,0,false);
        //timeKey will definitely in _roundSlotsIndex after init

        // IFarmCore.RoundSlotInfo storage slot = _roundSlots[timeKey];
        IFarmCore.V2RewardInfo storage rSlot = _roundSlotsReward[timeKey][token];

        uint256 previousAccumulate = 0;
        uint256 slotIndex = 0;
        // bool findKey = false;
        uint256 tmpPreAccumulate=0;
        uint key;
        for (uint256 ii=_roundSlotsIndex.length;ii>0;ii--){
            key = _roundSlotsIndex[ii-1];
            if (key == timeKey){
                slotIndex = ii-1;
                if (ii>1){
                    tmpPreAccumulate = _roundSlotsReward[_roundSlotsIndex[ii-2]][token].rAccumulateAmount;
                    if (tmpPreAccumulate>0){
                        previousAccumulate = tmpPreAccumulate;
                        break;
                    }
                }
                break;
            }
        }
        if (previousAccumulate>0 && rSlot.rAccumulateAmount==0){
            //if we find a previous accumulate and current accu is 0, set current slot's accumulate to previous one's
            rSlot.rAccumulateAmount = previousAccumulate;
        }
        uint256 expandedAmount = amount.mul(IFarmCore.AMOUNT_BASE_MULTIPLY);
        rSlot.rAmount = rSlot.rAmount.add(expandedAmount);
        //update all accumulateamount from our slot to the latest one
        for (uint256 ii=slotIndex;ii<_roundSlotsIndex.length;ii++){
            key = _roundSlotsIndex[ii];
            IFarmCore.V2RewardInfo storage update = _roundSlotsReward[key][token];
            update.rAccumulateAmount = update.rAccumulateAmount.add(expandedAmount);
        }

        _allTimeTotalMinedTokens[token] = _allTimeTotalMinedTokens[token].add(amount);
        _totalRewardInPoolTokens[token] = _totalRewardInPoolTokens[token].add(amount);
        
        emit DepositRewardToken(token,account,amount,timeKey);
    }

    //5.get total rewardBalanceInPool for token
    function getTotalRewardBalanceInPoolForToken(address token,address account) public view returns (uint256){
        IFarmCore.V2UserInfo storage user = _userInfo[account];
        if (user.stakedTimeIndex.length==0){
            return user.tokens_rewardBalanceInpool[token];
        }
        IFarmCore.StakeRecord storage lastCSR = _userLastCSR[account];
        uint lastReducedTime = lastCSR.timeKey;
        uint currentKey = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        uint256 nextTimeKey = currentKey.sub(_miniStakePeriodInSeconds);
        if (nextTimeKey<=lastReducedTime){
            return user.tokens_rewardBalanceInpool[token];
        }
        uint256 totalMined = ___reduceToLastCombinedStakingRecordForTokenNoUpdate(token,lastCSR,user,
            lastReducedTime,nextTimeKey);
        return totalMined.add(user.tokens_rewardBalanceInpool[token]);
    }

    function ___reduceToLastCombinedStakingRecord(uint currentSlotTime,
        IFarmCore.StakeRecord storage lastCSR,IFarmCore.V2UserInfo storage user)internal {
        if (user.stakedTimeIndex.length==0){
            return;
        }
        uint lastReducedTime = lastCSR.timeKey;

        uint256 nextTimeKey = currentSlotTime.sub(_miniStakePeriodInSeconds);

        if (nextTimeKey<=lastReducedTime){
            return;
        }
        for (uint256 ii=0;ii<totalRewardTokenLen();++ii){
            address token = rewardTokenAt(ii);
            uint256 totalMined = ___reduceToLastCombinedStakingRecordForToken(token,lastCSR,
                        user,lastReducedTime,nextTimeKey);

            user.tokens_rewardBalanceInpool[token] = user.tokens_rewardBalanceInpool[token].add(totalMined);
            user.tokens_allTimeMinedBalance[token] = user.tokens_allTimeMinedBalance[token].add(totalMined);
        }

        lastCSR.timeKey = nextTimeKey;
        user.lastUpdateRewardTime = nextTimeKey.sub(_miniStakePeriodInSeconds);
    }
    function ___reduceToLastCombinedStakingRecordForTokenNoUpdate(address token,
        IFarmCore.StakeRecord storage lastCSR,IFarmCore.V2UserInfo storage user,
        uint lastReducedTime,uint256 nextTimeKey)internal view returns(uint256){
        uint256 totalMined = 0;
        uint256 mined = 0;
        uint lastUpdate = user.lastUpdateRewardTime;

        uint256 remainStaked = _getRecordStaked(lastCSR);
        if (remainStaked>0){
            mined = __calculateMinedRewardDuringForToken(token,lastReducedTime, remainStaked,
                             lastUpdate+_miniStakePeriodInSeconds, nextTimeKey);
            totalMined = totalMined.add(mined);
        }

        for (uint256 ii=user.stakedTimeIndex.length;ii>0;--ii){
            uint timeKey = user.stakedTimeIndex[ii-1];
            if (timeKey<=lastReducedTime){
                break;
            }
            if (timeKey<=nextTimeKey){
                IFarmCore.StakeRecord memory toCombineRecord = user.stakeInfo[timeKey];
                remainStaked = _getRecordStaked(toCombineRecord);
                if (remainStaked>0){
                    mined = __calculateMinedRewardDuringForToken(token,timeKey, remainStaked,
                             lastUpdate+_miniStakePeriodInSeconds, nextTimeKey); 
                    totalMined = totalMined.add(mined);        
                }
            }
        }
        //scaling for save gas fee,so rescale back
        totalMined = totalMined.div(IFarmCore.AMOUNT_BASE_MULTIPLY);
        return totalMined;
    }
    function ___reduceToLastCombinedStakingRecordForToken(address token,
        IFarmCore.StakeRecord storage lastCSR,IFarmCore.V2UserInfo storage user,
        uint lastReducedTime,uint256 nextTimeKey)internal returns(uint256){            
        uint256 totalMined = 0;
        uint256 mined = 0;
        uint lastUpdate = user.lastUpdateRewardTime;

        uint256 remainStaked = _getRecordStaked(lastCSR);
        if (remainStaked>0){
            mined = __calculateMinedRewardDuringForToken(token,lastReducedTime, remainStaked,
                             lastUpdate+_miniStakePeriodInSeconds, nextTimeKey);
            totalMined = totalMined.add(mined);
        }

        for (uint256 ii=user.stakedTimeIndex.length;ii>0;--ii){
            uint timeKey = user.stakedTimeIndex[ii-1];
            if (timeKey<=lastReducedTime){
                break;
            }
            if (timeKey<=nextTimeKey){
                IFarmCore.StakeRecord memory toCombineRecord = user.stakeInfo[timeKey];
                remainStaked = _getRecordStaked(toCombineRecord);
                if (remainStaked>0){
                    mined = __calculateMinedRewardDuringForToken(token,timeKey, remainStaked,
                             lastUpdate+_miniStakePeriodInSeconds, nextTimeKey); 
                    totalMined = totalMined.add(mined);        
                }

                lastCSR.amount  = lastCSR.amount.add(toCombineRecord.amount);
                lastCSR.lockedAmount  = lastCSR.lockedAmount.add(toCombineRecord.lockedAmount);
                lastCSR.withdrawed = lastCSR.withdrawed.add(toCombineRecord.withdrawed);
                lastCSR.lockedWithdrawed = lastCSR.lockedWithdrawed.add(toCombineRecord.lockedWithdrawed);
            }
        }
        //scaling for save gas fee,so rescale back
        totalMined = totalMined.div(IFarmCore.AMOUNT_BASE_MULTIPLY);
        return totalMined;
    }
    function ___withdrawAmountFromRecord(uint256 needCost,IFarmCore.StakeRecord storage record)internal returns(uint256){
        uint256 consume = record.amount.sub(record.withdrawed,"withdrawed>amount");
        if (needCost<=consume){
            record.withdrawed = record.withdrawed.add(needCost);
            consume = needCost;
            needCost = 0;
        }else{
            needCost = needCost.sub(consume,"consume>needCost");
            //withdrawed all of current record
            record.withdrawed = record.amount;
        }
        
        return needCost;
    }

    
    uint256[50] private __gap;  
}
