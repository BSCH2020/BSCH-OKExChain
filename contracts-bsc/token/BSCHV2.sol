// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "./Bitcoin Standard Circulation Hashrate TokenTokenV2.sol";


contract BSCHV2 is Bitcoin Standard Circulation Hashrate TokenTokenV2{
    function initialize() public initializer{
        super.initialize("Bitcoin Bitcoin Standard Circulation Hashrate Token Token","BSCH");
    }

    function adminUpgradeDecimal(uint8 decimals_) public onlyOwner{
        _setupDecimals(decimals_);
    }
}
