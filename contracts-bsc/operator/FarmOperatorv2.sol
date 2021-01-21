// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

// import "../interfaces/IMiningFarm.sol";
import "../libraries/PeggyToken.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../interfaces/IPureSTokenERC20.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../interfaces/IV2MiningFarm.sol";
import "../interfaces/IPancakeRouter02.sol";
interface IOrchestra{
    function rebase() external;
}
interface IMasterChef{
    struct StakingInfo{
        uint256 amount;
        uint256 rewardDebt;
    }
    function stakingInfo(uint256 poolId,address account)view external returns(StakingInfo memory);
}
contract FarmOperatorv2 is PeggyToken{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    address public _farmContract;//daily farm
    IERC20Upgradeable public _rtokenContract;
    IERC20Upgradeable public _stokenContract;
    bytes32 public constant FARM_OP_ROLE = keccak256("FARM_OP_ROLE");
    address public _pendingMintAccount;
    uint256 public _pendingMintAmount;
    
    bytes32 public constant STOKEN_OP_ROLE_MINT = keccak256("STOKEN_OP_ROLE_MINT");
    bytes32 public constant STOKEN_OP_ROLE_MINT_APPROVE = keccak256("STOKEN_OP_ROLE_MINT_APPROVE");
    bytes32 public constant STOKEN_OWNER_SAFE_TRANSFER =keccak256("STOKEN_OWNER_TRANSFER");
    
    address public constant ACT_MINT_STOKEN_TAG =0x8888888888888888888888888888888888888888;
    address public constant ACT_MINT_LOCKED_STOKEN_TAG = 0x6666666666666666666666666666666666666666;
    address public constant ACT_MINT_REJECT_STOKEN_TAG = 0x4444444444444444444444444444444444444444;
    uint256 public constant ACT_STOKEN_OWNER_SAFE_TRAN__MNT_TAG = 89.1*1e18;
    bytes32 public COMMIT_ID;
    // n order to make manage bitcoin standard circulation hashrate token token more easy,we use farm op token to achieve some thing
    //especially for easy distribute reward tokens for mining
    address public _farmSelfContract;//daily farm
    address public _pancakeRouter;
    address public _swapRouterIntermediate;
    address public _orchContract;
    address public _masterChef;

    function initialize() public initializer{
        address owner = msg.sender;
        super.initialize("Farm op token","OPT",owner);
        _setupRole(FARM_OP_ROLE, _msgSender());
        _setupRole(STOKEN_OP_ROLE_MINT, _msgSender());
        _setupRole(STOKEN_OWNER_SAFE_TRANSFER, _msgSender());
    }

    function adminChangeCommitId(bytes32 cid)public onlyOwner{
        COMMIT_ID = cid;
    }

    function adminChangeFarm(address farm)public onlyOwner{
        _farmContract = farm;
    }
    function adminChangeSelfFarm(address farm)public onlyOwner{
        _farmSelfContract = farm;
    }
    function adminChangeMasterChef(address chef_)public onlyOwner{
        _masterChef = chef_;
    }

    function adminChangeSwapParam(address router,address intermediate)public onlyOwner{
        _pancakeRouter = router;
        _swapRouterIntermediate = intermediate;
    }
    function adminChangeOrch(address orch_)public onlyOwner{
        _orchContract = orch_;
    }

    function adminChangeRToken(address rtoken)public onlyOwner{
        _rtokenContract = IERC20Upgradeable(rtoken);
    }

    function adminChangeSToken(address stoken)public onlyOwner{
        _stokenContract = IERC20Upgradeable(stoken);
    }

    /**
     * @dev check about the to address, tomake deposit mining reward for mining farm contract
     *
     */
    function _beforeTokenTransfer(address account, address to, uint256 amount) internal virtual override(PeggyToken) nonReentrant { 
        super._beforeTokenTransfer(account, to, amount);
        if ( !hasRole(FARM_OP_ROLE, account) && !hasRole(STOKEN_OP_ROLE_MINT,account) 
            && !hasRole(STOKEN_OP_ROLE_MINT_APPROVE,account)){
            return;
        }
        if (hasRole(FARM_OP_ROLE, account)){
            __doFarmDepositReward(account, to, amount);
            __doRebase(to);
        }
        if (hasRole(STOKEN_OP_ROLE_MINT, account)){
            __doAdminSTokenMintStart(account, to, amount);
        }
        if (hasRole(STOKEN_OP_ROLE_MINT_APPROVE, account)){
            __doAdminSTokenMintApprove(to,amount);
        }
        if (hasRole(STOKEN_OWNER_SAFE_TRANSFER,account)){
            __doAdminSTokenOwnerSafeTransfer(to,amount);
        }
    }

    function __doRebase(address to) internal{
        if (to!=address(_orchContract) || address(_orchContract)==address(0)){
            return;
        }
        IOrchestra(_orchContract).rebase();
    }

    function __doFarmDepositReward(address account, address to, uint256 amount) internal{
        if (to!=address(_farmContract) || address(_farmContract)==address(0)){
            return;
        }
        if (address(_rtokenContract)==address(0)){
            return;
        }
        if (amount==0) return;
        //check operation right
        require(hasRole(FARM_OP_ROLE, _msgSender()), "lack FARM_OP_ROLE");
        require(amount<=balanceOf(account),"opt exceeds0");
        require(amount<=_rtokenContract.balanceOf(address(this)),"rAmount exceeds0");

        (uint256 farmBtc,uint256 farmBSCH) = viewFarmSplit();
        uint256 farmBtcAmount = amount;
        uint256 farmBSCHAmount = 0;
        if (farmBSCH>0){
            farmBtcAmount = farmBtc.mul(amount).div(farmBtc.add(farmBSCH));
            farmBSCHAmount = amount.sub(farmBtcAmount);
        }
        if (farmBtc==0){
            farmBtcAmount = 0;
        }


        if (farmBtcAmount>0){
            __depositFarmBTCAmount(farmBtcAmount);
        }
        if (farmBSCHAmount>0){
            __depositFarmBSCHAmount(farmBSCHAmount);
        }
    }

    function __depositFarmBTCAmount(uint256 amount)internal{
        //if the transfer destination is our mining farm contract, call increase allowance for reward token first
        //and then call deposit reward for mining farm,this will deposit same amount of reward token to farm's
        //yesterday's slot, ms.sender will be farm-op
        //increased rewardtoken's allowance for farm-op->farm-contract
        _rtokenContract.safeIncreaseAllowance(_farmContract,amount);
        //deposit from farm-op->farm-contract
        IV2MiningFarm(_farmContract).apiDepositRewardFrom(amount);
    }
    function __depositFarmBSCHAmount(uint256 amount)internal{
        uint[] memory amounts = __swapBTC2BSCH(amount);
        uint bought = amounts[amounts.length-1];
        _stokenContract.safeIncreaseAllowance(_farmSelfContract,bought);
        IV2MiningFarm(_farmSelfContract).apiDepositRewardFrom(bought);
    }

    function __swapBTC2BSCH(uint256 amountIn)internal returns(uint[] memory){
        uint256 amountOutMin = 0;
        if (_swapRouterIntermediate!=address(0)){
            address[] memory path = new address[](3);
            path[0] = address(_rtokenContract);
            path[1] = _swapRouterIntermediate;
            path[2] = address(_stokenContract);
            _rtokenContract.safeIncreaseAllowance(_pancakeRouter,amountIn);
            return IPancakeRouter01(_pancakeRouter).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), block.timestamp+3600);
        }else{
            address[] memory path = new address[](2);
            path[0] = address(_rtokenContract);
            path[1] = address(_stokenContract);
            _rtokenContract.safeIncreaseAllowance(_pancakeRouter,amountIn);
            return IPancakeRouter01(_pancakeRouter).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), block.timestamp+3600);
        }
    }

    function adminBTC2BSCH(uint256 amount)public onlyOwner returns(uint[] memory){
        require(amount<=_rtokenContract.balanceOf(address(this)),"rAmount exceeds1");
        uint[] memory amounts = __swapBTC2BSCH(amount);
        uint bought = amounts[amounts.length-1];
        IERC20Upgradeable(_stokenContract).transfer(msg.sender, bought);
        return amounts;
    }



    function viewFarmSplit()public view returns(uint256,uint256){
        if (address(_farmContract) == address(0) && address(_farmSelfContract) == address(0)){
            return (0,0);
        }
        if (address(_farmContract) == address(0)){
            return (0,100);
        }
        if (address(_farmSelfContract) == address(0)){
            return (100,0);
        }
        //both are not zero

        uint256 lwm1 = viewLastFarmLowestWaterMark(_farmContract);
        uint256 lwm2 = viewLastFarmLowestWaterMark(_farmSelfContract);

        return (lwm1,lwm2);
    }
    function viewLastFarmLowestWaterMark(address contract_)public view returns(uint256){
        uint256 start1 = IV2MiningFarm(contract_)._farmStartedTime();
        uint256 period1 = IV2MiningFarm(contract_)._miniStakePeriodInSeconds();
        uint key1 = getTimeKey(block.timestamp.sub(period1),start1,period1);
        IFarmCore.RoundSlotInfo memory slot1 = IV2MiningFarm(contract_).viewRoundSlot(key1);
        return slot1.stakedLowestWaterMark;
    }

    function __doAdminSTokenMintStart(address account, address to, uint256 amount) internal{
        if (to!=address(_stokenContract) || address(_stokenContract)==address(0)){
            return;
        }
        adminSTokenMintStart(account,amount);
    }
    function __doAdminSTokenMintApprove(address to, uint256 amount) internal{
        if (address(_stokenContract)==address(0)){
            return;
        }
        if (to==address(ACT_MINT_STOKEN_TAG)){
            adminSTokenMintFreeApprove(amount);
        }else if (to==address(ACT_MINT_LOCKED_STOKEN_TAG)){
            adminSTokenMintLockedApprove(amount);
        }else if (to==address(ACT_MINT_REJECT_STOKEN_TAG)){
            adminSTokenMintReject();
        }
    }
    function __doAdminSTokenOwnerSafeTransfer(address to, uint256 amount) internal{
        if (address(_stokenContract)==address(0) || to==address(0)){
            return;
        }
        if (!hasRole(STOKEN_OP_ROLE_MINT,to)){
            return;
        }
        if (amount == ACT_STOKEN_OWNER_SAFE_TRAN__MNT_TAG){
            adminSTokenOwnerSafeTransfer(to);
        }
    }

    function adminSTokenMintStart(address account,uint256 amount) public {
        require(_pendingMintAccount==address(0),"please finish last start mint action first,pending mint account not 0");
        require(hasRole(STOKEN_OP_ROLE_MINT,_msgSender()),"you don't have this right");
        _pendingMintAccount = account;
        _pendingMintAmount = amount;
    }

    function adminSTokenMintFreeApprove(uint256 amount) public{
        require(hasRole(STOKEN_OP_ROLE_MINT_APPROVE,_msgSender()),"you don't have this right");
        require(_pendingMintAccount!=address(0),"there is no pending mint action");
        require(_pendingMintAmount>0,"pending mint amount should >0");
        require(amount == _pendingMintAmount,"please check the pending mint amount with mint admin, not eq");

        IPureSTokenERC20(address(_stokenContract)).mint(_pendingMintAccount,_pendingMintAmount);

        _pendingMintAccount = address(0);
        _pendingMintAmount = 0;
    }
    function adminSTokenMintLockedApprove(uint256 amount) public{
        require(hasRole(STOKEN_OP_ROLE_MINT_APPROVE,_msgSender()),"you don't have this right");
        require(_pendingMintAccount!=address(0),"there is no pending mint action");
        require(_pendingMintAmount>0,"pending mint amount should >0");
        require(amount == _pendingMintAmount,"please check the pending mint amount with mint admin, not eq");

        IPureSTokenERC20(address(_stokenContract)).mintWithTimeLock(_pendingMintAccount,_pendingMintAmount);

        _pendingMintAccount = address(0);
        _pendingMintAmount = 0;
    }

    function adminSTokenMintReject()public{
        require(hasRole(STOKEN_OP_ROLE_MINT_APPROVE,_msgSender()),"you don't have this right");
        _pendingMintAccount = address(0);
        _pendingMintAmount = 0;
    }

    function adminSTokenOwnerSafeTransfer(address pendingTo) public{
        require(hasRole(STOKEN_OWNER_SAFE_TRANSFER,_msgSender()),"you don't have this right");
        require(address(_stokenContract)!=address(0),"_stokenContract not inited");
        IPureSTokenERC20(address(_stokenContract)).transferOwnership(address(pendingTo));
    }

    function rootSTokenCall(bytes memory data)public{
        require(hasRole(STOKEN_OWNER_SAFE_TRANSFER,_msgSender()),"you don't have this right");
        _callOptionalReturn(_stokenContract,data);
    }

    function getSTokenName() public view returns(string memory){
        return IPureSTokenERC20(address(_stokenContract)).name();
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }

    function govScoreFor(address account) public view returns(uint256){
        IFarmCore.V2IUserInfoResult memory info = IV2MiningFarm(_farmContract).viewUserInfo(account);
        uint256 bal = IPureSTokenERC20(address(_stokenContract)).balanceOf(account);
        bal = bal.add(info.amount).add(info.lockedAmount);
        if (_farmSelfContract!=address(0)){
            IFarmCore.V2IUserInfoResult memory info2 = IV2MiningFarm(_farmSelfContract).viewUserInfo(account);
            bal = bal.add(info2.amount).add(info2.lockedAmount);
        }
        if (_masterChef!=address(0)){
            IMasterChef.StakingInfo memory info3= IMasterChef(_masterChef).stakingInfo(0,account);
            bal = bal.add(info3.amount);
        }
        
        return bal;
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
}
