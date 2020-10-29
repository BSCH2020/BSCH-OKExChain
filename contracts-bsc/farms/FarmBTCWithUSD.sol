// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;
pragma experimental ABIEncoderV2;

import "../base/V2FarmWithApi.sol";


contract FarmBTCWithUSD is V2FarmWithApi{
    function initialize()override public initializer{
        super.initialize("Bitcoin Standard Circulation Hashrate Token Full BTC Farming");
    }
}
