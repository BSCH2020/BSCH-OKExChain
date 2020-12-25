// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "./V2FarmUpgradeableWithVcs.sol";

abstract contract V2FarmUpgradeableAllowLocked is V2FarmUpgradeableWithVcs{
    //if account need to start mining using it's locked tokens,
    //the account should lock this amount first
    uint256 public _miniSeedTokenNeedsForLockedStaking;
    //store each user's locked records
    mapping(address=>mapping(uint=>uint256)) _stakedLockedRecords;
    mapping(address=>uint[]) _stakedLockedBalanceFreeTimeKeys;
    mapping(address=>mapping(uint=>uint256)) _stakedLockedRecordsWithdrawed;


    uint256[50] private __gap; 
}
