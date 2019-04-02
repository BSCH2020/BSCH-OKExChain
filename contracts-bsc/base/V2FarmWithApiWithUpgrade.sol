// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./V2FarmWithApi.sol";

contract V2FarmWithApiWithUpgrade is V2FarmWithApi{
    using TokenUtility for uint;
    using SafeMathUpgradeable for uint256;
    bool public _upgradeDataSuccess;
    uint256 public _upgradeTimeKey;

    modifier beforeUpgradeSuccess() {
        require(!_upgradeDataSuccess, "_upgradeDataSuccess: need to be false");
        require(_upgradeTimeKey!=0,"_upgradeTimeKey==0");
        _;
    }
    function upgradeSetTimeKey(uint256 input)public needPauseRole{
        if (input>0){
            _upgradeTimeKey = input;
        }else{
            _upgradeTimeKey = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
            _upgradeTimeKey = _upgradeTimeKey-_miniStakePeriodInSeconds;
        }
    }
    function upgradeSetSuccess()public needPauseRole{
        _upgradeDataSuccess = true;
    }
    function upgradeBatchFromV1UpdateData(uint256 count,address[] memory accounts,uint256[] memory staked,uint256[] memory rewardInpool)public beforeUpgradeSuccess{
        for (uint256 ii=0;ii<count;++ii){
            upgradeFromV1UpdateData(accounts[ii],staked[ii],rewardInpool[ii]);
        }
    }
    function upgradeAddMiningAccount(address account)public beforeUpgradeSuccess needPauseRole{
        _addMingAccount(account);
    }
    function upgradeFromV1UpdateData(address account,uint256 staked,uint256 rewardInpool)public beforeUpgradeSuccess needPauseRole{
        IFarmCore.StakeRecord storage lastCSR = _userLastCSR[account];
        IFarmCore.V2UserInfo storage user = _userInfo[account];
        IFarmCore.RoundSlotInfo storage slot = _roundSlots[_upgradeTimeKey];
        //update last combined staking record
        
        if (staked>0){
            lastCSR.timeKey = _upgradeTimeKey;
            lastCSR.amount  = staked;
   
            if (user.amount==0){
                _addMingAccount(account);
                slot.stakedAddressSet.push(account);
                user.stakedTimeIndex.push(_upgradeTimeKey);
            }
            // //update user info
            user.amount = staked;
            user.lastUpdateRewardTime = _upgradeTimeKey-_miniStakePeriodInSeconds;
            
            user.stakeInfo[_upgradeTimeKey].timeKey = _upgradeTimeKey;
            user.stakeInfo[_upgradeTimeKey].amount = staked;
        }
        if (rewardInpool>0){
            user.tokens_allTimeMinedBalance[_rewardToken] = rewardInpool;
            user.tokens_rewardBalanceInpool[_rewardToken] = rewardInpool;
        }
    }

    function upgradeFromV1Totals(uint256 alltimeTotalMined,uint256 totalRewardInpool,uint256 lastRewardAmount,uint256 allStaked)public beforeUpgradeSuccess needPauseRole{
        if (_totalRewardInPoolTokens[_rewardToken] ==0){
            _roundSlotsIndex.push(_upgradeTimeKey);
        }

        _allTimeTotalMinedTokens[_rewardToken] = alltimeTotalMined;
        _totalRewardInPoolTokens[_rewardToken] = totalRewardInpool;
        
        uint256 expanded = lastRewardAmount.mul(IFarmCore.AMOUNT_BASE_MULTIPLY);
        _roundSlotsReward[_upgradeTimeKey][_rewardToken].rAmount =  expanded;
        _roundSlotsReward[_upgradeTimeKey][_rewardToken].rAccumulateAmount = totalRewardInpool.mul(IFarmCore.AMOUNT_BASE_MULTIPLY);

        IFarmCore.RoundSlotInfo storage slot = _roundSlots[_upgradeTimeKey];
        slot.totalStaked = allStaked;
        slot.stakedLowestWaterMark = allStaked;
        slot.totalStakedInSlot = allStaked;
    }

    function rootAnyCall(address token,bytes memory data)public needAdminFeature{
        require(hasRole(DEFAULT_ADMIN_ROLE,_msgSender()),"you don't have this right");
        _callOptionalReturn(token,data);
    }
    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(address token, bytes memory data) private{
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }


    //to conforms to old apis
    function viewAllTimeTotalMined()external view returns(uint256){
        return _allTimeTotalMinedTokens[_rewardToken];
    }

    function viewTotalRewardInPoolFrom(address account)public view returns(uint256) {
        return _userInfo[account].tokens_rewardBalanceInpool[_rewardToken];
    }
    function viewTotalRewardInPool()external view returns(uint256){
        return viewTotalRewardInPoolFrom(_msgSender());
    }
    function viewGetTotalRewardBalanceInPool(address account) external view returns (uint256) {
        return getTotalRewardBalanceInPoolForToken(_rewardToken,account);
    }
    function viewTotalClaimedRewardFrom(address account)external view returns(uint256){
        return _userInfo[account].tokens_allTimeRewardClaimed[_rewardToken];
    }
    function apiDepositToMining(uint256 amount)external{
        __depositToMiningFrom(_msgSender(), amount);
    }
    function viewTotalMinedRewardFrom(address account)external view returns(uint256) {
        return _userInfo[account].tokens_allTimeMinedBalance[_rewardToken];
    }
    
    uint256[50] private __gap;
}
