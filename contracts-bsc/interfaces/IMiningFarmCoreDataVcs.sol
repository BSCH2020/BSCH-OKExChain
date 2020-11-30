// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./IMiningFarmCoreDataBase.sol";
import "../libraries/IFarmCore.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "../interfaces/IPureSTokenERC20.sol";

abstract contract IMiningFarmCoreDataVcs is IMiningFarmCoreDataBase{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IPureSTokenERC20;
    using IFarmCore for *;
    bytes32 public constant OP_ROLE_MODIFY_RTOKEN_LIST  = keccak256("OP_ROLE_MODIFY_RTOKEN_LIST");
    bytes32 public constant OP_ROLE_REWARD_PROVIDER = keccak256("OP_ROLE_REWARD_PROVIDER");
    //user's info
    mapping (address => IFarmCore.V2UserInfo) public _userInfo;
    //time-key => RewardInfo
    mapping (uint=>mapping(address=>IFarmCore.V2RewardInfo))  public _roundSlotsReward;
    mapping (uint=>EnumerableSetUpgradeable.AddressSet) private _timeRewardTokenList;

    mapping (address=>uint256) public _allTimeTotalMinedTokens;
    mapping (address=>uint256) public _totalRewardInPoolTokens;
    
    EnumerableSetUpgradeable.AddressSet private _rewardTokenList;

    event ClaimToken(address token,address indexed user, uint256 amount);
    event DepositRewardToken(address token,address indexed user, uint256 amount,uint indexed time);
    function initialize(string memory name)override virtual public initializer{
        super.initialize(name);
        _setupRole(OP_ROLE_MODIFY_RTOKEN_LIST, _msgSender());
        _setupRole(OP_ROLE_REWARD_PROVIDER, _msgSender());
    }
    function changeRewardToken(address rewardToken)override public onlyOwner{
        _rewardTokenList.remove(_rewardToken);
        _rewardToken = rewardToken;
        _rewardTokenList.add(_rewardToken);
    }
    function rewardTokenList()public view returns(address[] memory){
        uint256 len = _rewardTokenList.length();
        address[] memory list = new address[](len);
        for (uint256 ii=0;ii<len;++ii){
            list[ii] = (_rewardTokenList.at(ii));
        }
        return list;
    }
    function totalRewardTokenLen()public view returns(uint256){
        return _rewardTokenList.length();
    }
    function addRewardToken(address token)public{
        require(hasRole(OP_ROLE_MODIFY_RTOKEN_LIST, _msgSender()), "rewardToken right error");
        _rewardTokenList.add(token);
    }
    function delRewardToken(address token)public{
        require(hasRole(OP_ROLE_MODIFY_RTOKEN_LIST, _msgSender()), "rewardToken right error");
        _rewardTokenList.remove(token);
    }
    function rewardTokenAt(uint256 ii)public view returns(address){
        return _rewardTokenList.at(ii);
    }

    function _getRewardTokenAt(uint time,uint256 ii)public view returns (address){
        return _timeRewardTokenList[time].at(ii);
    }
    function _addRewardToken(uint time,address token)internal{
        _timeRewardTokenList[time].add(token);
    }

    function _countRewardToken(uint time)public view returns(uint256){
        return _timeRewardTokenList[time].length();
    }
    

    /**
     * @dev calculate mined reward during after and before time, from the stake record
     * (after,before]
     * important !!
     */
    function __calculateMinedRewardDuringForToken(address token,uint timeKey,uint256 remainStaked,
        uint afterTime,uint beforeTime)internal view returns(uint256){
        uint256 mined = 0;
        uint key = 0;
        uint effectiveAfterTime = afterTime>timeKey? afterTime:timeKey;
        // uint256 rsInfo_amount = 0;
        uint256 seek = 0;
        IFarmCore.RoundSlotInfo storage slot;
        IFarmCore.V2RewardInfo storage rSlot;
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
            rSlot =   _roundSlotsReward[key][token];
            if (rSlot.rAmount!=0 && slot.stakedLowestWaterMark!=0){
                //calculate this period of mining reward
                mined = mined.add(rSlot.rAmount.div(slot.stakedLowestWaterMark));
            }
        }
        return mined.mul(remainStaked);
    }
    function _updateIndexAfterDeposit(address account,IFarmCore.V2UserInfo storage user,uint key,uint256 amount)internal {
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

    }

    function _initOrUpdateLowestWaterMarkAndTotalStaked(uint nextKey,uint256 amount,bool sub)internal{
        uint slotMaxLast = 0;
        IFarmCore.RoundSlotInfo storage slot = _roundSlots[nextKey];
        if (_roundSlotsIndex.length>0){
            slotMaxLast = _roundSlotsIndex[_roundSlotsIndex.length-1];
        }
        if (slotMaxLast<nextKey){
            //first time to init totalstaked and stakedLowestWaterMark
            _roundSlotsIndex.push(nextKey);
            if (slotMaxLast!=0){
                //we have previous ones
                IFarmCore.RoundSlotInfo storage previouSlot = _roundSlots[slotMaxLast];
                if (sub){
                    slot.totalStaked = previouSlot.totalStaked.sub(amount,"previouSlot.totalStaked<amount");
                }else{
                    slot.totalStaked = previouSlot.totalStaked.add(amount);
                }
                //firsttime init stakedLowestWaterMark, deal how much was subbed in outer function
                slot.stakedLowestWaterMark = previouSlot.totalStaked; 
            }else{
                //have no previous one
                slot.totalStaked = slot.totalStaked.add(amount);
                slot.stakedLowestWaterMark = 0;
            }
        }else{
            //meet again
            if (sub){
                slot.totalStaked = slot.totalStaked.sub(amount,"slot.totalStaked<amount");
            }else{
                slot.totalStaked = slot.totalStaked.add(amount);
            }
            
        }
        
    }
    uint256[50] private __gap;  
}
