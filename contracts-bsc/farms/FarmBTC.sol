// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../base/V2FarmWithApiWithUpgrade.sol";


contract FarmBTC is V2FarmWithApiWithUpgrade{
    function initialize()override public initializer{
        super.initialize("Bitcoin Standard Circulation Hashrate Token BTC Farming");
    }
}
