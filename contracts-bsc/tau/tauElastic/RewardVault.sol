// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import './ElasticTokenWithStrategy.sol';
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "../../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../../libraries/UpgradeableBase.sol";
interface ITauElasticToken{
    function isAboveWater() external view returns(bool);
    function isUnderWater() external view returns(bool);
}

contract RewardVault is UpgradeableBase{
    using SafeMathInt for int256;
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant MAX_POINTS = uint256(~uint128(0)*2**125);
    address public tauToken;
    struct VaultLog{
        uint256 index;
        uint256 rewardAmount;
        uint256 accumulateAmount;
    }

    mapping(uint256 => VaultLog) private vaultLog;

    mapping(address=>uint256) public userPoints;
    mapping(address=>uint256) public userlastAccum;
    uint256 public allPonits;
    uint256 public lastCleanTime;
    uint256 public EXPAND_BASE = 1e36;

    function adminSetTauToken(address token) public onlyOwner{
        tauToken = token;
    }
    modifier whenAboveWater(){
        require(ITauElasticToken(tauToken).isAboveWater(),"needs above water");
        _;
    }
    modifier onlyTauToken(){
        require(_msgSender() == tauToken,"only tau token");
        _;
    }

    function adminBurnAll()public onlyOwner{
        allPonits = 0;
        lastCleanTime = block.timestamp;
        ElasticTokenWithStrategy(tauToken).burn(IERC20Upgradeable(tauToken).balanceOf(address(this)));
    }

    function noticeUnderWaterSell(uint256 inputReward,uint256 logIndex) external onlyTauToken{
        vaultLog[logIndex].index = logIndex;
        vaultLog[logIndex].rewardAmount = vaultLog[logIndex].rewardAmount.add(inputReward);
    }

    function noticeUnderWaterBuy(uint256 index,address buyer,uint256 amount)external onlyTauToken{
        VaultLog memory log = vaultLog[index];
        if (log.rewardAmount>0 && amount>0){
            uint256 acc = log.accumulateAmount + amount;
            vaultLog[index].accumulateAmount = acc;
            uint256 points = amount.mul(EXPAND_BASE).mul(log.rewardAmount).div(acc);
            if (userlastAccum[buyer]<lastCleanTime){
                userPoints[buyer] = points;   
            }else{
                userPoints[buyer] = userPoints[buyer].add(points);
            }
            allPonits = allPonits.add(points);
            userlastAccum[buyer] = block.timestamp;
        }
    }

    function pendingReward(address account)public view returns(uint256,uint256){
        if (allPonits==0) return (0,0);
        uint256 bal = IERC20Upgradeable(tauToken).balanceOf(account);
        uint256 point = userPoints[account];
        uint256 reward = point.mul(bal).div(allPonits);
        uint256 calimable = reward;
        if (ITauElasticToken(tauToken).isUnderWater()){
            calimable = 0;
        }
        return (reward,calimable);
    }

    function claimReward(address account)public whenAboveWater{
        if (allPonits==0) return;
        uint256 bal = IERC20Upgradeable(tauToken).balanceOf(account);
        uint256 point = userPoints[account];
        uint256 reward = point.mul(bal).div(allPonits);
        IERC20Upgradeable(tauToken).transfer(account, reward);
        userPoints[account] = 0;
        allPonits = allPonits.sub(point);
    }
}
