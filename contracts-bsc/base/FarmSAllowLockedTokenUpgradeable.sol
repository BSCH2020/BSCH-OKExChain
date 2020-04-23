// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./FarmSUpgradeable.sol";
import "../libraries/TokenUtility.sol";
import "../interfaces/IPureSTokenERC20.sol";

contract FarmSAllowLockedTokenUpgradeable is FarmSUpgradeable{
    using SafeMathUpgradeable for uint256;
    using TokenUtility for *;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    
    //if account need to start mining using it's locked tokens,
    //the account should lock this amount first
    uint256 public _miniSeedTokenNeedsForLockedStaking;
    //store each user's locked records
    mapping(address=>mapping(uint=>uint256)) _stakedLockedRecords;
    mapping(address=>uint[]) _stakedLockedBalanceFreeTimeKeys;
    mapping(address=>mapping(uint=>uint256)) _stakedLockedRecordsWithdrawed;

    function apiDepositLockedToMining(uint256 amount) external whenNotPaused{
        require(amount>0,"deposit number should greater than 0");
        address account = address(msg.sender);
        uint256 bal = ISTokenERC20(_stoken).linearLockedBalanceOf(account);
        require(bal>=amount,"deposit locked amount exceeds locked balance 4");
        
        //first try to transfer locked amount from sender to this contract
        (uint[] memory freeTimeKey,uint256[] memory lockedArray) = ISTokenERC20(_stoken).transferLockedFrom(account,address(this),amount);
        uint[] storage stakedLockedBalanceFreeTime = _stakedLockedBalanceFreeTimeKeys[account];
        //update staked locked records;
        for(uint256 ii=0;ii<freeTimeKey.length;++ii){
            uint _timeKey = freeTimeKey[ii];
            _stakedLockedRecords[account][_timeKey] = 
            _stakedLockedRecords[account][_timeKey].add(lockedArray[ii]);
            if (stakedLockedBalanceFreeTime.length>0){
                uint max = stakedLockedBalanceFreeTime[stakedLockedBalanceFreeTime.length-1];
                if (_timeKey > max){
                    stakedLockedBalanceFreeTime.push(_timeKey);
                }
            }else{
                stakedLockedBalanceFreeTime.push(_timeKey);
            }
            
        }
        //if successed let's update the status
        _addMingAccount(account);
        uint key = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        IFarmCore.UserInfo storage user = _userInfo[account];
        IFarmCore.StakeRecord storage record = user.stakeInfo[key];
        //update user's record
        record.lockedAmount = record.lockedAmount.add(amount);
        record.timeKey = key;
        //update staked amount of this user
        user.lockedAmount = user.lockedAmount.add(amount);
        
        _updateIndexAfterDeposit(account,user, key, amount);

        emit DepositToMining(msg.sender,amount);
    }

    /**
     * @dev override the super calculate method add locked remain amount
     */
    function _getRecordStaked(IFarmCore.StakeRecord memory record)internal pure override returns(uint256){
        return super._getRecordStaked(record)
                .add(record.lockedAmount.sub(record.lockedWithdrawed,"lockedWithdrawed>lockedAmount"));
    }
    /**
     * @dev exit mining by withdraw a part of STokens
     */
    function apiWithdrawLatestLockedSToken(uint256 amount)external{
        address account = address(msg.sender);
        IFarmCore.UserInfo storage user = _userInfo[account];
        require(amount > 0,"you can't withdraw 0 amount");
        require(user.lockedAmount>=amount,"you can't withdraw locked amount larger than you have deposit");
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
            update = record.lockedAmount.sub(record.lockedWithdrawed,"lockedWithdrawed>lockedAmount");
            if (needCost<=update){
                record.lockedWithdrawed = record.lockedWithdrawed.add(needCost);
                update = needCost;
                needCost = 0;
            }else{
                needCost = needCost.sub(update,"locked update > needCost");
                //withdrawed all of this record
                record.lockedWithdrawed = record.lockedAmount;
                //record maybe can be delete, withdrawed all
                if (_getRecordStaked(record)==0){
                    delete user.stakeInfo[timeKey];
                    toDelete[ii-1] = true;
                }
            }
            if (update>0){
                slot.totalStakedInSlot = slot.totalStakedInSlot.sub(update,"locked update>totalStakedInSlot");
            }
            if (update>0 && timeKey<currentKey){
                if (update <= currentSlot.stakedLowestWaterMark){
                    currentSlot.stakedLowestWaterMark = currentSlot.stakedLowestWaterMark.sub(update,"locked amount > stakedLowestWaterMark");
                }else{
                    currentSlot.stakedLowestWaterMark = 0;
                }
                
            }
        }
        if (amount <= currentSlot.totalStaked){
            //maker it safer for withdraw SToken
            currentSlot.totalStaked = currentSlot.totalStaked.sub(amount,"locked amount>totalStaked");
        }

        for(uint256 xx=0;xx<toDelete.length;xx++){
            bool del = toDelete[xx];
            if (del){
                delete user.stakedTimeIndex[xx];
            }
        }

        _safeLockedSTokenTransfer(user,account,amount);
        user.lockedAmount = user.lockedAmount.sub(amount,"amount > lockedAmount");
        emit Withdraw(account,amount); 
    }


    /**
     * @dev 1.check the amount required
     * 1. copy related locked records to recipient,and update related records for farm
     * 2. transfer locked balance to recipient
     * locked token transfer from farm to recipient
     * update recipient's locked record and farm's locked record
     */
    function _safeLockedSTokenTransfer(IFarmCore.UserInfo storage user,address to,uint256 amount)internal{
        uint256 locked = ISTokenERC20(_stoken).linearLockedBalanceOf(address(this));
        if (amount > locked){
            //incase some rounding errors token.transfer(to,locked);
            IPureSTokenERC20(_stoken).transferLockedTo(to,locked);
        }else{
            require(user.lockedAmount>= amount,"transfer locked amount exceeds user's lockedamount");

            uint[] memory stakeLockedTimekeys = _stakedLockedBalanceFreeTimeKeys[to];
            mapping(uint=>uint256) storage stakedRecord = _stakedLockedRecords[to];
            mapping (uint => uint256) storage stakeRecordsCost = _stakedLockedRecordsWithdrawed[to];

            (uint256 canCost,uint256[] memory costArray) = stakedRecord
                .calculateCostLocked(amount,stakeLockedTimekeys,stakeRecordsCost);

            require(canCost>= amount,"transfer locked amount exceeds user's avaliable lockedamount");
            IPureSTokenERC20(_stoken).transferLockedFromFarmWithRecord(to,amount,stakeLockedTimekeys,costArray);
            
            //update farm's staking records
            for (uint256 ii=0;ii<stakeLockedTimekeys.length;++ii){
                uint freeTime = stakeLockedTimekeys[ii];
                uint256 moreCost = costArray[ii];
                stakeRecordsCost[freeTime] = stakeRecordsCost[freeTime].add(moreCost);
            }
        }
    }

//--------------------above is core logical

    /**
     * @dev return the staked total number of SToken
     */
    function totalStaked()public view returns(uint256){
        uint256 amount = 0;
        uint256 len = totalUserMining();
        address account;
        IFarmCore.UserInfo storage user;
        for (uint256 ii=0; ii<len ;++ii){
            account = _getMiningAccountAt(ii);
            user = _userInfo[account];
            amount = amount.add(user.lockedAmount)
            .add(user.amount);
        }
        return amount;
    }
}
