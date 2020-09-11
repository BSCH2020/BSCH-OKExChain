// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./V2FarmCore.sol";

contract V2FarmWithApi is V2FarmCore{
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    /**
     * @dev for lookup slot infomation in store
     */
    function viewRoundSlot(uint timeKey) external view returns(IFarmCore.RoundSlotInfo memory){
        IFarmCore.RoundSlotInfo memory round = _roundSlots[timeKey];
        return round;
    }
    function viewRoundSlotsIndex()external view returns(uint[] memory){
        return _roundSlotsIndex;
    }
    function viewLastSlotIndex()external view returns(uint){
        if (_roundSlotsIndex.length>0){
            return _roundSlotsIndex[_roundSlotsIndex.length-1];
        }
        return 0 ;
    }
    /**
     * @dev for lookup ming accounts
     */
    function viewUserInfo(address account)external view returns(IFarmCore.V2IUserInfoResult memory){
        IFarmCore.V2UserInfo storage user = _userInfo[account];
        IFarmCore.IStakeRecord[] memory stakeRecords = new IFarmCore.IStakeRecord[](user.stakedTimeIndex.length);
        for(uint256 ii=0;ii<user.stakedTimeIndex.length;ii++){
            IFarmCore.StakeRecord memory r = user.stakeInfo[user.stakedTimeIndex[ii]];
            stakeRecords[ii].timeKey = r.timeKey;
            stakeRecords[ii].amount = r.amount;
            stakeRecords[ii].lockedAmount = r.lockedAmount;
            stakeRecords[ii].withdrawed = r.withdrawed;
            stakeRecords[ii].lockedWithdrawed = r.lockedWithdrawed;
        }
        uint256 count = totalRewardTokenLen();
        IFarmCore.V2IURewardInfo[] memory rewardList = new IFarmCore.V2IURewardInfo[](count);
        
        for (uint256 ii=0;ii<count;++ii){
            address token = rewardTokenAt(ii);
            rewardList[ii].token  = token;
            rewardList[ii].allTimeMinedBalance  = user.tokens_allTimeMinedBalance[token];
            rewardList[ii].rewardBalanceInpool  = user.tokens_rewardBalanceInpool[token];
            rewardList[ii].allTimeRewardClaimed = user.tokens_allTimeRewardClaimed[token];
        }
        return IFarmCore.V2IUserInfoResult({
            amount:user.amount,
            lockedAmount:user.lockedAmount,
            lastUpdateRewardTime:user.lastUpdateRewardTime,
            stakeInfo:stakeRecords,
            stakedTimeIndex:user.stakedTimeIndex,
            rewardInfoList:rewardList
        });
    }
    
    function getTotalRewardBalanceInPool(address account) public view returns (uint256){
        return getTotalRewardBalanceInPoolForToken(_rewardToken,account);
    }

}
