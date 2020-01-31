// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "../interfaces/IMiningFarm.sol";

import "./FarmSAllowLockedTokenUpgradeable.sol";

contract FarmSWithApiUpgradeable is FarmSAllowLockedTokenUpgradeable{
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    /**
     * @dev for lookup slot infomation in store
     */
    function viewRoundSlot(uint timeKey) external view returns(IFarmCore.RoundSlotInfo memory){
        IFarmCore.RoundSlotInfo memory round = _roundSlots[timeKey];
        return round;
    }
    // /**
    //  * @dev for lookup ming accounts
    //  */
    // function viewMiningAccounts()external view returns(address[] memory){
    //     uint256 total = totalUserMining();
    //     address[] memory addrs = new address[](total);
    //     for(uint256 ii=0;ii<total;ii++){
    //         addrs[ii] = _getMiningAccountAt(ii);
    //     }
    //     return addrs;
    // }
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
    function viewUserInfo(address account)external view returns(IFarmCore.IUserInfoResult memory){
        IFarmCore.UserInfo storage user = _userInfo[account];
        IFarmCore.IStakeRecord[] memory stakeRecords = new IFarmCore.IStakeRecord[](user.stakedTimeIndex.length);
        for(uint256 ii=0;ii<user.stakedTimeIndex.length;ii++){
            IFarmCore.StakeRecord memory r = user.stakeInfo[user.stakedTimeIndex[ii]];
            stakeRecords[ii].timeKey = r.timeKey;
            stakeRecords[ii].amount = r.amount;
            stakeRecords[ii].lockedAmount = r.lockedAmount;
            stakeRecords[ii].withdrawed = r.withdrawed;
            stakeRecords[ii].lockedWithdrawed = r.lockedWithdrawed;
        }
        return IFarmCore.IUserInfoResult({
            amount:user.amount,
            lockedAmount:user.lockedAmount,
            lastUpdateRewardTime:user.lastUpdateRewardTime,
            allTimeMinedBalance:user.allTimeMinedBalance,
            rewardBalanceInpool:user.rewardBalanceInpool,
            stakeInfo:stakeRecords,
            stakedTimeIndex:user.stakedTimeIndex
        });
    }



    
}
