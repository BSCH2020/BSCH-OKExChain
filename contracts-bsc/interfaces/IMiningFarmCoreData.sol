// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./IMiningFarmCoreDataBase.sol";
import "../libraries/IFarmCore.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "../interfaces/IPureSTokenERC20.sol";

abstract contract IMiningFarmCoreData is IMiningFarmCoreDataBase{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IPureSTokenERC20;
    using IFarmCore for *;   

    //user's info
    mapping (address => IFarmCore.UserInfo) public _userInfo;
    /**
     * @dev calculate mined reward during after and before time, from the stake record
     * (after,before]
     * important !!
     */
    function __calculateMinedRewardDuringFor(uint timeKey,uint256 remainStaked,
        uint afterTime,uint beforeTime)internal view returns(uint256){
        uint256 mined = 0;
        uint key = 0;
        uint effectiveAfterTime = afterTime>timeKey? afterTime:timeKey;
        // uint256 rsInfo_amount = 0;
        uint256 seek = 0;
        IFarmCore.RoundSlotInfo storage slot;
        for (uint256 ii=_roundSlotsIndex.length;ii>0;ii--){
            key = _roundSlotsIndex[ii-1];
            if (key>beforeTime){
                continue;
            }
            seek = ii;
            break;
        }

        for (uint256 ii=seek;ii>0;ii--){
            key = _roundSlotsIndex[ii-1];
            if (key<=effectiveAfterTime){
                break;
            }  
            slot = _roundSlots[key];    
            if (slot.rAmount!=0 && slot.stakedLowestWaterMark!=0){
                //calculate this period of mining reward
                mined = mined.add(slot.rAmount.div(slot.stakedLowestWaterMark));
            }
        }
        return mined.mul(remainStaked);
    }

    function _updateIndexAfterDeposit(address account,IFarmCore.UserInfo storage user,uint key,uint256 amount)internal {
        //update round slot
        IFarmCore.RoundSlotInfo storage slot = _roundSlots[key];
        //update indexes
        uint maxLast = 0;
        if (user.stakedTimeIndex.length>0){
            maxLast = user.stakedTimeIndex[user.stakedTimeIndex.length-1];
        }
        slot.totalStakedInSlot = slot.totalStakedInSlot.add(amount);
        if (maxLast<key){
            //first time to stake in this slot
            slot.stakedAddressSet.push(account);
            user.stakedTimeIndex.push(key);   
        }

        _initOrUpdateLowestWaterMarkAndTotalStaked(key,amount);
    }

    function _initOrUpdateLowestWaterMarkAndTotalStaked(uint nextKey,uint256 amount)internal virtual{
        uint slotMaxLast = 0;
        IFarmCore.RoundSlotInfo storage slot = _roundSlots[nextKey];
        if (_roundSlotsIndex.length>0){
            slotMaxLast = _roundSlotsIndex[_roundSlotsIndex.length-1];
        }
        if (slotMaxLast<nextKey){
            _roundSlotsIndex.push(nextKey);
            if (slotMaxLast!=0){
                //we have previous ones
                IFarmCore.RoundSlotInfo storage previouSlot = _roundSlots[slotMaxLast];
                slot.totalStaked = previouSlot.totalStaked.add(amount);
                //firsttime init stakedLowestWaterMark
                slot.stakedLowestWaterMark = previouSlot.totalStaked;
            }else{
                //have no previous one
                slot.totalStaked = slot.totalStaked.add(amount);
                slot.stakedLowestWaterMark = 0;
            }
        }else{
            slot.totalStaked = slot.totalStaked.add(amount);
            slot.totalStakedInSlot = slot.totalStakedInSlot.add(amount);
        }
    }

    uint256[50] private __gap;  
}
