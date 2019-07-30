// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

library TokenUtility{
    using SafeMathUpgradeable for uint256;
    /**
     * @dev cost amount of token among balanceFreeTime Keys indexed in records with recordCostRecords
     * return cost keys and cost values one to one 
     * LIFO
     */
    function calculateCostLocked(mapping (uint => uint256) storage records,uint256 toCost,uint[] memory keys,mapping (uint => uint256) storage recordsCost)internal view returns(uint256,uint256[] memory){
        uint256 lockedFreeToMove = 0;
        uint256[] memory cost = new uint256[](keys.length);
        for (uint256 ii=keys.length; ii > 0; --ii){
            //_lockTimeUnitPerSeconds:days:25*7,rounds:25
            if (toCost==0){
                break;
            }
            uint freeTime = keys[ii-1];
            uint256 lockedBal = records[freeTime];
            uint256 alreadyCost = recordsCost[freeTime];
            
            uint256 lockedToMove = lockedBal.sub(alreadyCost,"alreadyCost>lockedBal");

            lockedFreeToMove = lockedFreeToMove.add(lockedToMove);
            if (lockedToMove >= toCost){
                cost[ii-1] = toCost;
                toCost = 0;
            }else{
                cost[ii-1] = lockedToMove;
                toCost = toCost.sub(lockedToMove,"lockedToMove>toCost");
            }
        }
        return (lockedFreeToMove,cost);
    }

    /**
     * @dev a method to get time-key from a time parameter
     * returns time-key and round
     */
    function getTimeKey(uint time,uint256 _farmStartedTime,uint256 _miniStakePeriodInSeconds)internal pure returns (uint){
        require(time>_farmStartedTime,"time should larger than all thing stated time");
        //get the end time of period
        uint md = (time.sub(_farmStartedTime)).mod(_miniStakePeriodInSeconds);
        if (md==0) return time;
        return time.add(_miniStakePeriodInSeconds).sub(md);
    }

    /**
     * @dev cost amount of token among balanceFreeTime Keys indexed in records with recordCostRecords
     * return cost keys and cost values one to one 
     * LIFO
     */
    function calculateCostLockedWithoutSum(mapping (uint => uint256) storage records,uint256 toCost,uint[] memory keys,mapping (uint => uint256) storage recordsCost)internal view returns(uint256[] memory){
        uint256[] memory cost = new uint256[](keys.length);
        uint freeTime;
        uint256 lockedBal;
        uint256 alreadyCost;
        uint256 lockedToMove;
        for (uint256 ii=keys.length; ii > 0; --ii){
            //_lockTimeUnitPerSeconds:days:25*7,rounds:25
            if (toCost==0){
                break;
            }
            freeTime = keys[ii-1];
            lockedBal = records[freeTime];
            alreadyCost = recordsCost[freeTime];
            
            lockedToMove = lockedBal.sub(alreadyCost,"alreadyCost>lockedBal");

            if (lockedToMove >= toCost){
                cost[ii-1] = toCost;
                toCost = 0;
            }else{
                cost[ii-1] = lockedToMove;
                toCost = toCost.sub(lockedToMove,"lockedToMove>toCost");
            }
        }
        require(toCost==0,"require toCost full consumed");
        return cost;
    }

    function calculateFreeAmount(uint freeTime,uint256 lockedBal,uint256 _lockRounds,uint256 _lockTime,uint256 _lockTimeUnitPerSeconds)internal view returns(uint256,uint){
        uint remainTime = freeTime - block.timestamp;
        uint passedRound = _lockRounds.sub( 
            _lockRounds.mul(remainTime)
            .div(_lockTime.mul(_lockTimeUnitPerSeconds)) 
        );
        return (lockedBal.mul(passedRound).div(_lockRounds),passedRound);
    }
}
