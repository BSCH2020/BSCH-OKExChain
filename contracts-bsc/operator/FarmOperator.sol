// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "../interfaces/IMiningFarm.sol";
import "../libraries/PeggyToken.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../../3rdParty/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../deprecated/v1/Bitcoin Standard Circulation Hashrate TokenToken.sol";

contract FarmOperator is PeggyToken{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    address public _farmContract;
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
        if ( !hasRole(FARM_OP_ROLE, _msgSender()) && !hasRole(STOKEN_OP_ROLE_MINT,_msgSender()) 
            && !hasRole(STOKEN_OP_ROLE_MINT_APPROVE,_msgSender())){
            return;
        }
        if (hasRole(FARM_OP_ROLE, _msgSender())){
            __doFarmDepositReward(account, to, amount);
        }
        if (hasRole(STOKEN_OP_ROLE_MINT, _msgSender())){
            __doAdminSTokenMintStart(account, to, amount);
        }
        if (hasRole(STOKEN_OP_ROLE_MINT_APPROVE, _msgSender())){
            __doAdminSTokenMintApprove(to,amount);
        }
        if (hasRole(STOKEN_OWNER_SAFE_TRANSFER,_msgSender())){
            __doAdminSTokenOwnerSafeTransfer(to,amount);
        }
    }

    function __doFarmDepositReward(address account, address to, uint256 amount) internal{
        if (to!=address(_farmContract) || address(_farmContract)==address(0)){
            return;
        }
        if (address(_rtokenContract)==address(0)){
            return;
        }
        //check operation right
        require(hasRole(FARM_OP_ROLE, _msgSender()), "FarmOperator: must have FARM_OP_ROLE to distribute reward token");
        require(amount<=balanceOf(account),"amount exceeds opt balance,contact admin to get more OPTs");
        require(amount<=_rtokenContract.balanceOf(address(this)),"amount exceeds farm-op's reward token's balance,please deposit reward token to this contract first");

        //if the transfer destination is our mining farm contract, call increase allowance for reward token first
        //and then call deposit reward for mining farm,this will deposit same amount of reward token to farm's
        //yesterday's slot, ms.sender will be farm-op
        //increased rewardtoken's allowance for farm-op->farm-contract
        _rtokenContract.safeIncreaseAllowance(_farmContract,amount);
        //deposit from farm-op->farm-contract
        IMiningFarm(_farmContract).apiDepositRewardFrom(amount);
    }
    function __doAdminSTokenMintStart(address account, address to, uint256 amount) internal{
        if (to!=address(_stokenContract) || address(_stokenContract)==address(0)){
            return;
        }
        adminSTokenMintStart(account,amount);
    }
    function __doAdminSTokenMintApprove( address to, uint256 amount) internal{
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
    function __doAdminSTokenOwnerSafeTransfer( address to, uint256 amount) internal{
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

        Bitcoin Standard Circulation Hashrate TokenToken(address(_stokenContract)).mint(_pendingMintAccount,_pendingMintAmount);

        _pendingMintAccount = address(0);
        _pendingMintAmount = 0;
    }
    function adminSTokenMintLockedApprove(uint256 amount) public{
        require(hasRole(STOKEN_OP_ROLE_MINT_APPROVE,_msgSender()),"you don't have this right");
        require(_pendingMintAccount!=address(0),"there is no pending mint action");
        require(_pendingMintAmount>0,"pending mint amount should >0");
        require(amount == _pendingMintAmount,"please check the pending mint amount with mint admin, not eq");

        Bitcoin Standard Circulation Hashrate TokenToken(address(_stokenContract)).mintWithTimeLock(_pendingMintAccount,_pendingMintAmount);

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
        Bitcoin Standard Circulation Hashrate TokenToken(address(_stokenContract)).transferOwnership(address(pendingTo));
    }

    function rootSTokenCall(bytes memory data)public{
        require(hasRole(STOKEN_OWNER_SAFE_TRANSFER,_msgSender()),"you don't have this right");
        _callOptionalReturn(_stokenContract,data);
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
}
