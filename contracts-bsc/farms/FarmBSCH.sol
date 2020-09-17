// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../base/V2FarmWithApiDetails.sol";


contract FarmBSCH is V2FarmWithApiDetails{
    function initialize()override public initializer{
        super.initialize("Bitcoin Standard Circulation Hashrate Token BSCH Farming");
    }
}
