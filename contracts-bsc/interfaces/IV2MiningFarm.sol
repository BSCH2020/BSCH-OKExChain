// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../libraries/IFarmCore.sol";

interface IV2MiningFarm{
    function viewUserInfo(address account)external view returns(IFarmCore.V2IUserInfoResult memory);
    function apiDepositRewardFrom(uint256 amount)external;
    function _farmStartedTime()external view returns(uint256);
    function _miniStakePeriodInSeconds()external view returns(uint256);
    function viewRoundSlot(uint timeKey) external view returns(IFarmCore.RoundSlotInfo memory);
}
