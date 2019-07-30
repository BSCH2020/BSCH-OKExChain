// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../base/MasterChefPlusRebase.sol";
import "../base/MerkleDistributorPolicy.sol";

contract MasterChef is MasterChefPlusRebase,MerkleDistributorPolicy{

    uint256 public TARGET_AIRDROP_SUPPLY;
    uint256 public INIT_AIRDROP_BLOCK_REWARD;
    uint256 public merkleTotalAmount;
    string public name;
    
    uint256 public INIT_AIRDROP_LAST_BLOCK_REWARD;

    function initialize(string memory name_,address rToken_,uint256 target_init_supply_,uint256 stakeMiningSupply_,
        uint256 init_weeks_,uint256 blockSeconds_,uint256 startBlock_,uint256 airdropSupply) public initializer{
        __masterChef_init_chained(name_,rToken_,target_init_supply_,stakeMiningSupply_,init_weeks_,blockSeconds_,startBlock_,airdropSupply);
    }

    function __masterChef_init_chained(string memory name_,address rToken_,uint256 target_init_supply_,uint256 stakeMiningSupply_,
        uint256 init_weeks_,uint256 blockSeconds_,uint256 startBlock_,uint256 airdropSupply)internal initializer{
        __UpgradeableBase_init();
        __miningInitialPolicy_init_unchained(rToken_,target_init_supply_,stakeMiningSupply_,init_weeks_,blockSeconds_,startBlock_);
        __merkleDistributorPolicy_init_unchained(bytes32(0),block.number.add( halfingCycleBlocks*INIT_MINING_WEEKS ),rToken_);
        __masterChef_init_unchained(name_,airdropSupply,stakeMiningSupply_);
    }

    function __masterChef_init_unchained(string memory name_,uint256 airdropSupply,uint256 stakeMiningSupply_)internal initializer{
        name = name_;
        TARGET_AIRDROP_SUPPLY = airdropSupply;
        INIT_AIRDROP_BLOCK_REWARD = airdropSupply.mul(INIT_STAKING_BLOCK_REWARD).div(stakeMiningSupply_);
        setAirDropToken(address(rToken));
        airDropCap = TARGET_AIRDROP_SUPPLY;
    }


    function setAirdropSupply(uint256 supply)public onlyOwner{
        TARGET_AIRDROP_SUPPLY = supply;
        INIT_AIRDROP_BLOCK_REWARD = supply.mul(INIT_STAKING_BLOCK_REWARD).div(TARGET_MINING_SUPPLY);
        airDropCap = TARGET_AIRDROP_SUPPLY;

        uint256 max_end = startBlock + halfingCycleBlocks * INIT_MINING_WEEKS;
        INIT_AIRDROP_LAST_BLOCK_REWARD = TARGET_AIRDROP_SUPPLY.sub(
            getHalfingMiningRewardDuring(startBlock,max_end,INIT_AIRDROP_BLOCK_REWARD,0),"INIT_AIRDROP_LAST_BLOCK_REWARD<all");
    }

    function updateMerkleRootWithTotalFullAmount(bytes32 root,uint256 amount)public onlyOwner{
        merkleRoot = root;
        merkleTotalAmount = amount;
    }

    function pendingAirdrop(uint256 index,address account,uint256 fullAmount,bytes32[] calldata merkleProof)public view returns(uint256){
        // Verify the merkle proof.
        require(merkleTotalAmount>0,"merkleTotalAmount not set by admin");
        bytes32 node = keccak256(abi.encodePacked(index, account, fullAmount));
        require(MerkleProofUpgradeable.verify(merkleProof, merkleRoot, node), "BEP20 MerkleDistributor: Invalid proof.");
        (uint256 allClaimAble,uint256 remaining) = _normalizeAirdropMiningReward();
        uint256 userClaimAble = allClaimAble.mul(fullAmount).div(merkleTotalAmount);
        if (userClaimAble > fullAmount){
            userClaimAble = fullAmount;
        }
        if (userClaimAble<=merkleAlreadyClaimed[account]) return 0;

        userClaimAble = userClaimAble.sub(merkleAlreadyClaimed[account]);
        
        if (userClaimAble>remaining){
            return remaining;
        }
        return userClaimAble;
    }

    function claim(
        uint256 index,
        address account,    
        uint256 fullAmount,
        uint256 claimAmount,
        bytes32[] calldata merkleProof
    ) public virtual override underCap(claimAmount){
        uint256 pending = pendingAirdrop(index,account,fullAmount,merkleProof);
        require(claimAmount<=pending,"claimAmount<=pending");
        // Mark it claimed and send the token.
        _setClaimed(index);
        if (mintOneByOne){
            //need airdrop token give mint right to this contract
            airDropToken.mint(address(this),claimAmount);
        }
        IERC20Upgradeable(address(airDropToken)).safeTransfer(account, claimAmount);
        merkleAlreadyClaimed[account] = merkleAlreadyClaimed[account].add(claimAmount);
        merkleTotalAlreadyClaimed = merkleTotalAlreadyClaimed.add(claimAmount);
        emit Claimed(index, account, claimAmount);
    }

    function _normalizeAirdropMiningReward() internal virtual view returns(uint256,uint256){
        if (startBlock<deployedBlock){
            return (0,0);
        }
        uint256 allClaimAbleRewards = getHalfingMiningRewardDuring(startBlock, block.number,INIT_AIRDROP_BLOCK_REWARD,INIT_AIRDROP_LAST_BLOCK_REWARD);
        uint256 remaining = TARGET_AIRDROP_SUPPLY.sub(merkleTotalAlreadyClaimed,"TARGET_AIRDROP_SUPPLY< merkleTotalAlreadyClaimed");
        if (allClaimAbleRewards>TARGET_AIRDROP_SUPPLY){
            allClaimAbleRewards = TARGET_AIRDROP_SUPPLY;
        }
        return (allClaimAbleRewards,remaining);
    }

    
    
    uint256[50] private __gap;
    
}
