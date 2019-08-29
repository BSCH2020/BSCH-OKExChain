// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../../libraries/UpgradeableBase.sol";
import "../../interfaces/IBEP20.sol";
import "../../interfaces/IBEP20WithMint.sol";
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

interface IMigratorChef {
    // Perform LP token migration from legacy PancakeSwap to CakeSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to PancakeSwap LP tokens.
    // CakeSwap must mint EXACTLY the same amount of CakeSwap LP tokens or
    // else something bad will happen. Traditional PancakeSwap does not
    // do that so be careful!
    function migrate(IERC20Upgradeable token) external returns (IERC20Upgradeable);
}
contract MiningInitialPolicy is UpgradeableBase{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct StakingInfo{
        uint256 amount;
        uint256 rewardDebt;
    }
    struct PoolInfo{
        IERC20Upgradeable sToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
        uint256 alreadyMined;
        uint256 totalDepositAmount;
        uint256 stakedTokenShrinkFactor;//mul(stakedTokenShrinkFactor).div(EXPAND_BASE) => real staked amount
    }

    //totaldepositamount and user's amount they are on the same scale,comparing to outside ot this contract,
    //outside world balance = totalDepositAmount.mul(stakedTokenShrinkFactor).div(EXPAND_BASE)
    uint256 public constant EXPAND_BASE = 1e12;
    
    uint256 public constant DAY_PER_SECONDS =86400;
    uint256 public constant WEEK_PER_DAYS = 7;
    //INITIAL DAY'S AMOUNT: 2^(INITIAL_MINING_WEEKS-1)/(2^INITIAL_MINING_WEEKS -1 )*7
    uint256 public INIT_MINING_WEEKS;
    uint256 public BLOCK_MINTING_SECONDS;
    uint256 public TARGET_INITIAL_SUPPLY;
    uint256 public TARGET_MINING_SUPPLY;
    uint256 public INIT_STAKING_BLOCK_REWARD;

    
    IBEP20WithMint public rToken;
    uint256 public halfingCycleBlocks;
    uint256 public alreadyMinedReward;
    uint256 public totalMinted;
    uint256 public alreadySentReward;
    uint256 public shrinkedFactor;

    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;
    // Info of each pool.
    PoolInfo[] public poolInfo;

    uint256 public sTokenIsRTokenId;//index+1,default:0,other suitable value is > 0
    
    // Info of each user that stakes tokens to earn reward.
    mapping (uint256 => mapping (address => StakingInfo)) public stakingInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when initial supply mining starts.
    uint256 public startBlock;
    // Dev address.
    address public devaddr;
    uint256 public INIT_MINING_LAST_BLOCK_REWARD;
    
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    function initialize(address rToken_,uint256 target_init_supply_,uint256 miningSupply_,
        uint256 init_weeks_,uint256 blockSeconds_,uint256 startBlock_) public virtual initializer{
        __miningInitialPolicy_init(rToken_,target_init_supply_,miningSupply_,init_weeks_,blockSeconds_,startBlock_);
    }
    function __miningInitialPolicy_init(address rToken_,uint256 target_init_supply_,uint256 miningSupply_,
        uint256 init_weeks_,uint256 blockSeconds_,uint256 startBlock_)internal initializer{
        __UpgradeableBase_init();
        __miningInitialPolicy_init_unchained(rToken_,target_init_supply_,miningSupply_,init_weeks_,blockSeconds_,startBlock_);
    }
    function __miningInitialPolicy_init_unchained(address rToken_,uint256 target_init_supply_,uint256 miningSupply_,
        uint256 init_weeks_,uint256 blockSeconds_,uint256 startBlock_)internal initializer{
        TARGET_INITIAL_SUPPLY = target_init_supply_;
        INIT_MINING_WEEKS = init_weeks_;
        BLOCK_MINTING_SECONDS = blockSeconds_;
        TARGET_MINING_SUPPLY = miningSupply_;
        startBlock = startBlock_;
        rToken = IBEP20WithMint(rToken_);
        halfingCycleBlocks = WEEK_PER_DAYS.mul(DAY_PER_SECONDS).div(BLOCK_MINTING_SECONDS);
        INIT_STAKING_BLOCK_REWARD = _viewInitStakingBlockReward();
        devaddr = _msgSender();
        shrinkedFactor = EXPAND_BASE;
        totalAllocPoint = 0;

        uint256 max_end = startBlock + halfingCycleBlocks * INIT_MINING_WEEKS;
        INIT_MINING_LAST_BLOCK_REWARD 
        // __gap[0]
        = TARGET_MINING_SUPPLY.sub(
            getHalfingMiningRewardDuring(startBlock,max_end,INIT_STAKING_BLOCK_REWARD,0),"TARGET_MINING_SUPPLY<all");
    }
    function setRToken(address token_) public onlyOwner{
        rToken = IBEP20WithMint(token_);
    }
    function setStartBlock(uint256 startBlock_) external onlyOwner{
        startBlock = startBlock_;
    }
    function setTimeParams(uint256 blockSeconds_,uint256 halfingSeconds,uint256 halfingRounds) external onlyOwner{
        BLOCK_MINTING_SECONDS = blockSeconds_;
        halfingCycleBlocks = halfingSeconds.div(BLOCK_MINTING_SECONDS);
        INIT_MINING_WEEKS = halfingRounds;
        INIT_STAKING_BLOCK_REWARD = _viewInitStakingBlockReward();
        uint256 max_end = startBlock + halfingCycleBlocks * INIT_MINING_WEEKS;
        INIT_MINING_LAST_BLOCK_REWARD 
        // __gap[0]
        = TARGET_MINING_SUPPLY.sub(
            getHalfingMiningRewardDuring(startBlock,max_end,INIT_STAKING_BLOCK_REWARD,0),"TARGET_MINING_SUPPLY<all");
    }
    function upgradeExpandBase(uint256 _expand)public onlyOwner{
        require(_expand!=0 && _expand!=EXPAND_BASE,"restrictions");
       
        if (shrinkedFactor ==0 || shrinkedFactor==EXPAND_BASE){
            //upgrade from init
            uint256 length = poolInfo.length;
            for (uint256 pid = 0; pid < length; ++pid) {
                //mul 
                poolInfo[pid].accRewardPerShare = poolInfo[pid].accRewardPerShare.mul(_expand);
            }
        }else{
            uint256 length = poolInfo.length;
            for (uint256 pid = 0; pid < length; ++pid) {
                //mul 
                poolInfo[pid].accRewardPerShare = poolInfo[pid].accRewardPerShare.mul(_expand).div(shrinkedFactor);
            }
        }
        shrinkedFactor = _expand;
        massUpdatePools();
    }

    function _getNewExpandBase()public view returns(uint256){
        if (shrinkedFactor>0 && shrinkedFactor!= EXPAND_BASE){
            return shrinkedFactor.mul(EXPAND_BASE);
        }
        return EXPAND_BASE;
    }

    function setSupplyTargets(uint256 target_mining_supply_,uint256 target_init_supply_) external onlyOwner{
        require(startBlock==0 || block.number < startBlock,"already started");
        TARGET_MINING_SUPPLY = target_mining_supply_;
        TARGET_INITIAL_SUPPLY = target_init_supply_;
        INIT_STAKING_BLOCK_REWARD = _viewInitStakingBlockReward();
        uint256 max_end = startBlock + halfingCycleBlocks * INIT_MINING_WEEKS;
        INIT_MINING_LAST_BLOCK_REWARD 
        // __gap[0]
        = TARGET_MINING_SUPPLY.sub(
            getHalfingMiningRewardDuring(startBlock,max_end,INIT_STAKING_BLOCK_REWARD,0),"TARGET_MINING_SUPPLY<all");
    }
    
    function getUserStakingTokenRemain(uint256 _pid,address account)public view returns(uint256){
        StakingInfo memory user = stakingInfo[_pid][account];
        PoolInfo memory pool = poolInfo[_pid];
        if (pool.stakedTokenShrinkFactor>0){
            return user.amount.mul(pool.stakedTokenShrinkFactor).div(_getNewExpandBase());
        }else{
            return user.amount;
        }
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }
    // Migrate staking token to another staking contract
    function migrate(uint256 _pid) public onlyOwner{
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20Upgradeable sToken = pool.sToken;
        uint256 bal = sToken.balanceOf(address(this));
        sToken.safeApprove(address(migrator), bal);
        IERC20Upgradeable newSToken = migrator.migrate(sToken);
        require(bal == newSToken.balanceOf(address(this)), "migrate: bad");
        pool.sToken = newSToken;
    }
    // Add a new staking token to the pool. Can only be called by the owner.
    // XXX DO NOT add the same staking token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20Upgradeable _stoken, bool _withUpdate) public onlyOwner {
        if(_withUpdate){
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            sToken:_stoken,
            allocPoint:_allocPoint,
            lastRewardBlock:lastRewardBlock,
            accRewardPerShare:0,
            alreadyMined:0,
            totalDepositAmount:0,
            stakedTokenShrinkFactor:0
        }));
        if (address(_stoken) == address(rToken)){
            sTokenIsRTokenId = poolInfo.length;
        }
    }
    // Update the given pool's reward allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
        }
        if (address(poolInfo[_pid].sToken) == address(rToken)){
            sTokenIsRTokenId = _pid+1;
        }
    }    
    


    function _viewInitStakingBlockReward()public view returns(uint256){
        // uint256 dailyBlocks = DAY_PER_SECONDS/BLOCK_MINTING_SECONDS;
        // return TARGET_MINING_SUPPLY.mul(2**(INIT_MINING_WEEKS-1))
        //     .div(2**INIT_MINING_WEEKS-1).div( WEEK_PER_DAYS*dailyBlocks );
        return TARGET_MINING_SUPPLY.mul(2**(INIT_MINING_WEEKS-1))
            .div(2**INIT_MINING_WEEKS-1).div( halfingCycleBlocks );
    }
    //return reward for user,and for team
    function getMiningRewardDuring(uint256 from_,uint256 to_,uint256 init_block_reward) public virtual view returns(uint256,uint256){
        if (startBlock==0){
            return (0,0);
        }
        return (getHalfingMiningRewardDuring(from_,to_,init_block_reward,
        INIT_MINING_LAST_BLOCK_REWARD
        // __gap[0]
        ),0);
    }
    
    function getConstantMiningRewardDuring(uint256 from_,uint256 to_) public virtual view returns(uint256){
        if (from_<=startBlock){
            from_ = startBlock;
        }
        if (to_<=startBlock || from_ >= to_) return 0;
        if (to_ >= startBlock + halfingCycleBlocks * (INIT_MINING_WEEKS+1) ){
            return TARGET_MINING_SUPPLY;
        }
        return to_.sub(from_)
            .mul(TARGET_MINING_SUPPLY)
            .mul(BLOCK_MINTING_SECONDS)
            .div(DAY_PER_SECONDS*WEEK_PER_DAYS*INIT_MINING_WEEKS);
    }
    //(from,to],left open, right close range
    function getHalfingMiningRewardDuring(uint256 from_,uint256 to_,uint256 init_block_reward,uint256 lastBlockReward) public virtual view returns(uint256){
        if (from_<=startBlock){
            from_ = startBlock;
        }
        uint256 max_end = startBlock + halfingCycleBlocks * INIT_MINING_WEEKS;
        uint256 mined = 0;
        if (to_ > max_end ){
            to_ = max_end;
            mined = lastBlockReward;
        }
        if (to_<=startBlock || from_ >= to_) return 0;

        uint256 start = from_.sub(startBlock);
        uint256 end = to_.sub(startBlock);
        uint256 startCycle = start.sub( start.mod(halfingCycleBlocks) ).div(halfingCycleBlocks);
        uint256 endCycle = end.sub(end.mod(halfingCycleBlocks)).div(halfingCycleBlocks);
        
        
        uint256 blockReward = init_block_reward.div(2**startCycle);
        uint256 cyclePeriodStart = halfingCycleBlocks.mul(startCycle);
        // uint256 cyclePeriodEnd = halfingCycleBlocks.mul(startCycle+1);
        
        for (uint256 i=startCycle;i<=endCycle;i++){
            uint256 cyclePeriodEnd = cyclePeriodStart.add(halfingCycleBlocks);
            if (cyclePeriodEnd>end){
                //ended
                mined = mined.add(end.sub(start).mul(blockReward));
                break;
            }
            mined = mined.add((cyclePeriodEnd.sub(start)).mul(blockReward));
            blockReward = blockReward.div(2);
            start = cyclePeriodEnd;
            cyclePeriodStart = cyclePeriodStart.add(halfingCycleBlocks);
        }
        if (mined>TARGET_MINING_SUPPLY){
            return TARGET_MINING_SUPPLY;
        }
        return mined;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public virtual {
        // require(startBlock>0,"startBlock=0,not started");
        PoolInfo storage pool = poolInfo[_pid];
        uint256 sTokenSupply = __poolSTokenSupply(_pid,pool);
        __updatePoolWithStokenSupply(_pid,sTokenSupply);
    }

    function __updatePoolWithStokenSupply(uint256 _pid,uint256 sTokenSupply)internal{
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (sTokenSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        (uint256 miningReward,uint256 team) = _normalizeMiningRewardFor(pool);
        if (miningReward >0){
            rToken.mint(address(this), miningReward);
        }
        if (team>0 && devaddr!=address(0)){
            rToken.mint(address(devaddr), team);
        }
        pool.alreadyMined = pool.alreadyMined.add(miningReward);
        alreadyMinedReward = alreadyMinedReward.add(miningReward);
        totalMinted = totalMinted.add(miningReward).add(team);

        pool.accRewardPerShare = pool.accRewardPerShare.add( miningReward.mul(_getNewExpandBase()).div(sTokenSupply) );
        pool.lastRewardBlock = block.number;
    }

    // View function to see pending BSCHs on frontend.
    function pendingReward(uint256 _pid, address _user) public view returns (uint256) {
        if (startBlock==0){
            return 0;
        }
        PoolInfo storage pool = poolInfo[_pid];
        StakingInfo storage user = stakingInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 sTokenSupply = __poolSTokenSupply(_pid,pool);
        
        if (block.number > pool.lastRewardBlock && sTokenSupply != 0) {
            (uint256 miningReward,) = _normalizeMiningRewardFor(pool);
            accRewardPerShare = accRewardPerShare.add(miningReward.mul(_getNewExpandBase()).div(sTokenSupply));
        }
        return user.amount.mul(accRewardPerShare).div(_getNewExpandBase()).sub(user.rewardDebt,"acc<rewardDebt");
    }

    function claimReward(address account,uint256 _pid) public returns(uint256){
        return __depositAndWhetherTransfer(account,_pid,0,false);
    }

    function __poolSTokenSupply(uint256 _pid,PoolInfo memory pool)public view virtual returns(uint256){
        // return pool.sToken.balanceOf(address(this));
        return pool.totalDepositAmount;
    }
    // Deposit staking tokens to Mining for reward allocation.
    function deposit(uint256 _pid, uint256 _amount) public virtual {
        __depositAndWhetherTransfer(msg.sender,_pid,_amount,true);
    }

    function __depositAndWhetherTransfer(address account,uint256 _pid, uint256 _amount,bool _transfer) internal virtual returns(uint256){
        PoolInfo storage pool = poolInfo[_pid];
        StakingInfo storage user = stakingInfo[_pid][account];
        updatePool(_pid);
        uint256 pending = 0;
        if (user.amount > 0) {
            pending = user.amount.mul(pool.accRewardPerShare).div(_getNewExpandBase()).sub(user.rewardDebt);
            if(pending > 0) {
                safeRewardTransfer(account, pending);
            }
        }
        if(_amount > 0) {
            if (_transfer){
                pool.sToken.safeTransferFrom(address(account), address(this), _amount);
            }
            if (pool.stakedTokenShrinkFactor>0){
                uint256 rebased = _amount.mul(_getNewExpandBase()).div(pool.stakedTokenShrinkFactor);
                user.amount = user.amount.add(rebased);
                pool.totalDepositAmount = pool.totalDepositAmount.add(rebased);
            }else{
                user.amount = user.amount.add(_amount);
                pool.totalDepositAmount = pool.totalDepositAmount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(_getNewExpandBase());
        emit Deposit(account, _pid, _amount);
        return pending;
    }

    // Withdraw staking tokens from Mining.
    function __withdrawAndWhetherTransfer(address account,uint256 _pid, uint256 _amount,bool _transfer) internal virtual {
        PoolInfo storage pool = poolInfo[_pid];
        StakingInfo storage user = stakingInfo[_pid][account];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(_getNewExpandBase()).sub(user.rewardDebt);
        if(pending > 0) {
            safeRewardTransfer(account, pending);
        }
        if(_amount > 0) {
            if (pool.stakedTokenShrinkFactor>0){
                uint256 rebased = _amount.mul(_getNewExpandBase()).div(pool.stakedTokenShrinkFactor);
                user.amount = user.amount.sub(rebased,"rebased exceeds");
                pool.totalDepositAmount = pool.totalDepositAmount.sub(rebased,"rebased exceeds remain");
            }else{
                user.amount = user.amount.sub(_amount,"amt exceeds");
                pool.totalDepositAmount = pool.totalDepositAmount.sub(_amount,"amount exceeds remain");
            }
            
            if (_transfer){
                pool.sToken.safeTransfer(account, _amount);
            }
            
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(_getNewExpandBase());
        emit Withdraw(account, _pid, _amount);
    }

    // Withdraw staking tokens from Mining.
    function withdraw(uint256 _pid, uint256 _amount) public virtual {
        __withdrawAndWhetherTransfer(msg.sender,_pid,_amount,true);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        StakingInfo storage staking = stakingInfo[_pid][msg.sender];
        uint256 amount = staking.amount;
        staking.amount = 0;
        staking.rewardDebt = 0;
        uint256 outSideAmount = amount;
        if (pool.stakedTokenShrinkFactor>0){
            outSideAmount = amount.mul(pool.stakedTokenShrinkFactor).div(_getNewExpandBase());
        }
        pool.sToken.safeTransfer(address(msg.sender), outSideAmount);
        pool.totalDepositAmount = pool.totalDepositAmount.sub(amount,"amount exceeds remain");
        emit EmergencyWithdraw(msg.sender, _pid, outSideAmount);
    }
    //returns reward token amount for pool, and devaddress
    function _normalizeMiningRewardFor(PoolInfo memory pool) internal virtual view returns(uint256,uint256){
        (uint256 rewards,uint256 team) = getMiningRewardDuring(pool.lastRewardBlock, block.number,INIT_STAKING_BLOCK_REWARD);
        uint256 miningReward = rewards.mul(pool.allocPoint).div(totalAllocPoint);
        team = team.mul(pool.allocPoint).div(totalAllocPoint);

        uint256 remaining = TARGET_MINING_SUPPLY.mul(pool.allocPoint).div(totalAllocPoint);
        remaining = remaining.sub(pool.alreadyMined,"remaining < pool.alreadyMined");
        if (miningReward>remaining){
            miningReward = remaining;
        }
        return (miningReward,team);
    }

    function safeRewardTransfer(address _to,uint256 _amount) internal{
        alreadySentReward = alreadySentReward.add(_amount);
        safeTokenTransfer(rToken, _to, _amount);
    }

    function safeTokenTransfer(IBEP20 token,address to_,uint256 amount_) internal{
        uint256 bal = token.balanceOf(address(this));
        if (amount_ > bal){
            token.transfer(to_,bal);
        }else{
            token.transfer(to_,amount_);
        }
    }
    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require( (_msgSender() == devaddr) || (_msgSender()==owner()), "dev: wad?");
        devaddr = _devaddr;
    }    
    uint256[50] private __gap;    
}
