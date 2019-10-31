// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./V2FarmWithApi.sol";

contract V2FarmWithApiDetails is V2FarmWithApi{
    function rootAnyCall(address token,bytes memory data)public needAdminFeature{
        require(hasRole(DEFAULT_ADMIN_ROLE,_msgSender()),"you don't have this right");
        _callOptionalReturn(token,data);
    }
    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(address token, bytes memory data) private{
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }

    //to conforms to old apis
    function viewAllTimeTotalMined()external view returns(uint256){
        return _allTimeTotalMinedTokens[_rewardToken];
    }
    function viewTotalRewardInPoolFrom(address account)public view returns(uint256) {
        return _userInfo[account].tokens_rewardBalanceInpool[_rewardToken];
    }
    function viewTotalRewardInPool()external view returns(uint256){
        return viewTotalRewardInPoolFrom(_msgSender());
    }
    function viewGetTotalRewardBalanceInPool(address account) external view returns (uint256) {
        return getTotalRewardBalanceInPoolForToken(_rewardToken,account);
    }
    function viewTotalClaimedRewardFrom(address account)external view returns(uint256){
        return _userInfo[account].tokens_allTimeRewardClaimed[_rewardToken];
    }
    function apiDepositToMining(uint256 amount)external{
        __depositToMiningFrom(_msgSender(), amount);
    }
    function viewTotalMinedRewardFrom(address account)external view returns(uint256) {
        return _userInfo[account].tokens_allTimeMinedBalance[_rewardToken];
    }
    
    uint256[50] private __gap;
}
