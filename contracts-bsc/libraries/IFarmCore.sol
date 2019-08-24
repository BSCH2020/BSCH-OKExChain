// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
import "../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

library IFarmCore{
    using SafeMathUpgradeable for uint256;
    uint256 public constant AMOUNT_BASE_MULTIPLY = 1e32;
    //stake to mine record splited by time period
    struct StakeRecord{
        uint    timeKey;//when
        // address account;//which account
        uint256 amount;//how much amount SToken staked 
        uint256 lockedAmount;//how much locked amount SToken staked 
        
        uint256 withdrawed;//how much amount SToken withdrawed from this record
        uint256 lockedWithdrawed;//how much locked amount SToken withdrawed from this record
    } 
    /**
    * @dev period denotes (period start time,period end time], 
    * we use period end time for time-key
    * period end time = period start time + _miniStakePeriodInSeconds
    * to store users' info
    * stored in address key-indexed
    */
    struct UserInfo {
        //how many STokens the user has provided in all
        uint256 amount;
        //how many locked STokens the user has provided in all
        uint256 lockedAmount;

        //when >0 denotes that reward before this time already update into rewardBalanceInpool
        uint lastUpdateRewardTime;

        //all his lifetime mined target token amount
        uint256 allTimeMinedBalance;
        //mining reward balances in pool without widthdraw
        uint256 rewardBalanceInpool;
        //all time reward balance claimed
        uint256 allTimeRewardClaimed;
        //stake info account =>(time-key => staked record)
        mapping(uint => StakeRecord) stakeInfo;
        //store time-key arrays for stakeInfo
        uint[] stakedTimeIndex;
    }

    /**
     * @dev slot stores info of each period's mining info
     */
    struct RoundSlotInfo{
        //mining record submit by admin or submiter
        //MiningReward reward;//reward info in this period
        address rLastSubmiter;
        uint256 rAmount;//how much reward token deposit
        uint256 rAccumulateAmount;
        //before was reward

        uint256 totalStaked;//totalStaked = previous round's totalStaked + this Round's total staked 
        uint256 stakedLowestWaterMark;//lawest water mark for this slot
        
        uint256 totalStakedInSlot;//this Round's total staked
        //store addresses set which staked in this slot
        address[] stakedAddressSet;
    }

    //stake to mine record splited by time period
    struct IStakeRecord{
        uint    timeKey;//when
        // address account;//which account
        uint256 amount;//how much amount SToken staked 
        uint256 lockedAmount;//how much locked amount SToken staked 
        
        uint256 withdrawed;//how much amount SToken withdrawed from this record
        uint256 lockedWithdrawed;//how much locked amount SToken withdrawed from this record
    }
    struct IUserInfoResult{
        //how many STokens the user has provided in all
        uint256 amount;
        //how many locked STokens the user has provided in all
        uint256 lockedAmount;

        //when >0 denotes that reward before this time already update into rewardBalanceInpool
        uint lastUpdateRewardTime;

        //all his lifetime mined target token amount
        uint256 allTimeMinedBalance;
        //mining reward balances in pool without widthdraw
        uint256 rewardBalanceInpool;
        
        //stake info account =>(time-key => staked record)
        IStakeRecord[] stakeInfo;
        //store time-key arrays for stakeInfo
        uint[] stakedTimeIndex;
    }

    /**
    * @dev period denotes (period start time,period end time], 
    * we use period end time for time-key
    * period end time = period start time + _miniStakePeriodInSeconds
    * to store users' info
    * stored in address key-indexed
    */
    struct V2UserInfo {
        //how many STokens the user has provided in all
        uint256 amount;
        //how many locked STokens the user has provided in all
        uint256 lockedAmount;

        //when >0 denotes that reward before this time already update into rewardBalanceInpool
        uint lastUpdateRewardTime;

        //stake info account =>(time-key => staked record)
        mapping(uint => StakeRecord) stakeInfo;
        //store time-key arrays for stakeInfo
        uint[] stakedTimeIndex;

        //all his lifetime mined target token amount
        mapping(address=>uint256) tokens_allTimeMinedBalance;//to distribute more kinds of reward tokens
        //mining reward balances in pool without widthdraw
        mapping(address=>uint256) tokens_rewardBalanceInpool;//to distribute more kinds of reward tokens
        //all time reward balance claimed
        mapping(address=>uint256) tokens_allTimeRewardClaimed;//to distribute more kinds of reward tokens
    }


    struct V2RewardInfo{
        uint256 rAmount;//to distribute more kinds of reward tokens
        uint256 rAccumulateAmount;//to distribute more kinds of reward tokens
    }       
    struct V2IURewardInfo{
        address token;
        uint256 allTimeMinedBalance;
        uint256 rewardBalanceInpool;
        uint256 allTimeRewardClaimed;
    }
    struct V2IUserInfoResult{
        //how many STokens the user has provided in all
        uint256 amount;
        //how many locked STokens the user has provided in all
        uint256 lockedAmount;

        //when >0 denotes that reward before this time already update into rewardBalanceInpool
        uint lastUpdateRewardTime;
        
        //stake info account =>(time-key => staked record)
        IStakeRecord[] stakeInfo;
        //store time-key arrays for stakeInfo
        uint[] stakedTimeIndex;

        V2IURewardInfo[] rewardInfoList;
    }
}
