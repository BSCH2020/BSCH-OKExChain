// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./MiningInitialPolicy.sol";
import "../../interfaces/IMiningESTChef.sol";

contract MasterChefPlusRebase is MiningInitialPolicy,IMiningESTChef{
    struct MintMoreRecord{
        uint256 amount;
        uint256 amountPerBlock;
        uint256 startedRebaseMintBlock;
        uint256 endRebaseMintBlock;
    }
    MintMoreRecord[] public mintRebaseRecords;

    address rebasePolicy;
    uint256 public teamRebaseSplit;
    event LogMintMore(uint256 delta,uint256 startBlock,uint256 endBlock,uint256 time);
    event LogShrinked(uint256 delta,uint256 oldTotal,uint256 newTotal);
    modifier onlyRebasePolicy() {
        require(msg.sender == rebasePolicy);
        _;
    }
    function setRebasePolicy(address policy)external onlyOwner{
        rebasePolicy = policy;
    }
    function setTeamRebaseSplit(uint256 split)external onlyOwner{
        //eg: 40/100 *10**12 _getNewExpandBase(), 40 * 10**10 =40% 
        teamRebaseSplit = split;
    }

    function viewMintRebaseRecordslLen()public view returns(uint256){
        return mintRebaseRecords.length;
    }
    //rebase to mint more tokens
    function mintMoreDelta(uint256 delta,uint256 timeInSeconds) external override(IMiningESTChef) onlyRebasePolicy{
        uint256 gap = timeInSeconds.div(BLOCK_MINTING_SECONDS);
        uint256 endBlock = block.number.add(gap);
        mintRebaseRecords.push(MintMoreRecord({
            amount:delta,
            amountPerBlock:delta.div(gap),
            startedRebaseMintBlock:block.number,
            endRebaseMintBlock:endBlock
        }));
        emit LogMintMore(delta,block.number,endBlock,timeInSeconds);
    }

    function shrinkNoticedByPolicy(uint256 delta,uint256 newTotal)external override(IMiningESTChef) onlyRebasePolicy{
        //the chef need not be affected by rebase, so we need mint more tokens to chef in order to make the balance of chef remains the same
        //otherwise the chef's user mining numbers will be broken
        uint256 oldTotal = newTotal.add(delta);
        uint256 afterRebase = rToken.balanceOf(address(this));
        uint256 beforeRebase = afterRebase.mul(oldTotal).div(newTotal);
        if (beforeRebase>afterRebase){
            if (sTokenIsRTokenId>0){
                PoolInfo memory tokenSelfPool = poolInfo[sTokenIsRTokenId-1];
                uint256 oldOutSideBal = tokenSelfPool.totalDepositAmount;
                if (tokenSelfPool.stakedTokenShrinkFactor > 0){
                    oldOutSideBal = oldOutSideBal.mul(tokenSelfPool.stakedTokenShrinkFactor).div(_getNewExpandBase());
                }
                uint256 newOutSideBal = oldOutSideBal.mul(afterRebase).div(beforeRebase);

                // newOutSideBal = tokenSelfPool.totalDepositAmount * (stakedTokenShrinkFactor) /_getNewExpandBase()
                // poolInfo[sTokenIsRTokenId-1].stakedTokenShrinkFactor = oldOutSideBal.mul(afterRebase)
                //     .mul(_getNewExpandBase()).div(beforeRebase).div(tokenSelfPool.totalDepositAmount);

                poolInfo[sTokenIsRTokenId-1].stakedTokenShrinkFactor = newOutSideBal.mul(_getNewExpandBase())
                    .div(tokenSelfPool.totalDepositAmount);
                
                uint256 decreased = oldOutSideBal.sub(newOutSideBal,"decreased sub <0");
                rToken.mint(address(this),(beforeRebase.sub(afterRebase)).sub(decreased,"decreased sub err") );
            }else{
                rToken.mint(address(this),beforeRebase.sub(afterRebase));
            }
        }
        emit LogShrinked(delta,oldTotal,newTotal);
    }
    function getMiningRewardDuring(uint256 from_,uint256 to_,uint256 init_block_reward)override(MiningInitialPolicy) public virtual view returns(uint256,uint256){
        (uint256 reward,uint256 team) = super.getMiningRewardDuring(from_,to_,init_block_reward);
        (uint256 reward1,uint256 team1) = getRebaseInflationRewardDuring(from_,to_);
        return (reward.add(reward1),team.add(team1));
    }

    function getRebaseInflationRewardDuring(uint256 from_,uint256 to_)public virtual view returns(uint256,uint256){
        uint256 reward =0;
        uint256 team = 0;
        if (mintRebaseRecords.length>0){
            MintMoreRecord memory last = mintRebaseRecords[mintRebaseRecords.length-1];
            if (from_ < last.startedRebaseMintBlock ){
                from_ = last.startedRebaseMintBlock;
            }
            if (to_ > last.endRebaseMintBlock){
                to_ = last.endRebaseMintBlock;
            }
            if (to_>from_){
                uint256 rebaseAmount = (to_.sub(from_)).mul(last.amountPerBlock);

                uint256 teamAmount = rebaseAmount.mul(teamRebaseSplit).div(_getNewExpandBase());
                if (teamAmount < rebaseAmount){
                    reward = reward.add( rebaseAmount.sub(teamAmount) );
                    team = team.add(teamAmount);
                }else{
                    team = team.add(rebaseAmount);
                }
            }
        }
        return (reward,team);
    }
    //returns reward token amount for pool, and devaddress
    function _normalizeMiningRewardFor(PoolInfo memory pool) internal override view returns(uint256,uint256){
        (uint256 rewards,uint256 team) = super.getMiningRewardDuring(pool.lastRewardBlock, block.number,INIT_STAKING_BLOCK_REWARD);
        uint256 miningReward = rewards.mul(pool.allocPoint).div(totalAllocPoint);
        team = team.mul(pool.allocPoint).div(totalAllocPoint);

        // uint256 remaining = TARGET_MINING_SUPPLY.mul(pool.allocPoint).div(totalAllocPoint);
        // remaining = remaining.sub(pool.alreadyMined,"remaining < pool.alreadyMined");
        // if (miningReward>remaining){
        //     miningReward = remaining;
        // }
        // need no check again, rebase inflation may exceed the amount

        //after check we calculate rebase inflation rewards
        (uint256 rewards1,uint256 team1) = getRebaseInflationRewardDuring(pool.lastRewardBlock, block.number);
        miningReward = miningReward.add(rewards1.mul(pool.allocPoint).div(totalAllocPoint));
        team = team.add(team1.mul(pool.allocPoint).div(totalAllocPoint));

        return (miningReward,team);
    }


    uint256[50] private __gap;
}
