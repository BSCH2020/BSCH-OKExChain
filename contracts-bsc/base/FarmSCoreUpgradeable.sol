// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../libraries/TokenUtility.sol";
import "../libraries/IFarmCore.sol";

import "../interfaces/IMiningFarmCoreData.sol";
import "../interfaces/IPureSTokenERC20.sol";
import "../interfaces/IFarm.sol";

abstract contract FarmSCoreUpgradeable is IMiningFarmCoreData{
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IPureSTokenERC20;
    
    using TokenUtility for uint;
    using IFarmCore for *;
    uint256 public _allTimeTotalMined;
    //total reward still in pool, not claimed
    uint256 public _totalRewardInPool;
    
    //1.mining method
    function __depositToMiningFrom(address account,uint256 amount)override internal  whenNotPaused{
        require(amount>0,"deposit number should greater than 0");
        //first try to transfer amount from sender to this contract
        IERC20Upgradeable(_stoken).safeTransferFrom(account,address(this),amount);
        
        //if successed let's update the status
        _addMingAccount(account);
        uint key = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        IFarmCore.UserInfo storage user = _userInfo[account];
        IFarmCore.StakeRecord storage record = user.stakeInfo[key];
        //update user's record
        record.amount = record.amount.add(amount);
        
        //update staked amount of this user
        user.amount = user.amount.add(amount);
        
        _updateIndexAfterDeposit(account,user, key, amount);

        emit DepositToMining(account,amount);
    }
    //2.exit mining method
    function __withdrawLatestSTokenFrom(address account,uint256 amount)override internal{
        IFarmCore.UserInfo storage user = _userInfo[account];
        require(amount > 0,"you can't withdraw 0 amount");
        require(user.amount>=amount,"you can't withdraw amount larger than you have deposit");
        uint256 ii = user.stakedTimeIndex.length;
        require(ii>0,"no deposit record found");
        //we can't change the status for calculating reward before 2 rounds agao
        //because the user already staked full for mining 2 rounds agao
        uint alreadyMinedTimeKey = _getMaxAlreadyMinedTimeKey();
        __updateAlreadyMinedReward(account,alreadyMinedTimeKey); 
        uint currentKey = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        uint256 needCost = amount;

        bool[] memory toDelete = new bool[](ii);
        _initOrUpdateLowestWaterMarkAndTotalStaked(currentKey,0);
        IFarmCore.RoundSlotInfo storage currentSlot = _roundSlots[currentKey];
        uint256 update = 0;
        for (ii;ii>0;ii--){
            if (needCost == 0){
                break;
            }
            uint timeKey = user.stakedTimeIndex[ii-1];
            
            IFarmCore.StakeRecord storage record = user.stakeInfo[timeKey];
            IFarmCore.RoundSlotInfo storage slot = _roundSlots[timeKey];
            update = record.amount.sub(record.withdrawed,"withdrawed>amount");
            if (needCost<=update){
                record.withdrawed = record.withdrawed.add(needCost);
                update = needCost;
                needCost = 0;
            }else{
                needCost = needCost.sub(update,"update>needCost");
                //withdrawed all of this record
                record.withdrawed = record.amount;
                //record maybe can be delete, withdrawed all
                if (_getRecordStaked(record)==0){
                    delete user.stakeInfo[timeKey];
                    toDelete[ii-1]=true;
                }
            }
            if (update>0){
                slot.totalStakedInSlot = slot.totalStakedInSlot.sub(update,"update>totalStakedInSlot");
            }
            if (update>0 && timeKey<currentKey){
                if (update <= currentSlot.stakedLowestWaterMark){
                    currentSlot.stakedLowestWaterMark = currentSlot.stakedLowestWaterMark.sub(update,"update > stakedLowestWaterMark");
                }else{
                    currentSlot.stakedLowestWaterMark = 0;
                }
                
            }
        }
        if (amount <= currentSlot.totalStaked){
            //maker it safer for withdraw SToken
            currentSlot.totalStaked = currentSlot.totalStaked.sub(amount,"amount>totalStaked");
        }

        for(uint256 xx=0;xx<toDelete.length;xx++){
            bool del = toDelete[xx];
            if (del){
                delete user.stakedTimeIndex[xx];
            }
        }
        _safeTokenTransfer(account,amount,IERC20Upgradeable(_stoken));
        user.amount = user.amount.sub(amount,"amount>user.amount");
        emit Withdraw(account,amount); 
    }
    //3.claim mining reward method
    function __claimAmountOfReward(address account,uint256 amount,bool reCalculate)override internal{
        if (reCalculate){
            getAndUpdateRewardMinedInPool(account);
        }
        IFarmCore.UserInfo storage user = _userInfo[account];
        require(user.rewardBalanceInpool>=amount,"claim amount should not greater than total mined");

        user.rewardBalanceInpool = user.rewardBalanceInpool.sub(amount,"amount>rewardBalanceInpool");
        _safeTokenTransfer(account,amount,IERC20Upgradeable(_rewardToken));
        user.allTimeRewardClaimed = user.allTimeRewardClaimed.add(amount);
        _totalRewardInPool = _totalRewardInPool.sub(amount,"amount>_totalRewardInPool");
        emit Claim(account,amount);
    }
    //4.deposit mining reward token
    function __depositRewardFromForTime(address account,uint256 amount,uint time)override internal whenNotPaused{
        require(amount>0,"deposit number should greater than 0");
        IERC20Upgradeable(_rewardToken).safeTransferFrom(account,address(this),amount);
        uint timeKey= time.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        _initOrUpdateLowestWaterMarkAndTotalStaked(timeKey,0);
        //timeKey will definitely in _roundSlotsIndex after init

        IFarmCore.RoundSlotInfo storage slot = _roundSlots[timeKey];
        uint256 previousAccumulate = 0;
        uint256 slotIndex = 0;
        // bool findKey = false;
        uint256 tmpPreAccumulate=0;
        for (uint256 ii=_roundSlotsIndex.length;ii>0;ii--){
            uint key = _roundSlotsIndex[ii-1];
            if (key == timeKey){
                // findKey = true;
                slotIndex = ii-1;
                if (ii>1){
                    tmpPreAccumulate = _roundSlots[_roundSlotsIndex[ii-2]].rAccumulateAmount;
                    if (tmpPreAccumulate>0){
                        previousAccumulate = tmpPreAccumulate;
                        break;
                    }
                }
                break;
            }
        }
        if (previousAccumulate>0 && slot.rAccumulateAmount==0){
            //if we find a previous accumulate and current accu is 0, set current slot's accumulate to previous one's
            slot.rAccumulateAmount = previousAccumulate;
        }
        uint256 expandedAmount = amount.mul(IFarmCore.AMOUNT_BASE_MULTIPLY);
        slot.rAmount = slot.rAmount.add(expandedAmount);
        slot.rLastSubmiter = account;
        //update all accumulateamount from our slot to the latest one
        for (uint256 ii=slotIndex;ii<_roundSlotsIndex.length;ii++){
            uint key = _roundSlotsIndex[ii];
            IFarmCore.RoundSlotInfo storage update = _roundSlots[key];
            update.rAccumulateAmount = update.rAccumulateAmount.add(expandedAmount);
        }

        _allTimeTotalMined = _allTimeTotalMined.add(amount);
        _totalRewardInPool = _totalRewardInPool.add(amount);

        emit DepositReward(account,amount,timeKey);
    }
    
    function _getMaxAlreadyMinedTimeKey() internal view returns (uint){
        uint key = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        return key.sub(_miniStakePeriodInSeconds*2);
    }    
    function __withdrawLatestSToken(uint256 amount)internal{
        address account = address(msg.sender);
        __withdrawLatestSTokenFrom(account,amount);
    }
    
    function __updateAlreadyMinedReward(address account,uint before) internal {
        uint256 minedTotal = getUncalculateRewardBalanceInPoolBefore(account,before);
        IFarmCore.UserInfo storage user = _userInfo[account];
        user.rewardBalanceInpool = user.rewardBalanceInpool.add(minedTotal);
        user.allTimeMinedBalance = user.allTimeMinedBalance.add(minedTotal);
        user.lastUpdateRewardTime = before;
        //user.lastUpdateRewardTime+_miniStakePeriodInSeconds slot's reward already mined
    }


    function getAndUpdateRewardMinedInPool(address account) public returns (uint256){
        uint alreadyMinedTimeKey = _getMaxAlreadyMinedTimeKey(); 
        __updateAlreadyMinedReward(account,alreadyMinedTimeKey);
        return _userInfo[account].rewardBalanceInpool;
    }

    /**
     * @dev calculate how much reward the account mined
     * important !!
     */
    function getUncalculateRewardBalanceInPoolBefore(address account,uint before) public view returns(uint256){
        IFarmCore.UserInfo storage user = _userInfo[account];
        uint lastUpdate = user.lastUpdateRewardTime;
        if (before<=lastUpdate){
            return 0;
        }
        uint256 minedTotal = 0;
        uint time = 0;
        uint256 mined = 0;
        uint256 remainStaked =0;
        IFarmCore.StakeRecord memory record;
        if (user.stakedTimeIndex.length>0){
            for (uint256 xx=0;xx<user.stakedTimeIndex.length;xx++){
                time = user.stakedTimeIndex[xx];
                if (time<=before){
                    record = user.stakeInfo[time];
                    remainStaked = _getRecordStaked(record);
                    if (remainStaked>0){
                        mined = __calculateMinedRewardDuringFor(time,remainStaked,
                            lastUpdate+_miniStakePeriodInSeconds,
                            before+_miniStakePeriodInSeconds
                        );

                        minedTotal = minedTotal.add(mined);
                    }
                }
            }   
        }
        return minedTotal.div(IFarmCore.AMOUNT_BASE_MULTIPLY);
    }
}
