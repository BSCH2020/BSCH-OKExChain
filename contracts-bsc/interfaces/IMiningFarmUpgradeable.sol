// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../interfaces/IFarm.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../libraries/UpgradeableBase.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";


abstract contract IMiningFarmUpgradeable is UpgradeableBase,IFarm{
    function depositToMining(uint256 amount)external override virtual;
    function depositToMiningBySTokenTransfer(address from,uint256 amount)external override virtual;

    //a string to describe our mining farm
    string public _farmDescription;
    //stake this token to mine reward token
    address public _stoken;
    //which token to be mined by user's stake action
    address public _rewardToken;
    //a timestamp in seconds used as our mining start base time
    uint public _farmStartedTime;
    // a full mining stake period of time in seconds unit
    // if one's stake time was less than this user won't get reward
    uint public _miniStakePeriodInSeconds;
    string public _name;

    function initialize(string memory name)virtual public initializer{
        super.initialize();
        _name = name;
        //initial will be paused, should change parameters and then unpause
        pause();   
    }

    function changeBaseTime(uint time)public onlyOwner{
        require(time>0,"base time should >0");
        _farmStartedTime = time;
    }
    function changeDesc(string memory desc)public onlyOwner{
        _farmDescription = desc;
    }
    
    function changeMiniStakePeriodInSeconds(uint period) public onlyOwner{
        require(period>0,"mining period should >0");
        _miniStakePeriodInSeconds = period;
    }

    function changeRewardToken(address rewardToken)virtual public onlyOwner{
        _rewardToken = rewardToken;
    }
    function changeSToken(address stoken)public onlyOwner{
        _stoken =stoken;
    }
}
