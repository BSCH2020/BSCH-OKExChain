// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./IMiningFarmUpgradeable.sol";
import "../libraries/IFarmCore.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "../interfaces/IPureSTokenERC20.sol";

abstract contract IMiningFarmCoreDataBase is IMiningFarmUpgradeable{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IPureSTokenERC20;
    
    using IFarmCore for *;

    //reward records split recorded by round slots 
    //time-key => RoundSlotInfo
    mapping (uint=>IFarmCore.RoundSlotInfo) public _roundSlots;

    //store time-key arrays for slots
    uint[] public _roundSlotsIndex;
    
    //account which is mining in this farm
    EnumerableSetUpgradeable.AddressSet private _miningAccountSet;
    
    event DepositReward(address user, uint256 amount,uint indexed time);    
    event DepositToMining(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    

    //1.mining method
    function __depositToMiningFrom(address account,uint256 amount)virtual internal;
    //2.exit mining method
    function __withdrawLatestSTokenFrom(address account,uint256 amount)virtual internal;
    //3.claim mining reward method
    function __claimAmountOfReward(address account,uint256 amount,bool reCalculate)virtual internal;
    //4.deposit mining reward token
    function __depositRewardFromForTime(address account,uint256 amount,uint time)virtual internal;

    /**
     * @dev return how many user is mining
     */
    function totalUserMining()public view returns(uint256){
        return _miningAccountSet.length();
    }

    function _addMingAccount(address account)internal{
        _miningAccountSet.add(account);
    }
    // function _getMingAccount() internal view returns (EnumerableSetUpgradeable.AddressSet memory){
    //     return _miningAccountSet;
    // }
    function _getMiningAccountAt(uint256 ii)internal view returns (address){
        return _miningAccountSet.at(ii);
    }
    /**
     * @dev for lookup ming accounts
     */
    function viewMiningAccounts()external view returns(address[] memory){
        uint256 total = totalUserMining();
        address[] memory addrs = new address[](total);
        for(uint256 ii=0;ii<total;ii++){
            addrs[ii] = _getMiningAccountAt(ii);
        }
        return addrs;
    }
     /**
     * @dev denote how to calculate the user's remain staked amount for stake record
     * maybe override by inherated contract
     */
    function _getRecordStaked(IFarmCore.StakeRecord memory record)internal pure virtual returns(uint256){
        return record.amount.sub(record.withdrawed,"withdrawed>amount");
    }
    function _safeTokenTransfer(address to,uint256 amount,IERC20Upgradeable token) internal{
        uint256 bal = token.balanceOf(address(this));
        if (amount > bal){
            token.transfer(to,bal);
        }else{
            token.transfer(to,amount);
        }
    }

    /**
     * @dev emergency withdraw reward tokens to owner's account if there is some unusual thing happend
     */
    function emergencyWithdrawReward(uint256 amount) external onlyOwner needAdminFeature{
        uint256 bal = IERC20Upgradeable(_rewardToken).balanceOf(address(this));
        require(bal>=amount,"withdraw amount exceeds the reward token's balance");
        IERC20Upgradeable(_rewardToken).transfer(owner(),amount);
    }
    /**
     * @dev emergency withdraw hashrate tokens to owner's account if there is some unusual thing happend
     */
    function emergencyWithdrawSToken(uint256 amount) external onlyOwner needAdminFeature{
        uint256 bal = IERC20Upgradeable(_stoken).balanceOf(address(this));
        require(bal>=amount,"withdraw amount exceeds the hashrate token's balance");
        IERC20Upgradeable(_stoken).transfer(owner(),amount);
    }
    
    uint256[50] private __gap;  
}
