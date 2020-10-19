// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../../libraries/UpgradeableBase.sol";
import "../../libraries/IFarmCore.sol";
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../../interfaces/IBEP20.sol";

interface IAirdropChef{

}

interface IBlockChef{
    function claimReward(address account,uint256 _pid) external returns(uint256);
    function pendingReward(uint256 _pid, address _user) external view returns (uint256);
}
interface IDailyChef{
    function getTotalRewardBalanceInPoolForToken(address token,address account) external view returns (uint256);
    function apiClaimAmountOfRewardForToken(address token,address account,uint256 amount,bool reCalculate)external;
}

contract MasterCollector is  UpgradeableBase{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeMathUpgradeable for uint256;
    enum ChefType{Block,Daily}

    struct MiningChef{
        uint256 chefType;
        address  chef;
        IBEP20   rToken;
        uint256 pid;
    }
    struct RewardInfo{
        address rToken;
        uint256 amount;
    }
    MiningChef[] public miningChefs;

    mapping(address => MiningChef[]) rewardChefsMap;
    
    EnumerableSetUpgradeable.AddressSet private rewardTokens;

    event ChefAdded(address chef_,uint256 type_,address rToken);
    event ChefRemoved(address chef_,uint256 type_,address rToken);
    event RewardClaimed(address rToken,address account,uint256 amount);
    function removeRewardToken(address rToken_)public onlyOwner{
        if (rewardTokens.contains(rToken_)){
            rewardTokens.remove(rToken_);
        }
    }
    function addRewardToken(address rToken_)public onlyOwner{
        if (!rewardTokens.contains(rToken_)){
            rewardTokens.add(rToken_);
        }
    }
    function viewRewardList()public view returns(address[] memory){
        uint256 len = rewardTokens.length();
        address[] memory list = new address[](len);
        for (uint256 x=0;x<len;x++){
            list[x] = rewardTokens.at(x);
        }
        return list;
    }
    
    function addChef(address chef_,uint256 type_,address rToken_,uint256 pid_) public onlyOwner{
        miningChefs.push(MiningChef({
            chefType:type_,
            chef:chef_,
            rToken:IBEP20(rToken_),
            pid:pid_
        }));

        rewardChefsMap[rToken_].push(MiningChef({
            chefType:type_,
            chef:chef_,
            rToken:IBEP20(rToken_),
            pid:pid_
        }));
        if (!rewardTokens.contains(rToken_)){
            rewardTokens.add(rToken_);
        }
        emit ChefAdded(chef_,type_,rToken_);
    }

    function removeChef(uint256 index_)public onlyOwner{
        if (index_<miningChefs.length){
            MiningChef memory rm = miningChefs[index_];
            uint256 x;
            address rAddr = address(rm.rToken);
            for(x=0;x<rewardChefsMap[rAddr].length;x++){
                if ( rewardChefsMap[rAddr][x].chef == rm.chef && 
                    rewardChefsMap[rAddr][x].pid == rm.pid){
                    break;
                }
            }
            __removeFromArray(rewardChefsMap[rAddr],x);
            __removeFromArray(miningChefs,index_);
            emit ChefRemoved(rm.chef,rm.chefType,rAddr);
        }
    }

    function getMiningChefsLen() public view returns(uint256){
        return miningChefs.length;
    }

    function __removeFromArray(MiningChef[] storage list,uint256 index_)internal{
        if (index_<list.length){
            uint256 lastIndex = list.length-1;
            if (index_!=lastIndex){
                list[index_] = list[lastIndex];
            }
            list.pop();
        }
    }

    function getTotalPendingReward(address rToken,address account) view public returns(uint256) {
        uint256 ii;
        uint256 total = 0;
        for (ii=0;ii<rewardChefsMap[rToken].length;ii++){
            MiningChef memory miningChef = rewardChefsMap[rToken][ii];
            if (miningChef.chefType == uint256(ChefType.Block)){
                total = total.add(__getPendingBlockReward(miningChef,account));
            }else if (miningChef.chefType == uint256(ChefType.Daily)){
                total = total.add(__getPendingDailyReward(miningChef,account));
            }
        }
        return total;
    }

    function __getPendingBlockReward(MiningChef memory miningchef,address account) view public returns(uint256){
        uint256 amount = IBlockChef(miningchef.chef).pendingReward(miningchef.pid,account);
        return amount;
    }

    function __getPendingDailyReward(MiningChef memory miningchef,address account) view public returns(uint256){
        uint256 amount = IDailyChef(miningchef.chef).getTotalRewardBalanceInPoolForToken(address(miningchef.rToken),account);
        return amount;
    }

    function __claimChefsReward(MiningChef memory miningchef,address account) public returns(uint256) {
         if (miningchef.chefType == uint256(ChefType.Block)){
            return IBlockChef(miningchef.chef).claimReward(account,miningchef.pid);
        }else if (miningchef.chefType == uint256(ChefType.Daily)){
            uint256 amount = IDailyChef(miningchef.chef).getTotalRewardBalanceInPoolForToken(address(miningchef.rToken),account);
            if (amount>0){
                IDailyChef(miningchef.chef).apiClaimAmountOfRewardForToken(address(miningchef.rToken),account,amount,true);
            }
            return amount;
        }
        return 0;
    }

    function claimReward(address rToken,address account)public returns(uint256){
        uint256 ii;
        uint256 amount =0;
        for (ii=0;ii<rewardChefsMap[rToken].length;ii++){
            MiningChef memory miningChef = rewardChefsMap[rToken][ii];
            amount = amount.add(__claimChefsReward(miningChef,account));
        }
        return amount;
    }

    function claimAllReward(address account) public returns(RewardInfo[] memory){
        address[] memory list = viewRewardList();
        RewardInfo[] memory result = new RewardInfo[](list.length);

        for (uint256 x=0;x<list.length;x++){
            uint256 amt = claimReward(list[x],account);
            result[x] = RewardInfo({
                rToken:list[x],
                amount:amt
            });
            emit RewardClaimed(list[x],account,amt);
        }
        return result;
    }



    uint256[50] private __gap;
}
