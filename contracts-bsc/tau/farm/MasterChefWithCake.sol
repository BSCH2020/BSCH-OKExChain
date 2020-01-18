// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./MasterChef.sol";

interface ICakeMasterChef{
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of CAKEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCakePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCakePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
     function deposit(uint256 _pid, uint256 _amount) external;
     function withdraw(uint256 _pid, uint256 _amount) external;
     function pendingCake(uint256 _pid, address _user) external view returns (uint256);
     function userInfo(uint256 _pid, address _user) external view returns(UserInfo memory);
}

contract MasterChefWithCake is MasterChef{

    ICakeMasterChef public _cakePool;
    uint256 public _cakePoolID;
    IBEP20 public _cakeToken;
    
    uint256 public _ourCakePoolID;
    uint256 public _connectFactor;
    PoolInfo public _ourCakePool;

    function setCakeInfo(address pool_,address cake,uint256 cakePoolId_,uint256 ourPoolId_,uint256 factor_,uint256 cakeAllocPoint_)public onlyOwner{
        _cakePool = ICakeMasterChef(pool_);
        _cakeToken = IBEP20(cake);

        _cakePoolID = cakePoolId_;
        _ourCakePoolID = ourPoolId_;
        _ourCakePool.allocPoint = cakeAllocPoint_;
        _connectFactor = factor_;
    }

    function pendingCakeReward(address _user)public view returns (uint256) {
        if (address(_cakePool) == address(0)){
            return 0;
        }
        uint256 ucid = __universalCakePoolID();
        // PoolInfo storage innerPool = poolInfo[_pid];
        PoolInfo storage pool = _ourCakePool;
        StakingInfo storage user = stakingInfo[ucid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 sTokenSupply = __poolSTokenSupply(_ourCakePoolID,pool);

        if (block.number > pool.lastRewardBlock && sTokenSupply != 0) {
            uint256 pending = _cakePool.pendingCake(_cakePoolID,address(this));
            accRewardPerShare = accRewardPerShare.add(pending.mul(_getNewExpandBase()).div(sTokenSupply));
        }
        return (user.amount.mul(pool.accRewardPerShare).div(_getNewExpandBase()).div(_connectFactor)).sub(user.rewardDebt);
    }

    function __universalCakePoolID()public view returns(uint256){
        return _ourCakePoolID.mul(_getNewExpandBase()).add(_cakePoolID);
    }

    function depositAndEarnCake(uint256 _pid, uint256 _amount) public {
        if (_pid!=_ourCakePoolID || address(_cakePool) == address(0)){
            super.deposit(_pid,_amount);
            return;
        }
        uint256 ucid = __universalCakePoolID();
        PoolInfo storage innerPool = poolInfo[_pid];
        PoolInfo storage pool = _ourCakePool;
        StakingInfo storage user = stakingInfo[ucid][msg.sender];
        
        updateCake();
        if (user.amount>0){
            uint256 pending = (user.amount.mul(pool.accRewardPerShare).div(_getNewExpandBase()).div(_connectFactor)).sub(user.rewardDebt);
            if ( pending >0 ){
                safeTokenTransfer(_cakeToken, msg.sender, _amount);
            }
        }

        //should execute before stoken's balance was updated
        __depositAndWhetherTransfer(msg.sender,_pid,_amount,false);

        if (_amount>0){
            //transfer already happened in super
            user.amount = user.amount.add(_amount);
            //innerpool's sToken is the same token of cakepool's _cakePoolID lp token,deposit first then deposit it to cakepool
            innerPool.sToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            _cakePool.deposit(_cakePoolID,_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(_getNewExpandBase()).div(_connectFactor);
    }

    function withdrawAndEarnCake(uint256 _pid, uint256 _amount) public {
        if (_pid!=_ourCakePoolID || address(_cakePool) == address(0)){
            super.withdraw(_pid,_amount);
            return;
        }
        
        uint256 ucid = __universalCakePoolID();
        PoolInfo storage innerPool = poolInfo[_pid];
        PoolInfo storage pool = _ourCakePool;
        StakingInfo storage user = stakingInfo[ucid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updateCake();
        uint256 pending = (user.amount.mul(pool.accRewardPerShare).div(_getNewExpandBase()).div(_connectFactor)).sub(user.rewardDebt);
        if (pending>0){
            safeTokenTransfer(_cakeToken, msg.sender, pending);
        }
        //should execute before stoken's balance was updated
        __withdrawAndWhetherTransfer(msg.sender,_pid,_amount,false);

        if (_amount>0){
            //transfer already happened in super
            user.amount = user.amount.sub(_amount);
            _cakePool.withdraw(_cakePoolID, _amount);
            //innerpool's sToken is the same token of cakepool's _cakePoolID lp token,withdraw from cakepool first then withdraw
            innerPool.sToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(_getNewExpandBase()).div(_connectFactor);
    }

    function updateCake() internal{
        uint256 oldBal = _cakeToken.balanceOf(address(this));
        _cakePool.deposit(_cakePoolID,0);//harvest our contract's cake reward
        // uint256 oldStakeBal = poolInfo[_pid].sToken.balanceOf(address(this));
        uint256 newBal = _cakeToken.balanceOf(address(this));
        if (newBal > oldBal){
            uint256 miningReward = newBal.sub(oldBal);
            ICakeMasterChef.UserInfo memory ours = _cakePool.userInfo(_cakePoolID,address(this));
            uint256 sTokenSupply = ours.amount;
            _ourCakePool.alreadyMined = _ourCakePool.alreadyMined.add(miningReward);
            _ourCakePool.accRewardPerShare = _ourCakePool.accRewardPerShare.add( miningReward.mul(_getNewExpandBase()).div(sTokenSupply) );
        }
        _ourCakePool.lastRewardBlock = block.number;
    }
    function __poolSTokenSupply(uint256 _pid,PoolInfo memory pool)override public view virtual returns(uint256){
        if (_pid!=_ourCakePoolID || address(_cakePool) == address(0)){
            return super.__poolSTokenSupply(_pid,pool);
        }
        //cake pool's balance was in pancake's mining pool
        ICakeMasterChef.UserInfo memory ours = _cakePool.userInfo(_cakePoolID,address(this));
        return ours.amount;
    }

}
