// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "./Bitcoin Standard Circulation Hashrate TokenTokenV2.sol";


contract DAIST is Bitcoin Standard Circulation Hashrate TokenTokenV2{
    function initialize() public initializer{
        super.initialize("DAIST Stablecoin","DAIST");
    }
}
