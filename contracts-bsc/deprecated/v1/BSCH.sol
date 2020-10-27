// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import "./Bitcoin Standard Circulation Hashrate TokenToken.sol";


contract BSCH is Bitcoin Standard Circulation Hashrate TokenToken{
    function initialize() public initializer{
        super.initialize("StandardBTCHashrateToken","BSCH");
    }
}
