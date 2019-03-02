// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

interface IMiningFarmPure{
    //stake to mine record splited by time period
    struct IStakeRecord{
        uint    timeKey;//when
        // address account;//which account
        uint256 amount;//how much amount SToken staked 
        uint256 lockedAmount;//how much locked amount SToken staked 
        
        uint256 withdrawed;//how much amount SToken withdrawed from this record
        uint256 lockedWithdrawed;//how much locked amount SToken withdrawed from this record
    }
    struct ISlotInfoResult{
        address rewardLastSubmiter;
        uint256 rewardAmount;
        uint256 rewardAccumulateAmount;
        uint256 totalStaked;
        uint256 stakedLowestWaterMark;
        uint256 totalStakedInSlot;
        address[] stakedAddresses;
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
    function viewRoundSlot(uint timeKey) external view returns(ISlotInfoResult memory);
    function viewUserInfo(address account)external view returns(IUserInfoResult memory);
    
    function viewStakeRecord(address account,uint day)external view returns (uint,uint256,uint256,uint256,uint256);
    
    function apiWithdrawAllSToken()external;
    function apiWithdrawAllLockedSToken()external;
    function apiWithdrawLatestLockedSToken(uint256 amount)external;
    function apiWithdrawLatestSToken(uint256 amount)external;

    function apiDepositToMining(uint256 amount)external;
    function apiDepositLockedToMining(uint256 amount) external;

    function apiClaimAllReward(address account)external;
    function apiClaimAmountOfReward(address account,uint256 amount,bool reCalculate)external;
}
