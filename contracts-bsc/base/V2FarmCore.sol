// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./V2FarmUpgradeableAllowLocked.sol";

contract V2FarmCore is V2FarmUpgradeableAllowLocked{
    using SafeMathUpgradeable for uint256;
    using TokenUtility for uint;

    bool public _depositPaused;
    bool public _withdrawPaused;
    bool public _claimPaused;
    
    modifier whenDepositNotPaused() {
        require(!_depositPaused, "_depositPaused: paused");
        _;
    }
    modifier whenWithdrawNotPaused() {
        require(!_withdrawPaused, "_withdrawPaused: paused");
        _;
    }
    modifier whenClaimNotPaused() {
        require(!_claimPaused, "_claimPaused: paused");
        _;
    }
    function setDepositPause(bool input)public needPauseRole{
        _depositPaused = input;
    }
    function setWithdrawPause(bool input)public needPauseRole{
        _withdrawPaused = input;
    }
    function setClaimPause(bool input)public needPauseRole{
        _claimPaused = input;
    }
    
    
    //1.deposit to mine
    function depositToMining(uint256 amount)override external whenNotPaused whenDepositNotPaused{
        __depositToMiningFrom(_msgSender(), amount);
    }
    //1.1.deposit to mine by stoken notify
    function depositToMiningBySTokenTransfer(address from,uint256 amount)override external whenNotPaused whenDepositNotPaused{
        require(address(msg.sender)==address(_stoken),"require callee from stoken,only stoken can activly notice farm to stake other's token to mining");
        __depositToMiningFrom(from, amount);
    }

    //2.exit mining method
    function apiWithdrawLatestSToken(uint256 amount)external whenNotPaused whenWithdrawNotPaused{
        __withdrawLatestSTokenFrom(_msgSender(), amount);
    }

    //3.claim mining reward
    function apiClaimAmountOfReward(address account,uint256 amount,bool reCalculate)external whenNotPaused whenClaimNotPaused{
        __claimAmountOfRewardForToken(_rewardToken,account,amount,reCalculate);
    }
    //3.1.claim mining reward for token
    function apiClaimAmountOfRewardForToken(address token,address account,uint256 amount,bool reCalculate)external whenNotPaused whenClaimNotPaused{
        __claimAmountOfRewardForToken(token,account,amount,reCalculate);
    }

    /**
     * @dev deposit reward token from account to last period
     * == depositRewardFromForYesterday
     * 4.deposit mining reward token
     */
    function apiDepositRewardFrom(uint256 amount)external whenNotPaused{
        require(hasRole(OP_ROLE_REWARD_PROVIDER, _msgSender()),"have no right");
        uint time= block.timestamp.sub(_miniStakePeriodInSeconds);
        uint key = time.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        __depositRewardFromForTime(address(msg.sender),amount,key);
    }
    function apiDepositRewardFromForToken(address token,uint256 amount)external whenNotPaused{
        require(hasRole(OP_ROLE_REWARD_PROVIDER, _msgSender()),"have no right");
        uint time= block.timestamp.sub(_miniStakePeriodInSeconds);
        uint key = time.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        __depositRewardFromForTokenForTime(token,address(msg.sender),amount,key);
    }
    function depositRewardFromForToday(uint256 amount)external whenNotPaused{
        require(hasRole(OP_ROLE_REWARD_PROVIDER, _msgSender()),"have no right");
        uint key = block.timestamp.getTimeKey(_farmStartedTime,_miniStakePeriodInSeconds);
        __depositRewardFromForTime(address(msg.sender),amount,key);
    }
    function apiDepositRewardFromForTime(address account,uint256 amount,uint time) external whenNotPaused{
        require(hasRole(OP_ROLE_REWARD_PROVIDER, _msgSender()),"have no right");
        __depositRewardFromForTime(account, amount, time);
    }

    uint256[50] private __gap;
}
