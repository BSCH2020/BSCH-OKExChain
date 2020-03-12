// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../libraries/PeggyToken.sol";
import "../libraries/TokenUtility.sol";
import "../interfaces/ISTokenERC20.sol";

contract LinearReleaseTokenV2 is PeggyToken,ISTokenERC20{
    using SafeMathUpgradeable for uint256;
    using TokenUtility for *;
    /**
     * @dev how much time inall for linear time release minted tokens to unlock
     *
     */
    uint256 public _lockTime;
    /**
     * @dev during how many rounds, the token owner's token could be released
     */
    uint256 public _lockRounds;
    /**
     *
     */
    uint256 public _lockTimeUnitPerSeconds;

    /**
     * @dev statistic data total supply which was mint by time lock
     */
    uint256 private _totalSupplyReleaseByTimeLock;

    /**
     * @dev statistic data released total supply which was mint by time lock already
     */
    uint256 private _totalReleasedSupplyReleaseByTimeLock;
    
    /**
     * @dev store user's time locked balance number
     *
     */
    mapping (address => uint256) public _timeLockedBalances;
    /**
     * @dev store each users' time locked balance records by mint
     * the second array time is when this records' balance could be all freed
     */
    mapping (address => mapping (uint => uint256)) public _timeLockedBalanceRecords;

    /**
     * @dev store each users' time locked balance records by mint which was already cost and the cost sum
     * the second array time is when this records' balance could be all freed
     */
    mapping (address => mapping (uint => uint256)) public _timeLockedBalanceRecordsCost;


    /**
     * @dev store user's balance locked records keys which is when to free all of user's balance
     *
     */
    mapping (address => uint[]) public _balanceFreeTimeKeys;
    
    mapping (address => mapping (bytes32 => uint256)) _balanceFreeTimeKeysIndex;

    mapping(address=>mapping(address=>uint256)) _lockedAllowances;

    event LockedTransfer(address indexed from, address indexed to,uint256 amount);
    event ApproveLocked(address indexed owner,address indexed spender,uint256 amount);
    /**
     * @dev sets 0 initials tokens, the owner, and the supplyController.
     * this serves as the constructor for the proxy but compiles to the
     * memory model of the Implementation contract.
     */
    function initialize(string memory name, string memory symbol, address owner,uint256 lockTime,uint256 lockRounds) public virtual initializer {
        require(lockRounds > 0,"Lock Rounds should greater than 0");
        super.initialize(name,symbol,owner);
        _lockTime = lockTime;
        _lockRounds = lockRounds;
        _lockTimeUnitPerSeconds = 86400;//initial:1 day
    }

    /**
     * @dev See {locked allowance}.
     */
    function allowanceLocked(address owner, address spender) external view override returns (uint256) {
        return _lockedAllowances[owner][spender];
    }

    function _timeKeysPush(address account,uint timeKey)internal returns(bool){
        if (!_timeKeysContains(account,timeKey)){
            _balanceFreeTimeKeys[account].push(timeKey);
            _balanceFreeTimeKeysIndex[account][bytes32(timeKey)] = _balanceFreeTimeKeys[account].length;
            return true;
        }else{
            return false;
        }
    }

    function _timeKeysContains(address account,uint timeKey)internal view returns(bool){
        return _balanceFreeTimeKeysIndex[account][bytes32(timeKey)]!=0;
    }
    function _timeKeysRemove(address account,uint timeKey)internal returns(bool){
        uint256 valueIndex = _balanceFreeTimeKeysIndex[account][bytes32(timeKey)];
        if (valueIndex!=0){
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = _balanceFreeTimeKeys[account].length - 1;

            uint lastvalue = _balanceFreeTimeKeys[account][lastIndex];

            _balanceFreeTimeKeys[account][toDeleteIndex] = lastvalue;
            _balanceFreeTimeKeysIndex[account][bytes32(lastvalue)] = toDeleteIndex+1;
            _balanceFreeTimeKeys[account].pop();
            delete _balanceFreeTimeKeysIndex[account][bytes32(timeKey)];
            return true;
        }else{
            return false;
        }
    }

    function mintWithTimeLock(address account, uint256 amount) public virtual{
        require(hasRole(MINTER_ROLE, _msgSender()), "LinearReleaseToken: must have minter role to mint");
        require(account != address(0), "ERC20: mint to the zero address");
        if (_lockTime>0){
            uint freeTime = block.timestamp + _lockTime * _lockTimeUnitPerSeconds;
            _timeKeysPush(account, freeTime);

            mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
            records[freeTime] = records[freeTime].add(amount);
            _timeLockedBalances[account] = _timeLockedBalances[account].add(amount);  
            _totalSupplyReleaseByTimeLock = _totalSupplyReleaseByTimeLock.add(amount);  
        }
        super.mint(account,amount);
    }

    function linearLockedBalanceOf(address account) external view override returns (uint256){
        return _timeLockedBalances[account];
    }
    function _linearLockedBalanceOf(address account) public view returns (uint256){
        return _timeLockedBalances[account];
    }
    /**
     * @dev return how much free tokens the address could be used
     */
    function getFreeToTransferAmount(address account) external view override returns (uint256){
        uint256 balance = balanceOf(account);
        uint256 lockedBalance = _timeLockedBalances[account];
        if (lockedBalance == 0){
            return balance;
        }

        uint[] memory keys = _balanceFreeTimeKeys[account];
        uint256 allFreed = 0;
        mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];
        uint freeTime;
        uint256 lockedBal;
        uint256 alreadyCost;
        uint256 freeAmount;
        for (uint256 ii=0; ii < keys.length; ++ii){
            //_lockUTimenitPerSeconds:days:25*7,rounds:25
            freeTime = keys[ii];
            lockedBal = records[freeTime];
            alreadyCost = recordsCost[freeTime];
            freeAmount = 0;
            if (freeTime<=block.timestamp){
                freeAmount = lockedBal;
            }else{
                //to calculate how much rounds still remain
                // uint256 timePerRound = _lockTime.div(_lockRounds);
                // uint start = freeTime - _lockTime * _lockTimeUnitPerSeconds;
                // uint passed = block.timestamp - start;
                // uint passedRound = passed.div(timePerRound * _lockTimeUnitPerSeconds);
                uint passedRound;
                (freeAmount,passedRound) = freeTime.calculateFreeAmount(lockedBal,
                    _lockRounds,_lockTime,_lockTimeUnitPerSeconds);
            }
            if (freeAmount>alreadyCost){
                allFreed = allFreed.add(freeAmount.sub(alreadyCost,"alreadyCost>freeAmount"));
            }
        }
        if (allFreed < lockedBalance){
            return balance.sub(lockedBalance.sub(allFreed,"allFreed>lockedBalance"),"balance limited");
        }
        return balance;
    }

    /**
     * @dev total supply which was minted by time lock
     */
    function totalSupplyReleaseByTimeLock() external view override returns (uint256) {
        return _totalSupplyReleaseByTimeLock;
    }

    /**
     * @dev total supply which was already released to circulation from locked supply
     */
    function totalReleasedSupplyReleaseByTimeLock() external view override returns (uint256) {
        return _totalReleasedSupplyReleaseByTimeLock;
    }

    /**
     * @dev total remaining locked supply tokens
     */
    function getTotalRemainingSupplyLocked() external view override returns (uint256) {
        return _totalSupplyReleaseByTimeLock.sub(_totalReleasedSupplyReleaseByTimeLock);
    }

    /**
     * @dev admin method to change some parameters
     */
    function changeLockTime(uint256 nLockTime) public onlyOwner{
        _lockTime = nLockTime;
    }

    function changeLockRounds(uint256 nLockRounds) public onlyOwner{
        require(nLockRounds > 0,"Lock Rounds should greater than 0");
        _lockRounds = nLockRounds;
    }

    function changeLockTimeUnitPerSeconds(uint256 nval) public onlyOwner{
        require(nval < 864000000,"LockTimeUnitPerSeconds should less than 10000 days");
        _lockTimeUnitPerSeconds = nval;
    }

    /**
     * @dev check about the time release locked balance
     *
     */
    function _beforeTokenTransfer(address account, address to, uint256 amount) internal virtual override(PeggyToken) nonReentrant { 
        super._beforeTokenTransfer(account, to, amount);
        //pass check by mint process
        if(account == address(0)){
            return;
        }
        uint256 balance = balanceOf(account);
        uint256 lockedBalance = _timeLockedBalances[account];
        if (lockedBalance == 0 || amount > balance){
            //no locked balance or amount greater than whole balance pass check
            return;
        }
        uint256 totalFree = balance.sub(lockedBalance,"Locked ERC20: lockedBalance amount exceeds balance");
        if (amount <= totalFree){
            //amount less than pure unlocked balance
            return;
        }
        //following condition amount > totalFree
        //following step indicates that user want to send part of locked balances which was already unlocked during passed time
        //remain should be no greater than freed amounts
        uint256 remain = amount.sub(totalFree,"totalFree>amount");
        _updateCostLockedAlreadyFreed(account, remain);

    }

    function _updateCostLockedAlreadyFreed(address account,uint256 remain)internal {
        uint[] memory keys = _balanceFreeTimeKeys[account];
        mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];
    
        _timeLockedBalances[account] = _timeLockedBalances[account].sub(remain,"toBeCost>_timeLockedBalances");
        _totalReleasedSupplyReleaseByTimeLock = _totalReleasedSupplyReleaseByTimeLock.add(remain);
        // (uint256 allFreed,uint256[] memory cost) = records
        //     .calculateCostLockedAlreadyFreed(_lockTime,_lockRounds,_lockTimeUnitPerSeconds,remain,keys,recordsCost);

        uint256 allFreed = 0;
        uint256 toBeCost = remain;
        for (uint256 ii=0; ii < keys.length; ++ii){
            if (remain==0){
                break;
            }
            uint freeTime = keys[ii];
            uint256 freeAmount = 0;
            if (freeTime<=block.timestamp){
                freeAmount = records[freeTime];
            }else{
                //to calculate how much rounds still remain
                 uint passedRound;
                (freeAmount,passedRound) = freeTime.calculateFreeAmount(records[freeTime],
                    _lockRounds,_lockTime,_lockTimeUnitPerSeconds);
            }

            {
                uint256 alreadyCost = recordsCost[freeTime];
                uint256 freeToMove = freeAmount.sub(alreadyCost,"already cost > freeAmount");
                allFreed = allFreed.add(freeToMove);
                if (freeToMove >= remain){
                    recordsCost[freeTime] = alreadyCost.add(remain);
                    remain = 0;
                }else{
                    recordsCost[freeTime] = alreadyCost.add(freeToMove);
                    remain = remain.sub(freeToMove,"freeToMove>remain");
                }
            }
            
        }
        require(toBeCost <= allFreed,"user has locked amount,sending amounts exceeds the free amounts");
        //passed lock amount striction check,need to update cost,if not passed, we shouldn;t update the cost array
    }

    

    /**
     * @dev clear our expired and used out mint records to decrease everytime gas consumption when we are sending coins
     *
     */
    // function decreaseGasConsumptionByClearExpiredRecords(address account) public nonReentrant returns (uint256){
    //     uint[] memory keys = _balanceFreeTimeKeys[account];
    //     uint[] memory toBeClear = new uint[](keys.length);
    //     uint256 cleared = 0;
    //     mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
    //     mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];
    //     for (uint256 ii=0; ii < keys.length; ++ii){
    //         uint freeTime = keys[ii];
    //         uint256 lockedBal = records[freeTime];
    //         uint256 alreadyCost = recordsCost[freeTime];
    //         if (lockedBal == alreadyCost){
    //             //this minted coins were all cost, so we can remove this record
    //             toBeClear[ii] = 2;
    //             delete records[freeTime];
    //             delete recordsCost[freeTime];
    //             cleared = cleared.add(1);
    //         }
    //     }
    //     for (uint256 ii=0; ii < keys.length; ++ii){
    //         uint shouldClear = toBeClear[ii];
    //         if (shouldClear>1){
    //             uint timeKey = keys[ii];
    //             _timeKeysRemove(account, timeKey);
    //         }
    //     }
    //     return cleared;
    // }
    function decreaseGasConsumptionByClearExpiredRecords(address account) public nonReentrant returns (uint256){
        return 0;
    }

    function transferLockedFrom(address from,address to,uint256 amount) external nonReentrant override returns(uint[] memory,uint256[] memory) {
        require(to==_msgSender(),"only who receive locked tokens have right to call this method");
        (uint[] memory freeTimeIndex,uint256[] memory locked) = _transferLocked(from, to, amount);
        _approveLocked(from,to,
            _lockedAllowances[from][to].sub(amount,"Locked ERC20: transfer locked amount exceeds allowance")
        );
        return (freeTimeIndex,locked);
    }

    function transferLockedTo(address to,uint256 amount) public nonReentrant virtual returns(uint[] memory,uint256[] memory) {
        (uint[] memory freeTimeIndex,uint256[] memory locked) = _transferLocked(_msgSender(), to, amount);
        return (freeTimeIndex,locked);
    }

    function approveLocked(address spender,uint256 amount) external nonReentrant override returns(bool){
        _approveLocked(_msgSender(), spender, amount);
        return true;
    }

    function _approveLocked(address owner,address spender,uint256 amount) internal virtual{
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _lockedAllowances[owner][spender] = amount;
        emit ApproveLocked(owner,spender,amount);
    }

    /**
     * @dev transfer locked balance from oldest to latest
     * returns a mapping from time=>cost-amount
     */
    function _transferLocked(address account,address recipient,uint256 amount) internal virtual returns(uint[] memory,uint256[] memory){
        require(account != address(0), "Locked ERC20: transfer from the zero address");
        require(recipient != address(0), "Locked ERC20: transfer to the zero address");
        require(balanceOf(account)>=amount,"Locked ERC20: transfer amount exceeds balance 1");
        require(_timeLockedBalances[account]>=amount,"Locked ERC20: transfer amount exceeds balance 2 of locked");
        
        //the following update locked records
        uint[] memory keys = _balanceFreeTimeKeys[account];
        mapping (uint => uint256) storage records = _timeLockedBalanceRecords[account];
        mapping (uint => uint256) storage recordsCost = _timeLockedBalanceRecordsCost[account];
        uint256[] memory cost = records.calculateCostLockedWithoutSum(amount,keys,recordsCost);
        
        _timeLockedBalances[account] = _timeLockedBalances[account].sub(amount, "Locked ERC20: transfer amount exceeds locked balance");
        _transferDirect(account,recipient,amount);
           
        mapping (uint => uint256) storage rcpRecords = _timeLockedBalanceRecords[recipient];
        mapping (uint => uint256) storage rcpRecordsCost = _timeLockedBalanceRecordsCost[recipient];
        uint256 rcpTotalLocked = 0;
        uint256 rcpFreed = 0;
        for (uint256 ii=keys.length; ii > 0; --ii){
            uint256 willTransfer = cost[ii-1];
            if (willTransfer==0){
                break;
            }
            uint freeTime = keys[ii-1];
            if (freeTime<=block.timestamp){
                //if coins was free, just do nothing
                //no need to lock recipient's coins,willTransfer coins set free
                _totalReleasedSupplyReleaseByTimeLock = _totalReleasedSupplyReleaseByTimeLock.add(willTransfer);
                continue;
            }
            _timeKeysPush(recipient, freeTime);
            uint passedRound;

            uint256 tmpAmount;
            //freed coins among this batch
            (tmpAmount,passedRound) = freeTime.calculateFreeAmount(records[freeTime], _lockRounds, _lockTime, _lockTimeUnitPerSeconds);
            //remain freed coins among this batch 
            tmpAmount = tmpAmount.sub(recordsCost[freeTime]);
            if (tmpAmount>=willTransfer){
                //from address view it like transfered free amount coins unfreed coins
                recordsCost[freeTime] = recordsCost[freeTime].add(willTransfer);
                //no need to lock recipient's coins,willTransfer coins set free
                _totalReleasedSupplyReleaseByTimeLock = _totalReleasedSupplyReleaseByTimeLock.add(willTransfer);
                continue;
            }
            //freeAmount<willTransfer, willTransfer = freed + still_locked
            //freeAmount coins are set free
            _totalReleasedSupplyReleaseByTimeLock = _totalReleasedSupplyReleaseByTimeLock.add(tmpAmount);
            {
                tmpAmount = willTransfer.sub(tmpAmount);
                //need lock recipients' coins in a total way at the same time
                rcpTotalLocked = rcpTotalLocked.add(tmpAmount);
                {
                    (uint256 toStillLocked,uint256 freed) = __reduceAccountFreedCoins(passedRound,freeTime,rcpRecords,rcpRecordsCost);
                    tmpAmount = tmpAmount.add(toStillLocked);
                    rcpFreed = rcpFreed.add(freed);
                }
                __toLockAccountCoinsWithPassedRound(tmpAmount,passedRound,freeTime,rcpRecords,rcpRecordsCost);
                
                tmpAmount = records[freeTime].sub(recordsCost[freeTime]).sub(willTransfer);
                __toLockAccountCoinsWithPassedRound(tmpAmount,passedRound,freeTime,records,recordsCost);
            }
            
        }
        emit LockedTransfer(account,recipient,amount);
        //in order to save gas free,access storage at least
        amount = _timeLockedBalances[recipient];
        amount = amount.add(rcpTotalLocked);
        amount = amount.sub(rcpFreed);
        _timeLockedBalances[recipient] = amount;
        return (keys,cost);
    }

    function __toLockAccountCoinsWithPassedRound(uint256 remainLocked,uint passedRound,uint256 freeTime,
            mapping (uint => uint256) storage records,
            mapping (uint => uint256) storage recordsCost)internal{
        uint256 totalLocked = remainLocked.mul(_lockRounds).div(_lockRounds.sub(passedRound));
        records[freeTime] = totalLocked;
        recordsCost[freeTime] = totalLocked.sub(remainLocked);
    }

    function __reduceAccountFreedCoins(uint passedRound,uint256 freeTime,
            mapping (uint => uint256) storage records,
            mapping (uint => uint256) storage recordsCost)internal returns(uint256,uint256){
        uint256 freeAmount = records[freeTime].mul(passedRound).div(_lockRounds);
        freeAmount = freeAmount.sub(recordsCost[freeTime]);
        //freeAmount coins set to free
        _totalReleasedSupplyReleaseByTimeLock = _totalReleasedSupplyReleaseByTimeLock.add(freeAmount);
        // _timeLockedBalances[recipient] = _timeLockedBalances[recipient].sub(freeAmount);

        uint256 remainLocked = records[freeTime].sub(recordsCost[freeTime]).sub(freeAmount);
        return (remainLocked,freeAmount);
    }
}


