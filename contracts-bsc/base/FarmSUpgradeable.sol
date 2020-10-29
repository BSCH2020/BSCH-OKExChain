// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../libraries/TokenUtility.sol";
import "../interfaces/IFarm.sol";
import "./FarmSCoreUpgradeable.sol";


contract FarmSUpgradeable is FarmSCoreUpgradeable{
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using TokenUtility for uint;
    
    function initialize(string memory name)override public virtual initializer {
        // super.initialize(string(abi.encodePacked("fCredit:",name)),string(abi.encodePacked("fc",symbol)),owner);
        super.initialize(name);
    }
    /**
     * @dev deposit STokens to mine reward tokens
     */
    function depositToMining(uint256 amount)external override{
        __depositToMiningFrom(address(msg.sender), amount);
    }
    function depositToMiningBySTokenTransfer(address from,uint256 amount)external override{
        require(address(msg.sender)==address(_stoken),"require callee from stoken,only stoken can activly notice farm to stake other's token to mining");
        __depositToMiningFrom(from, amount);
    }
    function apiDepositToMining(uint256 amount)external{
        __depositToMiningFrom(address(msg.sender), amount);
    }

    /**
     * @dev deposit reward token from account to last period
     * == depositRewardFromForYesterday
     */
    function apiDepositRewardFrom(uint256 amount)public whenNotPaused{
        uint time= block.timestamp.sub(_miniStakePeriodInSeconds);
        uint key = time.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        __depositRewardFromForTime(address(msg.sender),amount,key);
    }
    function depositRewardFromForToday(uint256 amount)public whenNotPaused{
        uint key = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        __depositRewardFromForTime(address(msg.sender),amount,key);
    }
    function apiDepositRewardFromForTime(address account,uint256 amount,uint time) external whenNotPaused onlyOwner{
        __depositRewardFromForTime(account, amount, time);
    }

    /**
     * @dev exit mining by withdraw STokens
     */
    function apiWithdrawLatestSToken(uint256 amount)external{
        __withdrawLatestSToken(amount);
    }

    /**
     * @dev claim all reward tokens
     */
    function apiClaimAllReward(address account)external{
        uint256 totalMined = getAndUpdateRewardMinedInPool(account);
        __claimAmountOfReward(account,totalMined,false);
    }

    function apiClaimAmountOfReward(address account,uint256 amount,bool reCalculate)external{
        __claimAmountOfReward(account,amount,reCalculate);
    }

    //followings are many view functions to lookup inner data
    function viewGetTotalRewardBalanceInPool(address account) external view returns (uint256){
        uint alreadyMinedTimeKey = _getMaxAlreadyMinedTimeKey(); 
        uint256 old = _userInfo[account].rewardBalanceInpool;
        uint256 mined = getUncalculateRewardBalanceInPoolBefore(account,alreadyMinedTimeKey);
        return old.add(mined);
    }
    /**
     * @dev return the mining records of specific day
     */
    function viewMiningRewardIn(uint day)external view returns (address,uint256,uint256){
        uint key = day.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        IFarmCore.RoundSlotInfo memory slot = _roundSlots[key];
        return (slot.rLastSubmiter,slot.rAmount.div(IFarmCore.AMOUNT_BASE_MULTIPLY),slot.rAccumulateAmount);
    }
    /**
     * @dev return the stake records of specific day
     */
    function viewStakeRecord(address account,uint day)external view returns (uint,uint256,uint256,uint256,uint256) {
        uint key = day.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        IFarmCore.UserInfo storage user = _userInfo[account];
        IFarmCore.StakeRecord memory record = user.stakeInfo[key];
        return (record.timeKey,record.amount,record.lockedAmount,record.withdrawed,record.lockedWithdrawed);
    }
    /**
     * @dev return hown much already mined from account 
     */
    function viewTotalMinedRewardFrom(address account)external view returns(uint256) {
        return _userInfo[account].allTimeMinedBalance;
    }
    function viewTotalClaimedRewardFrom(address account)external view returns(uint256){
        return _userInfo[account].allTimeRewardClaimed;
    }
    /**
     * @dev return hown much already mined from account without widthdraw
     */
    function viewTotalRewardInPoolFrom(address account)external view returns(uint256) {
        return _userInfo[account].rewardBalanceInpool;
    }

/**

    function depositBonusFrom(address account,
        uint256 amount,IERC20 token,
        uint256 startTime,uint256 periodRound)public{
        token.safeTransferFrom(account,address(this),amount);

    }   
 */    
}
