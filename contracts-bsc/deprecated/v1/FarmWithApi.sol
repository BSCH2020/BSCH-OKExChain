// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../../interfaces/IMiningFarm.sol";
import "../../libraries/TokenUtility.sol";

import "./MiningFarm.sol";
import "./FarmAllowLockedToken.sol";


contract FarmWithApi is FarmAllowLockedToken,IMiningFarm{
    using SafeMath for uint256;
    using TokenUtility for *;
    using EnumerableSet for EnumerableSet.AddressSet;
    constructor(Bitcoin Standard Circulation Hashrate TokenToken SToken,IERC20Upgradeable  rewardToken,string memory desc)
        FarmAllowLockedToken(SToken,rewardToken,86400,now,desc) public{   
    }
    /**
     * @dev for lookup slot infomation in store
     */
    function viewRoundSlot(uint timeKey) external override view returns(ISlotInfoResult memory){
        RoundSlotInfo storage round = _roundSlots[timeKey];
        return ISlotInfoResult({
            rewardLastSubmiter:round.rLastSubmiter,
            rewardAmount:round.rAmount,
            rewardAccumulateAmount:round.rAccumulateAmount,
            totalStaked:round.totalStaked,
            stakedLowestWaterMark:round.stakedLowestWaterMark,
            totalStakedInSlot:round.totalStakedInSlot,
            stakedAddresses:round.stakedAddressSet
        });
    }
    /**
     * @dev for lookup ming accounts
     */
    function viewMiningAccounts()external view returns(address[] memory){
        uint256 total = totalUserMining();
        address[] memory addrs = new address[](total);
        for(uint256 ii=0;ii<total;ii++){
            addrs[ii] = getMiningAccountAt(ii);
        }
        return addrs;
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
    function viewUserInfo(address account)external override view returns(IUserInfoResult memory){
        UserInfo storage user = _userInfo[account];
        IStakeRecord[] memory stakeRecords = new IStakeRecord[](user.stakedTimeIndex.length);
        for(uint256 ii=0;ii<user.stakedTimeIndex.length;ii++){
            StakeRecord memory r = user.stakeInfo[user.stakedTimeIndex[ii]];
            stakeRecords[ii].timeKey = r.timeKey;
            stakeRecords[ii].amount = r.amount;
            stakeRecords[ii].lockedAmount = r.lockedAmount;
            stakeRecords[ii].withdrawed = r.withdrawed;
            stakeRecords[ii].lockedWithdrawed = r.lockedWithdrawed;
        }
        return IUserInfoResult({
            amount:user.amount,
            lockedAmount:user.lockedAmount,
            lastUpdateRewardTime:user.lastUpdateRewardTime,
            allTimeMinedBalance:user.allTimeMinedBalance,
            rewardBalanceInpool:user.rewardBalanceInpool,
            stakeInfo:stakeRecords,
            stakedTimeIndex:user.stakedTimeIndex
        });
    }

    /**
     * @dev emergency withdraw reward tokens to owner's account if there is some unusual thing happend
     */
    function emergencyWithdrawReward(uint256 amount) external onlyOwner{
        uint256 bal =_rewardToken.balanceOf(address(this));
        require(bal>=amount,"withdraw amount exceeds the reward token's balance");
        _rewardToken.transfer(owner(),amount);
    }
    /**
     * @dev emergency withdraw hashrate tokens to owner's account if there is some unusual thing happend
     */
    function emergencyWithdrawSToken(uint256 amount) external onlyOwner{
        uint256 bal =_stoken.balanceOf(address(this));
        require(bal>=amount,"withdraw amount exceeds the hashrate token's balance");
        _stoken.transfer(owner(),amount);
    }

    function apiWithdrawAllSToken()external override{
        withdrawAllSToken();
    }
    function apiWithdrawAllLockedSToken()external override{
        withdrawAllLockedSToken();
    }
    function apiWithdrawLatestLockedSToken(uint256 amount)external override{
        withdrawLatestLockedSToken(amount);
    }
    function apiWithdrawLatestSToken(uint256 amount)external override{
        withdrawLatestSToken(amount);
    }

    function apiDepositToMining(uint256 amount)external override{
        depositToMining(amount);
    }
    function apiDepositLockedToMining(uint256 amount) external override{
        depositLockedToMining(amount);
    }

    function apiDepositRewardFromForTime(address account,uint256 amount,uint time) external override{
        depositRewardFromForTime(account,amount,time);
    }
    function apiDepositRewardFrom(uint256 amount)external override{
        depositRewardFromForYesterday(amount);
    }
    function apiClaimAllReward(address account)external override{
        claimAllReward(account);
    }
    function apiClaimAmountOfReward(address account,uint256 amount,bool reCalculate)external override{
        claimAmountOfReward(account,amount,reCalculate);
    }
    
    function viewGetTotalRewardBalanceInPool(address account) external view override returns (uint256) {
        return getTotalRewardBalanceInPool(account);
    } 
    function viewMiningRewardIn(uint day)external view override returns (address,uint256,uint256) {
        return miningRewardIn(day);
    }
    function viewTotalClaimedRewardFrom(address account)external view override returns(uint256){
        return totalClaimedRewardFrom(account);
    }
    function viewTotalStaked()external view override returns(uint256) {
        return totalStaked();
    }
    function viewTotalUserMining()external view override returns(uint256) {
        return totalUserMining();
    }
    function viewTotalMinedRewardFrom(address account)external view override returns(uint256) {
        return totalMinedRewardFrom(account);
    }
    function viewTotalRewardInPoolFrom(address account)external view override returns(uint256) {
        return totalRewardInPoolFrom(account);
    }
    function viewTotalRewardInPool()external view override returns(uint256) {
        return totalRewardInPool();
    }

    function viewStakeRecord(address account,uint day)external view override returns (uint,uint256,uint256,uint256,uint256) {
        return stakeRecord(account, day);
    }

    function viewAllTimeTotalMined()external view override returns(uint256){
        return _allTimeTotalMined;
    }
}
