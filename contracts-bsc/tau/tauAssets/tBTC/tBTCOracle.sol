// SPDX-License-Identifier: MIT
pragma solidity>=0.6.9;

import '../../oracle/ManagedOracle.sol';

contract tBTCOracle is ManagedOracle{
    using SafeMathUpgradeable for uint256;
    
    function initialize()override public initializer{
        super.initialize("tBTC-Price-Oracle",1* 10**18);
    }
}
